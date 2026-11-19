import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:library_core/library_core.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app.dart';
import '../providers.dart';
import '../theme.dart';
import '../widgets/common.dart';

// ===========================================================================
// Notifications inbox
// ===========================================================================

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  IconData _icon(String type) => switch (type) {
        'issued' => Icons.outbox_rounded,
        'returned' => Icons.move_to_inbox_rounded,
        'due_soon' => Icons.schedule_rounded,
        'overdue' => Icons.warning_amber_rounded,
        'reservation_ready' => Icons.inventory_2_rounded,
        'reservation_queued' => Icons.hourglass_top_rounded,
        'renewed' => Icons.autorenew_rounded,
        'fine' => Icons.receipt_long_rounded,
        'broadcast' => Icons.campaign_rounded,
        'welcome' => Icons.celebration_rounded,
        _ => Icons.notifications_rounded,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(uidProvider);
    final personal = ref.watch(notificationsProvider);
    final broadcasts = ref.watch(broadcastsProvider).value ?? const <AppNotification>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications'), actions: [
        TextButton(onPressed: uid == null ? null : () => ref.read(repoProvider).markAllNotificationsRead(uid), child: const Text('Mark all read')),
      ]),
      body: AsyncView(
        value: personal,
        builder: (items) {
          final all = [...items, ...broadcasts]..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
          if (all.isEmpty) return const EmptyState(icon: Icons.notifications_none_rounded, title: 'You\'re all caught up');
          return ListView.separated(
            itemCount: all.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final n = all[i];
              final tile = ListTile(
                tileColor: n.read ? null : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.25),
                leading: CircleAvatar(child: Icon(_icon(n.type), size: 20)),
                title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w500 : FontWeight.w800)),
                subtitle: Text('${n.body}\n${timeAgo(n.createdAt)}'),
                isThreeLine: true,
                onTap: () {
                  if (!n.read && uid != null) ref.read(repoProvider).markNotificationRead(uid, n.id);
                  final d = n.data;
                  if (d['bookId'] != null && d['bookId']!.isNotEmpty) {
                    context.push('/book/${d['bookId']}');
                  } else if (n.type == 'fine') {
                    context.push('/fines');
                  } else if (d['loanId'] != null) {
                    context.go('/my-books');
                  }
                },
              );
              if (n.isBroadcast || uid == null) return tile;
              return Dismissible(
                key: ValueKey(n.id),
                direction: DismissDirection.endToStart,
                background: Container(color: AppColors.danger, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                onDismissed: (_) => ref.read(repoProvider).deleteNotification(uid, n.id),
                child: tile,
              );
            },
          );
        },
      ),
    );
  }
}

// ===========================================================================
// Fines
// ===========================================================================

