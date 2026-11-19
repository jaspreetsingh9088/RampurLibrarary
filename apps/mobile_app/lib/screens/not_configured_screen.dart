import 'package:flutter/material.dart';

import '../theme.dart';

/// Shown when the build was made without Firebase settings (e.g. a CI build before
/// the GitHub secrets are added). Explains what to do instead of crashing.
class NotConfiguredApp extends StatelessWidget {
  const NotConfiguredApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.settings_suggest_outlined, size: 56, color: AppColors.primary),
              const SizedBox(height: 20),
              const Text('Almost there!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              const Text(
                'This build of Rampur Library was made without Firebase settings, so it cannot connect yet.\n\n'
                'Add the FIREBASE_* secrets to the GitHub repository (see docs/SETUP.md) and re-run the '
                '"Mobile builds" workflow to get a working APK / IPA.',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
