import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:library_core/library_core.dart';

import '../providers.dart';
import '../widgets.dart';

// ===========================================================================
// Reports & activity log
// ===========================================================================

final _auditProvider = StreamProvider<List<Map<String, dynamic>>>((ref) => ref.watch(repoProvider).watchAuditLog(limit: 100));

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  String _stamp() => DateTime.now().toIso8601String().substring(0, 10);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repoProvider);
    final role = ref.watch(staffRoleProvider).value;

    Widget report(String title, String desc, IconData icon, Future<void> Function() run) => SizedBox(
          width: 320,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(icon, size: 30, color: brandPrimary),
                const SizedBox(height: 10),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                Text(desc, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                OutlinedButton.icon(onPressed: () => guard(run), icon: const Icon(Icons.download), label: const Text('Download CSV')),
              ]),
            ),
          ),
        );

    return ListView(children: [
      const PageHeader('Reports', subtitle: 'Export data for audits, committee meetings and stock-taking'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Wrap(spacing: 16, runSpacing: 16, children: [
          report('Full catalogue', 'Every book with copies, shelf, ISBN and rating', Icons.menu_book, () async {
            final books = await repo.allBooks();
            downloadText('catalogue-${_stamp()}.csv', toCsv([
              ['Title', 'Authors', 'ISBN', 'Publisher', 'Year', 'Language', 'Categories', 'Shelf', 'Total', 'Available', 'Rating', 'Reviews'],
              for (final b in books)
                [b.title, b.authors.join('; '), b.isbn, b.publisher, b.publishedYear, b.language, b.categories.join('; '), b.shelfLocation, b.totalCopies, b.availableCopies, b.ratingAvg, b.ratingCount],
            ]));
          }),
          report('Circulation (12 months)', 'All loans issued in the last year', Icons.swap_horiz, () async {
            final loans = await repo.allLoans(days: 365);
            downloadText('circulation-${_stamp()}.csv', toCsv([
              ['Book', 'Member', 'Membership ID', 'Issued', 'Due', 'Returned', 'Status', 'Renewals', 'Fine'],
              for (final l in loans)
                [l.bookTitle, l.userName, l.membershipId, formatDate(l.issuedAt), formatDate(l.dueAt), formatDate(l.returnedAt), l.status.name, l.renewCount, l.fineAmount],
            ]));
          }),
          report('Most borrowed books', 'Ranking by number of loans in 12 months', Icons.trending_up, () async {
            final loans = await repo.allLoans(days: 365);
            final counts = <String, int>{};
            for (final l in loans) {
              counts[l.bookTitle] = (counts[l.bookTitle] ?? 0) + 1;
            }
            final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
            downloadText('most-borrowed-${_stamp()}.csv', toCsv([
              ['Rank', 'Book', 'Loans'],
              for (var i = 0; i < sorted.length; i++) [i + 1, sorted[i].key, sorted[i].value],
            ]));
          }),
          report('Members', 'All members with status and dues', Icons.people_alt, () async {
            final members = await repo.allMembers();
            downloadText('members-${_stamp()}.csv', toCsv([
              ['Membership ID', 'Name', 'Phone', 'Email', 'Type', 'Status', 'Fines due', 'Joined'],
              for (final m in members) [m.membershipId, m.name, m.phone, m.email, m.membershipType, m.status.name, m.outstandingFines, formatDate(m.createdAt)],
            ]));
          }),
          report('Fines ledger', 'Every fine with payment mode', Icons.receipt_long, () async {
            final fines = await repo.allFines();
            downloadText('fines-${_stamp()}.csv', toCsv([
              ['Member', 'Book', 'Reason', 'Amount', 'Status', 'Mode', 'Created', 'Settled'],
              for (final f in fines) [f.userName, f.bookTitle, f.reason, f.amount, f.status.name, f.paymentMode, formatDate(f.createdAt), formatDate(f.paidAt)],
            ]));
          }),
        ]),
      ),
      if (role == StaffRole.admin) ...[
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Panel(
            title: 'Activity log',
            padding: EdgeInsets.zero,
            child: AsyncBody(
              value: ref.watch(_auditProvider),
              builder: (rows) => rows.isEmpty
                  ? const EmptyHint('No activity yet')
                  : Column(children: [
                      for (final r in rows)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.history, size: 18),
                          title: Text('${r['action']}'),
                          subtitle: Text(r.entries.where((e) => !const {'id', 'action', 'at'}.contains(e.key)).map((e) => '${e.key}: ${e.value}').join(' · ')),
                          trailing: Text(formatDateTime(tsToDate(r['at']))),
                        ),
                    ]),
            ),
          ),
        ),
      ],
    ]);
  }
}

