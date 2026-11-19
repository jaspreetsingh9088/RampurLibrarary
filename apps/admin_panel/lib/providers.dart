import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:library_core/library_core.dart';

final repoProvider = Provider<LibraryRepository>((ref) => LibraryRepository());

final authStateProvider = StreamProvider<User?>((ref) => FirebaseAuth.instance.idTokenChanges());

enum StaffRole { admin, librarian, none }

/// Staff role from the Firebase ID-token custom claims.
final staffRoleProvider = FutureProvider<StaffRole>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return StaffRole.none;
  final token = await user.getIdTokenResult();
  final claims = token.claims ?? const {};
  if (claims['admin'] == true) return StaffRole.admin;
  if (claims['librarian'] == true) return StaffRole.librarian;
  return StaffRole.none;
});

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
