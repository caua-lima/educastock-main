import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_env.dart';

final analyticsServiceProvider = Provider<AnalyticsService>((_) {
  return AnalyticsService(FirebaseAnalytics.instance, FirebaseCrashlytics.instance);
});

class AnalyticsService {
  final FirebaseAnalytics _analytics;
  final FirebaseCrashlytics _crashlytics;

  AnalyticsService(this._analytics, this._crashlytics);

  Future<void> logEvent(String name, {Map<String, Object>? params}) async {
    await _analytics.logEvent(name: name, parameters: {
      'app_env': AppEnv.name,
      ...?params,
    });
  }

  Future<void> logAuthLogin({required String method}) {
    return logEvent('auth_login', params: {'method': method});
  }

  Future<void> logAuthRegister() {
    return logEvent('auth_register');
  }

  Future<void> logPasswordReset() {
    return logEvent('auth_password_reset');
  }

  Future<void> logStockMovement({
    required String type,
    required int quantity,
    required bool fefoOverride,
    required bool requiresApproval,
  }) {
    return logEvent(
      'stock_movement_submitted',
      params: {
        'type': type,
        'quantity': quantity,
        'fefo_override': fefoOverride,
        'requires_approval': requiresApproval,
      },
    );
  }

  Future<void> logReportExport({required String format, required String reportType}) {
    return logEvent(
      'report_export',
      params: {
        'format': format,
        'report_type': reportType,
      },
    );
  }

  Future<void> recordHandledError(
    dynamic error,
    StackTrace stackTrace, {
    String reason = 'handled_error',
    bool fatal = false,
  }) async {
    if (kDebugMode) return;
    await _crashlytics.recordError(error, stackTrace, reason: reason, fatal: fatal);
  }
}
