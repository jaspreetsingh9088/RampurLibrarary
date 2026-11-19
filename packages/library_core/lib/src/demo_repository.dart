import 'dart:async';
import 'dart:typed_data';

import 'models.dart';
import 'repository.dart';
import 'utils.dart';

/// Offline, in-memory implementation used when a build has no Firebase config.
///
/// Lets you install and try every member-facing screen (login with OTP 123456,
/// browsing, reservations, renewals, wishlist, reviews, profile…) without any
/// backend. Data lives in memory and resets when the app restarts.
class DemoLibraryRepository extends LibraryRepository {
  DemoLibraryRepository() {
    _seed();
  }

  static const demoUid = 'demo-member';

  final _changes = StreamController<void>.broadcast();
  void _changed() => _changes.add(null);

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    await for (final _ in _changes.stream) {
      yield read();
    }
  }

  Future<void> _lag() => Future<void>.delayed(const Duration(milliseconds: 350));

  LibrarySettings _settings = const LibrarySettings(
    name: 'Rampur Library',
    address: 'Civil Lines, Rampur, Uttar Pradesh 244901',
    phone: '+91 98765 43210',
    email: 'hello@rampurlibrary.in',
  );
  final List<BookCategory> _categories = [];
  final Map<String, Book> _books = {};
  final Map<String, List<Review>> _reviews = {};
  final Map<String, Member> _members = {};
  final List<Loan> _loans = [];
  final List<Loan> _history = [];
  final List<Reservation> _reservations = [];
  final List<Fine> _fines = [];
  final List<AppNotification> _notifications = [];
  final List<AppNotification> _broadcasts = [];
  final List<LibraryEvent> _events = [];
  final List<BookRequest> _requests = [];
  final Map<String, Set<String>> _wishlist = {};
  int _seq = 100;

  String _id(String prefix) => '$prefix-${_seq++}';

  // ===========================================================================
  // Seed data
  // ===========================================================================

  void _seed() {
    final now = DateTime.now();
    const cats = [
      ('fiction', 'Fiction', '📖'),
      ('biography', 'Biography', '🧑‍🏫'),
      ('history', 'History', '🏛️'),
      ('science', 'Science', '🔬'),
      ('self-help', 'Self-help', '🌱'),
      ('children', 'Children', '🧸'),
      ('hindi-literature', 'Hindi Literature', '🪔'),
      ('urdu-literature', 'Urdu Literature', '🌙'),
      ('competitive-exams', 'Competitive Exams', '🎯'),
      ('religion-philosophy', 'Religion & Philosophy', '🕉️'),
    ];
    for (var i = 0; i < cats.length; i++) {
      _categories.add(BookCategory(id: cats[i].$1, slug: cats[i].$1, name: cats[i].$2, icon: cats[i].$3, order: i));
    }

    const books = [
      ('Wings of Fire', 'An Autobiography', ['A. P. J. Abdul Kalam', 'Arun Tiwari'], '9788173711466', 'Universities Press', 1999, ['biography'], 'English', 3, 196, true,
          'The autobiography of India\'s "Missile Man" and former President — from a boy in Rameswaram to the architect of India\'s space and missile programmes.'),
      ('Godaan', '', ['Munshi Premchand'], '9788171822028', 'Rajpal & Sons', 1936, ['hindi-literature', 'fiction'], 'Hindi', 2, 312, true,
          'Premchand\'s masterpiece about the poor farmer Hori and his lifelong wish to own a cow — a classic portrait of rural India.'),
      ('The Discovery of India', '', ['Jawaharlal Nehru'], '9780143031031', 'Penguin', 1946, ['history'], 'English', 2, 656, false,
          'Written in prison, Nehru\'s sweeping account of Indian history, philosophy and culture from ancient times to the freedom struggle.'),
      ('Gitanjali', 'Song Offerings', ['Rabindranath Tagore'], '9788171676088', 'Rupa', 1910, ['fiction'], 'English', 1, 120, false,
          'The Nobel Prize-winning collection of devotional poems by Tagore.'),
      ('A Brief History of Time', '', ['Stephen Hawking'], '9780553380163', 'Bantam', 1988, ['science'], 'English', 2, 212, true,
          'From the Big Bang to black holes — Hawking explains the universe for everyone.'),
      ('Atomic Habits', 'Tiny Changes, Remarkable Results', ['James Clear'], '9780735211292', 'Avery', 2018, ['self-help'], 'English', 3, 320, true,
          'A practical framework for building good habits and breaking bad ones, one 1% improvement at a time.'),
      ('The Guide', '', ['R. K. Narayan'], '9780143039648', 'Penguin', 1958, ['fiction'], 'English', 2, 220, false,
          'Raju the tourist guide becomes an unlikely holy man in this Sahitya Akademi Award-winning novel.'),
      ('Panchatantra', '', ['Vishnu Sharma'], '9788184820325', 'Penguin', 300, ['children'], 'English', 2, 400, false,
          'Timeless animal fables that teach wisdom and good conduct.'),
      ('Indian Polity', '', ['M. Laxmikanth'], '9789355322510', 'McGraw Hill', 2023, ['competitive-exams'], 'English', 4, 960, false,
          'The standard reference for UPSC and state civil services on the Indian Constitution and political system.'),
      ('Diwan-e-Ghalib', '', ['Mirza Ghalib'], '9788171678495', 'Rekhta', 1841, ['urdu-literature'], 'Urdu', 1, 280, false,
          'The collected ghazals of Mirza Ghalib, the greatest poet of the Urdu language.'),
      ('Bhagavad Gita As It Is', '', ['A. C. Bhaktivedanta Swami Prabhupada'], '9788184818185', 'BBT', 1972, ['religion-philosophy'], 'English', 2, 924, false,
          'The Bhagavad Gita with Sanskrit verses, translations and commentary.'),
      ('Malgudi Days', '', ['R. K. Narayan'], '9780143039655', 'Penguin', 1943, ['fiction', 'children'], 'English', 2, 256, true,
          'Short stories set in the fictional town of Malgudi, full of gentle humour and everyday life.'),
    ];
    for (var i = 0; i < books.length; i++) {
      final b = books[i];
      final id = 'book-${i + 1}';
      _books[id] = Book(
        id: id,
        title: b.$1,
        subtitle: b.$2,
        authors: b.$3,
        isbn: b.$4,
        publisher: b.$5,
        publishedYear: b.$6,
        categories: b.$7,
        language: b.$8,
        totalCopies: b.$9,
        availableCopies: b.$9,
        pages: b.$10,
        featured: b.$11,
        description: b.$12,
        coverUrl: 'https://covers.openlibrary.org/b/isbn/${b.$4}-L.jpg',
        shelfLocation: '${String.fromCharCode(65 + i % 6)}-${10 + i}',
        slug: slugify(b.$1),
        createdAt: now.subtract(Duration(days: i * 3)),
      );
    }
    _books['book-4'] = _books['book-4']!.copyWith(availableCopies: 0); // Gitanjali — all out
    _books['book-10'] = _books['book-10']!.copyWith(availableCopies: 0);

    // Reviews
    _reviews['book-1'] = [
      Review(userId: 'u1', userName: 'Ayesha K.', rating: 5, comment: 'Inspiring! Every student should read this.', createdAt: now.subtract(const Duration(days: 3))),
      Review(userId: 'u2', userName: 'Rohit S.', rating: 4, comment: 'Simple language, powerful message.', createdAt: now.subtract(const Duration(days: 9))),
    ];
    _reviews['book-6'] = [Review(userId: 'u3', userName: 'Neha', rating: 5, comment: 'Changed my daily routine.', createdAt: now.subtract(const Duration(days: 1)))];
    _reviews['book-2'] = [Review(userId: 'u4', userName: 'Imran', rating: 5, comment: 'प्रेमचंद की सबसे अच्छी रचना।', createdAt: now.subtract(const Duration(days: 20)))];
    for (final id in _reviews.keys) {
      _recomputeRating(id);
    }

    // Events
    _events.addAll([
      LibraryEvent(id: 'ev-1', title: 'Children\'s Story Hour', description: 'Stories, puppets and drawing for kids aged 5–10. Free for all.',
          startAt: DateTime(now.year, now.month, now.day + 3, 11), endAt: DateTime(now.year, now.month, now.day + 3, 12), location: 'Kids Corner', published: true),
      LibraryEvent(id: 'ev-2', title: 'Urdu Poetry Evening — Remembering Ghalib', description: 'An evening of ghazals and recitations. All are welcome.',
          startAt: DateTime(now.year, now.month, now.day + 9, 17), location: 'Main Hall', published: true),
      LibraryEvent(id: 'ev-3', title: 'UPSC Preparation Workshop', description: 'Tips from successful candidates on reading Polity and current affairs.',
          startAt: now.subtract(const Duration(days: 12)), location: 'Reading Room', published: true),
    ]);

    _broadcasts.add(AppNotification(
        id: 'bc-1', title: 'New arrivals this week', body: '25 new books in Fiction and Competitive Exams — open Explore to see them.',
        type: 'broadcast', read: true, isBroadcast: true, createdAt: now.subtract(const Duration(days: 2))));
  }

  /// Gives the demo member some loans, history and messages once they log in.
  void _seedMemberActivity(String uid) {
    final now = DateTime.now();
    Loan loan(String bookId, DateTime issued, DateTime due, {LoanStatus status = LoanStatus.issued, int renewals = 0, DateTime? returned}) {
      final b = _books[bookId]!;
      return Loan(
        id: _id('loan'), bookId: bookId, bookTitle: b.title, bookCover: b.coverUrl, userId: uid,
        issuedAt: issued, dueAt: due, status: status, renewCount: renewals, returnedAt: returned,
      );
    }

    _loans.addAll([
      loan('book-6', now.subtract(const Duration(days: 12)), now.add(const Duration(days: 2))),
      loan('book-3', now.subtract(const Duration(days: 18)), now.subtract(const Duration(days: 4)), status: LoanStatus.overdue),
    ]);
    for (final l in _loans) {
      _books[l.bookId] = _books[l.bookId]!.copyWith(availableCopies: _books[l.bookId]!.availableCopies - 1);
    }
    _history.addAll([
      loan('book-7', now.subtract(const Duration(days: 60)), now.subtract(const Duration(days: 46)), status: LoanStatus.returned, returned: now.subtract(const Duration(days: 47))),
      loan('book-2', now.subtract(const Duration(days: 40)), now.subtract(const Duration(days: 26)), status: LoanStatus.returned, returned: now.subtract(const Duration(days: 24))),
      loan('book-12', now.subtract(const Duration(days: 20)), now.subtract(const Duration(days: 6)), status: LoanStatus.returned, returned: now.subtract(const Duration(days: 7))),
    ]);
    _reservations.addAll([
      Reservation(id: _id('res'), bookId: 'book-1', bookTitle: _books['book-1']!.title, bookCover: _books['book-1']!.coverUrl, userId: uid,
          status: ReservationStatus.ready, createdAt: now.subtract(const Duration(days: 1)), readyAt: now, expiresAt: now.add(const Duration(days: 3))),
      Reservation(id: _id('res'), bookId: 'book-4', bookTitle: _books['book-4']!.title, bookCover: _books['book-4']!.coverUrl, userId: uid,
          status: ReservationStatus.pending, queuePosition: 2, createdAt: now.subtract(const Duration(days: 2))),
    ]);
    _books['book-1'] = _books['book-1']!.copyWith(availableCopies: _books['book-1']!.availableCopies - 1);
    _fines.addAll([
      Fine(id: _id('fine'), userId: uid, bookTitle: 'Godaan', amount: 10, status: FineStatus.paid, paymentMode: 'upi',
          createdAt: now.subtract(const Duration(days: 24)), paidAt: now.subtract(const Duration(days: 24))),
      Fine(id: _id('fine'), userId: uid, bookTitle: 'Malgudi Days', amount: 5, reason: 'Late return', status: FineStatus.waived,
          createdAt: now.subtract(const Duration(days: 7)), paidAt: now.subtract(const Duration(days: 7))),
    ]);
    _wishlist[uid] = {'book-5', 'book-9'};
    _requests.add(BookRequest(id: _id('req'), userId: uid, title: 'The White Tiger', author: 'Aravind Adiga', status: 'approved',
        adminNote: 'Ordered — arriving next week.', createdAt: now.subtract(const Duration(days: 5))));
    _notify(uid, 'Book overdue', '"The Discovery of India" was due 4 days ago. Fines of ₹5/day apply.', 'overdue',
        at: now.subtract(const Duration(hours: 3)), data: {'loanId': _loans[1].id});
    _notify(uid, 'Your reserved book is ready', '"Wings of Fire" is waiting at the desk. Collect it within 3 days.', 'reservation_ready',
        at: now.subtract(const Duration(hours: 1)), data: {'bookId': 'book-1'});
    _notify(uid, 'Due soon', '"Atomic Habits" is due in 2 days. Renew it in the app if you need more time.', 'due_soon',
        at: now.subtract(const Duration(minutes: 20)), data: {'loanId': _loans[0].id});
  }

  void _notify(String uid, String title, String body, String type, {DateTime? at, Map<String, String> data = const {}}) {
    _notifications.insert(0, AppNotification(id: _id('n'), title: title, body: body, type: type, data: data, createdAt: at ?? DateTime.now()));
    _notifications.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
  }

  void _recomputeRating(String bookId) {
    final list = _reviews[bookId] ?? const <Review>[];
    final b = _books[bookId];
    if (b == null) return;
    final avg = list.isEmpty ? 0.0 : list.map((r) => r.rating).reduce((a, c) => a + c) / list.length;
    _books[bookId] = Book.fromJson(bookId, {
      ...b.toJson(),
      'ratingAvg': (avg * 10).round() / 10,
      'ratingCount': list.length,
      'createdAt': b.createdAt,
    });
  }

  // ===========================================================================
  // Settings & catalogue
  // ===========================================================================

  @override
  Stream<LibrarySettings> watchSettings() => _watch(() => _settings);

  @override
  Future<LibrarySettings> getSettings() async => _settings;

  @override
  Future<void> saveSettings(LibrarySettings s) async {
    _settings = s;
    _changed();
  }

  @override
  Stream<List<Book>> watchBooks({String? category, bool featuredOnly = false, int limit = 50, String orderBy = 'createdAt'}) => _watch(() {
        var list = _books.values.where((b) => (category == null || category.isEmpty || b.categories.contains(category)) && (!featuredOnly || b.featured)).toList();
        if (orderBy == 'title') {
          list.sort((a, b) => a.title.compareTo(b.title));
        } else {
          list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
        }
        return list.take(limit).toList();
      });

  @override
  Stream<List<Book>> watchPopular({int limit = 10}) =>
      _watch(() => (_books.values.toList()..sort((a, b) => b.ratingCount.compareTo(a.ratingCount))).take(limit).toList());

  @override
  Stream<Book?> watchBook(String id) => _watch(() => _books[id]);

  @override
  Future<Book?> getBook(String id) async => _books[id];

  @override
  Future<Book?> findByIsbn(String isbn) async {
    final clean = isbn.replaceAll(RegExp(r'[^0-9Xx]'), '');
    return _books.values.where((b) => b.isbn == clean).firstOrNull;
  }

  @override
  Future<List<Book>> searchBooks(String query, {int limit = 40, bool availableOnly = false, String? language}) async {
    await _lag();
    final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return [];
    final digits = query.replaceAll(RegExp(r'[^0-9Xx]'), '');
    return _books.values.where((b) {
      if (availableOnly && !b.isAvailable) return false;
      if (language != null && language.isNotEmpty && b.language != language) return false;
      if (digits.length >= 10) return b.isbn == digits;
      final kw = buildSearchKeywords(title: b.title, authors: b.authors, isbn: b.isbn, tags: b.tags);
      return words.every((w) => kw.contains(w.length > 15 ? w.substring(0, 15) : w));
    }).take(limit).toList();
  }

  @override
  Stream<List<BookCategory>> watchCategories() => _watch(() => _categories.map((c) {
        final count = _books.values.where((b) => b.categories.contains(c.slug)).length;
        return BookCategory(id: c.id, name: c.name, slug: c.slug, icon: c.icon, order: c.order, bookCount: count);
      }).toList());

  @override
  Stream<List<Review>> watchReviews(String bookId) =>
      _watch(() => [...?_reviews[bookId]]..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0))));

  @override
  Future<void> submitReview({required String bookId, required String uid, required String userName, required int rating, required String comment}) async {
    await _lag();
    final list = _reviews.putIfAbsent(bookId, () => []);
    list.removeWhere((r) => r.userId == uid);
    list.add(Review(userId: uid, userName: userName, rating: rating.clamp(1, 5), comment: comment.trim(), createdAt: DateTime.now()));
    _recomputeRating(bookId);
    _changed();
  }

  @override
  Future<void> deleteReview(String bookId, String uid) async {
    _reviews[bookId]?.removeWhere((r) => r.userId == uid);
    _recomputeRating(bookId);
    _changed();
  }

  // ===========================================================================
  // Member
  // ===========================================================================

  @override
  Stream<Member?> watchMember(String uid) => _watch(() => _members[uid]);

  @override
  Future<Member?> getMember(String uid) async => _members[uid];

  @override
  Future<void> ensureMemberProfile({required String uid, String phone = '', String name = '', String email = '', String photoUrl = ''}) async {
    if (_members.containsKey(uid)) return;
    await _lag();
    _members[uid] = Member(
      id: uid,
      name: name,
      phone: phone.isEmpty ? '+919876543210' : phone,
      email: email,
      photoUrl: photoUrl,
      membershipId: 'RPL-000042',
      createdAt: DateTime.now().subtract(const Duration(days: 90)),
    );
    _seedMemberActivity(uid);
    _changed();
  }

  @override
  Future<void> updateProfile(Member m) async {
    await _lag();
    _members[m.id] = m;
    _changed();
  }

  @override
  Future<String> uploadAvatar(String uid, Uint8List bytes) async {
    throw LibraryException('Photo upload needs Firebase — available once the app is connected.');
  }

  @override
  Future<void> addFcmToken(String uid, String token) async {}

  @override
  Future<void> removeFcmToken(String uid, String token) async {}

  @override
  Future<void> deleteMyAccount() async {
    throw LibraryException('Account deletion is disabled in demo mode.');
  }

  // ===========================================================================
  // Wishlist & history
  // ===========================================================================

  @override
  Stream<Set<String>> watchWishlistIds(String uid) => _watch(() => {...?_wishlist[uid]});

  @override
  Stream<List<Book>> watchWishlist(String uid) => _watch(() => (_wishlist[uid] ?? const <String>{}).map((id) => _books[id]).whereType<Book>().toList());

  @override
  Future<void> toggleWishlist(String uid, Book book, bool add) async {
    final set = _wishlist.putIfAbsent(uid, () => {});
    add ? set.add(book.id) : set.remove(book.id);
    _changed();
  }

  @override
  Stream<List<Loan>> watchReadingHistory(String uid) =>
      _watch(() => _history.where((l) => l.userId == uid).toList()..sort((a, b) => (b.returnedAt ?? b.dueAt).compareTo(a.returnedAt ?? a.dueAt)));

  // ===========================================================================
  // Loans & renewals
  // ===========================================================================

  @override
  Stream<List<Loan>> watchMemberLoans(String uid, {bool activeOnly = false}) => _watch(() {
        final list = [..._loans, if (!activeOnly) ..._history].where((l) => l.userId == uid).toList();
        list.sort((a, b) => activeOnly ? a.dueAt.compareTo(b.dueAt) : b.issuedAt.compareTo(a.issuedAt));
        return list;
      });

  @override
  Future<DateTime> renewMyLoan(String loanId) async {
    await _lag();
    final i = _loans.indexWhere((l) => l.id == loanId);
    if (i < 0) throw LibraryException('Loan not found.');
    final l = _loans[i];
    if (l.status != LoanStatus.issued) throw LibraryException('Only active, non-overdue loans can be renewed.');
    if (l.renewCount >= _settings.maxRenewals) throw LibraryException('Renewal limit (${_settings.maxRenewals}) reached.');
    if (_reservations.any((r) => r.bookId == l.bookId && r.status == ReservationStatus.pending)) {
      throw LibraryException('Another member is waiting for this book, so it cannot be renewed.');
    }
    final due = l.dueAt.add(Duration(days: _settings.loanDays));
    _loans[i] = Loan(
      id: l.id, bookId: l.bookId, bookTitle: l.bookTitle, bookCover: l.bookCover, userId: l.userId,
      issuedAt: l.issuedAt, dueAt: due, status: LoanStatus.issued, renewCount: l.renewCount + 1,
    );
    _notify(l.userId, 'Loan renewed', 'New due date for "${l.bookTitle}": ${formatDate(due)}.', 'renewed', data: {'loanId': l.id});
    _changed();
    return due;
  }

  // ===========================================================================
  // Reservations
  // ===========================================================================

  @override
  Future<void> reserveBook({required Book book, required Member member}) async {
    await _lag();
    if (_reservations.any((r) => r.userId == member.id && r.bookId == book.id && r.isOpen)) {
      throw LibraryException('You already have a reservation for this book.');
    }
    final current = _books[book.id]!;
    final now = DateTime.now();
    if (current.availableCopies > 0) {
      _books[book.id] = current.copyWith(availableCopies: current.availableCopies - 1);
      _reservations.insert(0, Reservation(id: _id('res'), bookId: book.id, bookTitle: book.title, bookCover: book.coverUrl, userId: member.id,
          status: ReservationStatus.ready, createdAt: now, readyAt: now, expiresAt: now.add(Duration(days: _settings.reservationHoldDays))));
      _notify(member.id, 'Your reserved book is ready', '"${book.title}" is waiting for you at the desk.', 'reservation_ready', data: {'bookId': book.id});
    } else {
      final ahead = _reservations.where((r) => r.bookId == book.id && r.status == ReservationStatus.pending).length + 1;
      _reservations.insert(0, Reservation(id: _id('res'), bookId: book.id, bookTitle: book.title, bookCover: book.coverUrl, userId: member.id,
          status: ReservationStatus.pending, queuePosition: ahead, createdAt: now));
      _notify(member.id, 'Reservation placed', 'You are #$ahead in the queue for "${book.title}".', 'reservation_queued', data: {'bookId': book.id});
    }
    _changed();
  }

  @override
  Future<void> cancelReservation(String id) async {
    final i = _reservations.indexWhere((r) => r.id == id);
    if (i < 0) return;
    final r = _reservations[i];
    if (r.status == ReservationStatus.ready) {
      final b = _books[r.bookId]!;
      _books[r.bookId] = b.copyWith(availableCopies: b.availableCopies + 1);
    }
    _reservations[i] = Reservation(id: r.id, bookId: r.bookId, bookTitle: r.bookTitle, bookCover: r.bookCover, userId: r.userId,
        status: ReservationStatus.cancelled, createdAt: r.createdAt);
    _changed();
  }

  @override
  Stream<List<Reservation>> watchMemberReservations(String uid) => _watch(() => _reservations.where((r) => r.userId == uid).toList());

  // ===========================================================================
  // Fines, notifications, events, requests
  // ===========================================================================

  @override
  Stream<List<Fine>> watchMemberFines(String uid) => _watch(() => _fines.where((f) => f.userId == uid).toList());

  @override
  Stream<List<AppNotification>> watchNotifications(String uid) => _watch(() => List.of(_notifications));

  @override
  Stream<int> watchUnreadCount(String uid) => _watch(() => _notifications.where((n) => !n.read).length);

  AppNotification _asRead(AppNotification n) =>
      AppNotification(id: n.id, title: n.title, body: n.body, type: n.type, data: n.data, createdAt: n.createdAt, read: true);

  @override
  Future<void> markNotificationRead(String uid, String id) async {
    final i = _notifications.indexWhere((n) => n.id == id);
    if (i >= 0) _notifications[i] = _asRead(_notifications[i]);
    _changed();
  }

  @override
  Future<void> markAllNotificationsRead(String uid) async {
    for (var i = 0; i < _notifications.length; i++) {
      _notifications[i] = _asRead(_notifications[i]);
    }
    _changed();
  }

  @override
  Future<void> deleteNotification(String uid, String id) async {
    _notifications.removeWhere((n) => n.id == id);
    _changed();
  }

  @override
  Stream<List<AppNotification>> watchBroadcastsAsNotifications({int limit = 30}) => _watch(() => List.of(_broadcasts));

  @override
  Stream<List<LibraryEvent>> watchEvents({bool publishedOnly = true, int limit = 50}) =>
      _watch(() => _events.where((e) => !publishedOnly || e.published).toList()..sort((a, b) => a.startAt.compareTo(b.startAt)));

  @override
  Future<void> submitBookRequest({required Member member, required String title, String author = '', String note = ''}) async {
    await _lag();
    _requests.insert(0, BookRequest(id: _id('req'), userId: member.id, userName: member.name, title: title.trim(), author: author.trim(),
        note: note.trim(), createdAt: DateTime.now()));
    _changed();
  }

  @override
  Stream<List<BookRequest>> watchMyBookRequests(String uid) => _watch(() => _requests.where((r) => r.userId == uid).toList());

  @override
  Future<void> submitFeedback({required String uid, required String message, int rating = 0}) => _lag();
}
