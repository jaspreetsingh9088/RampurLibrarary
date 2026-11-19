import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'pages/books_page.dart';
import 'pages/circulation_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/engagement_pages.dart';
import 'pages/login_page.dart';
import 'pages/members_page.dart';
import 'pages/admin_pages.dart';
import 'providers.dart';
import 'widgets.dart';

class _Refresh extends ChangeNotifier {
  _Refresh(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
    ref.listen(staffRoleProvider, (_, _) => notifyListeners());
  }
}

class NavItem {
  const NavItem(this.path, this.label, this.icon, {this.adminOnly = false});
  final String path;
  final String label;
  final IconData icon;
  final bool adminOnly;
}

const navItems = [
  NavItem('/dashboard', 'Dashboard', Icons.space_dashboard_outlined),
  NavItem('/circulation', 'Issue / Return', Icons.swap_horiz_rounded),
  NavItem('/books', 'Books', Icons.menu_book_outlined),
  NavItem('/categories', 'Categories', Icons.category_outlined),
  NavItem('/members', 'Members', Icons.people_alt_outlined),
  NavItem('/reservations', 'Reservations', Icons.bookmark_border_rounded),
  NavItem('/fines', 'Fines', Icons.receipt_long_outlined),
  NavItem('/notifications', 'Notifications', Icons.campaign_outlined),
  NavItem('/events', 'Events', Icons.event_outlined),
  NavItem('/requests', 'Suggestions', Icons.lightbulb_outline),
  NavItem('/reports', 'Reports', Icons.insights_outlined),
  NavItem('/staff', 'Staff', Icons.admin_panel_settings_outlined, adminOnly: true),
  NavItem('/settings', 'Settings', Icons.settings_outlined, adminOnly: true),
];

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: _Refresh(ref),
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      if (auth.isLoading) return null;
      final loggedIn = auth.value != null;
      final atLogin = state.matchedLocation == '/login';
      if (!loggedIn) return atLogin ? null : '/login';
      final role = ref.read(staffRoleProvider);
      if (role.isLoading) return null;
      if (role.value == StaffRole.none) return atLogin ? null : '/login';
      if (atLogin) return '/dashboard';
      final item = navItems.where((n) => state.matchedLocation.startsWith(n.path)).firstOrNull;
      if (item != null && item.adminOnly && role.value != StaffRole.admin) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/', redirect: (_, _) => '/dashboard'),
      ShellRoute(
        builder: (context, state, child) => AdminLayout(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, _) => const DashboardPage()),
          GoRoute(path: '/circulation', builder: (_, s) => CirculationPage(initialMember: s.uri.queryParameters['member'])),
          GoRoute(path: '/books', builder: (_, _) => const BooksPage()),
          GoRoute(path: '/categories', builder: (_, _) => const CategoriesPage()),
          GoRoute(path: '/members', builder: (_, _) => const MembersPage()),
          GoRoute(path: '/members/:id', builder: (_, s) => MemberDetailPage(memberId: s.pathParameters['id']!)),
          GoRoute(path: '/reservations', builder: (_, _) => const ReservationsPage()),
          GoRoute(path: '/fines', builder: (_, _) => const FinesPage()),
          GoRoute(path: '/notifications', builder: (_, _) => const NotificationsPage()),
          GoRoute(path: '/events', builder: (_, _) => const EventsPage()),
          GoRoute(path: '/requests', builder: (_, _) => const RequestsPage()),
          GoRoute(path: '/reports', builder: (_, _) => const ReportsPage()),
          GoRoute(path: '/staff', builder: (_, _) => const StaffPage()),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ThemeData theme(Brightness b) {
      final scheme = ColorScheme.fromSeed(seedColor: brandPrimary, brightness: b, secondary: brandAccent);
      return ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: b == Brightness.light ? const Color(0xFFF4F6F8) : null,
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6))),
        ),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(), isDense: true),
      );
    }

    return MaterialApp.router(
      title: 'Rampur Library Admin',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: messengerKey,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => ref.watch(isDemoProvider)
          ? Banner(message: 'DEMO', location: BannerLocation.topEnd, color: brandAccent, child: child ?? const SizedBox())
          : child ?? const SizedBox(),
    );
  }
}

class AdminLayout extends ConsumerWidget {
  const AdminLayout({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(staffRoleProvider).value ?? StaffRole.none;
    final user = ref.watch(authStateProvider).value;
    final items = navItems.where((n) => !n.adminOnly || role == StaffRole.admin).toList();
    final selected = items.indexWhere((n) => location.startsWith(n.path));
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final scheme = Theme.of(context).colorScheme;

    final nav = NavigationRail(
      extended: wide,
      minExtendedWidth: 230,
      selectedIndex: selected < 0 ? null : selected,
      onDestinationSelected: (i) {
        context.go(items[i].path);
        if (!wide) Navigator.of(context).maybePop();
      },
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset('assets/logo.png', width: 40, height: 40)),
          if (wide) ...[
            const SizedBox(width: 10),
            const Text('Rampur Library', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ]),
      ),
      destinations: [for (final n in items) NavigationRailDestination(icon: Icon(n.icon), label: Text(n.label))],
    );

    final topBar = AppBar(
      automaticallyImplyLeading: !wide,
      title: wide ? null : const Text('Rampur Library Admin'),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      actions: [
        IconButton(tooltip: 'Quick issue', icon: const Icon(Icons.qr_code_scanner), onPressed: () => context.go('/circulation')),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          tooltip: 'Account',
          onSelected: (v) async {
            if (v == 'logout') await ref.read(staffAuthProvider).signOut();
          },
          itemBuilder: (_) => [
            PopupMenuItem(enabled: false, child: Text('${user?.email ?? ''}\n${role.name}${ref.watch(isDemoProvider) ? ' · demo' : ''}')),
            const PopupMenuItem(value: 'logout', child: ListTile(leading: Icon(Icons.logout), title: Text('Sign out'))),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              child: Text((user?.email.isNotEmpty == true ? user!.email : 'A').substring(0, 1).toUpperCase(), style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      ],
    );

    if (wide) {
      return Scaffold(
        body: Row(children: [
          SingleChildScrollView(child: ConstrainedBox(constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height), child: IntrinsicHeight(child: nav))),
          const VerticalDivider(width: 1),
          Expanded(child: Scaffold(appBar: topBar, body: child)),
        ]),
      );
    }
    return Scaffold(
      appBar: topBar,
      drawer: Drawer(child: SafeArea(child: SingleChildScrollView(child: SizedBox(height: 60.0 * items.length + 120, child: nav)))),
      body: child,
    );
  }
}
