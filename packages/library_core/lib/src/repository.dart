import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'config.dart';
import 'models.dart';
import 'utils.dart';

/// A user-facing error (validation / business rule). Show [message] as-is.
class LibraryException implements Exception {
  LibraryException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Single data-access layer used by both apps. Every Firestore path lives here.
class LibraryRepository {
  LibraryRepository({FirebaseFirestore? firestore, FirebaseStorage? storage, FirebaseFunctions? functions})
      : _firestoreOverride = firestore,
        _storageOverride = storage,
        _functionsOverride = functions;

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseStorage? _storageOverride;
  final FirebaseFunctions? _functionsOverride;

  // Resolved lazily so a subclass (e.g. the offline demo) never touches Firebase.
  late final FirebaseFirestore _db = _firestoreOverride ?? FirebaseFirestore.instance;
  late final FirebaseStorage _storage = _storageOverride ?? FirebaseStorage.instance;
  late final FirebaseFunctions _functions = _functionsOverride ?? FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion);

  CollectionReference<Json> get _books => _db.collection('books');
  CollectionReference<Json> get _users => _db.collection('users');
  CollectionReference<Json> get _loans => _db.collection('loans');
  CollectionReference<Json> get _reservations => _db.collection('reservations');
  CollectionReference<Json> get _fines => _db.collection('fines');
  CollectionReference<Json> get _events => _db.collection('events');
  CollectionReference<Json> get _categories => _db.collection('categories');
  CollectionReference<Json> get _broadcasts => _db.collection('broadcasts');
  CollectionReference<Json> get _requests => _db.collection('bookRequests');
  DocumentReference<Json> get _settingsDoc => _db.collection('settings').doc('library');

  // =========================================================================
  // Settings
  // =========================================================================

  Stream<LibrarySettings> watchSettings() =>
      _settingsDoc.snapshots().map((s) => LibrarySettings.fromJson(s.data() ?? {}));

  Future<LibrarySettings> getSettings() async => LibrarySettings.fromJson((await _settingsDoc.get()).data() ?? {});

  Future<void> saveSettings(LibrarySettings s) => _settingsDoc.set(s.toJson(), SetOptions(merge: true));

  // =========================================================================
  // Catalogue
  // =========================================================================

  Stream<List<Book>> watchBooks({String? category, bool featuredOnly = false, int limit = 50, String orderBy = 'createdAt'}) {
    Query<Json> q = _books;
    if (category != null && category.isNotEmpty) q = q.where('categories', arrayContains: category);
    if (featuredOnly) q = q.where('featured', isEqualTo: true);
    q = q.orderBy(orderBy, descending: orderBy != 'title').limit(limit);
    return q.snapshots().map((s) => s.docs.map(Book.fromDoc).toList());
  }

  Stream<List<Book>> watchPopular({int limit = 10}) => _books
      .orderBy('ratingCount', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(Book.fromDoc).toList());

  Stream<Book?> watchBook(String id) => _books.doc(id).snapshots().map((s) => s.exists ? Book.fromDoc(s) : null);

  Future<Book?> getBook(String id) async {
    final s = await _books.doc(id).get();
    return s.exists ? Book.fromDoc(s) : null;
  }

  Future<Book?> findByIsbn(String isbn) async {
    final clean = isbn.replaceAll(RegExp(r'[^0-9Xx]'), '');
    if (clean.isEmpty) return null;
    final s = await _books.where('isbn', isEqualTo: clean).limit(1).get();
    return s.docs.isEmpty ? null : Book.fromDoc(s.docs.first);
  }

  /// Prefix search on title/author words and ISBN. Matches every word typed.
  Future<List<Book>> searchBooks(String query, {int limit = 40, bool availableOnly = false, String? language}) async {
    final token = searchToken(query);
    if (token.isEmpty) return [];
    final snap = await _books.where('searchKeywords', arrayContains: token).limit(limit * 2).get();
    final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return snap.docs.where((d) {
      final kw = List<String>.from(d.data()['searchKeywords'] ?? const []);
      return words.every((w) => kw.contains(w.length > 15 ? w.substring(0, 15) : w) || token == w);
    }).map(Book.fromDoc).where((b) {
      if (availableOnly && !b.isAvailable) return false;
      if (language != null && language.isNotEmpty && b.language != language) return false;
      return true;
    }).take(limit).toList();
  }

