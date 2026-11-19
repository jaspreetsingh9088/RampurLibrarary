import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:library_core/library_core.dart';

import '../providers.dart';
import '../widgets.dart';

// ===========================================================================
// Reservations
// ===========================================================================

final _reservationsProvider = StreamProvider.family<List<Reservation>, ReservationStatus?>(
  (ref, s) => ref.watch(repoProvider).watchReservations(status: s, limit: 300),
);

class ReservationsPage extends ConsumerStatefulWidget {
  const ReservationsPage({super.key});

  @override
  ConsumerState<ReservationsPage> createState() => _ReservationsPageState();
}

class _ReservationsPageState extends ConsumerState<ReservationsPage> {
  ReservationStatus? _status = ReservationStatus.ready;

  @override
  Widget build(BuildContext context) {
    final staffUid = ref.watch(staffUidProvider);
    return ListView(children: [
      const PageHeader('Reservations', subtitle: '"Ready" books are on the hold shelf waiting for pickup'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<ReservationStatus?>(
            segments: const [
              ButtonSegment(value: ReservationStatus.ready, label: Text('Ready for pickup')),
              ButtonSegment(value: ReservationStatus.pending, label: Text('Waiting list')),
              ButtonSegment(value: null, label: Text('All')),
            ],
            selected: {_status},
            onSelectionChanged: (s) => setState(() => _status = s.first),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Panel(
          padding: EdgeInsets.zero,
          child: AsyncBody(
            value: ref.watch(_reservationsProvider(_status)),
            builder: (items) => items.isEmpty
                ? const EmptyHint('No reservations here')
                : WideTable(
                    columns: const [
                      DataColumn(label: Text('Book')),
                      DataColumn(label: Text('Member')),
                      DataColumn(label: Text('Placed')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Hold expires')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: [
                      for (final r in items)
                        DataRow(cells: [
                          DataCell(Row(children: [CoverThumb(r.bookCover, width: 32, height: 46), const SizedBox(width: 10), Text(r.bookTitle)])),
                          DataCell(Text('${r.userName}\n${r.membershipId}'), onTap: () => context.go('/members/${r.userId}')),
                          DataCell(Text(formatDateTime(r.createdAt))),
                          DataCell(Pill(r.status == ReservationStatus.pending && r.queuePosition != null ? 'queue #${r.queuePosition}' : r.status.name,
                              color: reservationColor(r.status))),
                          DataCell(Text(r.status == ReservationStatus.ready ? formatDate(r.expiresAt) : '—')),
                          DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                            if (r.status == ReservationStatus.ready)
                              FilledButton.tonal(
                                onPressed: () => guard(
                                  () => ref.read(repoProvider).issueBook(bookId: r.bookId, memberId: r.userId, staffUid: staffUid),
                                  success: 'Issued to ${r.userName}',
                                ),
                                child: const Text('Issue now'),
                              ),
                            if (r.isOpen)
                              TextButton(
                                onPressed: () async {
                                  if (await confirm(context, 'Cancel this reservation?', danger: true, ok: 'Cancel reservation')) {
                                    await guard(() => ref.read(repoProvider).setReservationStatus(r.id, ReservationStatus.cancelled));
                                  }
                                },
                                child: const Text('Cancel'),
                              ),
                          ])),
                        ]),
                    ],
                  ),
          ),
        ),
      ),
    ]);
  }
}

// ===========================================================================
// Fines
// ===========================================================================

final _finesProvider = StreamProvider.family<List<Fine>, FineStatus?>((ref, s) => ref.watch(repoProvider).watchFines(status: s, limit: 300));

class FinesPage extends ConsumerStatefulWidget {
  const FinesPage({super.key});

  @override
  ConsumerState<FinesPage> createState() => _FinesPageState();
}

class _FinesPageState extends ConsumerState<FinesPage> {
  FineStatus? _status = FineStatus.unpaid;

