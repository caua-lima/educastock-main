import 'dart:async';
import 'package:firebase_app_check/firebase_app_check.dart';
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

  static Future<void> initialize() async {
    await Firebase.initializeApp(options: _options);

    await _activateAppCheck();

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
