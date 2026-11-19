import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:library_core/library_core.dart';

import '../providers.dart';
import '../widgets.dart';

final _allBooksProvider = StreamProvider.family<List<Book>, String>(
  (ref, category) => ref.watch(repoProvider).watchBooks(category: category.isEmpty ? null : category, limit: 300, orderBy: 'title'),
);

class BooksPage extends ConsumerStatefulWidget {
  const BooksPage({super.key});

  @override
  ConsumerState<BooksPage> createState() => _BooksPageState();
}

class _BooksPageState extends ConsumerState<BooksPage> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<Book>? _results;
  String _category = '';

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (q.trim().isEmpty) {
        setState(() => _results = null);
        return;
      }
      final r = await ref.read(repoProvider).searchBooks(q, limit: 100);
      if (mounted) setState(() => _results = r);
    });
  }

  Future<void> _edit([Book? book]) async {
    await showDialog<void>(context: context, barrierDismissible: false, builder: (_) => BookFormDialog(book: book));
    if (_search.text.isNotEmpty) _onSearch(_search.text);
  }

  Future<void> _import() async {
    final text = await pickTextFile();
    if (text == null) return;
    final rows = parseCsv(text);
    if (rows.length < 2) {
      toast('The file has no data rows.', error: true);
      return;
    }
    final header = rows.first.map((h) => h.trim().toLowerCase()).toList();
    int col(String name) => header.indexOf(name);
    if (col('title') < 0) {
      toast('CSV must have a "title" column.', error: true);
      return;
    }
    String cell(List<String> r, String name) {
      final i = col(name);
      return i >= 0 && i < r.length ? r[i].trim() : '';
    }

    final repo = ref.read(repoProvider);
    var ok = 0, failed = 0;
    for (final r in rows.skip(1)) {
      final title = cell(r, 'title');
      if (title.isEmpty) continue;
      final copies = int.tryParse(cell(r, 'copies')) ?? 1;
      try {
        await repo.saveBook(Book(
          id: '',
          title: title,
          subtitle: cell(r, 'subtitle'),
          authors: cell(r, 'authors').split(RegExp(r'[;|]')).map((a) => a.trim()).where((a) => a.isNotEmpty).toList(),
          isbn: cell(r, 'isbn'),
          publisher: cell(r, 'publisher'),
          publishedYear: int.tryParse(cell(r, 'year')),
          categories: cell(r, 'categories').split(RegExp(r'[;|]')).map((c) => slugify(c.trim())).where((c) => c.isNotEmpty && c != 'book').toList(),
          language: cell(r, 'language').isEmpty ? 'English' : cell(r, 'language'),
          description: cell(r, 'description'),
          coverUrl: cell(r, 'coverurl'),
          pages: int.tryParse(cell(r, 'pages')),
          totalCopies: copies,
          availableCopies: copies,
          shelfLocation: cell(r, 'shelf'),
        ));
        ok++;
      } catch (_) {
        failed++;
      }
    }
    toast('Imported $ok book(s)${failed > 0 ? ', $failed failed' : ''}.', error: failed > 0 && ok == 0);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(categoriesProvider).value ?? const <BookCategory>[];
    final listValue = ref.watch(_allBooksProvider(_category));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader('Books', subtitle: 'Manage the catalogue', actions: [
        OutlinedButton.icon(
          onPressed: () => downloadText('books-import-template.csv',
              toCsv([
                ['title', 'subtitle', 'authors', 'isbn', 'publisher', 'year', 'categories', 'language', 'copies', 'shelf', 'pages', 'description', 'coverUrl'],
                ['Wings of Fire', 'An Autobiography', 'A. P. J. Abdul Kalam', '9788173711466', 'Universities Press', '1999', 'biography;inspiration', 'English', '3', 'B-12', '196', '', ''],
              ])),
          icon: const Icon(Icons.download_outlined),
          label: const Text('CSV template'),
        ),
        OutlinedButton.icon(onPressed: _import, icon: const Icon(Icons.upload_file), label: const Text('Import CSV')),
        FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Add book')),
      ]),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: 360,
            child: TextField(
              controller: _search,
              onChanged: _onSearch,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search title, author, ISBN'),
            ),
          ),
          SizedBox(
            width: 240,
            child: DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                const DropdownMenuItem(value: '', child: Text('All categories')),
                for (final c in cats) DropdownMenuItem(value: c.slug, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _category = v ?? ''),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Panel(
            padding: EdgeInsets.zero,
            child: _results != null
                ? _table(_results!)
                : AsyncBody(value: listValue, builder: (books) => _table(books)),
          ),
        ),
      ),
    ]);
  }

  Widget _table(List<Book> books) {
    if (books.isEmpty) return const EmptyHint('No books found. Add one or import a CSV.', icon: Icons.menu_book_outlined);
    return WideTable(
      columns: const [
        DataColumn(label: Text('Book')),
        DataColumn(label: Text('ISBN')),
        DataColumn(label: Text('Shelf')),
        DataColumn(label: Text('Copies'), numeric: true),
        DataColumn(label: Text('Rating')),
        DataColumn(label: Text('Featured')),
        DataColumn(label: Text('')),
      ],
      rows: [
        for (final b in books)
          DataRow(cells: [
            DataCell(
              Row(children: [
                Thumb(b.coverUrl),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(b.authorLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
              ]),
              onTap: () => _edit(b),
            ),
            DataCell(SelectableText(b.isbn)),
            DataCell(Text(b.shelfLocation)),
            DataCell(Pill('${b.availableCopies}/${b.totalCopies}', color: b.isAvailable ? okColor : warnColor)),
            DataCell(Text(b.ratingCount == 0 ? '—' : '★ ${b.ratingAvg.toStringAsFixed(1)} (${b.ratingCount})')),
            DataCell(Switch(
              value: b.featured,
              onChanged: (v) => guard(() => ref.read(repoProvider).saveBook(b.copyWith(featured: v))),
            )),
            DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(b)),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline, color: dangerColor),
                onPressed: () async {
                  if (await confirm(context, 'Delete "${b.title}"?', message: 'This cannot be undone.', ok: 'Delete', danger: true)) {
                    await guard(() => ref.read(repoProvider).deleteBook(b.id), success: 'Book deleted');
                    if (_search.text.isNotEmpty) _onSearch(_search.text);
                  }
                },
              ),
            ])),
          ]),
      ],
    );
  }
}

