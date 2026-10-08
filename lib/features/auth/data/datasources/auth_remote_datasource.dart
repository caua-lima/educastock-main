import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../donations/domain/entities/donor_profile.dart';
import '../../domain/entities/app_user.dart';

class AuthRemoteDatasource {
  static const _rememberLoginKey = 'remember_login';
  static const _rememberedEmailKey = 'remembered_email';

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn? _googleSignIn;

  AuthRemoteDatasource({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = kIsWeb ? null : (googleSignIn ?? GoogleSignIn());

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> _configurePersistence(bool rememberLogin) async {
    if (!kIsWeb) return;
    await _auth.setPersistence(
      rememberLogin ? Persistence.LOCAL : Persistence.SESSION,
    );
  }

  Future<void> setRememberLogin(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberLoginKey, value);
  }

  Future<bool> getRememberLogin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberLoginKey) ?? true;
  }

  Future<void> setRememberedEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rememberedEmailKey, email);
  }

  Future<String?> getRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_rememberedEmailKey)?.trim();
    if (email == null || email.isEmpty) return null;
    return email;
  }

  Future<void> clearRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rememberedEmailKey);
  }

  Future<AppUser?> signIn({
    required String email,
    required String password,
    bool rememberLogin = true,
  }) async {
    await _configurePersistence(rememberLogin);
    await setRememberLogin(rememberLogin);
    if (rememberLogin) {
      await setRememberedEmail(email);
    } else {
      await clearRememberedEmail();
    }

    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (credential.user == null) return null;
    final profile = await _fetchUser(credential.user!.uid);
    final user = profile ?? _fromFirebaseUser(credential.user!);
    _saveFcmToken(credential.user!.uid);
    _setupTokenRefreshListener(credential.user!.uid);
    return user;
  }

  Future<AppUser?> signInWithGoogle({bool rememberLogin = true}) async {
    await _configurePersistence(rememberLogin);
    await setRememberLogin(rememberLogin);

    UserCredential credential;

    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      credential = await _auth.signInWithPopup(provider);
    } else {
      final googleUser = await _googleSignIn!.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final authCredential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      credential = await _auth.signInWithCredential(authCredential);
    }

    final firebaseUser = credential.user;
    if (firebaseUser == null) return null;
    if (rememberLogin) {
      await setRememberedEmail(firebaseUser.email ?? '');
    } else {
      await clearRememberedEmail();
    }
    final user = await _ensureUserDocument(firebaseUser);
    _saveFcmToken(firebaseUser.uid);
    _setupTokenRefreshListener(firebaseUser.uid);
    return user;
  }

  Future<void> signOut() async {
    await _googleSignIn?.signOut();
    await _auth.signOut();
  }

  Future<void> _saveFcmToken(String userId) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.trim().isEmpty) return;
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[AuthDS] _saveFcmToken error: $e');
    }
  }

  void _setupTokenRefreshListener(String userId) {
    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      try {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('[AuthDS] token refresh update error: $e');
      }
    });
  }

  Future<AppUser?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    // Garante que o ID token esteja pronto antes de ler o Firestore — evita
    // a corrida de `permission-denied` no primeiro load (web/PWA iOS).
    try {
      await user.getIdToken();
    } catch (_) {
      // Se falhar, _fetchUser ainda tem retry para cobrir.
    }
    final profile = await _fetchUser(user.uid);
    return profile ?? _fromFirebaseUser(user);
  }

  Future<AppUser?> _fetchUser(String uid) async {
    // No web/PWA, logo após o Firebase restaurar a sessão (primeiro load),
    // o token de auth pode ainda não estar anexado à 1ª requisição do
    // Firestore → retorna `permission-denied` momentâneo. Antes isso fazia
    // o app cair no fallback com role `consulta` (permissão mínima),
    // exigindo reload. Agora `permission-denied` é tratado como transitório
    // e re-tentado algumas vezes antes de desistir.
    const maxAttempts = 5;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final doc = await _firestore.collection('users').doc(uid).get();
        if (!doc.exists || doc.data() == null) return null;
        return AppUser.fromMap(doc.data()!, doc.id);
      } on FirebaseException catch (e) {
        final isTransient = e.code == 'permission-denied' ||
            e.code == 'unavailable' ||
            e.code == 'deadline-exceeded';
        final isLastAttempt = attempt == maxAttempts;
        if (!isTransient || isLastAttempt) {
          if (isTransient) return null;
          rethrow;
        }
        // Backoff progressivo: 200, 400, 600, 800ms
        await Future<void>.delayed(Duration(milliseconds: 200 * attempt));
      }
    }

    return null;
  }

  Future<AppUser?> createUser({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    bool rememberLogin = true,
  }) async {
    await _configurePersistence(rememberLogin);
    await setRememberLogin(rememberLogin);
    if (rememberLogin) {
      await setRememberedEmail(email);
    } else {
      await clearRememberedEmail();
    }

    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.updateDisplayName(name);
    final appUser = AppUser(
      id: credential.user!.uid,
      name: name,
      email: email,
      role: role,
      isActive: true,
      createdAt: DateTime.now(),
    );
    try {
      await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .set(appUser.toMap());
    } on FirebaseException catch (e) {
      // Se a regra do Firestore estiver bloqueando escrita, não quebramos o cadastro.
      if (e.code != 'permission-denied') rethrow;
    }
    return appUser;
  }

  /// Cadastro autônomo do doador (RF16, tela D02): cria a conta no Auth e, em
  /// um único lote atômico, `users/{uid}` (papel `doador`, imposto pelas regras
  /// — achado F1) e `donors/{uid}` (perfil + consentimento dos termos).
  Future<AppUser?> createDonor({
    required String email,
    required String password,
    required String name,
    required DonorType donorType,
    required String phone,
    required String city,
    bool rememberLogin = true,
  }) async {
    await _configurePersistence(rememberLogin);
    await setRememberLogin(rememberLogin);
    if (rememberLogin) {
      await setRememberedEmail(email);
    } else {
      await clearRememberedEmail();
    }

    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final firebaseUser = credential.user;
    if (firebaseUser == null) return null;
    await firebaseUser.updateDisplayName(name);

    final appUser = AppUser(
      id: firebaseUser.uid,
      name: name,
      email: email,
      role: UserRole.doador,
      isActive: true,
      createdAt: DateTime.now(),
    );
    final profile = DonorProfile(
      uid: firebaseUser.uid,
      displayName: name,
      donorType: donorType,
      phone: phone,
      city: city,
    );

    final batch = _firestore.batch();
    batch.set(_firestore.collection('users').doc(firebaseUser.uid), appUser.toMap());
    batch.set(
      _firestore.collection('donors').doc(firebaseUser.uid),
      profile.toCreateMap(),
    );
    await batch.commit();

    try {
      await firebaseUser.sendEmailVerification();
    } catch (e) {
      debugPrint('[AuthDS] sendEmailVerification error: $e');
    }
    _saveFcmToken(firebaseUser.uid);
    _setupTokenRefreshListener(firebaseUser.uid);
    return appUser;
  }

  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  Future<void> sendEmailVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  /// Recarrega o usuário e renova o ID token para que a claim `email_verified`
  /// chegue às regras do Firestore (necessária para registrar intenção, RN-D02).
  Future<bool> refreshEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    await _auth.currentUser?.getIdToken(true);
    return _auth.currentUser?.emailVerified ?? false;
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  Future<void> sendOtp(String userId) async {
    final code = (Random.secure().nextInt(900000) + 100000).toString();
    final expiresAt = DateTime.now().add(const Duration(minutes: 10));
    await _firestore.collection('otp_codes').doc(userId).set({
      'code': code,
      'expiresAt': expiresAt.toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<bool> verifyOtp(String userId, String code) async {
    final doc = await _firestore.collection('otp_codes').doc(userId).get();
    if (!doc.exists || doc.data() == null) return false;
    final data = doc.data()!;
    final storedCode = data['code'] as String?;
    final expiresAtRaw = data['expiresAt'] as String?;
    if (storedCode == null || expiresAtRaw == null) return false;
    final expiresAt = DateTime.tryParse(expiresAtRaw);
    if (expiresAt == null) return false;
    final valid = code == storedCode && DateTime.now().isBefore(expiresAt);
    if (valid) {
      await _firestore.collection('otp_codes').doc(userId).delete();
    }
    return valid;
  }

  Future<void> enable2FA(String userId, {required bool enabled}) async {
    await _firestore.collection('users').doc(userId).update({
      'twoFactorEnabled': enabled,
    });
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null || user.email!.trim().isEmpty) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Sessao invalida para trocar senha.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  Future<AppUser> _ensureUserDocument(User firebaseUser) async {
    final existing = await _fetchUser(firebaseUser.uid);
    if (existing != null) return existing;

    final appUser = AppUser(
      id: firebaseUser.uid,
      name: firebaseUser.displayName?.trim().isNotEmpty == true
          ? firebaseUser.displayName!.trim()
          : (firebaseUser.email?.split('@').first ?? 'Novo usuario'),
      email: firebaseUser.email ?? '',
      role: UserRole.doador,
      isActive: true,
      createdAt: DateTime.now(),
    );

    try {
      await _firestore.collection('users').doc(firebaseUser.uid).set(appUser.toMap());
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
    }
    return appUser;
  }

  AppUser _fromFirebaseUser(User user) {
    return AppUser(
      id: user.uid,
      name: user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : (user.email?.split('@').first ?? 'Usuario'),
      email: user.email ?? '',
      role: UserRole.doador,
      isActive: true,
      createdAt: DateTime.now(),
    );
  }
}