  /// Create or update a book (staff). Keeps available copies consistent when the
  /// total number of copies changes.
  Future<String> saveBook(Book book, {Uint8List? coverBytes, String coverContentType = 'image/jpeg'}) async {
    final ref = book.id.isEmpty ? _books.doc() : _books.doc(book.id);
    var coverUrl = book.coverUrl;
    if (coverBytes != null) {
      coverUrl = await uploadImage('covers/${ref.id}.jpg', coverBytes, contentType: coverContentType);
    }
    final isbn = book.isbn.replaceAll(RegExp(r'[^0-9Xx]'), '');
    final data = book.copyWith(coverUrl: coverUrl, isbn: isbn).toJson()
      ..['searchKeywords'] = buildSearchKeywords(title: book.title, authors: book.authors, isbn: isbn, tags: book.tags)
      ..['slug'] = '${slugify(book.title)}-${ref.id.substring(0, 6).toLowerCase()}'
      ..['updatedAt'] = FieldValue.serverTimestamp();

    await _db.runTransaction((tx) async {
      final existing = await tx.get(ref);
      if (existing.exists) {
        final oldTotal = (existing.data()?['totalCopies'] as num?)?.toInt() ?? 0;
        final oldAvail = (existing.data()?['availableCopies'] as num?)?.toInt() ?? 0;
        final delta = book.totalCopies - oldTotal;
        final newAvail = oldAvail + delta;
        if (newAvail < 0) {
          throw LibraryException('Cannot reduce copies below the number currently issued or on hold.');
        }
        data['availableCopies'] = newAvail;
        // Rating fields are owned by the reviews function.
        tx.update(ref, data);
      } else {
        data['availableCopies'] = book.totalCopies;
        data['ratingAvg'] = 0;
        data['ratingCount'] = 0;
        data['createdAt'] = FieldValue.serverTimestamp();
        tx.set(ref, data);
      }
    });
    return ref.id;
  }

  Future<void> deleteBook(String id) async {
    final active = await _loans.where('bookId', isEqualTo: id).where('status', whereIn: ['issued', 'overdue']).limit(1).get();
    if (active.docs.isNotEmpty) throw LibraryException('This book has copies out on loan. Return them first.');
    await _books.doc(id).delete();
  }

  Stream<List<BookCategory>> watchCategories() =>
      _categories.orderBy('order').snapshots().map((s) => s.docs.map(BookCategory.fromDoc).toList());

  Future<void> saveCategory({String? id, required String name, String icon = '', int order = 0}) {
    final doc = id == null || id.isEmpty ? _categories.doc(slugify(name)) : _categories.doc(id);
    return doc.set({'name': name, 'slug': doc.id, 'icon': icon, 'order': order}, SetOptions(merge: true));
  }

  Future<void> deleteCategory(String id) => _categories.doc(id).delete();