class FinesScreen extends ConsumerWidget {
  const FinesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider).value ?? const LibrarySettings();
    return Scaffold(
      appBar: AppBar(title: const Text('Fines & payments')),
      body: AsyncView(
        value: ref.watch(finesProvider),
        builder: (fines) {
          final due = fines.where((f) => f.status == FineStatus.unpaid).fold<double>(0, (a, f) => a + f.amount);
          return ListView(padding: const EdgeInsets.all(16), children: [
            Card(
              color: due > 0 ? AppColors.danger.withValues(alpha: 0.08) : AppColors.success.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  Text(due > 0 ? 'Outstanding' : 'No dues', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(formatMoney(due, s.currency), style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: due > 0 ? AppColors.danger : AppColors.success)),
                  const SizedBox(height: 8),
                  Text('Fines are ${formatMoney(s.finePerDay, s.currency)} per day late. Pay at the library desk (cash / UPI).',
                      textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            if (fines.isEmpty) const EmptyState(icon: Icons.verified_rounded, title: 'No fines ever — great reader!'),
            for (final f in fines)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(f.bookTitle.isEmpty ? f.reason : f.bookTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${f.reason} · ${formatDate(f.createdAt)}${f.paidAt != null ? '\nSettled ${formatDate(f.paidAt)}' : ''}'),
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(formatMoney(f.amount, s.currency), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 4),
                    StatusPill(f.status.name, color: switch (f.status) {
                      FineStatus.unpaid => AppColors.danger,
                      FineStatus.paid => AppColors.success,
                      FineStatus.waived => Colors.grey,
                    }),
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

// ===========================================================================
// Events
// ===========================================================================

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Events & workshops')),
      body: AsyncView(
        value: ref.watch(eventsProvider),
        builder: (events) {
          final upcoming = events.where((e) => e.isUpcoming).toList();
          final past = events.where((e) => !e.isUpcoming).toList().reversed.toList();
          if (events.isEmpty) return const EmptyState(icon: Icons.event_outlined, title: 'No events yet', message: 'Story time, book clubs and workshops will appear here.');
          return ListView(padding: const EdgeInsets.all(16), children: [
            if (upcoming.isNotEmpty) const SectionHeader('Upcoming'),
            for (final e in upcoming) _EventCard(event: e),
            if (past.isNotEmpty) const SectionHeader('Past events'),
            for (final e in past.take(10)) Opacity(opacity: 0.6, child: _EventCard(event: e)),
          ]);
        },
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});
  final LibraryEvent event;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (event.imageUrl.isNotEmpty)
            AspectRatio(aspectRatio: 16 / 9, child: Image.network(event.imageUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox())),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(event.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.schedule, size: 16),
                const SizedBox(width: 6),
                Expanded(child: Text(event.endAt == null ? formatDateTime(event.startAt) : '${formatDateTime(event.startAt)} – ${formatDateTime(event.endAt)}')),
              ]),
              if (event.location.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(children: [const Icon(Icons.place_outlined, size: 16), const SizedBox(width: 6), Expanded(child: Text(event.location))]),
                ),
              if (event.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(event.description, style: const TextStyle(height: 1.45))),
            ]),
          ),
        ]),
      );
}

// ===========================================================================
// Book suggestions
// ===========================================================================

class BookRequestsScreen extends ConsumerWidget {
  const BookRequestsScreen({super.key});

  Future<void> _new(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    final author = TextEditingController();
    final note = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Suggest a book', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Title *')),
          const SizedBox(height: 10),
          TextField(controller: author, decoration: const InputDecoration(labelText: 'Author')),
          const SizedBox(height: 10),
          TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Why should we add it?')),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => Navigator.pop(ctx, title.text.trim().isNotEmpty), child: const Text('Send suggestion')),
        ]),
      ),
    );
    final member = ref.read(memberProvider).value;
    if (ok != true || member == null) return;
    await ref.read(repoProvider).submitBookRequest(member: member, title: title.text, author: author.text, note: note.text);
    showSnack('Thanks! The librarian will review your suggestion.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book suggestions')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _new(context, ref), icon: const Icon(Icons.add), label: const Text('Suggest')),
      body: AsyncView(
        value: ref.watch(bookRequestsProvider),
        builder: (items) => items.isEmpty
            ? const EmptyState(icon: Icons.lightbulb_outline, title: 'Can\'t find a book?', message: 'Suggest it and we\'ll try to add it to the collection.')
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final r = items[i];
                  return Card(
                    child: ListTile(
                      title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text([if (r.author.isNotEmpty) r.author, formatDate(r.createdAt), if (r.adminNote.isNotEmpty) 'Librarian: ${r.adminNote}'].join(' · ')),
                      trailing: StatusPill(r.status, color: switch (r.status) {
                        'approved' || 'acquired' => AppColors.success,
                        'rejected' => AppColors.danger,
                        _ => AppColors.warning,
                      }),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// ===========================================================================
// About the library
// ===========================================================================

class AboutLibraryScreen extends ConsumerWidget {
  const AboutLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider).value ?? const LibrarySettings();
    return Scaffold(
      appBar: AppBar(title: Text(s.name)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Center(child: Image.asset('assets/images/logo.png', width: 90, height: 90)),
        const SizedBox(height: 12),
        Text(s.tagline, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 20),
        Card(
          child: Column(children: [
            ListTile(leading: const Icon(Icons.schedule), title: const Text('Opening hours'), subtitle: Text(s.openingHours)),
            if (s.address.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.place_outlined),
                title: const Text('Address'),
                subtitle: Text(s.address),
                trailing: const Icon(Icons.directions_outlined),
                onTap: () => launchUrl(Uri.parse('https://maps.google.com/?q=${Uri.encodeComponent(s.address)}'), mode: LaunchMode.externalApplication),
              ),
            if (s.phone.isNotEmpty)
              ListTile(leading: const Icon(Icons.call_outlined), title: const Text('Call us'), subtitle: Text(s.phone), onTap: () => launchUrl(Uri.parse('tel:${s.phone}'))),
            if (s.email.isNotEmpty)
              ListTile(leading: const Icon(Icons.mail_outline), title: const Text('Email'), subtitle: Text(s.email), onTap: () => launchUrl(Uri.parse('mailto:${s.email}'))),
          ]),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Borrowing rules', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 10),
              Text('• Borrow up to ${s.maxLoansPerMember} books at a time'),
              Text('• Loan period: ${s.loanDays} days'),
              Text('• Renew up to ${s.maxRenewals} times (if no one is waiting)'),
              Text('• Late fine: ${formatMoney(s.finePerDay, s.currency)} per day${s.maxFinePerLoan > 0 ? ' (max ${formatMoney(s.maxFinePerLoan, s.currency)} per book)' : ''}'),
              Text('• Reserved books are held for ${s.reservationHoldDays} days'),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => launchUrl(Uri.parse(AppConfig.siteUrl), mode: LaunchMode.externalApplication),
          icon: const Icon(Icons.language),
          label: const Text('Visit our website'),
        ),
      ]),
    );
  }
}

