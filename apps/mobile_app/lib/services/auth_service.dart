import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

/// Phone-number OTP sign-in with Firebase Auth.
///
/// On Android the SMS can be read automatically (instant verification); on iOS
/// Firebase uses a silent APNs push or a reCAPTCHA fallback before sending the SMS.
class PhoneAuthService {
  PhoneAuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  String? _verificationId;
  int? _resendToken;
  String? phoneNumber;

  /// Sends the OTP. Completes with `true` when the code was sent, or `false` when
  /// Android verified the number automatically and the user is already signed in.
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

  Future<UserCredential> verifyCode(String smsCode) async {
    final id = _verificationId;
    if (id == null) throw Exception('Please request a new code.');
    try {
      return await _auth.signInWithCredential(PhoneAuthProvider.credential(verificationId: id, smsCode: smsCode.trim()));
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

  Future<void> signOut() => _auth.signOut();
}
