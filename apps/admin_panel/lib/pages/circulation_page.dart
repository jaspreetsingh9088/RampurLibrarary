import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:library_core/library_core.dart';

import '../providers.dart';
import '../widgets.dart';

final _loansProvider = StreamProvider.family<List<Loan>, LoanStatus?>(
  (ref, status) => status == null
      ? ref.watch(repoProvider).watchLoans(limit: 300).map((l) => l.where((x) => x.isActive).toList())
      : ref.watch(repoProvider).watchLoans(status: status, limit: 300),
);

class CirculationPage extends StatelessWidget {
  const CirculationPage({super.key, this.initialMember});
  final String? initialMember;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const PageHeader('Issue / Return', subtitle: 'Scan a membership card QR or type the number, then scan the book ISBN'),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [
            Tab(icon: Icon(Icons.outbox), text: 'Issue'),
            Tab(icon: Icon(Icons.move_to_inbox), text: 'Books out (return)'),
            Tab(icon: Icon(Icons.warning_amber), text: 'Overdue'),
          ]),
        ),
        Expanded(
          child: TabBarView(children: [
            _IssueTab(initialMember: initialMember),
            const _LoansTab(status: null),
            const _LoansTab(status: LoanStatus.overdue),
          ]),
        ),
      ]),
    );
  }
}

class _IssueTab extends ConsumerStatefulWidget {
  const _IssueTab({this.initialMember});
  final String? initialMember;

  @override
  ConsumerState<_IssueTab> createState() => _IssueTabState();
}

class _IssueTabState extends ConsumerState<_IssueTab> {
  final _memberQ = TextEditingController();
  final _bookQ = TextEditingController();
  final _bookFocus = FocusNode();
  Member? _member;
  List<Book> _bookResults = const [];
  Book? _book;
  int? _days;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialMember != null && widget.initialMember!.isNotEmpty) {
      _memberQ.text = widget.initialMember!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _findMember());
    }
  }

  Future<void> _findMember() async {
    final q = _memberQ.text.trim();
    if (q.isEmpty) return;
    final m = await ref.read(repoProvider).findMember(q);
    setState(() => _member = m);
    if (m == null) {
      toast('No member found for "$q".', error: true);
    } else {
      _bookFocus.requestFocus();
    }
  }

  Future<void> _findBook() async {
    final q = _bookQ.text.trim();
    if (q.isEmpty) return;
    final repo = ref.read(repoProvider);
    final digits = q.replaceAll(RegExp(r'[^0-9Xx]'), '');
    if (digits.length >= 10) {
      final b = await repo.findByIsbn(digits);
      setState(() {
        _book = b;
        _bookResults = b == null ? const [] : [b];
      });
      if (b == null) toast('No book with ISBN $digits.', error: true);
      return;
    }
    final r = await repo.searchBooks(q, limit: 10);
    setState(() {
      _bookResults = r;
      _book = r.length == 1 ? r.first : null;
    });
    if (r.isEmpty) toast('No matching books.', error: true);
  }

  Future<void> _issue() async {
    final m = _member, b = _book;
    if (m == null || b == null) return;
    setState(() => _busy = true);
    final ok = await guard(
      () => ref.read(repoProvider).issueBook(bookId: b.id, memberId: m.id, staffUid: ref.read(staffUidProvider), loanDaysOverride: _days),
      success: '"${b.title}" issued to ${m.name}',
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) {
        _book = null;
        _bookResults = const [];
        _bookQ.clear();
        _bookFocus.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value ?? const LibrarySettings();
    final m = _member;
    return ListView(padding: const EdgeInsets.all(24), children: [
      Wrap(spacing: 16, runSpacing: 16, children: [
        SizedBox(
          width: 460,
          child: Panel(
            title: '1 · Member',
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(
                controller: _memberQ,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'RPL-000123 or mobile number',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _findMember),
                ),
                onSubmitted: (_) => _findMember(),
              ),
              if (m != null) ...[
                const SizedBox(height: 14),
                Consumer(builder: (context, ref, _) {
                  final loans = (ref.watch(memberLoansProvider(m.id)).value ?? const <Loan>[]).where((l) => l.isActive).toList();
                  final problems = <String>[
                    if (m.status != MemberStatus.active) 'Membership ${m.status.name}',
                    if (loans.any((l) => l.isOverdue)) 'Has overdue books',
                    if (loans.length >= m.maxLoans) 'Loan limit reached (${m.maxLoans})',
                    if (m.outstandingFines > 0) 'Fines due ${formatMoney(m.outstandingFines, settings.currency)}',
                  ];
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(backgroundImage: m.photoUrl.isEmpty ? null : NetworkImage(m.photoUrl), child: m.photoUrl.isEmpty ? Text(m.initials) : null),
                      title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('${m.membershipId} · ${m.phone} · ${loans.length}/${m.maxLoans} books'),
                      trailing: TextButton(onPressed: () => context.go('/members/${m.id}'), child: const Text('Profile')),
                    ),
                    for (final p in problems) Padding(padding: const EdgeInsets.only(bottom: 4), child: Pill(p, color: dangerColor)),
                    if (loans.isNotEmpty) const Divider(),
                    for (final l in loans)
                      Text('• ${l.bookTitle} — due ${formatDate(l.dueAt)}', style: TextStyle(color: l.isOverdue ? dangerColor : null)),
                  ]);
                }),
              ],
            ]),
          ),
        ),
        SizedBox(
          width: 460,
          child: Panel(
            title: '2 · Book',
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(
                controller: _bookQ,
                focusNode: _bookFocus,
                decoration: InputDecoration(
                  hintText: 'Scan ISBN or type a title',
                  prefixIcon: const Icon(Icons.qr_code_scanner),
                  suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _findBook),
                ),
                onSubmitted: (_) => _findBook(),
              ),
              const SizedBox(height: 8),
              for (final b in _bookResults)
                ListTile(
                  selected: _book?.id == b.id,
                  onTap: () => setState(() => _book = b),
                  leading: Icon(_book?.id == b.id ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                  trailing: CoverThumb(b.coverUrl),
                  title: Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${b.authorLine} · ${b.availableCopies}/${b.totalCopies} available'),
                ),
            ]),
          ),
        ),
        SizedBox(
          width: 460,
          child: Panel(
            title: '3 · Confirm',
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              DropdownButtonFormField<int?>(
                initialValue: _days,
                decoration: const InputDecoration(labelText: 'Loan period'),
                items: [
                  DropdownMenuItem(value: null, child: Text('Default (${settings.loanDays} days)')),
                  for (final d in [7, 14, 21, 30]) DropdownMenuItem(value: d, child: Text('$d days')),
                ],
                onChanged: (v) => setState(() => _days = v),
              ),
              const SizedBox(height: 12),
              Text(
                _member == null || _book == null
                    ? 'Choose a member and a book.'
                    : 'Issue "${_book!.title}" to ${_member!.name}, due ${formatDate(DateTime.now().add(Duration(days: _days ?? settings.loanDays)))}.',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: _busy || _member == null || _book == null ? null : _issue,
                icon: const Icon(Icons.check),
                label: Text(_busy ? 'Issuing…' : 'Issue book'),
              ),
            ]),
          ),
        ),
      ]),
    ]);
  }
}

