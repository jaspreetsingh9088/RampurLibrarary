import 'package:intl/intl.dart';

/// URL-friendly slug: "The Gita — A Guide!" → "the-gita-a-guide"
String slugify(String input) {
  final s = input
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s-]'), ' ')
      .trim()
      .replaceAll(RegExp(r'[\s-]+'), '-');
  return s.isEmpty ? 'book' : s;
}

/// Firestore has no full-text search, so every book stores lowercase word prefixes of
/// its title and authors plus its ISBN. A search for "harr pot" matches on "harr".
List<String> buildSearchKeywords({required String title, List<String> authors = const [], String isbn = '', List<String> tags = const []}) {
  final out = <String>{};
  void addWords(String text) {
    for (final word in text.toLowerCase().split(RegExp(r'[^a-z0-9ऀ-ॿ]+'))) {
      if (word.isEmpty) continue;
      for (var i = 1; i <= word.length && i <= 15; i++) {
        out.add(word.substring(0, i));
      }
    }
  }

  addWords(title);
  for (final a in authors) {
    addWords(a);
  }
  for (final t in tags) {
    addWords(t);
  }
  final cleanIsbn = isbn.replaceAll(RegExp(r'[^0-9Xx]'), '');
  if (cleanIsbn.isNotEmpty) out.add(cleanIsbn.toLowerCase());
  return out.toList()..sort();
}

/// First search token used for the Firestore array-contains query.
String searchToken(String query) {
  final words = query.toLowerCase().split(RegExp(r'[^a-z0-9ऀ-ॿ]+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '';
  final digits = query.replaceAll(RegExp(r'[^0-9Xx]'), '');
  if (digits.length >= 10) return digits.toLowerCase();
  words.sort((a, b) => b.length.compareTo(a.length));
  final w = words.first;
  return w.length > 15 ? w.substring(0, 15) : w;
}

/// Late fine for a loan: whole days late (minus grace) × fine per day, capped.
double computeFine({required DateTime dueAt, required DateTime at, required double finePerDay, int graceDays = 0, double maxFine = 0}) {
  final diff = at.difference(dueAt);
  if (diff.inSeconds <= 0) return 0;
  final daysLate = (diff.inSeconds / 86400).ceil() - graceDays;
  if (daysLate <= 0) return 0;
  final fine = daysLate * finePerDay;
  return maxFine > 0 && fine > maxFine ? maxFine : fine;
}

/// Normalise Indian numbers to E.164: "98765 43210" → "+919876543210".
String normalizePhone(String input, {String countryCode = '+91'}) {
  final trimmed = input.trim();
  final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  if (trimmed.startsWith('+')) return '+$digits';
  if (digits.length == 10) return '$countryCode$digits';
  if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
  if (digits.length == 11 && digits.startsWith('0')) return '$countryCode${digits.substring(1)}';
  return '+$digits';
}

bool isValidIndianMobile(String input) => RegExp(r'^\+91[6-9]\d{9}$').hasMatch(normalizePhone(input));

bool isValidIsbn(String isbn) {
  final s = isbn.replaceAll(RegExp(r'[^0-9Xx]'), '').toUpperCase();
  if (s.length == 10) {
    var sum = 0;
    for (var i = 0; i < 10; i++) {
      final c = s[i];
      final v = c == 'X' ? 10 : int.tryParse(c);
      if (v == null || (c == 'X' && i != 9)) return false;
      sum += v * (10 - i);
    }
    return sum % 11 == 0;
  }
  if (s.length == 13) {
    var sum = 0;
    for (var i = 0; i < 13; i++) {
      final v = int.tryParse(s[i]);
      if (v == null) return false;
      sum += v * (i.isEven ? 1 : 3);
    }
    return sum % 10 == 0;
  }
  return false;
}

final _date = DateFormat('d MMM yyyy');
final _dateTime = DateFormat('d MMM yyyy, h:mm a');

String formatDate(DateTime? d) => d == null ? '—' : _date.format(d.toLocal());
String formatDateTime(DateTime? d) => d == null ? '—' : _dateTime.format(d.toLocal());
String formatMoney(num amount, [String symbol = '₹']) =>
    '$symbol${amount % 1 == 0 ? amount.toInt().toString() : amount.toStringAsFixed(2)}';

String timeAgo(DateTime? d) {
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return formatDate(d);
}

/// RFC-4180 CSV encoding for report exports.
String toCsv(List<List<Object?>> rows) => rows
    .map((r) => r.map((c) {
          final s = c?.toString() ?? '';
          return s.contains(RegExp(r'[",\n\r]')) ? '"${s.replaceAll('"', '""')}"' : s;
        }).join(','))
    .join('\r\n');

/// Minimal RFC-4180 CSV parser (quoted fields, escaped quotes, CRLF) for bulk imports.
List<List<String>> parseCsv(String input) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  final text = input.startsWith('﻿') ? input.substring(1) : input;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(c);
      }
    } else if (c == '"') {
      inQuotes = true;
    } else if (c == ',') {
      row.add(field.toString());
      field.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(field.toString());
      field.clear();
      if (row.any((f) => f.trim().isNotEmpty)) rows.add(row);
      row = <String>[];
    } else {
      field.write(c);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    if (row.any((f) => f.trim().isNotEmpty)) rows.add(row);
  }
  return rows;
}
