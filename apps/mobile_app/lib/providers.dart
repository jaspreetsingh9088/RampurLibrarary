import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:library_core/library_core.dart';

final repoProvider = Provider<LibraryRepository>((ref) => LibraryRepository());

final authStateProvider = StreamProvider<User?>((ref) => FirebaseAuth.instance.authStateChanges());

final uidProvider = Provider<String?>((ref) => ref.watch(authStateProvider).value?.uid);

final memberProvider = StreamProvider<Member?>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(repoProvider).watchMember(uid);
});

final settingsProvider = StreamProvider<LibrarySettings>((ref) => ref.watch(repoProvider).watchSettings());

final categoriesProvider = StreamProvider<List<BookCategory>>((ref) => ref.watch(repoProvider).watchCategories());

final newArrivalsProvider = StreamProvider<List<Book>>((ref) => ref.watch(repoProvider).watchBooks(limit: 12));

final featuredProvider = StreamProvider<List<Book>>((ref) => ref.watch(repoProvider).watchBooks(featuredOnly: true, limit: 10));

final popularProvider = StreamProvider<List<Book>>((ref) => ref.watch(repoProvider).watchPopular(limit: 12));

final categoryBooksProvider = StreamProvider.family<List<Book>, String>(
  (ref, slug) => ref.watch(repoProvider).watchBooks(category: slug, limit: 100, orderBy: 'title'),
);

final bookProvider = StreamProvider.family<Book?, String>((ref, id) => ref.watch(repoProvider).watchBook(id));

final reviewsProvider = StreamProvider.family<List<Review>, String>((ref, id) => ref.watch(repoProvider).watchReviews(id));

final eventsProvider = StreamProvider<List<LibraryEvent>>((ref) => ref.watch(repoProvider).watchEvents());

Stream<T> _forUser<T>(Ref ref, T empty, Stream<T> Function(LibraryRepository repo, String uid) build) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(empty);
  return build(ref.watch(repoProvider), uid);
}

final activeLoansProvider = StreamProvider<List<Loan>>(
  (ref) => _forUser(ref, const <Loan>[], (r, uid) => r.watchMemberLoans(uid, activeOnly: true)),
);

final historyProvider = StreamProvider<List<Loan>>(
  (ref) => _forUser(ref, const <Loan>[], (r, uid) => r.watchReadingHistory(uid)),
);

final reservationsProvider = StreamProvider<List<Reservation>>(
  (ref) => _forUser(ref, const <Reservation>[], (r, uid) => r.watchMemberReservations(uid)),
);

final finesProvider = StreamProvider<List<Fine>>(
  (ref) => _forUser(ref, const <Fine>[], (r, uid) => r.watchMemberFines(uid)),
);

final wishlistProvider = StreamProvider<List<Book>>(
  (ref) => _forUser(ref, const <Book>[], (r, uid) => r.watchWishlist(uid)),
);

final wishlistIdsProvider = StreamProvider<Set<String>>(
  (ref) => _forUser(ref, const <String>{}, (r, uid) => r.watchWishlistIds(uid)),
);

final notificationsProvider = StreamProvider<List<AppNotification>>(
  (ref) => _forUser(ref, const <AppNotification>[], (r, uid) => r.watchNotifications(uid)),
);

final broadcastsProvider = StreamProvider<List<AppNotification>>((ref) {
  if (ref.watch(uidProvider) == null) return Stream.value(const <AppNotification>[]);
  return ref.watch(repoProvider).watchBroadcastsAsNotifications();
});

final unreadCountProvider = StreamProvider<int>((ref) => _forUser(ref, 0, (r, uid) => r.watchUnreadCount(uid)));

final bookRequestsProvider = StreamProvider<List<BookRequest>>(
  (ref) => _forUser(ref, const <BookRequest>[], (r, uid) => r.watchMyBookRequests(uid)),
);