  Future<void> _collect(Fine f) async {
    var mode = 'cash';
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: Text('Collect ${formatMoney(f.amount)}'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${f.userName} · ${f.reason}'),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'cash', label: Text('Cash')),
                ButtonSegment(value: 'upi', label: Text('UPI')),
                ButtonSegment(value: 'card', label: Text('Card')),
              ],
              selected: {mode},
              onSelectionChanged: (s) => set(() => mode = s.first),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Mark paid')),
          ],
        ),
      ),
    );
    if (ok == true) {
      await guard(() => ref.read(repoProvider).settleFine(f.id, waive: false, paymentMode: mode, staffUid: ref.read(staffUidProvider)), success: 'Payment recorded');
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(_finesProvider(_status));
    return ListView(children: [
      PageHeader('Fines', subtitle: 'Late returns, lost and damaged books', actions: [
        OutlinedButton.icon(
          onPressed: () async {
            final fines = await ref.read(repoProvider).allFines();
            downloadText('fines.csv', toCsv([
              ['Member', 'Book', 'Reason', 'Amount', 'Status', 'Mode', 'Created', 'Settled'],
              for (final f in fines) [f.userName, f.bookTitle, f.reason, f.amount, f.status.name, f.paymentMode, formatDate(f.createdAt), formatDate(f.paidAt)],
            ]));
          },
          icon: const Icon(Icons.download_outlined),
          label: const Text('Export CSV'),
        ),
      ]),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(children: [
          SegmentedButton<FineStatus?>(
            segments: const [
              ButtonSegment(value: FineStatus.unpaid, label: Text('Unpaid')),
              ButtonSegment(value: FineStatus.paid, label: Text('Paid')),
              ButtonSegment(value: FineStatus.waived, label: Text('Waived')),
              ButtonSegment(value: null, label: Text('All')),
            ],
            selected: {_status},
            onSelectionChanged: (s) => setState(() => _status = s.first),
          ),
          const Spacer(),
          if (value.value != null)
            Text('Total: ${formatMoney(value.value!.fold<double>(0, (a, f) => a + f.amount))}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
      ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Panel(
          padding: EdgeInsets.zero,
          child: AsyncBody(
            value: value,
            builder: (fines) => fines.isEmpty
                ? const EmptyHint('No fines here', icon: Icons.verified_outlined)
                : WideTable(
                    columns: const [
                      DataColumn(label: Text('Member')),
                      DataColumn(label: Text('Book / reason')),
                      DataColumn(label: Text('Amount'), numeric: true),
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: [
                      for (final f in fines)
                        DataRow(cells: [
                          DataCell(Text(f.userName), onTap: () => context.go('/members/${f.userId}')),
                          DataCell(Text('${f.bookTitle.isEmpty ? '' : '${f.bookTitle}\n'}${f.reason}')),
                          DataCell(Text(formatMoney(f.amount), style: const TextStyle(fontWeight: FontWeight.w800))),
                          DataCell(Text(formatDate(f.createdAt))),
                          DataCell(Pill(f.status == FineStatus.paid && f.paymentMode.isNotEmpty ? 'paid · ${f.paymentMode}' : f.status.name,
                              color: f.status == FineStatus.unpaid ? dangerColor : f.status == FineStatus.paid ? okColor : Colors.grey)),
                          DataCell(f.status != FineStatus.unpaid
                              ? const SizedBox()
                              : Row(mainAxisSize: MainAxisSize.min, children: [
                                  FilledButton.tonal(onPressed: () => _collect(f), child: const Text('Collect')),
                                  TextButton(
                                    onPressed: () async {
                                      if (await confirm(context, 'Waive ${formatMoney(f.amount)} for ${f.userName}?', ok: 'Waive')) {
                                        await guard(() => ref.read(repoProvider).settleFine(f.id, waive: true, staffUid: ref.read(staffUidProvider)), success: 'Fine waived');
                                      }
                                    },
                                    child: const Text('Waive'),
                                  ),
                                ])),
                        ]),
                    ],
                  ),
          ),
        ),
      ),
    ]);
  }
}

// ===========================================================================
// Push notifications
// ===========================================================================

final _broadcastsProvider = StreamProvider<List<Broadcast>>((ref) => ref.watch(repoProvider).watchBroadcasts());

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _sending = false;

  static const _templates = [
    ('Holiday notice', 'The library will remain closed tomorrow. Happy holidays!'),
    ('New arrivals', 'Fresh books just landed on our shelves — open the app to explore.'),
    ('Reminder', 'Please return overdue books to avoid fines.'),
  ];

  Future<void> _send() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      toast('Add a title and a message.', error: true);
      return;
    }
    if (!await confirm(context, 'Send to all app users?', message: _title.text, ok: 'Send now')) return;
    setState(() => _sending = true);
    final ok = await guard(
      () => ref.read(repoProvider).sendBroadcast(title: _title.text.trim(), body: _body.text.trim(), staffUid: ref.read(staffUidProvider)),
      success: 'Notification queued — members will receive it in a few seconds',
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      _title.clear();
      _body.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      const PageHeader('Push notifications', subtitle: 'Send announcements to every member\'s phone'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Wrap(spacing: 16, runSpacing: 16, crossAxisAlignment: WrapCrossAlignment.start, children: [
          SizedBox(
            width: 480,
            child: Panel(
              title: 'Compose',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final t in _templates)
                    ActionChip(label: Text(t.$1), onPressed: () => setState(() {
                          _title.text = t.$1;
                          _body.text = t.$2;
                        })),
                ]),
                const SizedBox(height: 12),
                TextField(controller: _title, maxLength: 65, decoration: const InputDecoration(labelText: 'Title'), onChanged: (_) => setState(() {})),
                const SizedBox(height: 6),
                TextField(controller: _body, maxLength: 240, maxLines: 4, decoration: const InputDecoration(labelText: 'Message'), onChanged: (_) => setState(() {})),
                const SizedBox(height: 10),
                const Text('Preview', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: ListTile(
                    leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset('assets/logo.png', width: 36)),
                    title: Text(_title.text.isEmpty ? 'Notification title' : _title.text, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(_body.text.isEmpty ? 'Your message appears here' : _body.text),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send),
                  label: Text(_sending ? 'Sending…' : 'Send to all members'),
                ),
                const SizedBox(height: 8),
                const Text('To message one member, open their profile and click "Message".', style: TextStyle(fontSize: 12)),
              ]),
            ),
          ),
          SizedBox(
            width: 560,
            child: Panel(
              title: 'History',
              padding: EdgeInsets.zero,
              child: AsyncBody(
                value: ref.watch(_broadcastsProvider),
                builder: (items) => items.isEmpty
                    ? const EmptyHint('No announcements sent yet')
                    : Column(children: [
                        for (final b in items)
                          ListTile(
                            leading: const Icon(Icons.campaign_outlined),
                            title: Text(b.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('${b.body}\n${formatDateTime(b.createdAt)}'),
                            isThreeLine: true,
                            trailing: Pill(b.status, color: b.status == 'sent' ? okColor : b.status == 'failed' ? dangerColor : warnColor),
                          ),
                      ]),
              ),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 24),
    ]);
  }
}

