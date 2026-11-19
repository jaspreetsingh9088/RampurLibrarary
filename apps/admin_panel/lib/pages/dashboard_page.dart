import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:library_core/library_core.dart';

import '../providers.dart';
import '../widgets.dart';

final _overdueProvider = StreamProvider<List<Loan>>((ref) => ref.watch(repoProvider).watchLoans(status: LoanStatus.overdue, limit: 8));
final _recentResProvider = StreamProvider<List<Reservation>>((ref) => ref.watch(repoProvider).watchReservations(status: ReservationStatus.pending, limit: 8));

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    final settings = ref.watch(settingsProvider).value ?? const LibrarySettings();
    final collected = ref.watch(finesCollectedProvider).value ?? 0;
    final width = MediaQuery.sizeOf(context).width;
    final cols = width > 1400 ? 4 : width > 900 ? 3 : width > 600 ? 2 : 1;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardStatsProvider);
        ref.invalidate(issuesPerDayProvider);
        ref.invalidate(finesCollectedProvider);
      },
      child: ListView(children: [
        PageHeader('Dashboard', subtitle: 'Today at ${settings.name}', actions: [
          FilledButton.icon(onPressed: () => context.go('/circulation'), icon: const Icon(Icons.swap_horiz), label: const Text('Issue / Return')),
          OutlinedButton.icon(
            onPressed: () {
              ref.invalidate(dashboardStatsProvider);
              ref.invalidate(issuesPerDayProvider);
              ref.invalidate(finesCollectedProvider);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: AsyncBody(
            value: stats,
            builder: (s) => GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 2.6,
              children: [
                StatCard(label: 'Books in catalogue', value: '${s.totalBooks}', icon: Icons.menu_book, onTap: () => context.go('/books')),
                StatCard(label: 'Members', value: '${s.totalMembers}', icon: Icons.people_alt, color: Colors.indigo, onTap: () => context.go('/members')),
                StatCard(label: 'Books out on loan', value: '${s.activeLoans}', icon: Icons.outbox, color: Colors.teal, onTap: () => context.go('/circulation')),
                StatCard(label: 'Overdue', value: '${s.overdueLoans}', icon: Icons.warning_amber_rounded, color: dangerColor, onTap: () => context.go('/circulation')),
                StatCard(label: 'Open reservations', value: '${s.pendingReservations}', icon: Icons.bookmark, color: warnColor, onTap: () => context.go('/reservations')),
                StatCard(label: 'Unpaid fines', value: '${s.unpaidFines}', icon: Icons.receipt_long, color: Colors.deepOrange, onTap: () => context.go('/fines')),
                StatCard(label: 'Fines collected (30 days)', value: formatMoney(collected, settings.currency), icon: Icons.payments_outlined, color: okColor),
                StatCard(label: 'Book suggestions', value: '${s.pendingRequests}', icon: Icons.lightbulb_outline, color: Colors.purple, onTap: () => context.go('/requests')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Panel(title: 'Books issued — last 14 days', child: SizedBox(height: 260, child: _IssuesChart())),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: width > 1100
              ? const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: _OverduePanel()),
                  SizedBox(width: 16),
                  Expanded(child: _ReservationsPanel()),
                ])
              : const Column(children: [_OverduePanel(), SizedBox(height: 16), _ReservationsPanel()]),
        ),
      ]),
    );
  }
}

class _IssuesChart extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return AsyncBody(
      value: ref.watch(issuesPerDayProvider),
      builder: (data) {
        final maxY = data.fold<int>(0, (m, e) => e.value > m ? e.value : m);
        return BarChart(BarChartData(
          maxY: (maxY < 4 ? 4 : maxY + 1).toDouble(),
          gridData: FlGridData(drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: scheme.outlineVariant.withValues(alpha: 0.5), strokeWidth: 1)),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: 1 + (maxY ~/ 5).toDouble(),
                getTitlesWidget: (v, meta) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 11)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox();
                  final d = data[i].key;
                  return Padding(padding: const EdgeInsets.only(top: 6), child: Text('${d.day}/${d.month}', style: const TextStyle(fontSize: 11)));
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < data.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(toY: data[i].value.toDouble(), color: brandPrimary, width: 16, borderRadius: BorderRadius.circular(4)),
              ]),
          ],
        ));
      },
    );
  }
}

class _OverduePanel extends ConsumerWidget {
  const _OverduePanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Panel(
      title: 'Overdue books',
      trailing: TextButton(onPressed: () => context.go('/circulation'), child: const Text('View all')),
      padding: EdgeInsets.zero,
      child: AsyncBody(
        value: ref.watch(_overdueProvider),
        builder: (loans) => loans.isEmpty
            ? const EmptyHint('Nothing overdue 🎉', icon: Icons.check_circle_outline)
            : Column(children: [
                for (final l in loans)
                  ListTile(
                    leading: Thumb(l.bookCover),
                    title: Text(l.bookTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${l.userName} · ${l.membershipId} · due ${formatDate(l.dueAt)}'),
                    trailing: Pill('${DateTime.now().difference(l.dueAt).inDays}d late', color: dangerColor),
                    onTap: () => context.go('/members/${l.userId}'),
                  ),
              ]),
      ),
    );
  }
}

class _ReservationsPanel extends ConsumerWidget {
  const _ReservationsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Panel(
      title: 'Waiting list',
      trailing: TextButton(onPressed: () => context.go('/reservations'), child: const Text('View all')),
      padding: EdgeInsets.zero,
      child: AsyncBody(
        value: ref.watch(_recentResProvider),
        builder: (items) => items.isEmpty
            ? const EmptyHint('No one is waiting')
            : Column(children: [
                for (final r in items)
                  ListTile(
                    leading: Thumb(r.bookCover),
                    title: Text(r.bookTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${r.userName} · ${timeAgo(r.createdAt)}'),
                    trailing: Pill(r.queuePosition == null ? 'pending' : '#${r.queuePosition}', color: warnColor),
                  ),
              ]),
      ),
    );
  }
}
