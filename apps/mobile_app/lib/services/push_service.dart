import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:library_core/library_core.dart';

import '../widgets/common.dart';

/// Must be a top-level function: runs in its own isolate when a data message
/// arrives while the app is in the background or terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await AppConfig.initFirebase();
  debugPrint('Background push: ${message.messageId}');
}

/// Wires Firebase Cloud Messaging into the app: permission, token registration,
/// the `all` broadcast topic, foreground banners and tap-to-open navigation.
class PushService {
  PushService(this._repo);

  final LibraryRepository _repo;
  final _messaging = FirebaseMessaging.instance;
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _fgSub;
  StreamSubscription<RemoteMessage>? _openSub;
  String? _uid;
  String? _token;

  static GoRouter? router;

  Future<void> start(String uid) async {
    if (_uid == uid) return;
    _uid = uid;
    try {
      final settings = await _messaging.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      await _messaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // The APNs token can arrive a moment after permission is granted.
        for (var i = 0; i < 5 && await _messaging.getAPNSToken() == null; i++) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }
      _token = await _messaging.getToken();
      if (_token != null) await _repo.addFcmToken(uid, _token!);
      _tokenSub = _messaging.onTokenRefresh.listen((t) {
        _token = t;
        _repo.addFcmToken(uid, t);
      });
      await _messaging.subscribeToTopic('all');

      _fgSub = FirebaseMessaging.onMessage.listen(_showInApp);
      _openSub = FirebaseMessaging.onMessageOpenedApp.listen(_open);
      final initial = await _messaging.getInitialMessage();
      if (initial != null) _open(initial);
    } catch (e) {
      debugPrint('Push setup failed: $e');
    }
  }

  Future<void> stop() async {
    final uid = _uid;
    _uid = null;
    await _tokenSub?.cancel();
    await _fgSub?.cancel();
    await _openSub?.cancel();
    try {
      if (uid != null && _token != null) await _repo.removeFcmToken(uid, _token!);
      await _messaging.unsubscribeFromTopic('all');
      await _messaging.deleteToken();
    } catch (_) {}
    _token = null;
  }

  void _showInApp(RemoteMessage m) {
    final n = m.notification;
    if (n == null) return;
    scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(n.title ?? 'Rampur Library', style: const TextStyle(fontWeight: FontWeight.w700)),
        if (n.body != null) Text(n.body!),
      ]),
      action: SnackBarAction(label: 'View', onPressed: () => _open(m)),
    ));
  }

  void _open(RemoteMessage m) {
    final r = router;
    if (r == null) return;
    final d = m.data;
    final type = d['type'] ?? '';
    if (d['bookId'] != null && (type == 'reservation_ready' || type == 'reservation_queued')) {
      r.push('/my-books?tab=1');
    } else if (d['loanId'] != null) {
      r.go('/my-books');
    } else if (type == 'fine') {
      r.push('/fines');
    } else if ((d['link'] ?? '').toString().startsWith('/events')) {
      r.push('/events');
    } else {
      r.push('/notifications');
    }
  }
}
