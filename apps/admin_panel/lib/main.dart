import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:library_core/library_core.dart';

import 'app.dart';
import 'providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  // Without Firebase keys the panel runs in offline demo mode on sample data.
  final configured = await AppConfig.initFirebase();
  runApp(ProviderScope(overrides: [isDemoProvider.overrideWithValue(!configured)], child: const AdminApp()));
}
