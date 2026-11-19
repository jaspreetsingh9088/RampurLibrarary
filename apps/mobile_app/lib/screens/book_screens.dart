import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:library_core/library_core.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_plus/share_plus.dart';

import '../providers.dart';
import '../theme.dart';
import '../widgets/common.dart';

// ===========================================================================
// Search / explore
// ===========================================================================

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery = ''});
  final String initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final _controller = TextEditingController(text: widget.initialQuery);
  Timer? _debounce;
  bool _availableOnly = false;
  String? _language;
  List<Book>? _results;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.isNotEmpty) _run(widget.initialQuery);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(q));
  }

  Future<void> _run(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _results = null);
      return;
    }
    setState(() => _loading = true);
    try {
      final r = await ref.read(repoProvider).searchBooks(q, availableOnly: _availableOnly, language: _language);
      if (mounted) setState(() => _results = r);
    } catch (e) {
      showSnack(errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scan() async {
    final isbn = await context.push<String>('/scan');
    if (isbn == null || !mounted) return;
    final book = await ref.read(repoProvider).findByIsbn(isbn);
    if (!mounted) return;
    if (book != null) {
      context.push('/book/${book.id}');
    } else {
      _controller.text = isbn;
      _run(isbn);
      showSnack('No book with ISBN $isbn in the library yet. You can suggest it from your profile.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(categoriesProvider).value ?? const <BookCategory>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Explore')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            onSubmitted: _run,
            decoration: InputDecoration(
              hintText: 'Title, author or ISBN',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                if (_controller.text.isNotEmpty)
                  IconButton(icon: const Icon(Icons.close), onPressed: () {
                    _controller.clear();
                    _run('');
                  }),
                IconButton(icon: const Icon(Icons.qr_code_scanner_rounded), tooltip: 'Scan ISBN barcode', onPressed: _scan),
              ]),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            FilterChip(
              label: const Text('Available now'),
              selected: _availableOnly,
              onSelected: (v) {
                setState(() => _availableOnly = v);
                _run(_controller.text);
              },
            ),
            const SizedBox(width: 8),
            for (final lang in ['English', 'Hindi', 'Urdu', 'Punjabi'])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(lang),
                  selected: _language == lang,
                  onSelected: (v) {
                    setState(() => _language = v ? lang : null);
                    _run(_controller.text);
                  },
                ),
              ),
          ]),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: _results == null
              ? ListView(children: [
                  const SectionHeader('Categories'),
                  if (cats.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Categories will appear here.')),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.6,
                    children: [
                      for (final c in cats)
                        Card(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => context.push('/category/${c.slug}?name=${Uri.encodeComponent(c.name)}'),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: Row(children: [
                                Text(c.icon.isEmpty ? '📚' : c.icon, style: const TextStyle(fontSize: 22)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    Text('${c.bookCount} books', style: Theme.of(context).textTheme.bodySmall),
                                  ]),
                                ),
                              ]),
                            ),
                          ),
                        ),
                    ],
                  ),
                ])
              : _results!.isEmpty
                  ? EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No books found',
                      message: 'Try a different word, or suggest this book to the library.',
                      action: OutlinedButton(onPressed: () => context.push('/requests'), child: const Text('Suggest a book')),
                    )
                  : ListView.separated(
                      itemCount: _results!.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, indent: 94),
                      itemBuilder: (_, i) => BookTile(book: _results![i]),
                    ),
        ),
      ]),
    );
  }
}

class CategoryScreen extends ConsumerWidget {
  const CategoryScreen({super.key, required this.slug, this.name = ''});
  final String slug;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(name.isEmpty ? 'Category' : name)),
      body: AsyncView(
        value: ref.watch(categoryBooksProvider(slug)),
        builder: (books) => books.isEmpty
            ? const EmptyState(icon: Icons.menu_book_outlined, title: 'No books in this category yet')
            : ListView.separated(
                itemCount: books.length,
                separatorBuilder: (_, _) => const Divider(height: 1, indent: 94),
                itemBuilder: (_, i) => BookTile(book: books[i]),
              ),
      ),
    );
  }
}