// ===========================================================================
// Add / edit book dialog with ISBN lookup
// ===========================================================================

class BookFormDialog extends ConsumerStatefulWidget {
  const BookFormDialog({super.key, this.book});
  final Book? book;

  @override
  ConsumerState<BookFormDialog> createState() => _BookFormDialogState();
}

class _BookFormDialogState extends ConsumerState<BookFormDialog> {
  final _form = GlobalKey<FormState>();
  late final Book _b = widget.book ?? Book(id: '', title: '');
  late final _title = TextEditingController(text: _b.title);
  late final _subtitle = TextEditingController(text: _b.subtitle);
  late final _authors = TextEditingController(text: _b.authors.join(', '));
  late final _isbn = TextEditingController(text: _b.isbn);
  late final _publisher = TextEditingController(text: _b.publisher);
  late final _year = TextEditingController(text: _b.publishedYear?.toString() ?? '');
  late final _pages = TextEditingController(text: _b.pages?.toString() ?? '');
  late final _copies = TextEditingController(text: _b.totalCopies.toString());
  late final _shelf = TextEditingController(text: _b.shelfLocation);
  late final _description = TextEditingController(text: _b.description);
  late final _tags = TextEditingController(text: _b.tags.join(', '));
  late final _coverUrl = TextEditingController(text: _b.coverUrl);
  late final _ebook = TextEditingController(text: _b.ebookUrl);
  late final _price = TextEditingController(text: _b.price?.toString() ?? '');
  late String _language = _b.language;
  late bool _featured = _b.featured;
  late final Set<String> _cats = {..._b.categories};
  Uint8List? _coverBytes;
  bool _saving = false;
  bool _looking = false;

  static const _languages = ['English', 'Hindi', 'Urdu', 'Punjabi', 'Sanskrit', 'Bengali', 'Tamil', 'Telugu', 'Marathi', 'Gujarati', 'Other'];

