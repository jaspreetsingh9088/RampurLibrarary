import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:library_core/library_core.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  final configured = await AppConfig.initFirebase();
  runApp(configured
      ? const ProviderScope(child: AdminApp())
      : const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Firebase is not configured for this build.\nAdd the FIREBASE_* secrets in GitHub (see docs/SETUP.md) and redeploy.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ),
        ));
}