// ===========================================================================
// Settings
// ===========================================================================

class AppSettingsScreen extends ConsumerWidget {
  const AppSettingsScreen({super.key});

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text('This permanently deletes your profile, wishlist and history. You must return all books and clear fines first.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.danger), onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      if (!ref.read(isDemoProvider)) await ref.read(pushServiceProvider).stop();
      await ref.read(repoProvider).deleteMyAccount();
      await ref.read(authGatewayProvider).signOut();
      showSnack('Your account has been deleted.');
    } catch (e) {
      showSnack(errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(memberProvider).value;
    final mode = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(children: [
        SwitchListTile(
          secondary: const Icon(Icons.notifications_active_outlined),
          title: const Text('Push notifications'),
          subtitle: const Text('Due dates, reservations and library news'),
          value: member?.pushEnabled ?? true,
          onChanged: member == null ? null : (v) => ref.read(repoProvider).updateProfile(member.copyWith(pushEnabled: v)),
        ),
        ListTile(
          leading: const Icon(Icons.dark_mode_outlined),
          title: const Text('Theme'),
          trailing: SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined)),
              ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.phone_android)),
              ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined)),
            ],
            selected: {mode},
            onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.first),
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('Privacy policy'),
          onTap: () => launchUrl(Uri.parse('${AppConfig.siteUrl}/privacy')),
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text('Terms of use'),
          onTap: () => launchUrl(Uri.parse('${AppConfig.siteUrl}/terms')),
        ),
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (_, snap) => ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('App version'),
            subtitle: Text(snap.hasData ? '${snap.data!.version} (${snap.data!.buildNumber})' : '…'),
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.delete_forever_outlined, color: AppColors.danger),
          title: const Text('Delete my account', style: TextStyle(color: AppColors.danger)),
          onTap: () => _deleteAccount(context, ref),
        ),
      ]),
    );
  }
}

// ===========================================================================
// Feedback
// ===========================================================================

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _text = TextEditingController();
  int _rating = 0;
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send feedback')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('How do you like the library?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 1; i <= 5; i++)
            IconButton(
              iconSize: 38,
              onPressed: () => setState(() => _rating = i),
              icon: Icon(i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded, color: AppColors.accent),
            ),
        ]),
        TextField(controller: _text, maxLines: 6, decoration: const InputDecoration(hintText: 'Ideas, problems, compliments…')),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _sending
              ? null
              : () async {
                  final uid = ref.read(uidProvider);
                  if (uid == null || _text.text.trim().isEmpty) return;
                  setState(() => _sending = true);
                  await ref.read(repoProvider).submitFeedback(uid: uid, message: _text.text, rating: _rating);
                  showSnack('Thank you for your feedback!');
                  if (context.mounted) context.pop();
                },
          child: const Text('Send'),
        ),
      ]),
    );
  }
}
