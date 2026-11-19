import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    (Icons.menu_book_rounded, 'Thousands of books', 'Browse the full Rampur Library catalogue, check availability and find exactly where a book sits on the shelf.'),
    (Icons.bookmark_add_rounded, 'Reserve & renew', 'Reserve books that are out, get notified the moment they are ready, and renew your loans from your phone.'),
    (Icons.notifications_active_rounded, 'Never pay a late fine', 'Due-date reminders, a digital membership card, events and news — all in one place.'),
  ];

  Future<void> _finish() async {
    await ref.read(onboardingSeenProvider.notifier).complete();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = _page == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _finish, child: const Text('Skip'))),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _pages.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) {
                final (icon, title, body) = _pages[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                      child: Icon(icon, size: 96, color: scheme.primary),
                    ),
                    const SizedBox(height: 40),
                    Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 14),
                    Text(body, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, height: 1.5, color: scheme.onSurfaceVariant)),
                  ]),
                );
              },
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < _pages.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.all(4),
                width: i == _page ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(color: i == _page ? scheme.primary : scheme.outlineVariant, borderRadius: BorderRadius.circular(4)),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.all(24),
            child: FilledButton(
              onPressed: last ? _finish : () => _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
              child: Text(last ? 'Get started' : 'Next'),
            ),
          ),
        ]),
      ),
    );
  }
}
