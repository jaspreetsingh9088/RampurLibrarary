import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:library_core/library_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'providers.dart';
import 'services/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Without Firebase keys the app runs in offline demo mode on sample data.
  final configured = await AppConfig.initFirebase();
  if (configured) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
  }

  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      isDemoProvider.overrideWithValue(!configured),
    ],
    child: const RampurLibraryApp(),
  ));
}