// ===========================================================================
// Barcode scanner
// ===========================================================================

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA, BarcodeFormat.qrCode]);
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan ISBN barcode'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.flash_on), onPressed: () => _controller.toggleTorch()),
          IconButton(icon: const Icon(Icons.cameraswitch_outlined), onPressed: () => _controller.switchCamera()),
        ],
      ),
      body: Stack(children: [
        MobileScanner(
          controller: _controller,
          onDetect: (capture) {
            if (_done) return;
            final value = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstWhere((v) => v.isNotEmpty, orElse: () => '');
            if (value.isEmpty) return;
            _done = true;
            context.pop(value.replaceAll(RegExp(r'[^0-9Xx]'), ''));
          },
        ),
        Center(
          child: Container(
            width: 280,
            height: 160,
            decoration: BoxDecoration(border: Border.all(color: AppColors.accent, width: 3), borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 48,
          child: Text('Point the camera at the barcode on the back cover', textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
        ),
      ]),
    );
  }
}

// ===========================================================================
// Book detail
// ===========================================================================

class BookDetailScreen extends ConsumerWidget {
  const BookDetailScreen({super.key, required this.bookId});
  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView(
      value: ref.watch(bookProvider(bookId)),
      loading: const Scaffold(body: Center(child: CircularProgressIndicator())),
      builder: (book) => book == null
          ? Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.menu_book_outlined, title: 'Book not found'))
          : _BookDetail(book: book),
    );
  }
}

class _BookDetail extends ConsumerWidget {
  const _BookDetail({required this.book});
  final Book book;

  Future<void> _reserve(BuildContext context, WidgetRef ref) async {
    final member = ref.read(memberProvider).value;
    if (member == null) return;
    try {
      await ref.read(repoProvider).reserveBook(book: book, member: member);
      showSnack(book.isAvailable ? 'Reserved! We\'ll hold a copy for you at the desk.' : 'You\'re in the queue. We\'ll notify you when it\'s ready.');
    } catch (e) {
      showSnack(errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final uid = ref.watch(uidProvider);
    final wish = ref.watch(wishlistIdsProvider).value ?? const <String>{};
    final inWishlist = wish.contains(book.id);
    final loans = ref.watch(activeLoansProvider).value ?? const <Loan>[];
    final reservations = ref.watch(reservationsProvider).value ?? const <Reservation>[];
    final hasLoan = loans.any((l) => l.bookId == book.id);
    final openRes = reservations.where((r) => r.bookId == book.id && r.isOpen).firstOrNull;
    final cats = ref.watch(categoriesProvider).value ?? const <BookCategory>[];

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 320,
          actions: [
            IconButton(
              tooltip: inWishlist ? 'Remove from wishlist' : 'Add to wishlist',
              icon: Icon(inWishlist ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: inWishlist ? Colors.redAccent : null),
              onPressed: uid == null ? null : () => ref.read(repoProvider).toggleWishlist(uid, book, !inWishlist),
            ),
            IconButton(
              tooltip: 'Share',
              icon: const Icon(Icons.share_outlined),
              onPressed: () => SharePlus.instance.share(ShareParams(
                text: '${book.title} by ${book.authorLine} — available at Rampur Library\n${AppConfig.siteUrl}/books/${book.slug.isEmpty ? book.id : book.slug}',
                subject: book.title,
              )),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [t.colorScheme.primaryContainer, t.scaffoldBackgroundColor]),
              ),
              alignment: Alignment.bottomCenter,
              padding: const EdgeInsets.only(bottom: 16, top: 90),
              child: BookCover(url: book.coverUrl, title: book.title, width: 150, height: 220, heroTag: 'cover-${book.id}'),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          sliver: SliverList.list(children: [
            Text(book.title, textAlign: TextAlign.center, style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            if (book.subtitle.isNotEmpty) Text(book.subtitle, textAlign: TextAlign.center, style: t.textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(book.authorLine, textAlign: TextAlign.center, style: t.textTheme.titleMedium?.copyWith(color: t.colorScheme.primary)),
            const SizedBox(height: 14),
            Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
              AvailabilityChip(book: book),
              if (book.ratingCount > 0) StatusPill('★ ${book.ratingAvg.toStringAsFixed(1)} (${book.ratingCount})', color: AppColors.accent),
              if (book.shelfLocation.isNotEmpty) StatusPill('Shelf ${book.shelfLocation}', color: t.colorScheme.primary),
            ]),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _Fact('Pages', book.pages?.toString() ?? '—'),
                  _Fact('Language', book.language),
                  _Fact('Year', book.publishedYear?.toString() ?? '—'),
                  _Fact('Copies', '${book.availableCopies}/${book.totalCopies}'),
                ]),
              ),
            ),
            if (book.description.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('About this book', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              _ExpandableText(book.description),
            ],
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final slug in book.categories)
                ActionChip(
                  label: Text(cats.where((c) => c.slug == slug).firstOrNull?.name ?? slug),
                  onPressed: () => context.push('/category/$slug'),
                ),
            ]),
            const SizedBox(height: 16),
            _DetailRow('Publisher', book.publisher),
            _DetailRow('ISBN', book.isbn),
            if (book.ebookUrl.isNotEmpty) _DetailRow('E-book', 'Available online'),
            const SizedBox(height: 24),
            _Reviews(book: book),
          ]),
        ),
      ]),
      bottomSheet: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: BoxDecoration(color: t.colorScheme.surface, border: Border(top: BorderSide(color: t.colorScheme.outlineVariant))),
          child: hasLoan
              ? const FilledButton(onPressed: null, child: Text('You have this book'))
              : openRes != null
                  ? OutlinedButton.icon(
                      onPressed: () => ref.read(repoProvider).cancelReservation(openRes.id),
                      icon: const Icon(Icons.close),
                      label: Text(openRes.status == ReservationStatus.ready ? 'Ready at desk · Cancel hold' : 'In queue · Cancel reservation'),
                    )
                  : FilledButton.icon(
                      onPressed: () => _reserve(context, ref),
                      icon: const Icon(Icons.bookmark_add_outlined),
                      label: Text(book.isAvailable ? 'Reserve for pickup' : 'Join the waitlist'),
                    ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ]);
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(width: 100, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
        Expanded(child: SelectableText(value, style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

class _ExpandableText extends StatefulWidget {
  const _ExpandableText(this.text);
  final String text;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _open = false;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.text, maxLines: _open ? null : 5, overflow: _open ? null : TextOverflow.ellipsis, style: const TextStyle(height: 1.5)),
        if (widget.text.length > 250)
          TextButton(onPressed: () => setState(() => _open = !_open), child: Text(_open ? 'Show less' : 'Read more')),
      ]);
}

