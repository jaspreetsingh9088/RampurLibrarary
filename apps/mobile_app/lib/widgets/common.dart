import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:library_core/library_core.dart';

import '../theme.dart';

/// Global messenger so push notifications can show banners from anywhere.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void showSnack(String message, {bool error = false}) {
  scaffoldMessengerKey.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? AppColors.danger : null,
    ));
}

String errorText(Object e) {
  if (e is LibraryException) return e.message;
  final s = e.toString().replaceFirst('Exception: ', '');
  return s.replaceFirst(RegExp(r'^\[[^\]]+\]\s*'), '');
}

/// Renders an AsyncValue with consistent loading / error states.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.builder, this.loading});

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () => loading ?? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
      error: (e, _) => EmptyState(icon: Icons.cloud_off, title: 'Something went wrong', message: errorText(e)),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(radius: 36, backgroundColor: t.colorScheme.primaryContainer, child: Icon(icon, size: 34, color: t.colorScheme.primary)),
          const SizedBox(height: 16),
          Text(title, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 8, 8),
      child: Row(children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
        if (onSeeAll != null) TextButton(onPressed: onSeeAll, child: const Text('See all')),
      ]),
    );
  }
}

class BookCover extends StatelessWidget {
  const BookCover({super.key, required this.url, required this.title, this.width = 90, this.height = 130, this.heroTag});

  final String url;
  final String title;
  final double width;
  final double height;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [scheme.primary, scheme.tertiary], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      alignment: Alignment.center,
      child: Text(title, maxLines: 4, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w700, fontSize: width / 8)),
    );
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: url.isEmpty
          ? placeholder
          : Image.network(url, width: width, height: height, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder,
              loadingBuilder: (c, child, p) => p == null ? child : SizedBox(width: width, height: height, child: ColoredBox(color: scheme.surfaceContainerHighest))),
    );
    return heroTag == null ? image : Hero(tag: heroTag!, child: image);
  }
}

class AvailabilityChip extends StatelessWidget {
  const AvailabilityChip({super.key, required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    final ok = book.isAvailable;
    final color = ok ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(ok ? '${book.availableCopies} available' : 'On loan',
          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

/// Vertical card for horizontal carousels.
class BookCard extends StatelessWidget {
  const BookCard({super.key, required this.book, this.width = 120});
  final Book book;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => context.push('/book/${book.id}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          BookCover(url: book.coverUrl, title: book.title, width: width, height: width * 1.45, heroTag: 'cover-${book.id}-card'),
          const SizedBox(height: 8),
          Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.2)),
          const SizedBox(height: 2),
          Text(book.authorLine, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

/// Row-style tile for lists and search results.
class BookTile extends StatelessWidget {
  const BookTile({super.key, required this.book, this.trailing});
  final Book book;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return InkWell(
      onTap: () => context.push('/book/${book.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          BookCover(url: book.coverUrl, title: book.title, width: 64, height: 92),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(book.authorLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall),
              const SizedBox(height: 8),
              Row(children: [
                AvailabilityChip(book: book),
                if (book.ratingCount > 0) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.star_rounded, size: 16, color: AppColors.accent),
                  Text(' ${book.ratingAvg.toStringAsFixed(1)}', style: t.textTheme.bodySmall),
                ],
              ]),
            ]),
          ),
          ?trailing,
        ]),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
      );
}

class MemberAvatar extends StatelessWidget {
  const MemberAvatar({super.key, required this.member, this.radius = 28});
  final Member? member;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = member?.photoUrl ?? '';
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
      child: url.isEmpty
          ? Text(member?.initials ?? '?', style: TextStyle(fontSize: radius * 0.7, fontWeight: FontWeight.w800, color: scheme.primary))
          : null,
    );
  }
}
