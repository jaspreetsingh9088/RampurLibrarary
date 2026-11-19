import 'package:flutter_test/flutter_test.dart';
import 'package:library_core/library_core.dart';

void main() {
  group('slugify', () {
    test('lowercases and hyphenates', () => expect(slugify('The Gita — A Guide!'), 'the-gita-a-guide'));
    test('falls back for empty', () => expect(slugify('!!!'), 'book'));
  });

  group('search keywords', () {
    final kw = buildSearchKeywords(title: 'Wings of Fire', authors: ['A. P. J. Abdul Kalam'], isbn: '978-81-7371-146-6');
    test('has title prefixes', () => expect(kw, containsAll(['w', 'wi', 'wings', 'fire'])));
    test('has author prefixes', () => expect(kw, containsAll(['abdul', 'kal', 'kalam'])));
    test('has clean isbn', () => expect(kw, contains('9788173711466')));
    test('search token picks longest word', () => expect(searchToken('of fire'), 'fire'));
    test('search token uses isbn digits', () => expect(searchToken('978-81-7371-146-6'), '9788173711466'));
  });

  group('fines', () {
    final due = DateTime(2026, 1, 10, 10);
    test('on time is free', () => expect(computeFine(dueAt: due, at: due.subtract(const Duration(hours: 1)), finePerDay: 5), 0));
    test('charges per started day', () => expect(computeFine(dueAt: due, at: due.add(const Duration(days: 2, hours: 1)), finePerDay: 5), 15));
    test('grace days', () => expect(computeFine(dueAt: due, at: due.add(const Duration(days: 2)), finePerDay: 5, graceDays: 2), 0));
    test('cap', () => expect(computeFine(dueAt: due, at: due.add(const Duration(days: 500)), finePerDay: 5, maxFine: 500), 500));
  });

  group('phone', () {
    test('10 digits', () => expect(normalizePhone('98765 43210'), '+919876543210'));
    test('with 0', () => expect(normalizePhone('09876543210'), '+919876543210'));
    test('with +91', () => expect(normalizePhone('+91 98765-43210'), '+919876543210'));
    test('validity', () {
      expect(isValidIndianMobile('9876543210'), isTrue);
      expect(isValidIndianMobile('1234567890'), isFalse);
    });
  });

  group('isbn', () {
    test('valid isbn13', () => expect(isValidIsbn('978-81-7371-146-6'), isTrue));
    test('valid isbn10', () => expect(isValidIsbn('0-306-40615-2'), isTrue));
    test('invalid', () => expect(isValidIsbn('1234567890'), isFalse));
  });

  test('csv escaping', () {
    expect(toCsv([
      ['a', 'b,c', 'say "hi"'],
    ]), 'a,"b,c","say ""hi"""');
  });

  test('money', () {
    expect(formatMoney(15), '₹15');
    expect(formatMoney(12.5), '₹12.50');
  });

  test('csv parsing', () {
    final rows = parseCsv('title,authors\r\n"Hello, World","A ""B"""\nPlain,X\n');
    expect(rows, [
      ['title', 'authors'],
      ['Hello, World', 'A "B"'],
      ['Plain', 'X'],
    ]);
  });
}