class _Reviews extends ConsumerWidget {
  const _Reviews({required this.book});
  final Book book;

  Future<void> _write(BuildContext context, WidgetRef ref, Review? mine) async {
    final member = ref.read(memberProvider).value;
    if (member == null) return;
    var rating = mine?.rating ?? 5;
    final comment = TextEditingController(text: mine?.comment ?? '');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Rate this book', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  iconSize: 38,
                  onPressed: () => setSheet(() => rating = i),
                  icon: Icon(i <= rating ? Icons.star_rounded : Icons.star_outline_rounded, color: AppColors.accent),
                ),
            ]),
            TextField(controller: comment, maxLines: 4, maxLength: 1000, decoration: const InputDecoration(hintText: 'What did you think? (optional)')),
            const SizedBox(height: 8),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Post review')),
          ]),
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(repoProvider).submitReview(bookId: book.id, uid: member.id, userName: member.name, rating: rating, comment: comment.text);
      showSnack('Thanks for your review!');
    } catch (e) {
      showSnack(errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(uidProvider);
    final reviews = ref.watch(reviewsProvider(book.id)).value ?? const <Review>[];
    final mine = reviews.where((r) => r.userId == uid).firstOrNull;
    final t = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('Reviews', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
        TextButton.icon(onPressed: () => _write(context, ref, mine), icon: const Icon(Icons.rate_review_outlined), label: Text(mine == null ? 'Write' : 'Edit yours')),
      ]),
      if (reviews.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No reviews yet — be the first!')),
      for (final r in reviews.take(20))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(r.userName, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text('★' * r.rating, style: const TextStyle(color: AppColors.accent)),
              const Spacer(),
              Text(timeAgo(r.createdAt), style: t.textTheme.bodySmall),
            ]),
            if (r.comment.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(r.comment)),
          ]),
        ),
    ]);
  }
}