class _LoansTab extends ConsumerStatefulWidget {
  const _LoansTab({required this.status});
  final LoanStatus? status;

  @override
  ConsumerState<_LoansTab> createState() => _LoansTabState();
}

class _LoansTabState extends ConsumerState<_LoansTab> {
  String _filter = '';

  Future<void> _return(Loan l, {bool lost = false}) async {
    final settings = ref.read(settingsProvider).value ?? const LibrarySettings();
    final fine = computeFine(dueAt: l.dueAt, at: DateTime.now(), finePerDay: settings.finePerDay, graceDays: settings.graceDays, maxFine: settings.maxFinePerLoan);
    var waive = false;
    final charge = TextEditingController(text: '0');
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: Text(lost ? 'Mark as lost' : 'Return book'),
          content: SizedBox(
            width: 400,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('"${l.bookTitle}" — ${l.userName} (${l.membershipId})'),
              const SizedBox(height: 8),
              Text('Due ${formatDate(l.dueAt)}'),
              if (fine > 0) ...[
                const SizedBox(height: 12),
                Text('Late fine: ${formatMoney(fine, settings.currency)}', style: const TextStyle(fontWeight: FontWeight.w800, color: dangerColor)),
                CheckboxListTile(contentPadding: EdgeInsets.zero, value: waive, onChanged: (v) => set(() => waive = v ?? false), title: const Text('Waive the late fine')),
              ],
              if (lost) ...[
                const SizedBox(height: 12),
                TextField(controller: charge, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Replacement charge (₹)')),
                const SizedBox(height: 6),
                const Text('The book\'s total copies will be reduced by one.'),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(lost ? 'Mark lost' : 'Confirm return')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await guard(() async {
      final charged = await ref.read(repoProvider).returnBook(
            loan: l,
            staffUid: ref.read(staffUidProvider),
            waiveFine: waive,
            lost: lost,
            lostCharge: double.tryParse(charge.text),
          );
      toast(charged > 0 ? 'Done. ${formatMoney(charged, settings.currency)} added to the member\'s account.' : 'Returned.');
    });
  }

  Future<void> _extend(Loan l) async {
    final days = await showDialog<int>(
      context: context,
      builder: (d) => SimpleDialog(title: const Text('Extend due date by'), children: [
        for (final n in [3, 7, 14]) SimpleDialogOption(onPressed: () => Navigator.pop(d, n), child: Text('$n days')),
      ]),
    );
    if (days != null) await guard(() => ref.read(repoProvider).extendLoan(l.id, days), success: 'Due date extended');
  }

  void _remind(Loan l) {
    guard(
      () => ref.read(repoProvider).sendToMember(
            uid: l.userId,
            title: 'Please return "${l.bookTitle}"',
            body: 'It was due on ${formatDate(l.dueAt)}. Kindly return it to the library at the earliest.',
          ),
      success: 'Reminder sent to ${l.userName}',
    );
  }

  void _exportCsv(List<Loan> loans) {
    downloadText('loans-${widget.status?.name ?? 'active'}.csv', toCsv([
      ['Book', 'Member', 'Membership ID', 'Issued', 'Due', 'Status', 'Renewals'],
      for (final l in loans) [l.bookTitle, l.userName, l.membershipId, formatDate(l.issuedAt), formatDate(l.dueAt), l.isOverdue ? 'overdue' : l.status.name, l.renewCount],
    ]));
  }

  @override
  Widget build(BuildContext context) {
    return AsyncBody(
      value: ref.watch(_loansProvider(widget.status)),
      builder: (all) {
        final q = _filter.toLowerCase();
        final loans = q.isEmpty
            ? all
            : all.where((l) => l.bookTitle.toLowerCase().contains(q) || l.userName.toLowerCase().contains(q) || l.membershipId.toLowerCase().contains(q)).toList();
        return ListView(padding: const EdgeInsets.all(24), children: [
          Row(children: [
            SizedBox(
              width: 360,
              child: TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.filter_list), hintText: 'Filter by book, member or RPL number'),
                onChanged: (v) => setState(() => _filter = v),
              ),
            ),
            const Spacer(),
            Text('${loans.length} loan(s)  '),
            OutlinedButton.icon(onPressed: () => _exportCsv(loans), icon: const Icon(Icons.download_outlined), label: const Text('CSV')),
          ]),
          const SizedBox(height: 12),
          Panel(
            padding: EdgeInsets.zero,
            child: loans.isEmpty
                ? const EmptyHint('Nothing here', icon: Icons.check_circle_outline)
                : WideTable(
                    columns: const [
                      DataColumn(label: Text('Book')),
                      DataColumn(label: Text('Member')),
                      DataColumn(label: Text('Issued')),
                      DataColumn(label: Text('Due')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: [
                      for (final l in loans)
                        DataRow(cells: [
                          DataCell(Row(children: [
                            CoverThumb(l.bookCover, width: 32, height: 46),
                            const SizedBox(width: 10),
                            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 260), child: Text(l.bookTitle, overflow: TextOverflow.ellipsis)),
                          ])),
                          DataCell(Text('${l.userName}\n${l.membershipId}'), onTap: () => context.go('/members/${l.userId}')),
                          DataCell(Text(formatDate(l.issuedAt))),
                          DataCell(Text(formatDate(l.dueAt))),
                          DataCell(l.isOverdue
                              ? Pill('${DateTime.now().difference(l.dueAt).inDays}d overdue', color: dangerColor)
                              : Pill('${l.daysLeft}d left', color: l.daysLeft <= 2 ? warnColor : okColor)),
                          DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                            FilledButton.tonal(onPressed: () => _return(l), child: const Text('Return')),
                            const SizedBox(width: 4),
                            PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'extend') _extend(l);
                                if (v == 'remind') _remind(l);
                                if (v == 'lost') _return(l, lost: true);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'extend', child: Text('Extend due date')),
                                PopupMenuItem(value: 'remind', child: Text('Send reminder')),
                                PopupMenuItem(value: 'lost', child: Text('Mark as lost')),
                              ],
                            ),
                          ])),
                        ]),
                    ],
                  ),
          ),
        ]);
      },
    );
  }
}