  Future<void> _lookup() async {
    final isbn = _isbn.text.replaceAll(RegExp(r'[^0-9Xx]'), '');
    if (isbn.length < 10) {
      toast('Enter a 10 or 13 digit ISBN first.', error: true);
      return;
    }
    setState(() => _looking = true);
    try {
      final existing = await ref.read(repoProvider).findByIsbn(isbn);
      if (existing != null && existing.id != _b.id) {
        toast('"${existing.title}" already has this ISBN — edit that book to add copies.', error: true);
      }
      final res = await http.get(Uri.parse('https://www.googleapis.com/books/v1/volumes?q=isbn:$isbn'));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final items = (data['items'] as List?) ?? const [];
      if (items.isEmpty) {
        _coverUrl.text = _coverUrl.text.isEmpty ? 'https://covers.openlibrary.org/b/isbn/$isbn-L.jpg' : _coverUrl.text;
        toast('No details found online. Fill the form manually.');
        return;
      }
      final v = (items.first as Map<String, dynamic>)['volumeInfo'] as Map<String, dynamic>;
      setState(() {
        _title.text = v['title'] as String? ?? _title.text;
        _subtitle.text = v['subtitle'] as String? ?? _subtitle.text;
        _authors.text = ((v['authors'] as List?) ?? const []).join(', ');
        _publisher.text = v['publisher'] as String? ?? _publisher.text;
        final date = v['publishedDate'] as String? ?? '';
        if (date.length >= 4) _year.text = date.substring(0, 4);
        if (v['pageCount'] != null) _pages.text = '${v['pageCount']}';
        _description.text = (v['description'] as String? ?? _description.text).replaceAll(RegExp(r'<[^>]+>'), '');
        final lang = v['language'] as String? ?? '';
        _language = switch (lang) { 'hi' => 'Hindi', 'ur' => 'Urdu', 'pa' => 'Punjabi', 'en' => 'English', _ => _language };
        final img = (v['imageLinks'] as Map?)?['thumbnail'] as String?;
        _coverUrl.text = img != null
            ? img.replaceFirst('http://', 'https://').replaceAll('&edge=curl', '').replaceAll('zoom=1', 'zoom=2')
            : 'https://covers.openlibrary.org/b/isbn/$isbn-L.jpg';
        final gCats = ((v['categories'] as List?) ?? const []).map((c) => '$c'.toLowerCase());
        final known = ref.read(categoriesProvider).value ?? const <BookCategory>[];
        for (final c in known) {
          if (gCats.any((g) => g.contains(c.name.toLowerCase()) || g.contains(c.slug))) _cats.add(c.slug);
        }
      });
      toast('Details filled from Google Books.');
    } catch (e) {
      toast('Lookup failed: ${errText(e)}', error: true);
    } finally {
      if (mounted) setState(() => _looking = false);
    }
  }

