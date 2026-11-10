import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/domain/entities/app_user.dart';
import '../../features/auth/presentation/controllers/auth_provider.dart';
import '../../features/settings/presentation/controllers/system_settings_provider.dart';
import '../router/app_router.dart';
import '../firebase/firebase_providers.dart';
import 'app_messenger.dart';
import 'package:flutter/material.dart';

class PushNotificationService {
  final FirebaseMessaging? _messagingOverride;
  final FirebaseFirestore _firestore;

  FirebaseMessaging get _messaging => _messagingOverride ?? FirebaseMessaging.instance;

  bool _permissionRequested = false;
  bool _navigationBound = false;

  /// Roteador ATUAL (o app recria o GoRouter ao trocar de conta; os listeners
  /// usam sempre o mais recente).
  GoRouter? _router;
  String? _lastUserId;
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;

  AlertsConfig? _alertsConfig;

  PushNotificationService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
  })  : _messagingOverride = messaging,
        _firestore = firestore ?? FirebaseFirestore.instance;

  void updateAlertsConfig(AlertsConfig config) {
    _alertsConfig = config;
  }

  Future<void> configure({
    required GoRouter router,
    required AppUser? user,
  }) async {
    if (!_permissionRequested) {
      _permissionRequested = true;
      try {
        await _messaging.requestPermission();
      } catch (e) {
        // Navegador sem suporte a notificações (ex.: Safari do iPhone fora do modo app).
        debugPrint('[PNS] requestPermission indisponível: $e');
      }
    }

    _router = router;
    if (!_navigationBound) {
      _navigationBound = true;

      // Tocou na notificação: abrir os alertas é o que a pessoa pediu.
      FirebaseMessaging.onMessageOpenedApp.listen((_) {
        _router?.go(AppRoutes.alerts);
      });

      try {
        final initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) _router?.go(AppRoutes.alerts);
      } catch (e) {
        debugPrint('[PNS] getInitialMessage indisponível: $e');
      }

      // Suppress foreground notifications during silent hours
      await _foregroundSub?.cancel();
      _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
        final config = _alertsConfig;
        if (config != null && config.isSilentNow) {
          debugPrint('[PNS] Silent mode active — suppressing foreground message');
          return;
        }
        // App aberto: só avisa, com atalho. Não tira a pessoa do que está fazendo
        // (ex.: um formulário pela metade).
        final title = message.notification?.title ?? 'Novo alerta de validade';
        appMessengerKey.currentState?.showSnackBar(SnackBar(
          content: Text(title),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Ver alertas',
            onPressed: () => _router?.go(AppRoutes.alerts),
          ),
        ));
      });
    }

    if (user == null) {
      _lastUserId = null;
      await _tokenSub?.cancel();
      _tokenSub = null;
      return;
    }

    if (_lastUserId == user.id) return;
    _lastUserId = user.id;

    await _registerCurrentToken(user.id);

    await _tokenSub?.cancel();
    _tokenSub = _messaging.onTokenRefresh.listen((token) async {
      await _saveToken(userId: user.id, token: token);
    });
  }

  /// Notificação recusada/bloqueada ou navegador sem suporte: segue sem push (o app
  /// continua funcionando; os alertas aparecem dentro dele). Antes a exceção escapava.
  Future<void> _registerCurrentToken(String userId) async {
    try {
      final token = await _messaging.getToken();
      if (token == null || token.trim().isEmpty) return;
      await _saveToken(userId: userId, token: token);
    } catch (e) {
      debugPrint('[PNS] sem token de push (permissão recusada ou sem suporte): $e');
    }
  }

  Future<void> _saveToken({
    required String userId,
    required String token,
  }) async {
    final tokenId = token.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    await _firestore.collection('device_tokens').doc(tokenId).set({
      'userId': userId,
      'token': token,
      'platform': defaultTargetPlatform.name,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  // ─── Topic subscriptions ─────────────────────────────────────────────────

  static const _topicCritical = 'vencimento_critico';
  static const _topicWarning = 'vencimento_aviso';

  Future<void> subscribeToTopics(UserRole role) async {
    try {
      if (role == UserRole.admin || role == UserRole.estoquista) {
        await _messaging.subscribeToTopic(_topicCritical);
        await _messaging.subscribeToTopic(_topicWarning);
      } else if (role == UserRole.voluntario) {
        await _messaging.subscribeToTopic(_topicWarning);
      }
    } catch (e) {
      debugPrint('[PNS] subscribeToTopics error: $e');
    }
  }

  Future<void> unsubscribeFromTopics() async {
    try {
      await _messaging.unsubscribeFromTopic(_topicCritical);
      await _messaging.unsubscribeFromTopic(_topicWarning);
    } catch (e) {
      debugPrint('[PNS] unsubscribeFromTopics error: $e');
    }
  }
}

final pushNotificationServiceProvider = Provider<PushNotificationService>(
  (ref) => PushNotificationService(firestore: ref.watch(firestoreProvider)),
);

final pushNotificationsBootstrapProvider = Provider<void>((ref) {
  final user = ref.watch(currentUserProvider);
  final router = ref.watch(routerProvider);
  // Feed silent-mode config into the service whenever it changes
  final alertsConfig = ref.watch(alertsConfigProvider).valueOrNull;
  final service = ref.read(pushNotificationServiceProvider);
  if (alertsConfig != null) {
    service.updateAlertsConfig(alertsConfig);
  }
  unawaited(
    service.configure(router: router, user: user).catchError((Object e) {
      debugPrint('[PNS] configuração de push falhou: $e');
    }),
  );
});
