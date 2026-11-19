import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:library_core/library_core.dart';

import 'staff_auth.dart';

export 'staff_auth.dart';

/// True when the build has no Firebase config: the panel runs on offline sample data.
final isDemoProvider = Provider<bool>((ref) => false);

final repoProvider = Provider<LibraryRepository>(
  (ref) => ref.watch(isDemoProvider) ? DemoLibraryRepository(withCommunity: true) : LibraryRepository(),
);

final staffAuthProvider = Provider<StaffAuth>((ref) => ref.watch(isDemoProvider) ? DemoStaffAuth() : FirebaseStaffAuth());

/// Signed-in staff account (null when signed out).
final authStateProvider = StreamProvider<StaffSession?>((ref) => ref.watch(staffAuthProvider).sessions());

/// Staff role from the session (Firebase custom claims in production).
final staffRoleProvider = Provider<AsyncValue<StaffRole>>(
  (ref) => ref.watch(authStateProvider).whenData((s) => s?.role ?? StaffRole.none),
);

final staffUidProvider = Provider<String>((ref) => ref.watch(authStateProvider).value?.uid ?? '');

final settingsProvider = StreamProvider<LibrarySettings>((ref) => ref.watch(repoProvider).watchSettings());
final categoriesProvider = StreamProvider<List<BookCategory>>((ref) => ref.watch(repoProvider).watchCategories());
final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) => ref.watch(repoProvider).dashboardStats());
final issuesPerDayProvider = FutureProvider<List<MapEntry<DateTime, int>>>((ref) => ref.watch(repoProvider).issuesPerDay(days: 14));
final finesCollectedProvider = FutureProvider<double>((ref) => ref.watch(repoProvider).finesCollected(days: 30));

final memberProvider = StreamProvider.family<Member?, String>((ref, id) => ref.watch(repoProvider).watchMember(id));
final memberLoansProvider = StreamProvider.family<List<Loan>, String>((ref, id) => ref.watch(repoProvider).watchMemberLoans(id));
final memberFinesProvider = StreamProvider.family<List<Fine>, String>((ref, id) => ref.watch(repoProvider).watchMemberFines(id));
final memberReservationsProvider =
    StreamProvider.family<List<Reservation>, String>((ref, id) => ref.watch(repoProvider).watchMemberReservations(id));