// ===========================================================================
// Events
// ===========================================================================

final _eventsProvider = StreamProvider<List<LibraryEvent>>((ref) => ref.watch(repoProvider).watchEvents(publishedOnly: false, limit: 200));

class EventsPage extends ConsumerWidget {
  const EventsPage({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, [LibraryEvent? e]) async {
    final title = TextEditingController(text: e?.title ?? '');
    final desc = TextEditingController(text: e?.description ?? '');
    final location = TextEditingController(text: e?.location ?? 'Rampur Library');
    var start = e?.startAt ?? DateTime.now().add(const Duration(days: 7));
    DateTime? end = e?.endAt;
    var published = e?.published ?? true;
    var notify = e == null;
    Uint8List? image;

    Future<DateTime?> pick(BuildContext c, DateTime initial) async {
      final d = await showDatePicker(context: c, initialDate: initial, firstDate: DateTime(2020), lastDate: DateTime(2100));
      if (d == null || !c.mounted) return null;
      final t = await showTimePicker(context: c, initialTime: TimeOfDay.fromDateTime(initial));
      return DateTime(d.year, d.month, d.day, t?.hour ?? 10, t?.minute ?? 0);
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: Text(e == null ? 'New event' : 'Edit event'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 10),
                TextField(controller: desc, maxLines: 4, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 10),
                TextField(controller: location, decoration: const InputDecoration(labelText: 'Location')),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Starts'),
                  subtitle: Text(formatDateTime(start)),
                  trailing: const Icon(Icons.edit_calendar),
                  onTap: () async {
                    final v = await pick(d, start);
                    if (v != null) set(() => start = v);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ends (optional)'),
                  subtitle: Text(end == null ? '—' : formatDateTime(end)),
                  trailing: const Icon(Icons.edit_calendar),
                  onTap: () async {
                    final v = await pick(d, end ?? start.add(const Duration(hours: 2)));
                    if (v != null) set(() => end = v);
                  },
                ),
                Row(children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
                      if (f != null) {
                        final bytes = await f.readAsBytes();
                        set(() => image = bytes);
                      }
                    },
                    icon: const Icon(Icons.image_outlined),
                    label: Text(image != null ? 'Image selected' : 'Banner image'),
                  ),
                ]),
                SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Published (visible in app & website)'), value: published, onChanged: (v) => set(() => published = v)),
                SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Send push notification when published'), value: notify, onChanged: (v) => set(() => notify = v)),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(d, title.text.trim().isNotEmpty), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await guard(
      () => ref.read(repoProvider).saveEvent(
            LibraryEvent(
              id: e?.id ?? '',
              title: title.text.trim(),
              description: desc.text.trim(),
              imageUrl: e?.imageUrl ?? '',
              startAt: start,
              endAt: end,
              location: location.text.trim(),
              published: published,
              notify: notify,
            ),
            imageBytes: image,
          ),
      success: 'Event saved',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(children: [
      PageHeader('Events', subtitle: 'Story time, book clubs, workshops', actions: [
        FilledButton.icon(onPressed: () => _edit(context, ref), icon: const Icon(Icons.add), label: const Text('New event')),
      ]),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Panel(
          padding: EdgeInsets.zero,
          child: AsyncBody(
            value: ref.watch(_eventsProvider),
            builder: (events) => events.isEmpty
                ? const EmptyHint('No events yet', icon: Icons.event_outlined)
                : Column(children: [
                    for (final e in events)
                      ListTile(
                        leading: e.imageUrl.isEmpty
                            ? const CircleAvatar(child: Icon(Icons.event))
                            : ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(e.imageUrl, width: 64, height: 40, fit: BoxFit.cover)),
                        title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${formatDateTime(e.startAt)} · ${e.location}'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Pill(e.published ? (e.isUpcoming ? 'upcoming' : 'past') : 'draft', color: e.published ? (e.isUpcoming ? okColor : Colors.grey) : warnColor),
                          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(context, ref, e)),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: dangerColor),
                            onPressed: () async {
                              if (await confirm(context, 'Delete "${e.title}"?', danger: true, ok: 'Delete')) {
                                await guard(() => ref.read(repoProvider).deleteEvent(e.id));
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
// Book suggestions from members
// ===========================================================================

final _requestsProvider = StreamProvider<List<BookRequest>>((ref) => ref.watch(repoProvider).watchBookRequests());

class RequestsPage extends ConsumerWidget {
  const RequestsPage({super.key});

  Future<void> _update(BuildContext context, WidgetRef ref, BookRequest r, String status) async {
    final note = TextEditingController(text: r.adminNote);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Mark as $status'),
        content: SizedBox(width: 380, child: TextField(controller: note, decoration: const InputDecoration(labelText: 'Note to member (optional)'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Update & notify')),
        ],
      ),
    );
    if (ok == true) await guard(() => ref.read(repoProvider).updateBookRequest(r.id, status, adminNote: note.text.trim()), success: 'Member notified');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(children: [
      const PageHeader('Book suggestions', subtitle: 'Purchase requests from members'),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Panel(
          padding: EdgeInsets.zero,
          child: AsyncBody(
            value: ref.watch(_requestsProvider),
            builder: (items) => items.isEmpty
                ? const EmptyHint('No suggestions yet', icon: Icons.lightbulb_outline)
                : Column(children: [
                    for (final r in items)
                      ListTile(
                        title: Text('${r.title}${r.author.isEmpty ? '' : ' — ${r.author}'}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${r.userName} · ${formatDate(r.createdAt)}${r.note.isEmpty ? '' : '\n"${r.note}"'}'),
                        isThreeLine: r.note.isNotEmpty,
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Pill(r.status, color: switch (r.status) {
                            'approved' || 'acquired' => okColor,
                            'rejected' => dangerColor,
                            _ => warnColor,
                          }),
                          PopupMenuButton<String>(
                            onSelected: (s) => _update(context, ref, r, s),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'approved', child: Text('Approve (will order)')),
                              PopupMenuItem(value: 'acquired', child: Text('Acquired (now in library)')),
                              PopupMenuItem(value: 'rejected', child: Text('Reject')),
                            ],
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
