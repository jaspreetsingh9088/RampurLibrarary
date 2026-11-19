import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:library_core/library_core.dart';

import '../providers.dart';
import '../theme.dart';
import '../widgets/common.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(memberProvider).value;
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    final loans = ref.watch(activeLoansProvider).value ?? const <Loan>[];
    final ready = (ref.watch(reservationsProvider).value ?? const <Reservation>[]).where((r) => r.status == ReservationStatus.ready).toList();
    final t = Theme.of(context);
    final firstName = (member?.name ?? '').split(' ').first;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(newArrivalsProvider);
          ref.invalidate(featuredProvider);
          ref.invalidate(popularProvider);
        },
        child: CustomScrollView(slivers: [
          SliverAppBar(
            floating: true,
            titleSpacing: 16,
            title: Row(children: [
              MemberAvatar(member: member, radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_greeting(), style: t.textTheme.bodySmall),
                  Text(firstName.isEmpty ? 'Reader' : firstName, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                ]),
              ),
            ]),
            actions: [
              IconButton(icon: const Icon(Icons.qr_code_2_rounded), tooltip: 'Membership card', onPressed: () => context.push('/card')),
              IconButton(
                tooltip: 'Notifications',
                onPressed: () => context.push('/notifications'),
                icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.notifications_outlined)),
              ),
              const SizedBox(width: 4),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => context.go('/search'),
                child: InputDecorator(
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search title, author or ISBN'),
                  child: Text('Search title, author or ISBN', style: t.textTheme.bodyLarge?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                ),
              ),
            ),
          ),
          if (ready.isNotEmpty)
            SliverToBoxAdapter(
              child: _Alert(
                color: AppColors.success,
                icon: Icons.inventory_2_rounded,
                text: ready.length == 1 ? '"${ready.first.bookTitle}" is ready to collect' : '${ready.length} reserved books are ready to collect',
                onTap: () => context.go('/my-books?tab=1'),
              ),
            ),
          if (loans.any((l) => l.isOverdue))
            SliverToBoxAdapter(
              child: _Alert(
                color: AppColors.danger,
                icon: Icons.warning_amber_rounded,
                text: '${loans.where((l) => l.isOverdue).length} book(s) overdue — return soon to avoid fines',
                onTap: () => context.go('/my-books'),
              ),
            )
          else if (loans.any((l) => l.daysLeft <= 2))
            SliverToBoxAdapter(
              child: _Alert(
                color: AppColors.warning,
                icon: Icons.schedule_rounded,
                text: 'A book is due in ${loans.first.daysLeft <= 0 ? 'less than a day' : '${loans.first.daysLeft} days'}. Renew it?',
                onTap: () => context.go('/my-books'),
              ),
            ),
          if (loans.isNotEmpty) SliverToBoxAdapter(child: _LoanStrip(loans: loans)),
          const SliverToBoxAdapter(child: _Categories()),
          SliverToBoxAdapter(child: _Carousel(title: 'Featured', provider: featuredProvider, hideWhenEmpty: true)),
          SliverToBoxAdapter(child: _Carousel(title: 'New arrivals', provider: newArrivalsProvider, onSeeAll: () => context.go('/search?q='))),
          SliverToBoxAdapter(child: _Carousel(title: 'Most reviewed', provider: popularProvider, hideWhenEmpty: true)),
          const SliverToBoxAdapter(child: _EventsTeaser()),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ]),
      ),
    );
  }
}

class _Alert extends StatelessWidget {
  const _Alert({required this.color, required this.icon, required this.text, required this.onTap});
  final Color color;
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Material(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Icon(icon, color: color),
                const SizedBox(width: 12),
                Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700))),
                Icon(Icons.chevron_right, color: color),
              ]),
            ),
          ),
        ),
      );
}

class _LoanStrip extends StatelessWidget {
  const _LoanStrip({required this.loans});
  final List<Loan> loans;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader('Currently reading', onSeeAll: () => context.go('/my-books')),
      SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: loans.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, i) {
            final l = loans[i];
            final color = l.isOverdue ? AppColors.danger : (l.daysLeft <= 2 ? AppColors.warning : AppColors.success);
            return SizedBox(
              width: 260,
              child: Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.push('/book/${l.bookId}'),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(children: [
                      BookCover(url: l.bookCover, title: l.bookTitle, width: 50, height: 74),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(l.bookTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          StatusPill(l.isOverdue ? 'Overdue' : 'Due ${formatDate(l.dueAt)}', color: color),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

class _Categories extends ConsumerWidget {
  const _Categories();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoriesProvider).value ?? const <BookCategory>[];
    if (cats.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader('Browse by category'),
      SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: cats.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final c = cats[i];
            return ActionChip(
              avatar: c.icon.isEmpty ? null : Text(c.icon),
              label: Text(c.bookCount > 0 ? '${c.name} · ${c.bookCount}' : c.name),
              onPressed: () => context.push('/category/${c.slug}?name=${Uri.encodeComponent(c.name)}'),
            );
          },
        ),
      ),
    ]);
  }
}

class _Carousel extends ConsumerWidget {
  const _Carousel({required this.title, required this.provider, this.onSeeAll, this.hideWhenEmpty = false});
  final String title;
  final StreamProvider<List<Book>> provider;
  final VoidCallback? onSeeAll;
  final bool hideWhenEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(provider);
    final books = value.value ?? const <Book>[];
    if (hideWhenEmpty && books.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(title, onSeeAll: onSeeAll),
      SizedBox(
        height: 250,
        child: value.isLoading && books.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : books.isEmpty
                ? const Center(child: Text('No books yet'))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: books.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (_, i) => BookCard(book: books[i]),
                  ),
      ),
    ]);
  }
}

class _EventsTeaser extends ConsumerWidget {
  const _EventsTeaser();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = (ref.watch(eventsProvider).value ?? const <LibraryEvent>[]).where((e) => e.isUpcoming).take(3).toList();
    if (events.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader('Upcoming events', onSeeAll: () => context.push('/events')),
      for (final e in events)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Card(
            child: ListTile(
              onTap: () => context.push('/events'),
              leading: Container(
                width: 48,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(10)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${e.startAt.day}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  Text(formatDate(e.startAt).split(' ')[1].toUpperCase(), style: const TextStyle(fontSize: 11)),
                ]),
              ),
              title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(e.location.isEmpty ? formatDateTime(e.startAt) : '${formatDateTime(e.startAt)} · ${e.location}'),
            ),
          ),
        ),
    ]);
  }
}
