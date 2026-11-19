import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:library_core/library_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers.dart';
import 'screens/auth_screens.dart';
import 'screens/book_screens.dart';
import 'screens/home_screen.dart';
import 'screens/my_books_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_screens.dart';
import 'screens/more_screens.dart';
import 'screens/shell.dart';
import 'services/push_service.dart';
import 'theme.dart';
import 'widgets/common.dart';

final prefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('override in main'));

class OnboardingNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(prefsProvider).getBool('onboardingSeen') ?? false;

  Future<void> complete() async {
    await ref.read(prefsProvider).setBool('onboardingSeen', true);
    state = true;
  }
}

final onboardingSeenProvider = NotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final v = ref.watch(prefsProvider).getString('themeMode');
    return ThemeMode.values.firstWhere((m) => m.name == v, orElse: () => ThemeMode.system);
  }

  Future<void> set(ThemeMode mode) async {
    await ref.read(prefsProvider).setString('themeMode', mode.name);
    state = mode;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

final pushServiceProvider = Provider<PushService>((ref) => PushService(ref.watch(repoProvider)));

/// Side effects tied to the signed-in user: create the profile doc, start/stop push.
final sessionEffectsProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<User?>>(authStateProvider, (prev, next) async {
    final user = next.value;
    final push = ref.read(pushServiceProvider);
    if (user != null) {
      try {
        await ref.read(repoProvider).ensureMemberProfile(user);
      } catch (e) {
        debugPrint('Profile setup failed: $e');
      }
      await push.start(user.uid);
      FirebaseAnalytics.instance.setUserId(id: user.uid);
    } else if (prev?.value != null) {
      await push.stop();
    }
  }, fireImmediately: true);
});

/// Re-runs the router's redirect when auth, profile or onboarding state changes.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
    ref.listen(memberProvider, (_, _) => notifyListeners());
    ref.listen(onboardingSeenProvider, (_, _) => notifyListeners());
  }
}

const _publicRoutes = {'/login', '/otp', '/onboarding'};

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  final router = GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    observers: [FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance)],
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final auth = ref.read(authStateProvider);
      if (auth.isLoading) return '/splash';
      final user = auth.value;

      if (!ref.read(onboardingSeenProvider)) return loc == '/onboarding' ? null : '/onboarding';
      if (user == null) return _publicRoutes.contains(loc) ? null : '/login';

      final member = ref.read(memberProvider);
      if (member.isLoading || member.value == null) return loc == '/splash' ? null : '/splash';
      if (!member.value!.isProfileComplete) return loc == '/complete-profile' ? null : '/complete-profile';
      if (_publicRoutes.contains(loc) || loc == '/splash' || loc == '/complete-profile') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, _) => const PhoneLoginScreen()),
      GoRoute(path: '/otp', builder: (_, _) => const OtpScreen()),
      GoRoute(path: '/complete-profile', builder: (_, _) => const EditProfileScreen(onboarding: true)),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, _) => const HomeScreen())]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/search', builder: (_, s) => SearchScreen(initialQuery: s.uri.queryParameters['q'] ?? '')),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/my-books', builder: (_, s) => MyBooksScreen(initialTab: int.tryParse(s.uri.queryParameters['tab'] ?? '') ?? 0)),
          ]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen())]),
        ],
      ),
      GoRoute(path: '/book/:id', builder: (_, s) => BookDetailScreen(bookId: s.pathParameters['id']!)),
      GoRoute(path: '/category/:slug', builder: (_, s) => CategoryScreen(slug: s.pathParameters['slug']!, name: s.uri.queryParameters['name'] ?? '')),
      GoRoute(path: '/scan', builder: (_, _) => const ScanScreen()),
      GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
      GoRoute(path: '/fines', builder: (_, _) => const FinesScreen()),
      GoRoute(path: '/events', builder: (_, _) => const EventsScreen()),
      GoRoute(path: '/requests', builder: (_, _) => const BookRequestsScreen()),
      GoRoute(path: '/card', builder: (_, _) => const MembershipCardScreen()),
      GoRoute(path: '/edit-profile', builder: (_, _) => const EditProfileScreen()),
      GoRoute(path: '/about', builder: (_, _) => const AboutLibraryScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const AppSettingsScreen()),
      GoRoute(path: '/feedback', builder: (_, _) => const FeedbackScreen()),
    ],
  );
  PushService.router = router;
  ref.onDispose(router.dispose);
  return router;
});

class RampurLibraryApp extends ConsumerWidget {
  const RampurLibraryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(sessionEffectsProvider);
    final router = ref.watch(routerProvider);
    final mode = ref.watch(themeModeProvider);
    final name = ref.watch(settingsProvider).value?.name ?? 'Rampur Library';
    return MaterialApp.router(
      title: name,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: mode,
      routerConfig: router,
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.primary,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.asset('assets/images/logo.png', width: 96, height: 96),
          const SizedBox(height: 20),
          Text('Rampur Library', style: TextStyle(color: scheme.onPrimary, fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 24),
          SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: scheme.onPrimary)),
        ]),
      ),
    );
  }
}

/// Helper used by screens that need the current member (always non-null inside the shell).
extension MemberRef on WidgetRef {
  Member? get member => watch(memberProvider).value;
}
