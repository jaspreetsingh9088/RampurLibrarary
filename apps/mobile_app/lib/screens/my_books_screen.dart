import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:library_core/library_core.dart';

import '../providers.dart';
import '../theme.dart';
import '../widgets/common.dart';

class MyBooksScreen extends ConsumerWidget {
  const MyBooksScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      initialIndex: initialTab.clamp(0, 3),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Books'),
          bottom: const TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [
            Tab(text: 'Borrowed'),
            Tab(text: 'Reservations'),
            Tab(text: 'History'),
            Tab(text: 'Wishlist'),
          ]),
        ),
        body: const TabBarView(children: [_Borrowed(), _Reservations(), _History(), _Wishlist()]),
      ),
    );
  }
}

class _Borrowed extends ConsumerWidget {
  const _Borrowed();

  Future<void> _renew(WidgetRef ref, Loan loan) async {
    try {
      final due = await ref.read(repoProvider).renewMyLoan(loan.id);
      showSnack('Renewed! New due date: ${formatDate(due)}');
    } catch (e) {
      showSnack(errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value ?? const LibrarySettings();
    return AsyncView(
      value: ref.watch(activeLoansProvider),
      builder: (loans) => loans.isEmpty
          ? EmptyState(
              icon: Icons.auto_stories_outlined,
              title: 'No books borrowed',
              message: 'Find something to read and reserve it for pickup.',
              action: FilledButton(onPressed: () => context.go('/search'), child: const Text('Explore books')),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: loans.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final l = loans[i];
                final overdue = l.isOverdue;
                final color = overdue ? AppColors.danger : (l.daysLeft <= 2 ? AppColors.warning : AppColors.success);
                final fine = overdue
                    ? computeFine(dueAt: l.dueAt, at: DateTime.now(), finePerDay: settings.finePerDay, graceDays: settings.graceDays, maxFine: settings.maxFinePerLoan)
                    : 0.0;
                final total = l.dueAt.difference(l.issuedAt).inHours.clamp(1, 1 << 30);
                final used = DateTime.now().difference(l.issuedAt).inHours.clamp(0, total);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(children: [
                      InkWell(
                        onTap: () => context.push('/book/${l.bookId}'),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          BookCover(url: l.bookCover, title: l.bookTitle, width: 60, height: 88),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(l.bookTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text('Issued ${formatDate(l.issuedAt)}', style: Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 8),
                              StatusPill(
                                overdue
                                    ? 'Overdue · fine ${formatMoney(fine, settings.currency)}'
                                    : l.daysLeft <= 0
                                        ? 'Due today'
                                        : 'Due ${formatDate(l.dueAt)} · ${l.daysLeft} days left',
                                color: color,
                              ),
                            ]),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: used / total, minHeight: 6, color: color, backgroundColor: color.withValues(alpha: 0.15)),
                      ),
                      const SizedBox(height: 10),
                      Row(children: [
                        Text('Renewed ${l.renewCount}/${settings.maxRenewals}', style: Theme.of(context).textTheme.bodySmall),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: overdue || l.renewCount >= settings.maxRenewals ? null : () => _renew(ref, l),
                          icon: const Icon(Icons.autorenew_rounded, size: 18),
                          label: const Text('Renew'),
                        ),
                      ]),
                    ]),
                  ),
                );
              },
            ),
    );
  }
}

class _Reservations extends ConsumerWidget {
  const _Reservations();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView(
      value: ref.watch(reservationsProvider),
      builder: (items) => items.isEmpty
          ? const EmptyState(icon: Icons.bookmark_outline, title: 'No reservations', message: 'Reserve a book from its page and we\'ll hold it for you.')
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final r = items[i];
                final (label, color) = switch (r.status) {
                  ReservationStatus.ready => ('Ready · collect by ${formatDate(r.expiresAt)}', AppColors.success),
                  ReservationStatus.pending => (r.queuePosition == null ? 'In queue' : 'Queue position #${r.queuePosition}', AppColors.warning),
                  ReservationStatus.fulfilled => ('Collected', Theme.of(context).colorScheme.primary),
                  ReservationStatus.cancelled => ('Cancelled', Colors.grey),
                  ReservationStatus.expired => ('Expired', Colors.grey),
                };
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    onTap: () => context.push('/book/${r.bookId}'),
                    leading: BookCover(url: r.bookCover, title: r.bookTitle, width: 44, height: 64),
                    title: Text(r.bookTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Padding(padding: const EdgeInsets.only(top: 6), child: Align(alignment: Alignment.centerLeft, child: StatusPill(label, color: color))),
                    trailing: r.isOpen
                        ? IconButton(
                            tooltip: 'Cancel',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text('Cancel reservation?'),
                                  content: Text('"${r.bookTitle}" will go to the next person in line.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')),
                                    FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Cancel it')),
                                  ],
                                ),
                              );
                              if (ok == true) await ref.read(repoProvider).cancelReservation(r.id);
                            },
                          )
                        : null,
                  ),
                );
              },
            ),
    );
  }
}

class _History extends ConsumerWidget {
  const _History();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView(
      value: ref.watch(historyProvider),
      builder: (items) => items.isEmpty
          ? const EmptyState(icon: Icons.history_rounded, title: 'No reading history yet')
          : ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text('You\'ve read ${items.length} book${items.length == 1 ? '' : 's'} with us 🎉',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ),
              for (final l in items)
                ListTile(
                  onTap: () => context.push('/book/${l.bookId}'),
                  leading: BookCover(url: l.bookCover, title: l.bookTitle, width: 40, height: 58),
                  title: Text(l.bookTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${formatDate(l.issuedAt)} → ${formatDate(l.returnedAt)}'),
                  trailing: const Icon(Icons.chevron_right),
                ),
            ]),
    );
  }
}

class _Wishlist extends ConsumerWidget {
  const _Wishlist();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(uidProvider);
    return AsyncView(
      value: ref.watch(wishlistProvider),
      builder: (books) => books.isEmpty
          ? const EmptyState(icon: Icons.favorite_border_rounded, title: 'Your wishlist is empty', message: 'Tap the heart on any book to save it for later.')
          : ListView.separated(
              itemCount: books.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 94),
              itemBuilder: (_, i) => BookTile(
                book: books[i],
                trailing: IconButton(
                  icon: const Icon(Icons.favorite_rounded, color: Colors.redAccent),
                  onPressed: uid == null ? null : () => ref.read(repoProvider).toggleWishlist(uid, books[i], false),
                ),
              ),
            ),
    );
  }
}
