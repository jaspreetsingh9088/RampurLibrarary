import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:library_core/library_core.dart';

import '../providers.dart';
import '../widgets.dart';

final _membersProvider = StreamProvider.family<List<Member>, (String, MemberStatus?)>(
  (ref, args) => ref.watch(repoProvider).watchMembers(search: args.$1, status: args.$2, limit: 200),
);

class MembersPage extends ConsumerStatefulWidget {
  const MembersPage({super.key});

  @override
  ConsumerState<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends ConsumerState<MembersPage> {
  String _query = '';
  MemberStatus? _status;
  Timer? _debounce;

  Future<void> _addWalkIn() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final email = TextEditingController();
    final address = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Register walk-in member'),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('For members without a smartphone. If they install the app later and sign in with the same number, '
                'staff can link the records.'),
            const SizedBox(height: 14),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name *')),
            const SizedBox(height: 10),
            TextField(controller: phone, decoration: const InputDecoration(labelText: 'Mobile number *', prefixText: '+91 ')),
            const SizedBox(height: 10),
            TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 10),
            TextField(controller: address, decoration: const InputDecoration(labelText: 'Address'), maxLines: 2),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Register')),
        ],
      ),
    );
    if (ok != true) return;
    if (name.text.trim().isEmpty || !isValidIndianMobile(phone.text)) {
      toast('Enter a name and a valid 10-digit mobile number.', error: true);
      return;
    }
    String? id;
    final done = await guard(() async {
      id = await ref.read(repoProvider).createWalkInMember(name: name.text, phone: phone.text, email: email.text, address: address.text);
    }, success: 'Member registered — membership number is being assigned');
    if (done && id != null && mounted) context.go('/members/$id');
  }

  Future<void> _export() async {
    final members = await ref.read(repoProvider).allMembers();
    downloadText('members-${DateTime.now().toIso8601String().substring(0, 10)}.csv', toCsv([
      ['Membership ID', 'Name', 'Phone', 'Email', 'Type', 'Status', 'Outstanding fines', 'Joined'],
      for (final m in members) [m.membershipId, m.name, m.phone, m.email, m.membershipType, m.status.name, m.outstandingFines, formatDate(m.createdAt)],
    ]));
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(_membersProvider((_query, _query.isEmpty ? _status : null)));
    return ListView(children: [
      PageHeader('Members', subtitle: 'Search by name, phone or membership number', actions: [
        OutlinedButton.icon(onPressed: _export, icon: const Icon(Icons.download_outlined), label: const Text('Export CSV')),
        FilledButton.icon(onPressed: _addWalkIn, icon: const Icon(Icons.person_add_alt), label: const Text('Walk-in member')),
      ]),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: 360,
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Name, 98765…, or RPL-000123'),
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), () => setState(() => _query = v.trim()));
              },
            ),
          ),
          SegmentedButton<MemberStatus?>(
            segments: const [
              ButtonSegment(value: null, label: Text('All')),
              ButtonSegment(value: MemberStatus.active, label: Text('Active')),
              ButtonSegment(value: MemberStatus.suspended, label: Text('Suspended')),
            ],
            selected: {_status},
            onSelectionChanged: (s) => setState(() => _status = s.first),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Panel(
          padding: EdgeInsets.zero,
          child: AsyncBody(
            value: value,
            builder: (members) => members.isEmpty
                ? const EmptyHint('No members match', icon: Icons.person_search)
                : WideTable(
                    columns: const [
                      DataColumn(label: Text('Member')),
                      DataColumn(label: Text('Membership')),
                      DataColumn(label: Text('Phone')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Fines due'), numeric: true),
                      DataColumn(label: Text('Joined')),
                    ],
                    rows: [
                      for (final m in members)
                        DataRow(
                          onSelectChanged: (_) => context.go('/members/${m.id}'),
                          cells: [
                            DataCell(Row(children: [
                              CircleAvatar(radius: 16, backgroundImage: m.photoUrl.isEmpty ? null : NetworkImage(m.photoUrl), child: m.photoUrl.isEmpty ? Text(m.initials, style: const TextStyle(fontSize: 12)) : null),
                              const SizedBox(width: 10),
                              Text(m.name.isEmpty ? '(no name)' : m.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            ])),
                            DataCell(Text('${m.membershipId} · ${m.membershipType}')),
                            DataCell(Text(m.phone)),
                            DataCell(Pill(m.status.name, color: m.status == MemberStatus.active ? okColor : dangerColor)),
                            DataCell(Text(m.outstandingFines > 0 ? formatMoney(m.outstandingFines) : '—',
                                style: TextStyle(color: m.outstandingFines > 0 ? dangerColor : null, fontWeight: FontWeight.w700))),
                            DataCell(Text(formatDate(m.createdAt))),
                          ],
                        ),
                    ],
                  ),
          ),
        ),
      ),
    ]);
  }
}

