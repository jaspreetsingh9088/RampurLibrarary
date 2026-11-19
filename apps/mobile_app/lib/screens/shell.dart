import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeLoansProvider).value ?? const [];
    final overdue = active.where((l) => l.isOverdue).length;
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          const NavigationDestination(icon: Icon(Icons.search_rounded), label: 'Explore'),
          NavigationDestination(
            icon: Badge(isLabelVisible: active.isNotEmpty, label: Text('${active.length}'),
                backgroundColor: overdue > 0 ? Colors.red : null, child: const Icon(Icons.auto_stories_outlined)),
            selectedIcon: const Icon(Icons.auto_stories_rounded),
            label: 'My Books',
          ),
          const NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}