// ===========================================================================
// Staff management (admins only)
// ===========================================================================

final _staffProvider = StreamProvider<List<StaffMember>>((ref) => ref.watch(repoProvider).watchStaff());

class StaffPage extends ConsumerWidget {
  const StaffPage({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final id = TextEditingController();
    var role = 'librarian';
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: const Text('Add staff member'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('The person must already have an account: create one under Firebase Console → Authentication '
                  '(email + password), or they can sign in once with their phone in the member app.'),
              const SizedBox(height: 14),
              TextField(controller: id, decoration: const InputDecoration(labelText: 'Email or mobile number')),
              const SizedBox(height: 14),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'librarian', label: Text('Librarian'), icon: Icon(Icons.local_library_outlined)),
                  ButtonSegment(value: 'admin', label: Text('Admin'), icon: Icon(Icons.admin_panel_settings_outlined)),
                ],
                selected: {role},
                onSelectionChanged: (s) => set(() => role = s.first),
              ),
              const SizedBox(height: 8),
              const Text('Librarians run circulation and the catalogue. Admins can also manage staff and settings.', style: TextStyle(fontSize: 12)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(d, id.text.trim().isNotEmpty), child: const Text('Grant access')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final v = id.text.trim();
    await guard(
      () => ref.read(repoProvider).setStaffRole(email: v.contains('@') ? v : null, phone: v.contains('@') ? null : v, role: role),
      success: 'Access granted. They need to sign out and in again.',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(staffUidProvider);
    return ListView(children: [
      PageHeader('Staff', subtitle: 'Who can use this admin panel', actions: [
        FilledButton.icon(onPressed: () => _add(context, ref), icon: const Icon(Icons.person_add_alt), label: const Text('Add staff')),
      ]),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Panel(
          padding: EdgeInsets.zero,
          child: AsyncBody(
            value: ref.watch(_staffProvider),
            builder: (staff) => staff.isEmpty
                ? const EmptyHint('No staff recorded yet')
                : Column(children: [
                    for (final s in staff)
                      ListTile(
                        leading: CircleAvatar(child: Icon(s.role == 'admin' ? Icons.admin_panel_settings : Icons.local_library)),
                        title: Text(s.email.isNotEmpty ? s.email : s.phone, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(s.uid == me ? 'You' : s.uid),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Pill(s.role, color: s.role == 'admin' ? brandPrimary : okColor),
                          if (s.uid != me)
                            IconButton(
                              tooltip: 'Revoke access',
                              icon: const Icon(Icons.person_remove_outlined, color: dangerColor),
                              onPressed: () async {
                                if (await confirm(context, 'Revoke access for ${s.email.isNotEmpty ? s.email : s.phone}?', danger: true, ok: 'Revoke')) {
                                  await guard(() => ref.read(repoProvider).setStaffRole(uid: s.uid, role: 'none'), success: 'Access revoked');
                                }
                              },
                            ),
                        ]),
                      ),
                  ]),
          ),
        ),
      ),
    ]);
  }
}

