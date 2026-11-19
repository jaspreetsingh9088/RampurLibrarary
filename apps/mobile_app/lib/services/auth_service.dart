import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:library_core/library_core.dart';

/// Phone-number OTP sign-in. Two implementations: Firebase (real SMS) and an
/// offline demo used when the build has no Firebase config.
abstract class AuthGateway {
  /// Emits the signed-in user's id, or null when signed out.
  Stream<String?> uidChanges();

  /// Phone number the code was sent to (E.164).
  String? get phoneNumber;

  /// Sends the OTP. Completes with `true` when the code was sent, or `false` when the
  /// number was verified automatically (Android) and the user is already signed in.
  Future<bool> sendCode(String e164Phone);

  Future<void> verifyCode(String smsCode);

  Future<void> signOut();
}

class FirebaseAuthGateway implements AuthGateway {
  FirebaseAuthGateway({FirebaseAuth? auth}) : _authOverride = auth;

  final FirebaseAuth? _authOverride;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  String? _verificationId;
  int? _resendToken;
  @override
  String? phoneNumber;

  @override
  Stream<String?> uidChanges() => _auth.authStateChanges().map((u) {
        if (u?.phoneNumber != null) phoneNumber = u!.phoneNumber;
        return u?.uid;
      });

  @override
  Future<bool> sendCode(String e164Phone) {
    phoneNumber = e164Phone;
    final done = Completer<bool>();
    _auth.verifyPhoneNumber(
      phoneNumber: e164Phone,
      timeout: const Duration(seconds: 60),
      forceResendingToken: _resendToken,
      verificationCompleted: (credential) async {
        try {
          await _auth.signInWithCredential(credential);
          if (!done.isCompleted) done.complete(false);
        } catch (e) {
          if (!done.isCompleted) done.completeError(e);
        }
      },
      verificationFailed: (e) {
        if (!done.isCompleted) done.completeError(_friendly(e));
      },
      codeSent: (verificationId, resendToken) {
        _verificationId = verificationId;
        _resendToken = resendToken;
        if (!done.isCompleted) done.complete(true);
      },
      codeAutoRetrievalTimeout: (verificationId) => _verificationId = verificationId,
    );
    return done.future;
  }

  @override
  Future<void> verifyCode(String smsCode) async {
    final id = _verificationId;
    if (id == null) throw Exception('Please request a new code.');
    try {
      await _auth.signInWithCredential(PhoneAuthProvider.credential(verificationId: id, smsCode: smsCode.trim()));
    } on FirebaseAuthException catch (e) {
      throw _friendly(e);
    }
  }

  Exception _friendly(FirebaseAuthException e) {
    final msg = switch (e.code) {
      'invalid-phone-number' => 'That phone number looks invalid.',
      'invalid-verification-code' => 'Incorrect code. Please check and try again.',
      'session-expired' => 'The code has expired. Please request a new one.',
      'too-many-requests' => 'Too many attempts. Please try again later.',
      'quota-exceeded' => 'SMS limit reached for today. Please try again later.',
      'network-request-failed' => 'No internet connection.',
      _ => e.message ?? 'Verification failed (${e.code}).',
    };
    return Exception(msg);
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

/// Offline demo: any valid mobile number, OTP is always 123456.
class DemoAuthGateway implements AuthGateway {
  static const demoCode = '123456';

  final _uid = StreamController<String?>.broadcast();
  String? _current;
  @override
  String? phoneNumber;

  @override
  Stream<String?> uidChanges() async* {
    yield _current;
    yield* _uid.stream;
  }

  @override
  Future<bool> sendCode(String e164Phone) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    phoneNumber = e164Phone;
    return true;
  }

  @override
  Future<void> verifyCode(String smsCode) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (smsCode.trim() != demoCode) throw Exception('Incorrect code. In demo mode the code is $demoCode.');
    _current = DemoLibraryRepository.demoUid;
    _uid.add(_current);
  }

  @override
  Future<void> signOut() async {
    _current = null;
    _uid.add(null);
  }
}
