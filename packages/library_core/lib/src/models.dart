import 'package:cloud_firestore/cloud_firestore.dart';

typedef Json = Map<String, dynamic>;

DateTime? tsToDate(Object? v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return null;
}

Timestamp? dateToTs(DateTime? d) => d == null ? null : Timestamp.fromDate(d);

List<String> _strings(Object? v) => v is Iterable ? v.map((e) => e.toString()).toList() : <String>[];
int _int(Object? v, [int fallback = 0]) => v is num ? v.toInt() : int.tryParse('$v') ?? fallback;
double _double(Object? v, [double fallback = 0]) => v is num ? v.toDouble() : double.tryParse('$v') ?? fallback;
String _str(Object? v, [String fallback = '']) => v?.toString() ?? fallback;

// ---------------------------------------------------------------------------
// Catalogue
// ---------------------------------------------------------------------------

class Book {
  Book({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.authors = const [],
    this.isbn = '',
    this.publisher = '',
    this.publishedYear,
    this.categories = const [],
    this.language = 'English',
    this.description = '',
    this.coverUrl = '',
    this.pages,
    this.totalCopies = 1,
    this.availableCopies = 1,
    this.shelfLocation = '',
    this.tags = const [],
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.slug = '',
    this.featured = false,
    this.ebookUrl = '',
    this.price,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<String> authors;
  final String isbn;
  final String publisher;
  final int? publishedYear;
  final List<String> categories; // category slugs
  final String language;
  final String description;
  final String coverUrl;
  final int? pages;
  final int totalCopies;
  final int availableCopies;
  final String shelfLocation;
  final List<String> tags;
  final double ratingAvg;
  final int ratingCount;
  final String slug;
  final bool featured;
  final String ebookUrl;
  final double? price;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isAvailable => availableCopies > 0;
  String get authorLine => authors.isEmpty ? 'Unknown author' : authors.join(', ');

  factory Book.fromDoc(DocumentSnapshot<Json> doc) => Book.fromJson(doc.id, doc.data() ?? {});

  factory Book.fromJson(String id, Json d) => Book(
        id: id,
        title: _str(d['title'], 'Untitled'),
        subtitle: _str(d['subtitle']),
        authors: _strings(d['authors']),
        isbn: _str(d['isbn']),
        publisher: _str(d['publisher']),
        publishedYear: d['publishedYear'] == null ? null : _int(d['publishedYear']),
        categories: _strings(d['categories']),
        language: _str(d['language'], 'English'),
        description: _str(d['description']),
        coverUrl: _str(d['coverUrl']),
        pages: d['pages'] == null ? null : _int(d['pages']),
        totalCopies: _int(d['totalCopies'], 1),
        availableCopies: _int(d['availableCopies'], 0),
        shelfLocation: _str(d['shelfLocation']),
        tags: _strings(d['tags']),
        ratingAvg: _double(d['ratingAvg']),
        ratingCount: _int(d['ratingCount']),
        slug: _str(d['slug']),
        featured: d['featured'] == true,
        ebookUrl: _str(d['ebookUrl']),
        price: d['price'] == null ? null : _double(d['price']),
        createdAt: tsToDate(d['createdAt']),
        updatedAt: tsToDate(d['updatedAt']),
      );

  Json toJson() => {
        'title': title,
        'subtitle': subtitle,
        'authors': authors,
        'isbn': isbn,
        'publisher': publisher,
        'publishedYear': publishedYear,
        'categories': categories,
        'language': language,
        'description': description,
        'coverUrl': coverUrl,
        'pages': pages,
        'totalCopies': totalCopies,
        'availableCopies': availableCopies,
        'shelfLocation': shelfLocation,
        'tags': tags,
        'slug': slug,
        'featured': featured,
        'ebookUrl': ebookUrl,
        'price': price,
      };

  Book copyWith({
    String? title,
    String? subtitle,
    List<String>? authors,
    String? isbn,
    String? publisher,
    int? publishedYear,
    List<String>? categories,
    String? language,
    String? description,
    String? coverUrl,
    int? pages,
    int? totalCopies,
    int? availableCopies,
    String? shelfLocation,
    List<String>? tags,
    bool? featured,
    String? ebookUrl,
    double? price,
  }) =>
      Book(
        id: id,
        title: title ?? this.title,
        subtitle: subtitle ?? this.subtitle,
        authors: authors ?? this.authors,
        isbn: isbn ?? this.isbn,
        publisher: publisher ?? this.publisher,
        publishedYear: publishedYear ?? this.publishedYear,
        categories: categories ?? this.categories,
        language: language ?? this.language,
        description: description ?? this.description,
        coverUrl: coverUrl ?? this.coverUrl,
        pages: pages ?? this.pages,
        totalCopies: totalCopies ?? this.totalCopies,
        availableCopies: availableCopies ?? this.availableCopies,
        shelfLocation: shelfLocation ?? this.shelfLocation,
        tags: tags ?? this.tags,
        ratingAvg: ratingAvg,
        ratingCount: ratingCount,
        slug: slug,
        featured: featured ?? this.featured,
        ebookUrl: ebookUrl ?? this.ebookUrl,
        price: price ?? this.price,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

class BookCategory {
  BookCategory({required this.id, required this.name, required this.slug, this.icon = '', this.bookCount = 0, this.order = 0});

  final String id;
  final String name;
  final String slug;
  final String icon; // emoji or material icon name
  final int bookCount;
  final int order;

  factory BookCategory.fromDoc(DocumentSnapshot<Json> doc) {
    final d = doc.data() ?? {};
    return BookCategory(
      id: doc.id,
      name: _str(d['name']),
      slug: _str(d['slug'], doc.id),
      icon: _str(d['icon']),
      bookCount: _int(d['bookCount']),
      order: _int(d['order']),
    );
  }

  Json toJson() => {'name': name, 'slug': slug, 'icon': icon, 'order': order};
}

class Review {
  Review({required this.userId, required this.userName, required this.rating, required this.comment, this.createdAt});

  final String userId;
  final String userName;
  final int rating;
  final String comment;
  final DateTime? createdAt;

  factory Review.fromDoc(DocumentSnapshot<Json> doc) {
    final d = doc.data() ?? {};
    return Review(
      userId: doc.id,
      userName: _str(d['userName'], 'Member'),
      rating: _int(d['rating'], 5),
      comment: _str(d['comment']),
      createdAt: tsToDate(d['createdAt']),
    );
  }
}

// ---------------------------------------------------------------------------
// Members
// ---------------------------------------------------------------------------

enum MemberStatus { active, suspended, expired }

class Member {
  Member({
    required this.id,
    this.name = '',
    this.phone = '',
    this.email = '',
    this.photoUrl = '',
    this.address = '',
    this.dateOfBirth,
    this.gender = '',
    this.membershipId = '',
    this.membershipType = 'standard',
    this.status = MemberStatus.active,
    this.maxLoans = 3,
    this.outstandingFines = 0,
    this.favouriteCategories = const [],
    this.pushEnabled = true,
    this.membershipExpiresAt,
    this.createdAt,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final String photoUrl;
  final String address;
  final DateTime? dateOfBirth;
  final String gender;
  final String membershipId;
  final String membershipType;
  final MemberStatus status;
  final int maxLoans;
  final double outstandingFines;
  final List<String> favouriteCategories;
  final bool pushEnabled;
  final DateTime? membershipExpiresAt;
  final DateTime? createdAt;

  bool get isProfileComplete => name.trim().isNotEmpty;
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  factory Member.fromDoc(DocumentSnapshot<Json> doc) {
    final d = doc.data() ?? {};
    final prefs = d['preferences'] is Map ? Map<String, dynamic>.from(d['preferences'] as Map) : <String, dynamic>{};
    return Member(
      id: doc.id,
      name: _str(d['name']),
      phone: _str(d['phone']),
      email: _str(d['email']),
      photoUrl: _str(d['photoUrl']),
      address: _str(d['address']),
      dateOfBirth: tsToDate(d['dateOfBirth']),
      gender: _str(d['gender']),
      membershipId: _str(d['membershipId']),
      membershipType: _str(d['membershipType'], 'standard'),
      status: MemberStatus.values.firstWhere((s) => s.name == d['status'], orElse: () => MemberStatus.active),
      maxLoans: _int(d['maxLoans'], 3),
      outstandingFines: _double(d['outstandingFines']),
      favouriteCategories: _strings(d['favouriteCategories']),
      pushEnabled: prefs['push'] != false,
      membershipExpiresAt: tsToDate(d['membershipExpiresAt']),
      createdAt: tsToDate(d['createdAt']),
    );
  }

  /// Fields a member may edit themselves.
  Json toProfileJson() => {
        'name': name.trim(),
        'email': email.trim(),
        'photoUrl': photoUrl,
        'address': address.trim(),
        'dateOfBirth': dateToTs(dateOfBirth),
        'gender': gender,
        'favouriteCategories': favouriteCategories,
        'preferences': {'push': pushEnabled},
      };

  Member copyWith({
    String? name,
    String? email,
    String? photoUrl,
    String? address,
    DateTime? dateOfBirth,
    String? gender,
    List<String>? favouriteCategories,
    bool? pushEnabled,
  }) =>
      Member(
        id: id,
        name: name ?? this.name,
        phone: phone,
        email: email ?? this.email,
        photoUrl: photoUrl ?? this.photoUrl,
        address: address ?? this.address,
        dateOfBirth: dateOfBirth ?? this.dateOfBirth,
        gender: gender ?? this.gender,
        membershipId: membershipId,
        membershipType: membershipType,
        status: status,
        maxLoans: maxLoans,
        outstandingFines: outstandingFines,
        favouriteCategories: favouriteCategories ?? this.favouriteCategories,
        pushEnabled: pushEnabled ?? this.pushEnabled,
        membershipExpiresAt: membershipExpiresAt,
        createdAt: createdAt,
      );
}

// ---------------------------------------------------------------------------
// Circulation
// ---------------------------------------------------------------------------

enum LoanStatus { issued, overdue, returned, lost }

class Loan {
  Loan({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    this.bookCover = '',
    required this.userId,
    this.userName = '',
    this.membershipId = '',
    required this.issuedAt,
    required this.dueAt,
    this.returnedAt,
    this.status = LoanStatus.issued,
    this.renewCount = 0,
    this.fineAmount = 0,
    this.accruedFine = 0,
    this.issuedBy = '',
  });

  final String id;
  final String bookId;
  final String bookTitle;
  final String bookCover;
  final String userId;
  final String userName;
  final String membershipId;
  final DateTime issuedAt;
  final DateTime dueAt;
  final DateTime? returnedAt;
  final LoanStatus status;
  final int renewCount;
  final double fineAmount;
  final double accruedFine;
  final String issuedBy;

  bool get isActive => status == LoanStatus.issued || status == LoanStatus.overdue;
  bool get isOverdue => status == LoanStatus.overdue || (status == LoanStatus.issued && DateTime.now().isAfter(dueAt));
  int get daysLeft => dueAt.difference(DateTime.now()).inHours ~/ 24;

  factory Loan.fromDoc(DocumentSnapshot<Json> doc) {
    final d = doc.data() ?? {};
    return Loan(
      id: doc.id,
      bookId: _str(d['bookId']),
      bookTitle: _str(d['bookTitle']),
      bookCover: _str(d['bookCover']),
      userId: _str(d['userId']),
      userName: _str(d['userName']),
      membershipId: _str(d['membershipId']),
      issuedAt: tsToDate(d['issuedAt']) ?? DateTime.now(),
      dueAt: tsToDate(d['dueAt']) ?? DateTime.now(),
      returnedAt: tsToDate(d['returnedAt']),
      status: LoanStatus.values.firstWhere((s) => s.name == d['status'], orElse: () => LoanStatus.issued),
      renewCount: _int(d['renewCount']),
      fineAmount: _double(d['fineAmount']),
      accruedFine: _double(d['accruedFine']),
      issuedBy: _str(d['issuedBy']),
    );
  }
}

enum ReservationStatus { pending, ready, fulfilled, cancelled, expired }

class Reservation {
  Reservation({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    this.bookCover = '',
    required this.userId,
    this.userName = '',
    this.membershipId = '',
    this.status = ReservationStatus.pending,
    this.queuePosition,
    this.createdAt,
    this.readyAt,
    this.expiresAt,
  });

  final String id;
  final String bookId;
  final String bookTitle;
  final String bookCover;
  final String userId;
  final String userName;
  final String membershipId;
  final ReservationStatus status;
  final int? queuePosition;
  final DateTime? createdAt;
  final DateTime? readyAt;
  final DateTime? expiresAt;

  bool get isOpen => status == ReservationStatus.pending || status == ReservationStatus.ready;

  factory Reservation.fromDoc(DocumentSnapshot<Json> doc) {
    final d = doc.data() ?? {};
    return Reservation(
      id: doc.id,
      bookId: _str(d['bookId']),
      bookTitle: _str(d['bookTitle']),
      bookCover: _str(d['bookCover']),
      userId: _str(d['userId']),
      userName: _str(d['userName']),
      membershipId: _str(d['membershipId']),
      status: ReservationStatus.values.firstWhere((s) => s.name == d['status'], orElse: () => ReservationStatus.pending),
      queuePosition: d['queuePosition'] == null ? null : _int(d['queuePosition']),
      createdAt: tsToDate(d['createdAt']),
      readyAt: tsToDate(d['readyAt']),
      expiresAt: tsToDate(d['expiresAt']),
    );
  }
}

enum FineStatus { unpaid, paid, waived }

class Fine {
  Fine({
    required this.id,
    required this.userId,
    this.userName = '',
    this.loanId = '',
    this.bookTitle = '',
    required this.amount,
    this.reason = 'Late return',
    this.status = FineStatus.unpaid,
    this.paymentMode = '',
    this.createdAt,
    this.paidAt,
  });

  final String id;
  final String userId;
  final String userName;
  final String loanId;
  final String bookTitle;
  final double amount;
  final String reason;
  final FineStatus status;
  final String paymentMode;
  final DateTime? createdAt;
  final DateTime? paidAt;

  factory Fine.fromDoc(DocumentSnapshot<Json> doc) {
    final d = doc.data() ?? {};
    return Fine(
      id: doc.id,
      userId: _str(d['userId']),
      userName: _str(d['userName']),
      loanId: _str(d['loanId']),
      bookTitle: _str(d['bookTitle']),
      amount: _double(d['amount']),
      reason: _str(d['reason'], 'Late return'),
      status: FineStatus.values.firstWhere((s) => s.name == d['status'], orElse: () => FineStatus.unpaid),
      paymentMode: _str(d['paymentMode']),
      createdAt: tsToDate(d['createdAt']),
      paidAt: tsToDate(d['paidAt']),
    );
  }
}

// ---------------------------------------------------------------------------
// Engagement
// ---------------------------------------------------------------------------

class LibraryEvent {
  LibraryEvent({
    required this.id,
    required this.title,
    this.description = '',
    this.imageUrl = '',
    required this.startAt,
    this.endAt,
    this.location = '',
    this.published = false,
    this.notify = false,
  });

  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final DateTime startAt;
  final DateTime? endAt;
  final String location;
  final bool published;
  final bool notify;

  bool get isUpcoming => (endAt ?? startAt).isAfter(DateTime.now());

  factory LibraryEvent.fromDoc(DocumentSnapshot<Json> doc) {
    final d = doc.data() ?? {};
    return LibraryEvent(
      id: doc.id,
      title: _str(d['title']),
      description: _str(d['description']),
      imageUrl: _str(d['imageUrl']),
      startAt: tsToDate(d['startAt']) ?? DateTime.now(),
      endAt: tsToDate(d['endAt']),
      location: _str(d['location']),
      published: d['published'] == true,
      notify: d['notify'] == true,
    );
  }

  Json toJson() => {
        'title': title,
        'description': description,
        'imageUrl': imageUrl,
        'startAt': Timestamp.fromDate(startAt),
        'endAt': dateToTs(endAt),
        'location': location,
        'published': published,
        'notify': notify,
      };
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.type = 'general',
    this.read = false,
    this.data = const {},
    this.createdAt,
    this.isBroadcast = false,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final bool read;
  final Map<String, String> data;
  final DateTime? createdAt;
  final bool isBroadcast;

  factory AppNotification.fromDoc(DocumentSnapshot<Json> doc, {bool broadcast = false}) {
    final d = doc.data() ?? {};
    final raw = d['data'];
    return AppNotification(
      id: doc.id,
      title: _str(d['title']),
      body: _str(d['body']),
      type: broadcast ? 'broadcast' : _str(d['type'], 'general'),
      read: broadcast ? true : d['read'] == true,
      data: raw is Map ? raw.map((k, v) => MapEntry('$k', '$v')) : const {},
      createdAt: tsToDate(d['createdAt']),
      isBroadcast: broadcast,
    );
  }
}

class Broadcast {
  Broadcast({required this.id, required this.title, required this.body, this.topic = 'all', this.status = '', this.createdAt});

  final String id;
  final String title;
  final String body;
  final String topic;
  final String status;
  final DateTime? createdAt;

  factory Broadcast.fromDoc(DocumentSnapshot<Json> doc) {
    final d = doc.data() ?? {};
    return Broadcast(
      id: doc.id,
      title: _str(d['title']),
      body: _str(d['body']),
      topic: _str(d['topic'], 'all'),
      status: _str(d['status'], 'queued'),
      createdAt: tsToDate(d['createdAt']),
    );
  }
}

class BookRequest {
  BookRequest({
    required this.id,
    required this.userId,
    this.userName = '',
    required this.title,
    this.author = '',
    this.note = '',
    this.status = 'pending',
    this.adminNote = '',
    this.createdAt,
  });

  final String id;
  final String userId;
  final String userName;
  final String title;
  final String author;
  final String note;
  final String status; // pending | approved | acquired | rejected
  final String adminNote;
  final DateTime? createdAt;

  factory BookRequest.fromDoc(DocumentSnapshot<Json> doc) {
    final d = doc.data() ?? {};
    return BookRequest(
      id: doc.id,
      userId: _str(d['userId']),
      userName: _str(d['userName']),
      title: _str(d['title']),
      author: _str(d['author']),
      note: _str(d['note']),
      status: _str(d['status'], 'pending'),
      adminNote: _str(d['adminNote']),
      createdAt: tsToDate(d['createdAt']),
    );
  }
}

class StaffMember {
  StaffMember({required this.uid, this.email = '', this.phone = '', this.name = '', this.role = 'none'});

  final String uid;
  final String email;
  final String phone;
  final String name;
  final String role;

  factory StaffMember.fromDoc(DocumentSnapshot<Json> doc) {
    final d = doc.data() ?? {};
    return StaffMember(uid: doc.id, email: _str(d['email']), phone: _str(d['phone']), name: _str(d['name']), role: _str(d['role'], 'none'));
  }
}

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

class LibrarySettings {
  const LibrarySettings({
    this.name = 'Rampur Library',
    this.tagline = 'Read. Learn. Grow.',
    this.address = '',
    this.phone = '',
    this.email = '',
    this.openingHours = 'Mon–Sat · 9:00 AM – 7:00 PM',
    this.loanDays = 14,
    this.maxRenewals = 2,
    this.finePerDay = 5,
    this.graceDays = 0,
    this.maxFinePerLoan = 500,
    this.maxLoansPerMember = 3,
    this.reservationHoldDays = 3,
    this.dueReminderDays = 2,
    this.currency = '₹',
    this.androidAppUrl = '',
    this.iosAppUrl = '',
  });

  final String name;
  final String tagline;
  final String address;
  final String phone;
  final String email;
  final String openingHours;
  final int loanDays;
  final int maxRenewals;
  final double finePerDay;
  final int graceDays;
  final double maxFinePerLoan;
  final int maxLoansPerMember;
  final int reservationHoldDays;
  final int dueReminderDays;
  final String currency;
  final String androidAppUrl;
  final String iosAppUrl;

  factory LibrarySettings.fromJson(Json d) => LibrarySettings(
        name: _str(d['name'], 'Rampur Library'),
        tagline: _str(d['tagline'], 'Read. Learn. Grow.'),
        address: _str(d['address']),
        phone: _str(d['phone']),
        email: _str(d['email']),
        openingHours: _str(d['openingHours'], 'Mon–Sat · 9:00 AM – 7:00 PM'),
        loanDays: _int(d['loanDays'], 14),
        maxRenewals: _int(d['maxRenewals'], 2),
        finePerDay: _double(d['finePerDay'], 5),
        graceDays: _int(d['graceDays']),
        maxFinePerLoan: _double(d['maxFinePerLoan'], 500),
        maxLoansPerMember: _int(d['maxLoansPerMember'], 3),
        reservationHoldDays: _int(d['reservationHoldDays'], 3),
        dueReminderDays: _int(d['dueReminderDays'], 2),
        currency: _str(d['currency'], '₹'),
        androidAppUrl: _str(d['androidAppUrl']),
        iosAppUrl: _str(d['iosAppUrl']),
      );

  Json toJson() => {
        'name': name,
        'tagline': tagline,
        'address': address,
        'phone': phone,
        'email': email,
        'openingHours': openingHours,
        'loanDays': loanDays,
        'maxRenewals': maxRenewals,
        'finePerDay': finePerDay,
        'graceDays': graceDays,
        'maxFinePerLoan': maxFinePerLoan,
        'maxLoansPerMember': maxLoansPerMember,
        'reservationHoldDays': reservationHoldDays,
        'dueReminderDays': dueReminderDays,
        'currency': currency,
        'androidAppUrl': androidAppUrl,
        'iosAppUrl': iosAppUrl,
      };
}

/// Headline numbers for the admin dashboard.
class DashboardStats {
  const DashboardStats({
    this.totalBooks = 0,
    this.totalMembers = 0,
    this.activeLoans = 0,
    this.overdueLoans = 0,
    this.pendingReservations = 0,
    this.unpaidFines = 0,
    this.pendingRequests = 0,
  });

  final int totalBooks;
  final int totalMembers;
  final int activeLoans;
  final int overdueLoans;
  final int pendingReservations;
  final int unpaidFines;
  final int pendingRequests;
}