// ===========================================================================
// Member detail
// ===========================================================================

class MemberDetailPage extends ConsumerWidget {
  const MemberDetailPage({super.key, required this.memberId});
  final String memberId;

  Future<void> _editMembership(BuildContext context, WidgetRef ref, Member m) async {
    var type = m.membershipType;
    final maxLoans = TextEditingController(text: '${m.maxLoans}');
    final name = TextEditingController(text: m.name);
    final email = TextEditingController(text: m.email);
    DateTime? expires = m.membershipExpiresAt;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: const Text('Edit membership'),
          content: SizedBox(
            width: 380,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 10),
              TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: const ['standard', 'premium', 'student', 'senior', 'staff'].contains(type) ? type : 'standard',
                decoration: const InputDecoration(labelText: 'Membership type'),
                items: const [
                  DropdownMenuItem(value: 'standard', child: Text('Standard')),
                  DropdownMenuItem(value: 'premium', child: Text('Premium')),
                  DropdownMenuItem(value: 'student', child: Text('Student')),
                  DropdownMenuItem(value: 'senior', child: Text('Senior citizen')),
                  DropdownMenuItem(value: 'staff', child: Text('Staff')),
                ],
                onChanged: (v) => type = v ?? 'standard',
              ),
              const SizedBox(height: 10),
              TextField(controller: maxLoans, decoration: const InputDecoration(labelText: 'Max books at a time'), keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Valid till'),
                subtitle: Text(expires == null ? 'No expiry' : formatDate(expires)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (expires != null) IconButton(icon: const Icon(Icons.clear), onPressed: () => set(() => expires = null)),
                  IconButton(
                    icon: const Icon(Icons.calendar_month),
                    onPressed: () async {
                      final dt = await showDatePicker(
                        context: d,
                        initialDate: expires ?? DateTime.now().add(const Duration(days: 365)),
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (dt != null) set(() => expires = dt);
                    },
                  ),
                ]),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await guard(
      () => ref.read(repoProvider).updateMemberAsStaff(m.id, {
        'name': name.text.trim(),
        'email': email.text.trim(),
        'membershipType': type,
        'maxLoans': int.tryParse(maxLoans.text) ?? m.maxLoans,
        'membershipExpiresAt': dateToTs(expires),
      }),
      success: 'Membership updated',
    );
  }

