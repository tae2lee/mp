import 'package:flutter/material.dart';

import '../library_repository.dart';
import '../links.dart';
import '../models.dart';
import '../widgets.dart';

/// 도서 상세 (Figma 03): 캠퍼스별 소장 정보, 예약, 서가 위치(청구기호 크게 보기)
class BookDetailScreen extends StatelessWidget {
  const BookDetailScreen({super.key, required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    final repo = LibraryRepository.instance;
    final cs = Theme.of(context).colorScheme;
    final allLoaned = book.holdings.isNotEmpty && book.holdings.every((h) => h.status == HoldingStatus.loaned);
    final firstAvailable = book.holdings.where((h) => h.status == HoldingStatus.available).firstOrNull;

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final fav = repo.favorites.contains(book.id);
        return Scaffold(
          appBar: AppBar(
            title: const Text('도서 상세'),
            actions: [
              IconButton(
                tooltip: fav ? '관심도서에서 빼기' : '관심도서에 담기',
                isSelected: fav,
                icon: const Icon(Icons.star_border),
                selectedIcon: const Icon(Icons.star),
                onPressed: () => repo.toggleFavorite(book.id),
              ),
            ],
          ),
          body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            Container(
              color: cs.surface,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(children: [
                BookCover(book, width: 124),
                const SizedBox(height: 14),
                StatusBadge.holding(context, book.statusFor(null)),
                const SizedBox(height: 10),
                Text(book.title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('${book.author} · ${book.year}', style: TextStyle(color: cs.onSurfaceVariant)),
              ]),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    if (book.holdings.isNotEmpty) _kv(context, '청구기호', book.holdings.first.callNo),
                    _kv(context, '자료유형', book.type == BookType.ebook ? '전자책' : '단행본'),
                    _kv(context, '주제', book.subject),
                    _kv(context, '발행년', '${book.year}'),
                  ]),
                ),
              ),
            ),
            if (book.type == BookType.ebook)
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(onPressed: () => openExternal(context, libraryHome), icon: const Icon(Icons.open_in_new), label: const Text('전자책 열람하기')),
              )
            else ...[
              SectionHeader('소장 정보 (${book.holdings.length}권)'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Column(children: [
                    for (final (i, h) in book.holdings.indexed) ...[
                      if (i > 0) const Divider(indent: 16, endIndent: 16),
                      ListTile(
                        title: Row(children: [
                          Text(h.campus.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(width: 6),
                          StatusBadge.holding(context, h.status),
                        ]),
                        subtitle: Text('${h.location} · ${h.callNo}${h.due != null ? ' · 반납예정 ${mmdd(h.due!)}' : ''}'),
                        trailing: switch (h.status) {
                          HoldingStatus.loaned => FilledButton.tonal(onPressed: () => _reserve(context), child: const Text('예약')),
                          HoldingStatus.available => OutlinedButton(onPressed: () => showCallNumber(context, h), child: const Text('위치')),
                          HoldingStatus.reference => null,
                        },
                      ),
                    ],
                  ]),
                ),
              ),
            ],
          ]),
          bottomNavigationBar: book.type == BookType.ebook
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(children: [
                      OutlinedButton.icon(
                        onPressed: () => repo.toggleFavorite(book.id),
                        icon: Icon(fav ? Icons.star : Icons.star_border),
                        label: const Text('관심도서'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: allLoaned
                            ? FilledButton(onPressed: () => _reserve(context), child: const Text('대출 예약하기'))
                            : FilledButton.icon(
                                onPressed: firstAvailable == null ? null : () => showCallNumber(context, firstAvailable),
                                icon: const Icon(Icons.place_outlined),
                                label: const Text('서가 위치 안내'),
                              ),
                      ),
                    ]),
                  ),
                ),
        );
      },
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 76, child: Text(k, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w500))),
        ]),
      );

  void _reserve(BuildContext context) => showMessage(context, '예약을 신청했어요. 반납되면 알려드릴게요 (샘플)');
}

/// 서가에서 찾기 쉽게 청구기호를 크게 보여 준다
void showCallNumber(BuildContext context, Holding h) {
  final cs = Theme.of(context).colorScheme;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(h.campus.label, style: TextStyle(color: cs.onSurfaceVariant)),
        Text(h.location, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            Text('청구기호', style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(h.callNo, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          ]),
        ),
        const SizedBox(height: 12),
        Text('서가 옆면의 청구기호 범위를 보고 찾아가세요. 찾지 못하면 자료실 데스크에 이 화면을 보여 주세요.',
            style: TextStyle(color: cs.onSurfaceVariant)),
      ]),
    ),
  );
}
