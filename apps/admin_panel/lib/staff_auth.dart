import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

enum StaffRole { admin, librarian, none }

/// The signed-in staff account.
class StaffSession {
  const StaffSession({required this.uid, required this.email, required this.role});
  final String uid;
  final String email;
  final StaffRole role;
}

/// Staff sign-in. Firebase email/password in production; an offline demo when the
/// build has no Firebase config.
abstract class StaffAuth {
  Stream<StaffSession?> sessions();
  Future<void> signIn(String email, String password);
  Future<void> resetPassword(String email);
  Future<void> signOut();
}

class FirebaseStaffAuth implements StaffAuth {
  FirebaseAuth get _auth => FirebaseAuth.instance;

  @override
  Stream<StaffSession?> sessions() => _auth.idTokenChanges().asyncMap((user) async {
        if (user == null) return null;
        final claims = (await user.getIdTokenResult()).claims ?? const {};
        final role = claims['admin'] == true
            ? StaffRole.admin
            : claims['librarian'] == true
                ? StaffRole.librarian
                : StaffRole.none;
        return StaffSession(uid: user.uid, email: user.email ?? user.phoneNumber ?? '', role: role);
      });

  @override
  Future<void> signIn(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      await cred.user?.getIdTokenResult(true); // pick up freshly granted staff claims
    } on FirebaseAuthException catch (e) {
      throw Exception(switch (e.code) {
        'invalid-credential' || 'wrong-password' || 'user-not-found' => 'Incorrect email or password.',
        'too-many-requests' => 'Too many attempts. Try again later.',
        _ => e.message ?? e.code,
      });
    }
  }

  @override
  Future<void> resetPassword(String email) => _auth.sendPasswordResetEmail(email: email);

  @override
  Future<void> signOut() => _auth.signOut();
}

/// Demo accounts: admin@demo.com / demo1234 (admin) and librarian@demo.com / demo1234.
class DemoStaffAuth implements StaffAuth {
  static const password = 'demo1234';
  static const accounts = {'admin@demo.com': StaffRole.admin, 'librarian@demo.com': StaffRole.librarian};

  final _sessions = StreamController<StaffSession?>.broadcast();
  StaffSession? _current;

  @override
  Stream<StaffSession?> sessions() async* {
    yield _current;
    yield* _sessions.stream;
  }

  @override
  Future<void> signIn(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final role = accounts[email.trim().toLowerCase()];
    if (role == null || password != DemoStaffAuth.password) {
      throw Exception('Demo login: use admin@demo.com or librarian@demo.com with password ${DemoStaffAuth.password}');
    }
    _current = StaffSession(uid: 'demo-${role.name}', email: email.trim().toLowerCase(), role: role);
    _sessions.add(_current);
  }

  @override
  Future<void> resetPassword(String email) async => throw Exception('Password reset is not available in demo mode.');

  @override
  Future<void> signOut() async {
    _current = null;
    _sessions.add(null);
  }
}
