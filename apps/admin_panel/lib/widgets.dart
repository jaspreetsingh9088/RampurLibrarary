import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:library_core/library_core.dart';
import 'package:web/web.dart' as web;

final messengerKey = GlobalKey<ScaffoldMessengerState>();

const brandPrimary = Color(0xFF1E4D6B);
const brandAccent = Color(0xFFE0A526);
const okColor = Color(0xFF2E7D32);
const warnColor = Color(0xFFEF6C00);
const dangerColor = Color(0xFFC62828);

void toast(String msg, {bool error = false}) {
  messengerKey.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, width: 420, backgroundColor: error ? dangerColor : null));
}

String errText(Object e) {
  if (e is LibraryException) return e.message;
  return e.toString().replaceFirst('Exception: ', '').replaceFirst(RegExp(r'^\[[^\]]+\]\s*'), '');
}

/// Run an async action with error toast; returns true on success.
Future<bool> guard(Future<void> Function() action, {String? success}) async {
  try {
    await action();
    if (success != null) toast(success);
    return true;
  } catch (e) {
    toast(errText(e), error: true);
    return false;
  }
}

Future<bool> confirm(BuildContext context, String title, {String? message, String ok = 'Confirm', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: dangerColor) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r == true;
}

/// Trigger a browser download of a text file (CSV reports).
void downloadText(String filename, String content, {String mime = 'text/csv;charset=utf-8'}) {
  final bytes = utf8.encode('﻿$content'); // BOM so Excel opens UTF-8 correctly
  final blob = web.Blob(<JSAny>[bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body?.append(a);
  a.click();
  a.remove();
  web.URL.revokeObjectURL(url);
}

/// Opens the browser file chooser and returns the chosen file's text (CSV imports).
Future<String?> pickTextFile({String accept = '.csv,text/csv'}) {
  final completer = Completer<String?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = accept;
  input.onchange = ((web.Event _) {
    final file = input.files?.item(0);
    if (file == null) {
      completer.complete(null);
      return;
    }
    file.text().toDart.then((t) => completer.complete(t.toDart), onError: (Object e) => completer.completeError(e));
  }).toJS;
  input.click();
  return completer.future;
}

class PageHeader extends StatelessWidget {
  const PageHeader(this.title, {super.key, this.subtitle, this.actions = const []});
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 12,
        spacing: 12,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            if (subtitle != null) Text(subtitle!, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          ]),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ),
    );
  }
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.title, this.trailing, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
            child: Row(children: [
              Expanded(child: Text(title!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
              ?trailing,
            ]),
          ),
        Padding(padding: padding, child: child),
      ]),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value, required this.icon, this.color = brandPrimary, this.onTap});
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.color = brandPrimary});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
      );
}

Color loanColor(LoanStatus s) => switch (s) {
      LoanStatus.issued => brandPrimary,
      LoanStatus.overdue => dangerColor,
      LoanStatus.returned => okColor,
      LoanStatus.lost => Colors.grey,
    };

Color reservationColor(ReservationStatus s) => switch (s) {
      ReservationStatus.pending => warnColor,
      ReservationStatus.ready => okColor,
      ReservationStatus.fulfilled => brandPrimary,
      ReservationStatus.cancelled || ReservationStatus.expired => Colors.grey,
    };

class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({super.key, required this.value, required this.builder});
  final AsyncValue<T> value;
  final Widget Function(T) builder;

  @override
  Widget build(BuildContext context) => value.when(
        data: builder,
        loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('Error: ${errText(e)}', style: const TextStyle(color: dangerColor)))),
      );
}

class EmptyHint extends StatelessWidget {
  const EmptyHint(this.text, {super.key, this.icon = Icons.inbox_outlined});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 42, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 10),
            Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ),
      );
}

class Thumb extends StatelessWidget {
  const Thumb(this.url, {super.key, this.width = 40, this.height = 56});
  final String url;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ph = Container(width: width, height: height, color: Theme.of(context).colorScheme.surfaceContainerHighest, child: const Icon(Icons.menu_book, size: 18));
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: url.isEmpty ? ph : Image.network(url, width: width, height: height, fit: BoxFit.cover, errorBuilder: (_, _, _) => ph),
    );
  }
}

/// Horizontally scrollable DataTable that fills the available width.
class WideTable extends StatelessWidget {
  const WideTable({super.key, required this.columns, required this.rows});
  final List<DataColumn> columns;
  final List<DataRow> rows;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: c.maxWidth),
          child: DataTable(
            showCheckboxColumn: false,
            headingRowColor: WidgetStateProperty.all(Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)),
            dataRowMinHeight: 52,
            dataRowMaxHeight: 72,
            columns: columns,
            rows: rows,
          ),
        ),
      ),
    );
  }
}