// ===========================================================================
// Library settings (admins only)
// ===========================================================================

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _form = GlobalKey<FormState>();
  final _c = <String, TextEditingController>{};
  bool _loaded = false;
  bool _saving = false;

  TextEditingController _ctl(String key) => _c.putIfAbsent(key, TextEditingController.new);

  void _load(LibrarySettings s) {
    if (_loaded) return;
    _loaded = true;
    s.toJson().forEach((k, v) => _ctl(k).text = '$v');
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    String t(String k) => _ctl(k).text.trim();
    final s = LibrarySettings(
      name: t('name'),
      tagline: t('tagline'),
      address: t('address'),
      phone: t('phone'),
      email: t('email'),
      openingHours: t('openingHours'),
      loanDays: int.parse(t('loanDays')),
      maxRenewals: int.parse(t('maxRenewals')),
      finePerDay: double.parse(t('finePerDay')),
      graceDays: int.parse(t('graceDays')),
      maxFinePerLoan: double.parse(t('maxFinePerLoan')),
      maxLoansPerMember: int.parse(t('maxLoansPerMember')),
      reservationHoldDays: int.parse(t('reservationHoldDays')),
      dueReminderDays: int.parse(t('dueReminderDays')),
      currency: t('currency'),
      androidAppUrl: t('androidAppUrl'),
      iosAppUrl: t('iosAppUrl'),
    );
    await guard(() => ref.read(repoProvider).saveSettings(s), success: 'Settings saved');
    if (mounted) setState(() => _saving = false);
  }

  Widget _text(String key, String label, {double width = 320, bool number = false, int lines = 1}) => SizedBox(
        width: width,
        child: TextFormField(
          controller: _ctl(key),
          maxLines: lines,
          keyboardType: number ? TextInputType.number : null,
          decoration: InputDecoration(labelText: label),
          validator: number ? (v) => num.tryParse(v ?? '') == null ? 'Number required' : null : null,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AsyncBody(
      value: ref.watch(settingsProvider),
      builder: (s) {
        _load(s);
        return Form(
          key: _form,
          child: ListView(children: [
            PageHeader('Settings', subtitle: 'Rules here apply instantly to the app, website and automatic reminders', actions: [
              FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save), label: Text(_saving ? 'Saving…' : 'Save changes')),
            ]),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Panel(
                title: 'Library details',
                child: Wrap(spacing: 16, runSpacing: 16, children: [
                  _text('name', 'Library name'),
                  _text('tagline', 'Tagline'),
                  _text('phone', 'Phone'),
                  _text('email', 'Email'),
                  _text('openingHours', 'Opening hours', width: 656),
                  _text('address', 'Address', width: 656, lines: 2),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Panel(
                title: 'Borrowing rules',
                child: Wrap(spacing: 16, runSpacing: 16, children: [
                  _text('loanDays', 'Loan period (days)', width: 200, number: true),
                  _text('maxRenewals', 'Max renewals', width: 200, number: true),
                  _text('maxLoansPerMember', 'Default books per member', width: 200, number: true),
                  _text('reservationHoldDays', 'Hold reserved books (days)', width: 200, number: true),
                  _text('dueReminderDays', 'Remind before due (days)', width: 200, number: true),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Panel(
                title: 'Fines',
                child: Wrap(spacing: 16, runSpacing: 16, children: [
                  _text('finePerDay', 'Fine per day', width: 200, number: true),
                  _text('graceDays', 'Grace days', width: 200, number: true),
                  _text('maxFinePerLoan', 'Max fine per book (0 = no cap)', width: 240, number: true),
                  _text('currency', 'Currency symbol', width: 140),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Panel(
                title: 'App download links (shown on the website)',
                child: Wrap(spacing: 16, runSpacing: 16, children: [
                  _text('androidAppUrl', 'Android APK / Play Store URL', width: 480),
                  _text('iosAppUrl', 'iOS App Store / TestFlight URL', width: 480),
                ]),
              ),
            ),
          ]),
        );
      },
    );
  }
}
