import 'dart:async';

import 'package:flutter/material.dart';

import '../library_repository.dart';
import '../models.dart';
import '../sample_data.dart' show popularKeywords;
import '../widgets.dart';
import 'book_detail_screen.dart';

/// 자료 검색 (Figma 02). 결과 목록에서 바로 대출 가능 여부와 위치를 보여 준다.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initialType});
  final BookType? initialType;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final repo = LibraryRepository.instance;
  final _controller = TextEditingController();
  Timer? _debounce;
  BookType? _type;
  bool _availableOnly = false;
  Campus? _campus;
  Future<List<Book>>? _results;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    if (_type != null) _run();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  bool get _hasQuery => _controller.text.trim().isNotEmpty || _type == BookType.ebook;

  void _run() {
    setState(() {
      _results = _hasQuery ? repo.search(_controller.text.trim(), type: _type, availableOnly: _availableOnly, campus: _campus) : null;
    });
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _run);
  }

  void _searchFor(String q) {
    _controller.text = q;
    repo.addRecent(q);
    _run();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: widget.initialType == null,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: (q) {
            if (q.trim().isNotEmpty) repo.addRecent(q.trim());
            _run();
          },
          decoration: InputDecoration(
            hintText: '도서명, 저자, 주제',
            filled: true,
            fillColor: cs.surfaceContainerHigh,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(tooltip: '지우기', icon: const Icon(Icons.close), onPressed: () {
                    _controller.clear();
                    _run();
                  }),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        actions: const [SizedBox(width: 12)],
      ),
      body: Column(children: [
        // 필터
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (final (t, label) in [(null, '통합검색'), (BookType.book, '소장자료'), (BookType.ebook, '전자자료')])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(label: Text(label), selected: _type == t, onSelected: (_) {
                    _type = t;
                    _run();
                  }),
                ),
              const VerticalDivider(width: 16, indent: 8, endIndent: 8),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(label: const Text('대출가능만'), selected: _availableOnly, onSelected: (v) {
                  _availableOnly = v;
                  _run();
                }),
              ),
              for (final c in Campus.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(label: Text(c.short), selected: _campus == c, onSelected: (v) {
                    _campus = v ? c : null;
                    _run();
                  }),
                ),
            ],
          ),
        ),
        const OfflineBanner(),
        Expanded(child: _results == null ? _suggestions(context) : _resultList(context)),
      ]),
    );
  }

  Widget _suggestions(BuildContext context) {
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) => ListView(padding: const EdgeInsets.all(16), children: [
        Text('인기 검색어', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (i, k) in popularKeywords.indexed) ActionChip(label: Text('${i + 1}  $k'), onPressed: () => _searchFor(k)),
        ]),
        if (repo.recentSearches.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('최근 검색어', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final k in repo.recentSearches) ActionChip(label: Text(k), onPressed: () => _searchFor(k)),
          ]),
        ],
        const SizedBox(height: 24),
        Text('샘플 검색은 서명·저자·주제에서 찾아요. 예: 플러터, 히가시노, 데이터베이스',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]),
    );
  }

  Widget _resultList(BuildContext context) {
    return FutureBuilder<List<Book>>(
      future: _results,
      builder: (context, snap) {
        if (snap.hasError) return EmptyState(icon: Icons.error_outline, title: '검색하지 못했어요', message: '${snap.error}', onRetry: _run);
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final items = snap.data!;
        if (items.isEmpty) {
          return EmptyState(icon: Icons.search_off, title: '"${_controller.text}" 검색 결과가 없어요', message: '철자를 확인하거나 필터를 풀어 보세요.');
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: items.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            if (i == 0) return Text('검색결과 ${items.length}건', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant));
            final b = items[i - 1];
            return BookTile(
              book: b,
              campus: _campus,
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => BookDetailScreen(book: b))),
            );
          },
        );
      },
    );
  }
}
