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

class PushNotificationService {
  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;

  bool _permissionRequested = false;
  bool _navigationBound = false;
  String? _lastUserId;
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;

  AlertsConfig? _alertsConfig;

  PushNotificationService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
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
      await _messaging.requestPermission();
    }

    if (!_navigationBound) {
      _navigationBound = true;

      FirebaseMessaging.onMessageOpenedApp.listen((_) {
        router.go(AppRoutes.alerts);
      });

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        router.go(AppRoutes.alerts);
      }

      // Suppress foreground notifications during silent hours
      await _foregroundSub?.cancel();
      _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
        final config = _alertsConfig;
        if (config != null && config.isSilentNow) {
          debugPrint('[PNS] Silent mode active — suppressing foreground message');
          return;
        }
        // Navigate to alerts so user sees the new alert
        router.go(AppRoutes.alerts);
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

  Future<void> _registerCurrentToken(String userId) async {
    final token = await _messaging.getToken();
    if (token == null || token.trim().isEmpty) return;
    await _saveToken(userId: userId, token: token);
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
  (_) => PushNotificationService(),
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
    service.configure(
      router: router,
      user: user,
    ),
  );
});