  Stream<List<Review>> watchReviews(String bookId) => _books
      .doc(bookId)
      .collection('reviews')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map(Review.fromDoc).toList());

  Future<void> submitReview({required String bookId, required String uid, required String userName, required int rating, required String comment}) =>
      _books.doc(bookId).collection('reviews').doc(uid).set({
        'rating': rating.clamp(1, 5),
        'comment': comment.trim(),
        'userName': userName,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> deleteReview(String bookId, String uid) => _books.doc(bookId).collection('reviews').doc(uid).delete();

  // =========================================================================
  // Members
  // =========================================================================

  Stream<Member?> watchMember(String uid) => _users.doc(uid).snapshots().map((s) => s.exists ? Member.fromDoc(s) : null);

  Future<Member?> getMember(String uid) async {
    final s = await _users.doc(uid).get();
    return s.exists ? Member.fromDoc(s) : null;
  }

  /// Called after OTP sign-in. The membership number is assigned by a Cloud Function.
  Future<void> ensureMemberProfile({required String uid, String phone = '', String name = '', String email = '', String photoUrl = ''}) async {
    final ref = _users.doc(uid);
    final snap = await ref.get();
    if (snap.exists) return;
    await ref.set({
      'name': name,
      'nameLower': name.toLowerCase(),
      'phone': phone,
      'email': email,
      'photoUrl': photoUrl,
      'preferences': {'push': true},
      'fcmTokens': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateProfile(Member m) => _users.doc(m.id).update({
        ...m.toProfileJson(),
        'nameLower': m.name.trim().toLowerCase(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<String> uploadAvatar(String uid, Uint8List bytes) async {
    final url = await uploadImage('avatars/$uid/profile.jpg', bytes);
    await _users.doc(uid).update({'photoUrl': url});
    return url;
  }

  Future<void> addFcmToken(String uid, String token) =>
      _users.doc(uid).set({'fcmTokens': FieldValue.arrayUnion([token]), 'lastSeenAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

  Future<void> removeFcmToken(String uid, String token) => _users.doc(uid).update({'fcmTokens': FieldValue.arrayRemove([token])});

  /// Staff: browse members. [search] matches membership number, phone or name prefix.
  Stream<List<Member>> watchMembers({String search = '', MemberStatus? status, int limit = 100}) {
    Query<Json> q = _users;
    final s = search.trim();
    if (s.isNotEmpty) {
      if (s.toUpperCase().startsWith('RPL')) {
        q = q.where('membershipId', isEqualTo: s.toUpperCase());
      } else if (RegExp(r'^[+\d\s]{6,}$').hasMatch(s)) {
        q = q.where('phone', isEqualTo: normalizePhone(s));
      } else {
        final lower = s.toLowerCase();
        q = q.where('nameLower', isGreaterThanOrEqualTo: lower).where('nameLower', isLessThan: '$lower');
      }
    } else {
      if (status != null) q = q.where('status', isEqualTo: status.name);
      q = q.orderBy('createdAt', descending: true);
    }
    return q.limit(limit).snapshots().map((s) => s.docs.map(Member.fromDoc).toList());
  }

  Future<Member?> findMember(String query) async {
    final list = await watchMembers(search: query, limit: 1).first;
    return list.isEmpty ? null : list.first;
  }

  Future<void> setMemberStatus(String uid, MemberStatus status) =>
      _users.doc(uid).update({'status': status.name, 'updatedAt': FieldValue.serverTimestamp()});

  Future<void> updateMemberAsStaff(String uid, Json fields) => _users.doc(uid).update({
        ...fields,
        if (fields['name'] is String) 'nameLower': (fields['name'] as String).toLowerCase(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// Staff can register walk-in members who don't use the app.
  Future<String> createWalkInMember({required String name, required String phone, String email = '', String address = ''}) async {
    final normalized = normalizePhone(phone);
    final existing = await _users.where('phone', isEqualTo: normalized).limit(1).get();
    if (existing.docs.isNotEmpty) throw LibraryException('A member with this phone number already exists.');
    final ref = _users.doc();
    await ref.set({
      'name': name.trim(),
      'nameLower': name.trim().toLowerCase(),
      'phone': normalized,
      'email': email.trim(),
      'address': address.trim(),
      'walkIn': true,
      'preferences': {'push': true},
      'fcmTokens': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  // =========================================================================
  // Wishlist
  // =========================================================================

  Stream<Set<String>> watchWishlistIds(String uid) =>
      _users.doc(uid).collection('wishlist').snapshots().map((s) => s.docs.map((d) => d.id).toSet());

  Stream<List<Book>> watchWishlist(String uid) => _users
      .doc(uid)
      .collection('wishlist')
      .orderBy('addedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => Book.fromJson(d.id, d.data())).toList());

  Future<void> toggleWishlist(String uid, Book book, bool add) {
    final ref = _users.doc(uid).collection('wishlist').doc(book.id);
    if (!add) return ref.delete();
    return ref.set({
      'title': book.title,
      'authors': book.authors,
      'coverUrl': book.coverUrl,
      'availableCopies': book.availableCopies,
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Loan>> watchReadingHistory(String uid) => _users
      .doc(uid)
      .collection('readingHistory')
      .orderBy('returnedAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map((d) {
            final data = d.data();
            return Loan(
              id: d.id,
              bookId: '${data['bookId'] ?? ''}',
              bookTitle: '${data['bookTitle'] ?? ''}',
              bookCover: '${data['bookCover'] ?? ''}',
              userId: uid,
              issuedAt: tsToDate(data['issuedAt']) ?? DateTime.now(),
              dueAt: tsToDate(data['returnedAt']) ?? DateTime.now(),
              returnedAt: tsToDate(data['returnedAt']),
              status: LoanStatus.returned,
            );
          }).toList());

  // =========================================================================
  // Circulation
  // =========================================================================

  Stream<List<Loan>> watchMemberLoans(String uid, {bool activeOnly = false}) {
    Query<Json> q = _loans.where('userId', isEqualTo: uid);
    if (activeOnly) {
      q = q.where('status', whereIn: ['issued', 'overdue']);
    } else {
      q = q.orderBy('issuedAt', descending: true).limit(100);
    }
    return q.snapshots().map((s) {
      final list = s.docs.map(Loan.fromDoc).toList();
      if (activeOnly) list.sort((a, b) => a.dueAt.compareTo(b.dueAt));
      return list;
    });
  }

  Stream<List<Loan>> watchLoans({LoanStatus? status, int limit = 200}) {
    Query<Json> q = _loans;
    if (status != null) {
      q = q.where('status', isEqualTo: status.name).orderBy('dueAt');
    } else {
      q = q.orderBy('issuedAt', descending: true);
    }
    return q.limit(limit).snapshots().map((s) => s.docs.map(Loan.fromDoc).toList());
  }

  Stream<List<Loan>> watchBookLoans(String bookId) => _loans
      .where('bookId', isEqualTo: bookId)
      .where('status', whereIn: ['issued', 'overdue'])
      .snapshots()
      .map((s) => s.docs.map(Loan.fromDoc).toList());

  /// Issue a copy to a member (staff). If the member has a ready reservation for
  /// this book, the copy held for them is used and the reservation is fulfilled.
  Future<String> issueBook({required String bookId, required String memberId, required String staffUid, int? loanDaysOverride}) async {
    final s = await getSettings();
    final active = await _loans.where('userId', isEqualTo: memberId).where('status', whereIn: ['issued', 'overdue']).get();
    final readyRes = await _reservations
        .where('userId', isEqualTo: memberId)
        .where('bookId', isEqualTo: bookId)
        .where('status', isEqualTo: 'ready')
        .limit(1)
        .get();
    final loanRef = _loans.doc();

    await _db.runTransaction((tx) async {
      final bookSnap = await tx.get(_books.doc(bookId));
      final userSnap = await tx.get(_users.doc(memberId));
      if (!bookSnap.exists) throw LibraryException('Book not found.');
      if (!userSnap.exists) throw LibraryException('Member not found.');
      final book = Book.fromDoc(bookSnap);
      final member = Member.fromDoc(userSnap);

      if (member.status != MemberStatus.active) throw LibraryException('Membership is ${member.status.name}.');
      if (active.docs.length >= member.maxLoans) {
        throw LibraryException('${member.name} already has ${active.docs.length} books (limit ${member.maxLoans}).');
      }
      if (active.docs.any((d) => d.data()['bookId'] == bookId)) throw LibraryException('This member already has this book.');
      if (active.docs.any((d) => d.data()['status'] == 'overdue')) {
        throw LibraryException('Member has an overdue book. Collect it before issuing another.');
      }

      final usingHold = readyRes.docs.isNotEmpty;
      if (!usingHold && book.availableCopies <= 0) throw LibraryException('No copies available. Place a reservation instead.');

      final now = DateTime.now();
      tx.set(loanRef, {
        'bookId': book.id,
        'bookTitle': book.title,
        'bookCover': book.coverUrl,
        'userId': member.id,
        'userName': member.name,
        'membershipId': member.membershipId,
        'issuedAt': Timestamp.fromDate(now),
        'dueAt': Timestamp.fromDate(now.add(Duration(days: loanDaysOverride ?? s.loanDays))),
        'status': 'issued',
        'renewCount': 0,
        'fineAmount': 0,
        'issuedBy': staffUid,
      });
      if (usingHold) {
        tx.update(readyRes.docs.first.reference, {'status': 'fulfilled', 'loanId': loanRef.id, 'updatedAt': FieldValue.serverTimestamp()});
      } else {
        tx.update(bookSnap.reference, {'availableCopies': FieldValue.increment(-1), 'updatedAt': FieldValue.serverTimestamp()});
      }
    });
    await log('issue', {'loanId': loanRef.id, 'bookId': bookId, 'memberId': memberId}, staffUid);
    return loanRef.id;
  }

  /// Return a loan (staff). Calculates the late fine from settings and records it.
  /// Returns the fine charged.
  Future<double> returnBook({required Loan loan, required String staffUid, bool waiveFine = false, bool lost = false, double? lostCharge}) async {
    final s = await getSettings();
    final now = DateTime.now();
    var fine = waiveFine ? 0.0 : computeFine(dueAt: loan.dueAt, at: now, finePerDay: s.finePerDay, graceDays: s.graceDays, maxFine: s.maxFinePerLoan);

    await _db.runTransaction((tx) async {
      final ref = _loans.doc(loan.id);
      final snap = await tx.get(ref);
      final status = snap.data()?['status'];
      if (status != 'issued' && status != 'overdue') throw LibraryException('This loan is already closed.');
      tx.update(ref, {
        'status': lost ? 'lost' : 'returned',
        'returnedAt': Timestamp.fromDate(now),
        'fineAmount': fine,
        'returnedTo': staffUid,
      });
      if (!lost) {
        tx.update(_books.doc(loan.bookId), {'availableCopies': FieldValue.increment(1), 'updatedAt': FieldValue.serverTimestamp()});
      } else {
        tx.update(_books.doc(loan.bookId), {'totalCopies': FieldValue.increment(-1), 'updatedAt': FieldValue.serverTimestamp()});
      }
      if (fine > 0) {
        tx.set(_fines.doc(), {
          'userId': loan.userId,
          'userName': loan.userName,
          'loanId': loan.id,
          'bookTitle': loan.bookTitle,
          'amount': fine,
          'reason': 'Late return',
          'status': 'unpaid',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      if (lost && (lostCharge ?? 0) > 0) {
        tx.set(_fines.doc(), {
          'userId': loan.userId,
          'userName': loan.userName,
          'loanId': loan.id,
          'bookTitle': loan.bookTitle,
          'amount': lostCharge,
          'reason': 'Lost book',
          'status': 'unpaid',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
    if (lost) fine += lostCharge ?? 0;
    await log(lost ? 'mark_lost' : 'return', {'loanId': loan.id, 'fine': fine}, staffUid);
    return fine;
  }

  /// Staff can extend a loan directly (members use [renewMyLoan]).
  Future<void> extendLoan(String loanId, int days) async {
    final snap = await _loans.doc(loanId).get();
    final due = tsToDate(snap.data()?['dueAt']) ?? DateTime.now();
    await _loans.doc(loanId).update({
      'dueAt': Timestamp.fromDate(due.add(Duration(days: days))),
      'status': 'issued',
      'renewCount': FieldValue.increment(1),
    });
  }

  /// Member renewal — validated server-side (limits, queue, fines).
  Future<DateTime> renewMyLoan(String loanId) async {
    try {
      final res = await _functions.httpsCallable('renewLoan').call<dynamic>({'loanId': loanId});
      final data = Map<String, dynamic>.from(res.data as Map);
      return DateTime.parse(data['dueAt'] as String).toLocal();
    } on FirebaseFunctionsException catch (e) {
      throw LibraryException(e.message ?? 'Could not renew.');
    }
  }

  // =========================================================================
  // Reservations
  // =========================================================================

  Future<void> reserveBook({required Book book, required Member member}) async {
    final existing = await _reservations
        .where('userId', isEqualTo: member.id)
        .where('bookId', isEqualTo: book.id)
        .where('status', whereIn: ['pending', 'ready'])
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) throw LibraryException('You already have a reservation for this book.');
    if (member.status != MemberStatus.active) throw LibraryException('Your membership is ${member.status.name}.');
    await _reservations.add({
      'bookId': book.id,
      'bookTitle': book.title,
      'bookCover': book.coverUrl,
      'userId': member.id,
      'userName': member.name,
      'membershipId': member.membershipId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelReservation(String id) =>
      _reservations.doc(id).update({'status': 'cancelled', 'updatedAt': FieldValue.serverTimestamp()});

  Stream<List<Reservation>> watchMemberReservations(String uid) => _reservations
      .where('userId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map(Reservation.fromDoc).toList());

  Stream<List<Reservation>> watchReservations({ReservationStatus? status, int limit = 200}) {
    Query<Json> q = _reservations;
    if (status != null) q = q.where('status', isEqualTo: status.name);
    return q.orderBy('createdAt', descending: true).limit(limit).snapshots().map((s) => s.docs.map(Reservation.fromDoc).toList());
  }

  Future<void> setReservationStatus(String id, ReservationStatus status) =>
      _reservations.doc(id).update({'status': status.name, 'updatedAt': FieldValue.serverTimestamp()});

  // =========================================================================
  // Fines
  // =========================================================================

  Stream<List<Fine>> watchMemberFines(String uid) => _fines
      .where('userId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(Fine.fromDoc).toList());

  Stream<List<Fine>> watchFines({FineStatus? status, int limit = 200}) {
    Query<Json> q = _fines;
    if (status != null) q = q.where('status', isEqualTo: status.name);
    return q.orderBy('createdAt', descending: true).limit(limit).snapshots().map((s) => s.docs.map(Fine.fromDoc).toList());
  }

  Future<void> settleFine(String id, {required bool waive, String paymentMode = 'cash', required String staffUid}) async {
    await _fines.doc(id).update({
      'status': waive ? 'waived' : 'paid',
      'paymentMode': waive ? '' : paymentMode,
      'paidAt': FieldValue.serverTimestamp(),
      'settledBy': staffUid,
    });
    await log(waive ? 'waive_fine' : 'collect_fine', {'fineId': id}, staffUid);
  }

  Future<void> addManualFine({required Member member, required double amount, required String reason}) => _fines.add({
        'userId': member.id,
        'userName': member.name,
        'amount': amount,
        'reason': reason,
        'status': 'unpaid',
        'createdAt': FieldValue.serverTimestamp(),
      });

  // =========================================================================
  // Notifications
  // =========================================================================

  Stream<List<AppNotification>> watchNotifications(String uid) => _users
      .doc(uid)
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map((d) => AppNotification.fromDoc(d)).toList());

  Stream<int> watchUnreadCount(String uid) => _users
      .doc(uid)
      .collection('notifications')
      .where('read', isEqualTo: false)
      .snapshots()
      .map((s) => s.size);

  Future<void> markNotificationRead(String uid, String id) =>
      _users.doc(uid).collection('notifications').doc(id).update({'read': true});

  Future<void> markAllNotificationsRead(String uid) async {
    final unread = await _users.doc(uid).collection('notifications').where('read', isEqualTo: false).get();
    final batch = _db.batch();
    for (final d in unread.docs) {
      batch.update(d.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> deleteNotification(String uid, String id) => _users.doc(uid).collection('notifications').doc(id).delete();

  Stream<List<Broadcast>> watchBroadcasts({int limit = 50}) =>
      _broadcasts.orderBy('createdAt', descending: true).limit(limit).snapshots().map((s) => s.docs.map(Broadcast.fromDoc).toList());

  Stream<List<AppNotification>> watchBroadcastsAsNotifications({int limit = 30}) => _broadcasts
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map((d) => AppNotification.fromDoc(d, broadcast: true)).toList());

  /// Staff: push to everyone subscribed to [topic] (all app users subscribe to `all`).
  Future<void> sendBroadcast({required String title, required String body, String topic = 'all', String link = '', required String staffUid}) =>
      _broadcasts.add({
        'title': title,
        'body': body,
        'topic': topic,
        'link': link,
        'status': 'queued',
        'createdBy': staffUid,
        'createdAt': FieldValue.serverTimestamp(),
      });

  /// Staff: push + inbox message to one member.
  Future<void> sendToMember({required String uid, required String title, required String body}) =>
      _users.doc(uid).collection('notifications').add({
        'title': title,
        'body': body,
        'type': 'general',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

  // =========================================================================
  // Events
  // =========================================================================

  Stream<List<LibraryEvent>> watchEvents({bool publishedOnly = true, int limit = 50}) {
    Query<Json> q = _events;
    if (publishedOnly) q = q.where('published', isEqualTo: true);
    return q.orderBy('startAt', descending: !publishedOnly).limit(limit).snapshots().map((s) => s.docs.map(LibraryEvent.fromDoc).toList());
  }

  Future<void> saveEvent(LibraryEvent e, {Uint8List? imageBytes}) async {
    final ref = e.id.isEmpty ? _events.doc() : _events.doc(e.id);
    final data = e.toJson();
    if (imageBytes != null) data['imageUrl'] = await uploadImage('events/${ref.id}.jpg', imageBytes);
    data['updatedAt'] = FieldValue.serverTimestamp();
    await ref.set(data, SetOptions(merge: true));
  }

  Future<void> deleteEvent(String id) => _events.doc(id).delete();

  // =========================================================================
  // Book requests (purchase suggestions)
  // =========================================================================

  Future<void> submitBookRequest({required Member member, required String title, String author = '', String note = ''}) => _requests.add({
        'userId': member.id,
        'userName': member.name,
        'title': title.trim(),
        'author': author.trim(),
        'note': note.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

  Stream<List<BookRequest>> watchMyBookRequests(String uid) => _requests
      .where('userId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(BookRequest.fromDoc).toList());

  Stream<List<BookRequest>> watchBookRequests({int limit = 200}) =>
      _requests.orderBy('createdAt', descending: true).limit(limit).snapshots().map((s) => s.docs.map(BookRequest.fromDoc).toList());

  Future<void> updateBookRequest(String id, String status, {String adminNote = ''}) =>
      _requests.doc(id).update({'status': status, 'adminNote': adminNote, 'updatedAt': FieldValue.serverTimestamp()});

  Future<void> submitFeedback({required String uid, required String message, int rating = 0}) => _db.collection('feedback').add({
        'userId': uid,
        'message': message.trim(),
        'rating': rating,
        'createdAt': FieldValue.serverTimestamp(),
      });

  // =========================================================================
  // Dashboard & reports (staff)
  // =========================================================================

  Future<int> _count(Query<Json> q) async => (await q.count().get()).count ?? 0;

  Future<DashboardStats> dashboardStats() async {
    final r = await Future.wait([
      _count(_books),
      _count(_users),
      _count(_loans.where('status', whereIn: ['issued', 'overdue'])),
      _count(_loans.where('status', isEqualTo: 'overdue')),
      _count(_reservations.where('status', whereIn: ['pending', 'ready'])),
      _count(_fines.where('status', isEqualTo: 'unpaid')),
      _count(_requests.where('status', isEqualTo: 'pending')),
    ]);
    return DashboardStats(
      totalBooks: r[0],
      totalMembers: r[1],
      activeLoans: r[2],
      overdueLoans: r[3],
      pendingReservations: r[4],
      unpaidFines: r[5],
      pendingRequests: r[6],
    );
  }

  /// Loans issued per day over the last [days] days (oldest first).
  Future<List<MapEntry<DateTime, int>>> issuesPerDay({int days = 14}) async {
    final start = DateTime.now().subtract(Duration(days: days - 1));
    final from = DateTime(start.year, start.month, start.day);
    final snap = await _loans.where('issuedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from)).get();
    final buckets = <DateTime, int>{for (var i = 0; i < days; i++) from.add(Duration(days: i)): 0};
    for (final d in snap.docs) {
      final t = tsToDate(d.data()['issuedAt']);
      if (t == null) continue;
      final key = DateTime(t.year, t.month, t.day);
      buckets[key] = (buckets[key] ?? 0) + 1;
    }
    return buckets.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  }

  Future<double> finesCollected({int days = 30}) async {
    final from = DateTime.now().subtract(Duration(days: days));
    final snap = await _fines.where('status', isEqualTo: 'paid').where('paidAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from)).get();
    return snap.docs.fold<double>(0, (sum, d) => sum + ((d.data()['amount'] as num?)?.toDouble() ?? 0));
  }

  Future<List<Book>> allBooks() async => (await _books.orderBy('title').get()).docs.map(Book.fromDoc).toList();
  Future<List<Member>> allMembers() async => (await _users.orderBy('createdAt', descending: true).get()).docs.map(Member.fromDoc).toList();
  Future<List<Loan>> allLoans({int days = 365}) async {
    final from = DateTime.now().subtract(Duration(days: days));
    return (await _loans.where('issuedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from)).orderBy('issuedAt', descending: true).get())
        .docs
        .map(Loan.fromDoc)
        .toList();
  }

  Future<List<Fine>> allFines() async => (await _fines.orderBy('createdAt', descending: true).get()).docs.map(Fine.fromDoc).toList();

  // =========================================================================
  // Staff management
  // =========================================================================

  Stream<List<StaffMember>> watchStaff() => _db
      .collection('staff')
      .where('role', whereIn: ['admin', 'librarian'])
      .snapshots()
      .map((s) => s.docs.map(StaffMember.fromDoc).toList());

  Future<void> setStaffRole({String? email, String? phone, String? uid, required String role}) async {
    try {
      await _functions.httpsCallable('setStaffRole').call<dynamic>({
        if (uid != null) 'uid': uid,
        if (email != null && email.isNotEmpty) 'email': email.trim(),
        if (phone != null && phone.isNotEmpty) 'phone': normalizePhone(phone),
        'role': role,
      });
    } on FirebaseFunctionsException catch (e) {
      throw LibraryException(e.message ?? 'Could not update role.');
    }
  }

  Future<void> deleteMyAccount() async {
    try {
      await _functions.httpsCallable('deleteMyAccount').call<dynamic>();
    } on FirebaseFunctionsException catch (e) {
      throw LibraryException(e.message ?? 'Could not delete account.');
    }
  }

  Stream<List<Json>> watchAuditLog({int limit = 100}) => _db
      .collection('auditLogs')
      .orderBy('at', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());

  // =========================================================================
  // Misc
  // =========================================================================

  Future<String> uploadImage(String path, Uint8List bytes, {String contentType = 'image/jpeg'}) async {
    final ref = _storage.ref(path);
    await ref.putData(bytes, SettableMetadata(contentType: contentType, cacheControl: 'public, max-age=31536000'));
    return ref.getDownloadURL();
  }

  Future<void> log(String action, Json details, String staffUid) =>
      _db.collection('auditLogs').add({'action': action, ...details, 'by': staffUid, 'at': FieldValue.serverTimestamp()});
}
