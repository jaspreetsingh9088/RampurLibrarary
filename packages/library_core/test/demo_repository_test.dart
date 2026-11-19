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
}
