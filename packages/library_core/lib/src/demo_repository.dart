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
  /// [withCommunity] adds a set of members with loans, reservations and fines so the
  /// admin panel has something to manage.
  DemoLibraryRepository({bool withCommunity = false}) {
    _seed();
    if (withCommunity) _seedCommunity();
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
  final Map<String, List<AppNotification>> _inbox = {};
  final List<StaffMember> _staff = [];
  final List<Map<String, dynamic>> _audit = [];
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

  List<AppNotification> _box(String uid) => _inbox.putIfAbsent(uid, () => []);

  void _notify(String uid, String title, String body, String type, {DateTime? at, Map<String, String> data = const {}}) {
    final box = _box(uid);
    box.insert(0, AppNotification(id: _id('n'), title: title, body: body, type: type, data: data, createdAt: at ?? DateTime.now()));
    box.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
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
  Stream<List<AppNotification>> watchNotifications(String uid) => _watch(() => List.of(_box(uid)));

  @override
  Stream<int> watchUnreadCount(String uid) => _watch(() => _box(uid).where((n) => !n.read).length);

  AppNotification _asRead(AppNotification n) =>
      AppNotification(id: n.id, title: n.title, body: n.body, type: n.type, data: n.data, createdAt: n.createdAt, read: true);

  @override
  Future<void> markNotificationRead(String uid, String id) async {
    final box = _box(uid);
    final i = box.indexWhere((n) => n.id == id);
    if (i >= 0) box[i] = _asRead(box[i]);
    _changed();
  }

  @override
  Future<void> markAllNotificationsRead(String uid) async {
    final box = _box(uid);
    for (var i = 0; i < box.length; i++) {
      box[i] = _asRead(box[i]);
    }
    _changed();
  }

  @override
  Future<void> deleteNotification(String uid, String id) async {
    _box(uid).removeWhere((n) => n.id == id);
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

  // ===========================================================================
  // Staff side (admin panel)
  // ===========================================================================

  void _seedCommunity() {
    final now = DateTime.now();
    const people = [
      ('Ayesha Khan', '+919811000001', 'standard'),
      ('Rohit Sharma', '+919811000002', 'student'),
      ('Imran Ali', '+919811000003', 'standard'),
      ('Neha Verma', '+919811000004', 'premium'),
      ('Gurpreet Kaur', '+919811000005', 'standard'),
      ('Mohd. Sameer', '+919811000006', 'student'),
      ('Pooja Saxena', '+919811000007', 'senior'),
      ('Arjun Mehta', '+919811000008', 'standard'),
    ];
    for (var i = 0; i < people.length; i++) {
      final p = people[i];
      final id = 'member-${i + 1}';
      _members[id] = Member(
        id: id,
        name: p.$1,
        phone: p.$2,
        membershipType: p.$3,
        membershipId: 'RPL-${(i + 1).toString().padLeft(6, '0')}',
        status: i == 7 ? MemberStatus.suspended : MemberStatus.active,
        createdAt: now.subtract(Duration(days: 200 - i * 20)),
      );
    }
    // (member, book, issued days ago, loan days)
    const loans = [
      (1, 'book-1', 5, 14), (1, 'book-9', 20, 14), (2, 'book-5', 16, 14), (3, 'book-2', 3, 14),
      (4, 'book-6', 18, 14), (5, 'book-12', 1, 14), (6, 'book-8', 12, 14), (7, 'book-11', 25, 14),
      (2, 'book-4', 9, 14), (6, 'book-10', 7, 14),
    ];
    for (final l in loans) {
      final b = _books[l.$2]!;
      final m = _members['member-${l.$1}']!;
      if (b.availableCopies <= 0 && l.$2 != 'book-4' && l.$2 != 'book-10') continue;
      final issued = now.subtract(Duration(days: l.$3, hours: 3));
      final due = issued.add(Duration(days: l.$4));
      _loans.add(Loan(
        id: _id('loan'), bookId: b.id, bookTitle: b.title, bookCover: b.coverUrl, userId: m.id, userName: m.name,
        membershipId: m.membershipId, issuedAt: issued, dueAt: due, status: due.isBefore(now) ? LoanStatus.overdue : LoanStatus.issued,
      ));
      if (l.$2 != 'book-4' && l.$2 != 'book-10') _books[b.id] = b.copyWith(availableCopies: b.availableCopies - 1);
    }
    // Returned loans spread over the last two weeks (for the dashboard chart)
    for (var d = 1; d <= 13; d++) {
      final b = _books['book-${(d % 12) + 1}']!;
      final m = _members['member-${(d % 7) + 1}']!;
      final issued = now.subtract(Duration(days: d, hours: 2));
      _history.add(Loan(
        id: _id('loan'), bookId: b.id, bookTitle: b.title, bookCover: b.coverUrl, userId: m.id, userName: m.name,
        membershipId: m.membershipId, issuedAt: issued, dueAt: issued.add(const Duration(days: 14)),
        returnedAt: issued.add(const Duration(days: 1)), status: LoanStatus.returned,
      ));
    }
    _reservations.addAll([
      Reservation(id: _id('res'), bookId: 'book-4', bookTitle: 'Gitanjali', bookCover: _books['book-4']!.coverUrl, userId: 'member-1',
          userName: 'Ayesha Khan', membershipId: 'RPL-000001', status: ReservationStatus.pending, queuePosition: 1, createdAt: now.subtract(const Duration(days: 2))),
      Reservation(id: _id('res'), bookId: 'book-3', bookTitle: 'The Discovery of India', bookCover: _books['book-3']!.coverUrl, userId: 'member-4',
          userName: 'Neha Verma', membershipId: 'RPL-000004', status: ReservationStatus.ready, createdAt: now.subtract(const Duration(days: 1)),
          readyAt: now, expiresAt: now.add(const Duration(days: 3))),
    ]);
    _books['book-3'] = _books['book-3']!.copyWith(availableCopies: _books['book-3']!.availableCopies - 1);
    _fines.addAll([
      Fine(id: _id('fine'), userId: 'member-7', userName: 'Pooja Saxena', bookTitle: 'Bhagavad Gita As It Is', amount: 55, createdAt: now.subtract(const Duration(days: 2))),
      Fine(id: _id('fine'), userId: 'member-2', userName: 'Rohit Sharma', bookTitle: 'Indian Polity', amount: 30, createdAt: now.subtract(const Duration(days: 6))),
      Fine(id: _id('fine'), userId: 'member-3', userName: 'Imran Ali', bookTitle: 'The Guide', amount: 20, status: FineStatus.paid, paymentMode: 'cash',
          createdAt: now.subtract(const Duration(days: 9)), paidAt: now.subtract(const Duration(days: 8))),
      Fine(id: _id('fine'), userId: 'member-5', userName: 'Gurpreet Kaur', bookTitle: 'Malgudi Days', amount: 350, reason: 'Lost book',
          createdAt: now.subtract(const Duration(days: 4))),
    ]);
    _refreshOutstanding();
    _requests.addAll([
      BookRequest(id: _id('req'), userId: 'member-2', userName: 'Rohit Sharma', title: 'Lucent\'s General Knowledge', author: 'Lucent', note: 'Very useful for SSC.',
          createdAt: now.subtract(const Duration(days: 1))),
      BookRequest(id: _id('req'), userId: 'member-4', userName: 'Neha Verma', title: 'Ikigai', author: 'Héctor García', status: 'approved',
          createdAt: now.subtract(const Duration(days: 8))),
    ]);
    _staff.addAll([
      StaffMember(uid: 'demo-admin', email: 'admin@demo.com', role: 'admin'),
      StaffMember(uid: 'demo-librarian', email: 'librarian@demo.com', role: 'librarian'),
    ]);
  }

  void _refreshOutstanding() {
    for (final id in _members.keys.toList()) {
      final total = _fines.where((f) => f.userId == id && f.status == FineStatus.unpaid).fold<double>(0, (a, f) => a + f.amount);
      final m = _members[id]!;
      _members[id] = Member(
        id: m.id, name: m.name, phone: m.phone, email: m.email, photoUrl: m.photoUrl, address: m.address, dateOfBirth: m.dateOfBirth,
        gender: m.gender, membershipId: m.membershipId, membershipType: m.membershipType, status: m.status, maxLoans: m.maxLoans,
        outstandingFines: total, favouriteCategories: m.favouriteCategories, pushEnabled: m.pushEnabled,
        membershipExpiresAt: m.membershipExpiresAt, createdAt: m.createdAt,
      );
    }
  }

  List<Loan> get _allLoans => [..._loans, ..._history];

  @override
  Future<void> log(String action, Json details, String staffUid) async {
    _audit.insert(0, {'id': _id('log'), 'action': action, ...details, 'by': staffUid, 'at': DateTime.now()});
  }

  @override
  Stream<List<Json>> watchAuditLog({int limit = 100}) => _watch(() => _audit.take(limit).toList());

  @override
  Future<String> uploadImage(String path, Uint8List bytes, {String contentType = 'image/jpeg'}) async {
    throw LibraryException('Image upload needs Firebase. In demo mode paste an image URL instead.');
  }

  // ----- Catalogue management -----

  @override
  Future<String> saveBook(Book book, {Uint8List? coverBytes, String coverContentType = 'image/jpeg'}) async {
    await _lag();
    if (coverBytes != null) throw LibraryException('Cover upload needs Firebase. In demo mode paste a cover image URL.');
    final id = book.id.isEmpty ? _id('book') : book.id;
    final old = _books[id];
    final available = old == null ? book.totalCopies : old.availableCopies + (book.totalCopies - old.totalCopies);
    if (available < 0) throw LibraryException('Cannot reduce copies below the number currently issued or on hold.');
    _books[id] = Book.fromJson(id, {
      ...book.toJson(),
      'isbn': book.isbn.replaceAll(RegExp(r'[^0-9Xx]'), ''),
      'availableCopies': available,
      'slug': slugify(book.title),
      'ratingAvg': old?.ratingAvg ?? 0,
      'ratingCount': old?.ratingCount ?? 0,
      'createdAt': old?.createdAt ?? DateTime.now(),
      'updatedAt': DateTime.now(),
    });
    _changed();
    return id;
  }

  @override
  Future<void> deleteBook(String id) async {
    if (_loans.any((l) => l.bookId == id)) throw LibraryException('This book has copies out on loan. Return them first.');
    _books.remove(id);
    _changed();
  }

  @override
  Future<void> saveCategory({String? id, required String name, String icon = '', int order = 0}) async {
    final key = id == null || id.isEmpty ? slugify(name) : id;
    _categories.removeWhere((c) => c.id == key);
    _categories.add(BookCategory(id: key, slug: key, name: name, icon: icon, order: order));
    _categories.sort((a, b) => a.order.compareTo(b.order));
    _changed();
  }

  @override
  Future<void> deleteCategory(String id) async {
    _categories.removeWhere((c) => c.id == id);
    _changed();
  }

  // ----- Members -----

  @override
  Stream<List<Member>> watchMembers({String search = '', MemberStatus? status, int limit = 100}) => _watch(() {
        final q = search.trim().toLowerCase();
        final digits = search.replaceAll(RegExp(r'[^0-9]'), '');
        var list = _members.values.where((m) {
          if (q.isEmpty) return status == null || m.status == status;
          if (q.startsWith('rpl')) return m.membershipId.toLowerCase() == q;
          if (digits.length >= 6) return m.phone.endsWith(digits.length > 10 ? digits.substring(digits.length - 10) : digits);
          return m.name.toLowerCase().startsWith(q) || m.name.toLowerCase().contains(' $q');
        }).toList();
        list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
        return list.take(limit).toList();
      });

  @override
  Future<Member?> findMember(String query) async => (await watchMembers(search: query, limit: 1).first).firstOrNull;

  Member _withFields(Member m, Json f) => Member(
        id: m.id,
        name: (f['name'] as String?) ?? m.name,
        phone: m.phone,
        email: (f['email'] as String?) ?? m.email,
        photoUrl: m.photoUrl,
        address: m.address,
        dateOfBirth: m.dateOfBirth,
        gender: m.gender,
        membershipId: m.membershipId,
        membershipType: (f['membershipType'] as String?) ?? m.membershipType,
        status: f.containsKey('status') ? MemberStatus.values.byName(f['status'] as String) : m.status,
        maxLoans: (f['maxLoans'] as int?) ?? m.maxLoans,
        outstandingFines: m.outstandingFines,
        favouriteCategories: m.favouriteCategories,
        pushEnabled: m.pushEnabled,
        membershipExpiresAt: f.containsKey('membershipExpiresAt') ? tsToDate(f['membershipExpiresAt']) : m.membershipExpiresAt,
        createdAt: m.createdAt,
      );

  @override
  Future<void> setMemberStatus(String uid, MemberStatus status) async {
    _members[uid] = _withFields(_members[uid]!, {'status': status.name});
    _changed();
  }

  @override
  Future<void> updateMemberAsStaff(String uid, Json fields) async {
    await _lag();
    _members[uid] = _withFields(_members[uid]!, fields);
    _changed();
  }

  @override
  Future<String> createWalkInMember({required String name, required String phone, String email = '', String address = ''}) async {
    await _lag();
    final normalized = normalizePhone(phone);
    if (_members.values.any((m) => m.phone == normalized)) throw LibraryException('A member with this phone number already exists.');
    final id = _id('member');
    _members[id] = Member(
      id: id, name: name.trim(), phone: normalized, email: email.trim(), address: address.trim(),
      membershipId: 'RPL-${(_members.length + 1).toString().padLeft(6, '0')}', createdAt: DateTime.now(),
    );
    _changed();
    return id;
  }

  // ----- Circulation -----

  @override
  Stream<List<Loan>> watchLoans({LoanStatus? status, int limit = 200}) => _watch(() {
        final now = DateTime.now();
        final list = status == null
            ? (_allLoans..sort((a, b) => b.issuedAt.compareTo(a.issuedAt)))
            : (_allLoans.where((l) => l.status == status || (status == LoanStatus.overdue && l.status == LoanStatus.issued && l.dueAt.isBefore(now))).toList()
              ..sort((a, b) => a.dueAt.compareTo(b.dueAt)));
        return list.take(limit).toList();
      });

  @override
  Stream<List<Loan>> watchBookLoans(String bookId) => _watch(() => _loans.where((l) => l.bookId == bookId).toList());

  @override
  Future<String> issueBook({required String bookId, required String memberId, required String staffUid, int? loanDaysOverride}) async {
    await _lag();
    final book = _books[bookId];
    final member = _members[memberId];
    if (book == null) throw LibraryException('Book not found.');
    if (member == null) throw LibraryException('Member not found.');
    if (member.status != MemberStatus.active) throw LibraryException('Membership is ${member.status.name}.');
    final active = _loans.where((l) => l.userId == memberId).toList();
    if (active.length >= member.maxLoans) throw LibraryException('${member.name} already has ${active.length} books (limit ${member.maxLoans}).');
    if (active.any((l) => l.bookId == bookId)) throw LibraryException('This member already has this book.');
    if (active.any((l) => l.isOverdue)) throw LibraryException('Member has an overdue book. Collect it before issuing another.');
    final hold = _reservations.indexWhere((r) => r.userId == memberId && r.bookId == bookId && r.status == ReservationStatus.ready);
    if (hold < 0 && book.availableCopies <= 0) throw LibraryException('No copies available. Place a reservation instead.');

    final now = DateTime.now();
    final loan = Loan(
      id: _id('loan'), bookId: book.id, bookTitle: book.title, bookCover: book.coverUrl, userId: member.id, userName: member.name,
      membershipId: member.membershipId, issuedAt: now, dueAt: now.add(Duration(days: loanDaysOverride ?? _settings.loanDays)), issuedBy: staffUid,
    );
    _loans.add(loan);
    if (hold >= 0) {
      final r = _reservations[hold];
      _reservations[hold] = Reservation(id: r.id, bookId: r.bookId, bookTitle: r.bookTitle, bookCover: r.bookCover, userId: r.userId,
          userName: r.userName, membershipId: r.membershipId, status: ReservationStatus.fulfilled, createdAt: r.createdAt);
    } else {
      _books[book.id] = book.copyWith(availableCopies: book.availableCopies - 1);
    }
    _notify(member.id, 'Book issued', '"${book.title}" is due back on ${formatDate(loan.dueAt)}.', 'issued', data: {'loanId': loan.id});
    await log('issue', {'loanId': loan.id, 'bookId': bookId, 'memberId': memberId}, staffUid);
    _changed();
    return loan.id;
  }

  @override
  Future<double> returnBook({required Loan loan, required String staffUid, bool waiveFine = false, bool lost = false, double? lostCharge}) async {
    await _lag();
    final i = _loans.indexWhere((l) => l.id == loan.id);
    if (i < 0) throw LibraryException('This loan is already closed.');
    final now = DateTime.now();
    var fine = waiveFine
        ? 0.0
        : computeFine(dueAt: loan.dueAt, at: now, finePerDay: _settings.finePerDay, graceDays: _settings.graceDays, maxFine: _settings.maxFinePerLoan);
    final l = _loans.removeAt(i);
    _history.add(Loan(
      id: l.id, bookId: l.bookId, bookTitle: l.bookTitle, bookCover: l.bookCover, userId: l.userId, userName: l.userName,
      membershipId: l.membershipId, issuedAt: l.issuedAt, dueAt: l.dueAt, returnedAt: now, status: lost ? LoanStatus.lost : LoanStatus.returned,
      renewCount: l.renewCount, fineAmount: fine,
    ));
    final b = _books[l.bookId];
    if (b != null) {
      _books[l.bookId] = lost ? b.copyWith(totalCopies: b.totalCopies - 1) : b.copyWith(availableCopies: b.availableCopies + 1);
    }
    if (fine > 0) {
      _fines.insert(0, Fine(id: _id('fine'), userId: l.userId, userName: l.userName, loanId: l.id, bookTitle: l.bookTitle, amount: fine, createdAt: now));
    }
    if (lost && (lostCharge ?? 0) > 0) {
      _fines.insert(0, Fine(id: _id('fine'), userId: l.userId, userName: l.userName, loanId: l.id, bookTitle: l.bookTitle, amount: lostCharge!,
          reason: 'Lost book', createdAt: now));
      fine += lostCharge;
    }
    _refreshOutstanding();
    // Serve the waiting list
    final next = _reservations.indexWhere((r) => r.bookId == l.bookId && r.status == ReservationStatus.pending);
    final nb = _books[l.bookId];
    if (!lost && next >= 0 && nb != null && nb.availableCopies > 0) {
      final r = _reservations[next];
      _books[l.bookId] = nb.copyWith(availableCopies: nb.availableCopies - 1);
      _reservations[next] = Reservation(id: r.id, bookId: r.bookId, bookTitle: r.bookTitle, bookCover: r.bookCover, userId: r.userId,
          userName: r.userName, membershipId: r.membershipId, status: ReservationStatus.ready, createdAt: r.createdAt, readyAt: now,
          expiresAt: now.add(Duration(days: _settings.reservationHoldDays)));
    }
    await log(lost ? 'mark_lost' : 'return', {'loanId': l.id, 'fine': fine}, staffUid);
    _changed();
    return fine;
  }

  @override
  Future<void> extendLoan(String loanId, int days) async {
    final i = _loans.indexWhere((l) => l.id == loanId);
    if (i < 0) return;
    final l = _loans[i];
    _loans[i] = Loan(
      id: l.id, bookId: l.bookId, bookTitle: l.bookTitle, bookCover: l.bookCover, userId: l.userId, userName: l.userName,
      membershipId: l.membershipId, issuedAt: l.issuedAt, dueAt: l.dueAt.add(Duration(days: days)), renewCount: l.renewCount + 1,
    );
    _changed();
  }

  // ----- Reservations & fines -----

  @override
  Stream<List<Reservation>> watchReservations({ReservationStatus? status, int limit = 200}) =>
      _watch(() => _reservations.where((r) => status == null || r.status == status).take(limit).toList());

  @override
  Future<void> setReservationStatus(String id, ReservationStatus status) async {
    if (status == ReservationStatus.cancelled) return cancelReservation(id);
    final i = _reservations.indexWhere((r) => r.id == id);
    if (i < 0) return;
    final r = _reservations[i];
    _reservations[i] = Reservation(id: r.id, bookId: r.bookId, bookTitle: r.bookTitle, bookCover: r.bookCover, userId: r.userId,
        userName: r.userName, membershipId: r.membershipId, status: status, createdAt: r.createdAt);
    _changed();
  }

  @override
  Stream<List<Fine>> watchFines({FineStatus? status, int limit = 200}) =>
      _watch(() => _fines.where((f) => status == null || f.status == status).take(limit).toList());

  @override
  Future<void> settleFine(String id, {required bool waive, String paymentMode = 'cash', required String staffUid}) async {
    final i = _fines.indexWhere((f) => f.id == id);
    if (i < 0) return;
    final f = _fines[i];
    _fines[i] = Fine(id: f.id, userId: f.userId, userName: f.userName, loanId: f.loanId, bookTitle: f.bookTitle, amount: f.amount, reason: f.reason,
        status: waive ? FineStatus.waived : FineStatus.paid, paymentMode: waive ? '' : paymentMode, createdAt: f.createdAt, paidAt: DateTime.now());
    _refreshOutstanding();
    await log(waive ? 'waive_fine' : 'collect_fine', {'fineId': id}, staffUid);
    _changed();
  }

  @override
  Future<void> addManualFine({required Member member, required double amount, required String reason}) async {
    _fines.insert(0, Fine(id: _id('fine'), userId: member.id, userName: member.name, amount: amount, reason: reason, createdAt: DateTime.now()));
    _refreshOutstanding();
    _changed();
  }

  // ----- Messaging, events, requests -----

  @override
  Stream<List<Broadcast>> watchBroadcasts({int limit = 50}) => _watch(() => _broadcasts
      .map((b) => Broadcast(id: b.id, title: b.title, body: b.body, status: 'sent (demo)', createdAt: b.createdAt))
      .take(limit)
      .toList());

  @override
  Future<void> sendBroadcast({required String title, required String body, String topic = 'all', String link = '', required String staffUid}) async {
    await _lag();
    _broadcasts.insert(0, AppNotification(id: _id('bc'), title: title, body: body, type: 'broadcast', read: true, isBroadcast: true, createdAt: DateTime.now()));
    _changed();
  }

  @override
  Future<void> sendToMember({required String uid, required String title, required String body}) async {
    _notify(uid, title, body, 'general');
    _changed();
  }

  @override
  Future<void> saveEvent(LibraryEvent e, {Uint8List? imageBytes}) async {
    await _lag();
    if (imageBytes != null) throw LibraryException('Image upload needs Firebase.');
    final id = e.id.isEmpty ? _id('ev') : e.id;
    _events.removeWhere((x) => x.id == id);
    _events.add(LibraryEvent(id: id, title: e.title, description: e.description, imageUrl: e.imageUrl, startAt: e.startAt, endAt: e.endAt,
        location: e.location, published: e.published, notify: e.notify));
    _changed();
  }

  @override
  Future<void> deleteEvent(String id) async {
    _events.removeWhere((e) => e.id == id);
    _changed();
  }

  @override
  Stream<List<BookRequest>> watchBookRequests({int limit = 200}) => _watch(() => _requests.take(limit).toList());

  @override
  Future<void> updateBookRequest(String id, String status, {String adminNote = ''}) async {
    final i = _requests.indexWhere((r) => r.id == id);
    if (i < 0) return;
    final r = _requests[i];
    _requests[i] = BookRequest(id: r.id, userId: r.userId, userName: r.userName, title: r.title, author: r.author, note: r.note,
        status: status, adminNote: adminNote, createdAt: r.createdAt);
    _changed();
  }

  // ----- Dashboard & reports -----

  @override
  Future<DashboardStats> dashboardStats() async => DashboardStats(
        totalBooks: _books.length,
        totalMembers: _members.length,
        activeLoans: _loans.length,
        overdueLoans: _loans.where((l) => l.isOverdue).length,
        pendingReservations: _reservations.where((r) => r.isOpen).length,
        unpaidFines: _fines.where((f) => f.status == FineStatus.unpaid).length,
        pendingRequests: _requests.where((r) => r.status == 'pending').length,
      );

  @override
  Future<List<MapEntry<DateTime, int>>> issuesPerDay({int days = 14}) async {
    final start = DateTime.now().subtract(Duration(days: days - 1));
    final from = DateTime(start.year, start.month, start.day);
    final buckets = <DateTime, int>{for (var i = 0; i < days; i++) from.add(Duration(days: i)): 0};
    for (final l in _allLoans) {
      final k = DateTime(l.issuedAt.year, l.issuedAt.month, l.issuedAt.day);
      if (buckets.containsKey(k)) buckets[k] = buckets[k]! + 1;
    }
    return buckets.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  }

  @override
  Future<double> finesCollected({int days = 30}) async {
    final from = DateTime.now().subtract(Duration(days: days));
    return _fines.where((f) => f.status == FineStatus.paid && (f.paidAt ?? DateTime(0)).isAfter(from)).fold<double>(0, (a, f) => a + f.amount);
  }

  @override
  Future<List<Book>> allBooks() async => _books.values.toList()..sort((a, b) => a.title.compareTo(b.title));

  @override
  Future<List<Member>> allMembers() async => _members.values.toList();

  @override
  Future<List<Loan>> allLoans({int days = 365}) async => _allLoans..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));

  @override
  Future<List<Fine>> allFines() async => List.of(_fines);

  // ----- Staff -----

  @override
  Stream<List<StaffMember>> watchStaff() => _watch(() => _staff.where((s) => s.role != 'none').toList());

  @override
  Future<void> setStaffRole({String? email, String? phone, String? uid, required String role}) async {
    await _lag();
    final key = uid ?? email ?? phone ?? '';
    _staff.removeWhere((s) => s.uid == key || (email != null && s.email == email));
    if (role != 'none') _staff.add(StaffMember(uid: uid ?? 'demo-${_seq++}', email: email ?? '', phone: phone ?? '', role: role));
    _changed();
  }
}
