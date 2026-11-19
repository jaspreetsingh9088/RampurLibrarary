import 'package:flutter_test/flutter_test.dart';
import 'package:library_core/library_core.dart';

void main() {
  const uid = DemoLibraryRepository.demoUid;

  test('demo repository works without Firebase', () async {
    final repo = DemoLibraryRepository();
    await repo.ensureMemberProfile(uid: uid, phone: '+919999900000');
    final member = await repo.getMember(uid);
    expect(member!.membershipId, 'RPL-000042');
    expect(member.isProfileComplete, isFalse);

    final loans = await repo.watchMemberLoans(uid, activeOnly: true).first;
    expect(loans, hasLength(2));

    // Renew the non-overdue loan
    final active = loans.firstWhere((l) => l.status == LoanStatus.issued);
    final newDue = await repo.renewMyLoan(active.id);
    expect(newDue.isAfter(active.dueAt), isTrue);

    // Overdue loans cannot be renewed
    final overdue = loans.firstWhere((l) => l.status == LoanStatus.overdue);
    expect(() => repo.renewMyLoan(overdue.id), throwsA(isA<LibraryException>()));

    // Reserve an available book → held immediately
    final book = (await repo.searchBooks('godaan')).single;
    await repo.reserveBook(book: book, member: member);
    final res = await repo.watchMemberReservations(uid).first;
    expect(res.first.status, ReservationStatus.ready);
    expect((await repo.getBook(book.id))!.availableCopies, book.availableCopies - 1);

    // Reviews update the rating
    await repo.submitReview(bookId: book.id, uid: uid, userName: 'Test', rating: 3, comment: 'ok');
    expect((await repo.getBook(book.id))!.ratingCount, 2);

    // Search by ISBN
    expect((await repo.findByIsbn('978-81-7371-146-6'))!.title, 'Wings of Fire');
  });

  test('admin demo: issue, return with fine, dashboard', () async {
    final repo = DemoLibraryRepository(withCommunity: true);
    final stats = await repo.dashboardStats();
    expect(stats.totalMembers, 8);
    expect(stats.activeLoans, greaterThan(0));
    expect(stats.overdueLoans, greaterThan(0));

    final member = (await repo.findMember('RPL-000003'))!;
    final book = (await repo.findByIsbn('9780553380163'))!; // A Brief History of Time
    final loanId = await repo.issueBook(bookId: book.id, memberId: member.id, staffUid: 'demo-admin');
    expect((await repo.getBook(book.id))!.availableCopies, book.availableCopies - 1);

    final loan = (await repo.watchMemberLoans(member.id, activeOnly: true).first).firstWhere((l) => l.id == loanId);
    final fine = await repo.returnBook(loan: loan, staffUid: 'demo-admin');
    expect(fine, 0);
    expect((await repo.getBook(book.id))!.availableCopies, book.availableCopies);

    // Overdue return creates a fine
    final overdue = (await repo.watchLoans(status: LoanStatus.overdue).first).first;
    expect(await repo.returnBook(loan: overdue, staffUid: 'demo-admin'), greaterThan(0));

    // Suspended member cannot borrow
    expect(() => repo.issueBook(bookId: book.id, memberId: 'member-8', staffUid: 'x'), throwsA(isA<LibraryException>()));

    expect((await repo.issuesPerDay()).length, 14);
  });
}
