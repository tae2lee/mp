import 'dart:async';

import 'package:flutter/material.dart';

import '../library_colors.dart';
import '../library_repository.dart';
import '../models.dart';
import '../sample_data.dart' show popularKeywords;
import '../widgets.dart';
import 'book_detail_screen.dart';

enum _Sort {
  relevance('정확도순'),
  newest('최신순'),
  title('서명순');

  const _Sort(this.label);
  final String label;
}

/// 자료 검색 (Figma 02). 결과 목록에서 바로 대출 가능 여부와 위치를 보여 준다.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initialType, this.focusNode, this.onBack});
  final BookType? initialType;
  final FocusNode? focusNode;
  final VoidCallback? onBack;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final repo = LibraryRepository.instance;
  final _controller = TextEditingController();
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  Timer? _debounce;
  bool _ebookOnly = false;
  bool _availableOnly = false;
  Campus? _campus;
  _Sort _sort = _Sort.relevance;
  Future<List<Book>>? _results;

  @override
  void initState() {
    super.initState();
    _ebookOnly = widget.initialType == BookType.ebook;
    if (_ebookOnly) _run();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  bool get _hasQuery => _controller.text.trim().isNotEmpty || _ebookOnly;

  void _run() {
    setState(() {
      _results = _hasQuery
          ? repo
              .search(_controller.text.trim(), type: _ebookOnly ? BookType.ebook : null, availableOnly: _availableOnly, campus: _campus)
              .then(_sorted)
          : null;
    });
  }

  List<Book> _sorted(List<Book> list) => switch (_sort) {
        _Sort.relevance => list,
        _Sort.newest => [...list]..sort((a, b) => b.year.compareTo(a.year)),
        _Sort.title => [...list]..sort((a, b) => a.title.compareTo(b.title)),
      };

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _run);
  }

  void _searchFor(String q) {
    _controller.text = q;
    repo.addRecent(q);
    _focus.unfocus();
    _run();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LC.bg,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        LibHeader(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 16, 12),
            child: Row(children: [
              IconBox('chev_left', tooltip: '뒤로', onTap: widget.onBack ?? () => Navigator.maybePop(context)),
              const SizedBox(width: 6),
              Expanded(child: _searchField()),
            ]),
          ),
          _filters(),
        ]),
        Expanded(child: _results == null ? _suggestions(context) : _resultList(context)),
      ]),
    );
  }

  Widget _searchField() => Box(
        height: 44,
        color: LC.bg,
        radius: 12,
        padding: const EdgeInsets.only(left: 14, right: 12),
        child: Row(children: [
          const Ico('search_18', size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              autofocus: widget.focusNode == null && widget.initialType == null,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: (q) {
                if (q.trim().isNotEmpty) repo.addRecent(q.trim());
                _run();
              },
              style: ts(15, w5, LC.ink, ls: -0.15),
              cursorColor: LC.primary,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: '도서명, 저자, ISBN 검색',
                hintStyle: ts(15, w4, LC.mute, ls: -0.15),
              ),
            ),
          ),
          if (_controller.text.isNotEmpty) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: '지우기',
              child: Box(
                width: 18,
                height: 18,
                radius: 9,
                color: LC.mute,
                alignment: Alignment.center,
                onTap: () {
                  _controller.clear();
                  _run();
                },
                child: const Ico('x_12_white', size: 12),
              ),
            ),
          ],
        ]),
      );

  Widget _filters() {
    Widget chip(String label, bool on, VoidCallback onTap) => Box(
          color: on ? LC.ink : LC.white,
          radius: 18,
          border: on ? null : const BorderSide(color: LC.line),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          onTap: onTap,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (on) ...[const Ico('check_14', size: 14), const SizedBox(width: 4)],
            Text(label, style: ts(13, on ? w7 : w5, on ? LC.white : LC.sub)),
          ]),
        );
    return SizedBox(
      height: 32.2 + 14, // 칩 높이 + 아래 여백 14
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          chip('대출가능만', _availableOnly, () {
            _availableOnly = !_availableOnly;
            _run();
          }),
          for (final c in Campus.values) ...[
            const SizedBox(width: 8),
            chip(c.short, _campus == c, () {
              _campus = _campus == c ? null : c;
              _run();
            }),
          ],
          const SizedBox(width: 8),
          chip('전자자료', _ebookOnly, () {
            _ebookOnly = !_ebookOnly;
            _run();
          }),
        ],
      ),
    );
  }

  Widget _suggestions(BuildContext context) => ListenableBuilder(
        listenable: repo,
        builder: (context, _) => ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 24), children: [
          Text('인기 검색어', style: ts(15, w7, LC.ink, ls: -0.15)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (i, k) in popularKeywords.indexed)
              Box(
                color: LC.white,
                radius: 18,
                border: const BorderSide(color: LC.line),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                onTap: () => _searchFor(k),
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: '${i + 1}  ', style: ts(13, w7, LC.primary)),
                  TextSpan(text: k, style: ts(13, w5, LC.ink)),
                ])),
              ),
          ]),
          if (repo.recentSearches.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('최근 검색어', style: ts(15, w7, LC.ink, ls: -0.15)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final k in repo.recentSearches)
                Box(
                  color: LC.white,
                  radius: 18,
                  border: const BorderSide(color: LC.line),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  onTap: () => _searchFor(k),
                  child: Text(k, style: ts(13, w5, LC.sub)),
                ),
            ]),
          ],
        ]),
      );

  Widget _resultList(BuildContext context) => FutureBuilder<List<Book>>(
        future: _results,
        builder: (context, snap) {
          if (snap.hasError) return EmptyState(icon: Icons.error_outline, title: '검색하지 못했어요', message: '${snap.error}', onRetry: _run);
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: LC.primary, strokeWidth: 2.5));
          final items = snap.data!;
          if (items.isEmpty) {
            return EmptyState(icon: Icons.search_off, title: '"${_controller.text}" 검색 결과가 없어요', message: '철자를 확인하거나 필터를 풀어 보세요.');
          }
          final sub = ts(13, w5, LC.sub, ls: -0.13);
          return ListView(padding: EdgeInsets.zero, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Row(children: [
                Expanded(
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: '검색결과 ', style: sub),
                    TextSpan(text: '${items.length}', style: ts(13, w7, LC.primary)),
                    TextSpan(text: '건', style: sub),
                  ])),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    _sort = _Sort.values[(_sort.index + 1) % _Sort.values.length];
                    _run();
                  },
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(_sort.label, style: ts(13, w7, LC.ink, ls: -0.13)),
                    const SizedBox(width: 2),
                    const Ico('chev_down_16', size: 16),
                  ]),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Gap(10, children: [
                for (final b in items)
                  BookItem(book: b, campus: _campus, onTap: () => pushLibrary<void>(context, BookDetailScreen(book: b))),
              ]),
            ),
          ]);
        },
      );
}