  Future<void> _pickCover() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    setState(() => _coverBytes = bytes);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final book = Book(
      id: _b.id,
      title: _title.text.trim(),
      subtitle: _subtitle.text.trim(),
      authors: _authors.text.split(',').map((a) => a.trim()).where((a) => a.isNotEmpty).toList(),
      isbn: _isbn.text.trim(),
      publisher: _publisher.text.trim(),
      publishedYear: int.tryParse(_year.text.trim()),
      categories: _cats.toList(),
      language: _language,
      description: _description.text.trim(),
      coverUrl: _coverUrl.text.trim(),
      pages: int.tryParse(_pages.text.trim()),
      totalCopies: int.tryParse(_copies.text.trim()) ?? 1,
      availableCopies: _b.availableCopies,
      shelfLocation: _shelf.text.trim(),
      tags: _tags.text.split(',').map((a) => a.trim()).where((a) => a.isNotEmpty).toList(),
      featured: _featured,
      ebookUrl: _ebook.text.trim(),
      price: double.tryParse(_price.text.trim()),
    );
    final ok = await guard(() => ref.read(repoProvider).saveBook(book, coverBytes: _coverBytes), success: _b.id.isEmpty ? 'Book added' : 'Book updated');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  Widget _field(TextEditingController c, String label, {String? Function(String?)? validator, int maxLines = 1, TextInputType? type, double width = 260, List<TextInputFormatter>? formatters}) =>
      SizedBox(
        width: width,
        child: TextFormField(
          controller: c,
          maxLines: maxLines,
          keyboardType: type,
          inputFormatters: formatters,
          decoration: InputDecoration(labelText: label),
          validator: validator,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(categoriesProvider).value ?? const <BookCategory>[];
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return AlertDialog(
      title: Text(_b.id.isEmpty ? 'Add book' : 'Edit book'),
      content: SizedBox(
        width: 860,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 150,
                    height: 220,
                    child: _coverBytes != null
                        ? Image.memory(_coverBytes!, fit: BoxFit.cover)
                        : _coverUrl.text.isNotEmpty
                            ? Image.network(_coverUrl.text, fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black12, child: Icon(Icons.broken_image)))
                            : const ColoredBox(color: Colors.black12, child: Icon(Icons.image_outlined, size: 40)),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(onPressed: _pickCover, icon: const Icon(Icons.upload), label: const Text('Upload cover')),
              ]),
              const SizedBox(width: 24),
              Expanded(
                child: Wrap(spacing: 14, runSpacing: 14, children: [
                  SizedBox(
                    width: 534,
                    child: Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: _isbn,
                          decoration: const InputDecoration(labelText: 'ISBN', helperText: 'Enter ISBN and click Lookup to auto-fill'),
                          validator: (v) => (v ?? '').trim().isEmpty || isValidIsbn(v!) ? null : 'Invalid ISBN checksum',
                          onFieldSubmitted: (_) => _lookup(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.tonalIcon(
                        onPressed: _looking ? null : _lookup,
                        icon: _looking ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.travel_explore),
                        label: const Text('Lookup'),
                      ),
                    ]),
                  ),
                  _field(_title, 'Title *', width: 534, validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null),
                  _field(_subtitle, 'Subtitle', width: 534),
                  _field(_authors, 'Authors (comma separated)', width: 534),
                  _field(_publisher, 'Publisher'),
                  _field(_year, 'Year', width: 120, formatters: digits),
                  _field(_pages, 'Pages', width: 126, formatters: digits),
                  SizedBox(
                    width: 260,
                    child: DropdownButtonFormField<String>(
                      initialValue: _languages.contains(_language) ? _language : 'Other',
                      decoration: const InputDecoration(labelText: 'Language'),
                      items: [for (final l in _languages) DropdownMenuItem(value: l, child: Text(l))],
                      onChanged: (v) => _language = v ?? 'English',
                    ),
                  ),
                  _field(_copies, 'Total copies *', width: 120, formatters: digits,
                      validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1 ? 'Min 1' : null),
                  _field(_shelf, 'Shelf location', width: 126),
                  _field(_price, 'Price (₹)', width: 120, type: TextInputType.number),
                  _field(_coverUrl, 'Cover image URL', width: 400),
                  _field(_ebook, 'E-book / PDF link (optional)', width: 534),
                  _field(_tags, 'Tags (comma separated)', width: 534),
                  _field(_description, 'Description', width: 534, maxLines: 5),
                  SizedBox(
                    width: 534,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Categories', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      if (cats.isEmpty) const Text('Create categories on the Categories page first.'),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final c in cats)
                          FilterChip(
                            label: Text(c.name),
                            selected: _cats.contains(c.slug),
                            onSelected: (v) => setState(() => v ? _cats.add(c.slug) : _cats.remove(c.slug)),
                          ),
                      ]),
                    ]),
                  ),
                  SizedBox(
                    width: 534,
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Featured on the home screen'),
                      value: _featured,
                      onChanged: (v) => setState(() => _featured = v),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save')),
      ],
    );
  }
}

// ===========================================================================
// Categories
// ===========================================================================

class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, [BookCategory? c]) async {
    final name = TextEditingController(text: c?.name ?? '');
    final icon = TextEditingController(text: c?.icon ?? '');
    final order = TextEditingController(text: '${c?.order ?? 0}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(c == null ? 'New category' : 'Edit category'),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(controller: icon, decoration: const InputDecoration(labelText: 'Emoji icon (e.g. 📖)')),
            const SizedBox(height: 12),
            TextField(controller: order, decoration: const InputDecoration(labelText: 'Sort order'), keyboardType: TextInputType.number),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(d, name.text.trim().isNotEmpty), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      await guard(
        () => ref.read(repoProvider).saveCategory(id: c?.id, name: name.text.trim(), icon: icon.text.trim(), order: int.tryParse(order.text) ?? 0),
        success: 'Category saved',
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(children: [
      PageHeader('Categories', subtitle: 'Genres shown in the app and on the website', actions: [
        FilledButton.icon(onPressed: () => _edit(context, ref), icon: const Icon(Icons.add), label: const Text('New category')),
      ]),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Panel(
          padding: EdgeInsets.zero,
          child: AsyncBody(
            value: ref.watch(categoriesProvider),
            builder: (cats) => cats.isEmpty
                ? const EmptyHint('No categories yet')
                : Column(children: [
                    for (final c in cats)
                      ListTile(
                        leading: Text(c.icon.isEmpty ? '📚' : c.icon, style: const TextStyle(fontSize: 24)),
                        title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('/${c.slug} · ${c.bookCount} books · order ${c.order}'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(context, ref, c)),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: dangerColor),
                            onPressed: () async {
                              if (await confirm(context, 'Delete "${c.name}"?', message: 'Books keep their tag but the category disappears from menus.', danger: true, ok: 'Delete')) {
                                await guard(() => ref.read(repoProvider).deleteCategory(c.id));
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
