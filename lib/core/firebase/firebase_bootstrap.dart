import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import '../config/app_env.dart';
import '../../firebase_options_dev.dart';
import '../../firebase_options_hml.dart';
import '../../firebase_options_prod.dart';

class FirebaseBootstrap {
  static FirebaseOptions get _options {
    switch (AppEnv.current) {
      case AppEnvironment.dev:
        return DefaultFirebaseOptionsDev.currentPlatform;
      case AppEnvironment.hml:
        return DefaultFirebaseOptionsHml.currentPlatform;
      case AppEnvironment.prod:
        return DefaultFirebaseOptionsProd.currentPlatform;
    }
  }

  /// `--dart-define=USE_EMULATORS=true`: liga o app aos emuladores locais (Auth,
  /// Firestore, Storage). Ambiente isolado de verdade para testar gravações — os nomes
  /// dev/hml/prod hoje apontam para o mesmo projeto Firebase (auditoria A11).
  static const useEmulators = bool.fromEnvironment('USE_EMULATORS');

  static Future<void> initialize() async {
    await Firebase.initializeApp(options: _options);

    if (useEmulators) {
      const host = String.fromEnvironment('EMULATOR_HOST', defaultValue: 'localhost');
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      await FirebaseStorage.instance.useStorageEmulator(host, 9199);
      debugPrint('[EducaStock] usando EMULADORES em $host (nenhum dado real é alterado)');
      return; // sem App Check/Crashlytics no ambiente local
    }

    // Cache local do Firestore: leituras continuam funcionando sem internet. No Android e
    // no iOS isso já é o padrão; na web precisa ser ligado.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    await _activateAppCheck();

    // Crashlytics não tem implementação web: na web os erros continuam no console do
    // navegador (com a causa original), em vez de sumirem num logger que não funciona.
    if (kIsWeb) return;
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  static Future<void> _activateAppCheck() async {
    const webSiteKey = String.fromEnvironment('APP_CHECK_WEB_RECAPTCHA_KEY', defaultValue: '');

    if (kIsWeb && webSiteKey.isEmpty) {
      return;
    }

    final androidProvider = AppEnv.isProd
        ? AndroidProvider.playIntegrity
        : AndroidProvider.debug;
    final appleProvider = AppEnv.isProd
        ? AppleProvider.appAttestWithDeviceCheckFallback
        : AppleProvider.debug;

    await FirebaseAppCheck.instance.activate(
      webProvider: webSiteKey.isNotEmpty
          ? ReCaptchaV3Provider(webSiteKey)
          : null,
      androidProvider: androidProvider,
      appleProvider: appleProvider,
    );
  }
}