  Future<void> _message(BuildContext context, WidgetRef ref, Member m) async {
    final title = TextEditingController();
    final body = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Message ${m.name}'),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 10),
            TextField(controller: body, maxLines: 4, decoration: const InputDecoration(labelText: 'Message')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(d, title.text.trim().isNotEmpty), child: const Text('Send push')),
        ],
      ),
    );
    if (ok == true) {
      await guard(() => ref.read(repoProvider).sendToMember(uid: m.id, title: title.text.trim(), body: body.text.trim()), success: 'Notification sent');
    }
  }

  Future<void> _addFine(BuildContext context, WidgetRef ref, Member m) async {
    final amount = TextEditingController();
    final reason = TextEditingController(text: 'Damaged book');
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Add charge'),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: amount, decoration: const InputDecoration(labelText: 'Amount (₹)'), keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            TextField(controller: reason, decoration: const InputDecoration(labelText: 'Reason')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Add')),
        ],
      ),
    );
    final value = double.tryParse(amount.text);
    if (ok == true && value != null && value > 0) {
      await guard(() => ref.read(repoProvider).addManualFine(member: m, amount: value, reason: reason.text.trim()), success: 'Charge added');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffUid = ref.watch(staffUidProvider);
    return AsyncBody(
      value: ref.watch(memberProvider(memberId)),
      builder: (m) {
        if (m == null) return const EmptyHint('Member not found');
        final active = m.status == MemberStatus.active;
        return ListView(children: [
          PageHeader(m.name.isEmpty ? 'Member' : m.name, subtitle: '${m.membershipId} · ${m.phone}', actions: [
            OutlinedButton.icon(onPressed: () => context.go('/members'), icon: const Icon(Icons.arrow_back), label: const Text('All members')),
            FilledButton.icon(
              onPressed: () => context.go('/circulation?member=${Uri.encodeComponent(m.membershipId.isEmpty ? m.phone : m.membershipId)}'),
              icon: const Icon(Icons.outbox),
              label: const Text('Issue book'),
            ),
            OutlinedButton.icon(onPressed: () => _message(context, ref, m), icon: const Icon(Icons.send_outlined), label: const Text('Message')),
            OutlinedButton.icon(onPressed: () => _editMembership(context, ref, m), icon: const Icon(Icons.edit_outlined), label: const Text('Edit')),
            OutlinedButton.icon(onPressed: () => _addFine(context, ref, m), icon: const Icon(Icons.add_card), label: const Text('Add charge')),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: active ? dangerColor : okColor),
              onPressed: () async {
                if (await confirm(context, active ? 'Suspend ${m.name}?' : 'Reactivate ${m.name}?', danger: active, ok: active ? 'Suspend' : 'Reactivate')) {
                  await guard(() => ref.read(repoProvider).setMemberStatus(m.id, active ? MemberStatus.suspended : MemberStatus.active));
                }
              },
              icon: Icon(active ? Icons.block : Icons.check_circle_outline),
              label: Text(active ? 'Suspend' : 'Reactivate'),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Wrap(spacing: 16, runSpacing: 16, children: [
              SizedBox(
                width: 360,
                child: Panel(
                  title: 'Profile',
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Center(
                      child: CircleAvatar(
                        radius: 40,
                        backgroundImage: m.photoUrl.isEmpty ? null : NetworkImage(m.photoUrl),
                        child: m.photoUrl.isEmpty ? Text(m.initials, style: const TextStyle(fontSize: 26)) : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _kv('Status', m.status.name),
                    _kv('Type', m.membershipType),
                    _kv('Max loans', '${m.maxLoans}'),
                    _kv('Email', m.email),
                    _kv('Address', m.address),
                    _kv('Date of birth', formatDate(m.dateOfBirth)),
                    _kv('Joined', formatDate(m.createdAt)),
                    _kv('Valid till', m.membershipExpiresAt == null ? 'No expiry' : formatDate(m.membershipExpiresAt)),
                    _kv('Outstanding', formatMoney(m.outstandingFines)),
                  ]),
                ),
              ),
              SizedBox(
                width: 640,
                child: Column(children: [
                  Panel(
                    title: 'Loans',
                    padding: EdgeInsets.zero,
                    child: AsyncBody(
                      value: ref.watch(memberLoansProvider(m.id)),
                      builder: (loans) => loans.isEmpty
                          ? const EmptyHint('No loans yet')
                          : Column(children: [
                              for (final l in loans.take(30))
                                ListTile(
                                  leading: CoverThumb(l.bookCover),
                                  title: Text(l.bookTitle),
                                  subtitle: Text('Issued ${formatDate(l.issuedAt)} · due ${formatDate(l.dueAt)}'
                                      '${l.returnedAt != null ? ' · returned ${formatDate(l.returnedAt)}' : ''}'),
                                  trailing: l.isActive
                                      ? FilledButton.tonal(
                                          onPressed: () async {
                                            await guard(() async {
                                              final fine = await ref.read(repoProvider).returnBook(loan: l, staffUid: staffUid);
                                              toast(fine > 0 ? 'Returned. Fine ${formatMoney(fine)} added.' : 'Returned on time.');
                                            });
                                          },
                                          child: const Text('Return'),
                                        )
                                      : Pill(l.status.name, color: loanColor(l.status)),
                                ),
                            ]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Panel(
                    title: 'Fines',
                    padding: EdgeInsets.zero,
                    child: AsyncBody(
                      value: ref.watch(memberFinesProvider(m.id)),
                      builder: (fines) => fines.isEmpty
                          ? const EmptyHint('No fines')
                          : Column(children: [
                              for (final f in fines)
                                ListTile(
                                  title: Text('${formatMoney(f.amount)} · ${f.reason}'),
                                  subtitle: Text('${f.bookTitle} · ${formatDate(f.createdAt)}'),
                                  trailing: f.status == FineStatus.unpaid
                                      ? Wrap(spacing: 6, children: [
                                          FilledButton.tonal(
                                            onPressed: () => guard(() => ref.read(repoProvider).settleFine(f.id, waive: false, staffUid: staffUid), success: 'Marked paid'),
                                            child: const Text('Paid'),
                                          ),
                                          TextButton(
                                            onPressed: () => guard(() => ref.read(repoProvider).settleFine(f.id, waive: true, staffUid: staffUid), success: 'Waived'),
                                            child: const Text('Waive'),
                                          ),
                                        ])
                                      : Pill(f.status.name, color: f.status == FineStatus.paid ? okColor : Colors.grey),
                                ),
                            ]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Panel(
                    title: 'Reservations',
                    padding: EdgeInsets.zero,
                    child: AsyncBody(
                      value: ref.watch(memberReservationsProvider(m.id)),
                      builder: (items) => items.isEmpty
                          ? const EmptyHint('No reservations')
                          : Column(children: [
                              for (final r in items.take(20))
                                ListTile(
                                  title: Text(r.bookTitle),
                                  subtitle: Text(formatDateTime(r.createdAt)),
                                  trailing: Pill(r.status.name, color: reservationColor(r.status)),
                                ),
                            ]),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 24),
        ]);
      },
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(k, style: const TextStyle(color: Colors.black54))),
          Expanded(child: SelectableText(v.isEmpty ? '—' : v, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}
