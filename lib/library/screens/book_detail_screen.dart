import 'package:flutter/material.dart';

import '../library_colors.dart';
import '../library_repository.dart';
import '../links.dart';
import '../models.dart';
import '../widgets.dart';

/// 도서 상세 (Figma 03): 서지 정보, 캠퍼스별 소장 정보, 서가 위치
class BookDetailScreen extends StatelessWidget {
  const BookDetailScreen({super.key, required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    final repo = LibraryRepository.instance;
    final allLoaned = book.holdings.isNotEmpty && book.holdings.every((h) => h.status == HoldingStatus.loaned);
    final firstAvailable = book.holdings.where((h) => h.status == HoldingStatus.available).firstOrNull;
    final shelf = firstAvailable ?? book.holdings.firstOrNull;

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final fav = repo.favorites.contains(book.id);
        return Scaffold(
          backgroundColor: LC.bg,
          body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            LibHeader(children: [
              TitleBar(
                '도서 상세',
                trailing: IconBox(
                  'star_24',
                  tooltip: fav ? '관심도서에서 빼기' : '관심도서에 담기',
                  color: fav ? LC.amber : null,
                  onTap: () => repo.toggleFavorite(book.id),
                ),
              ),
            ]),
            Expanded(
              child: ListView(padding: EdgeInsets.zero, children: [
                _hero(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  child: Gap(24, children: [
                    _bibInfo(),
                    if (book.type == BookType.ebook)
                      Btn('전자책 열람하기', onTap: () => openExternal(context, libraryHome))
                    else ...[
                      Gap(12, children: [
                        const SectionTitle('소장 정보'),
                        CardBox(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                          child: Column(children: [
                            for (final (i, h) in book.holdings.indexed) _holdingRow(context, h, divider: i > 0),
                          ]),
                        ),
                      ]),
                      if (shelf != null)
                        Gap(12, children: [
                          const SectionTitle('서가 위치'),
                          CardBox(
                            child: Gap(14, children: [
                              const _FloorMap(),
                              Row(children: [
                                const Ico('pin_16', size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text('${shelf.campus.fullName} ${shelf.location} · C열 4번 서가', style: ts(13.5, w5, LC.ink, ls: -0.135)),
                                ),
                              ]),
                            ]),
                          ),
                        ]),
                    ],
                  ]),
                ),
              ]),
            ),
            if (book.type != BookType.ebook)
              Container(
                decoration: const BoxDecoration(color: LC.white, border: Border(top: BorderSide(color: LC.line))),
                padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset(context, min: 30)),
                child: Row(children: [
                  Btn('관심도서', kind: BtnKind.outline, icon: 'star_18', onTap: () => repo.toggleFavorite(book.id)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: allLoaned
                        ? Btn('대출 예약하기', onTap: () => _reserve(context))
                        : Btn(
                            '서가 위치 안내',
                            icon: 'pin_18_white',
                            onTap: firstAvailable == null ? null : () => showCallNumber(context, firstAvailable),
                          ),
                  ),
                ]),
              ),
          ]),
        );
      },
    );
  }

  Widget _hero() => Container(
        decoration: const BoxDecoration(color: LC.white, borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Gap(14, crossAxisAlignment: CrossAxisAlignment.center, children: [
          BookCover(book, width: 124, height: 172, radius: 8),
          Padding(padding: const EdgeInsets.only(top: 6), child: HoldingBadge(book.statusFor(null))),
          Text(book.title, textAlign: TextAlign.center, style: ts(22, w9, LC.ink, height: 1.3, ls: -0.22)),
          Text(
            [
              '${book.author} 지음',
              '${book.year}',
              if (book.pages != null) '${book.pages}쪽',
            ].join(' · '),
            textAlign: TextAlign.center,
            style: ts(13.5, w4, LC.sub, ls: -0.135),
          ),
        ]),
      );

  Widget _bibInfo() {
    Widget kv(String k, String v) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 72, child: Text(k, style: ts(13.5, w5, LC.mute, ls: -0.135))),
          const SizedBox(width: 12),
          Expanded(child: Text(v, style: ts(13.5, w5, LC.ink, ls: -0.135))),
        ]);
    return CardBox(
      child: Gap(12, children: [
        if (book.holdings.isNotEmpty) kv('청구기호', book.holdings.first.callNo),
        kv('자료유형', book.type == BookType.ebook ? '전자책${book.ebookFormat == null ? '' : ' (${book.ebookFormat})'}' : '단행본'),
        if (book.isbn != null) kv('ISBN', book.isbn!),
        kv('주제', book.subject),
      ]),
    );
  }

  Widget _holdingRow(BuildContext context, Holding h, {required bool divider}) {
    final detail = h.status == HoldingStatus.loaned && h.due != null
        ? '${h.location} · 반납예정 ${mmdd(h.due!)}'
        : '${h.location} · ${h.regNo != null ? '등록번호 ${h.regNo}' : h.callNo}';
    return Container(
      foregroundDecoration: divider ? const BoxDecoration(border: rowDivider) : null,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(children: [
        Expanded(
          child: Gap(4, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(h.campus.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(15, w7, LC.ink, ls: -0.15))),
              const SizedBox(width: 6),
              HoldingBadge(h.status),
            ]),
            Text(detail, style: ts(12.5, w4, LC.sub, ls: -0.125)),
          ]),
        ),
        if (h.status == HoldingStatus.loaned) ...[
          const SizedBox(width: 12),
          Btn('예약', kind: BtnKind.soft, height: null, radius: 10, fontSize: 13, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), onTap: () => _reserve(context)),
        ],
      ]),
    );
  }

  void _reserve(BuildContext context) => showMessage(context, '예약을 신청했어요. 반납되면 알려드릴게요 (샘플)');
}

/// 서가 배치 그림 (Figma FloorMap 322×168). 카드 폭이 다르면 가운데에 맞춘다
class _FloorMap extends StatelessWidget {
  const _FloorMap();

  @override
  Widget build(BuildContext context) {
    const designWidth = 322.0;
    return LayoutBuilder(builder: (context, k) {
      final dx = (k.maxWidth - designWidth) / 2;
      Widget at(double left, double top, Widget child) => Positioned(left: left + dx, top: top, child: child);
      Widget shelf(double left, double top, {bool target = false}) => at(
            left,
            top,
            Container(
              width: 56,
              height: 12,
              decoration: BoxDecoration(color: target ? LC.primary : LC.seatUsed, borderRadius: BorderRadius.circular(3)),
            ),
          );
      const cols = [('A열', 22.0), ('B열', 98.0), ('C열', 174.0), ('D열', 250.0)];
      return Container(
        height: 168,
        decoration: BoxDecoration(color: LC.bg, borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          for (final (label, x) in cols) ...[
            at(x + 18, 12, Text(label, style: ts(11, w7, LC.sub))),
            for (var r = 0; r < 5; r++) shelf(x, 34.0 + r * 22, target: label == 'C열' && r == 3),
          ],
          at(191, 76, const Ico('pin_22_map', size: 22)),
          at(150, 146, Text('입구', style: ts(10, w7, LC.green))),
          at(137, 162, Container(width: 48, height: 4, decoration: BoxDecoration(color: LC.green, borderRadius: BorderRadius.circular(2)))),
        ]),
      );
    });
  }
}

/// 서가에서 찾기 쉽게 청구기호를 크게 보여 준다
void showCallNumber(BuildContext context, Holding h) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => libraryThemed(Container(
      decoration: const BoxDecoration(color: LC.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.fromLTRB(24, 10, 24, bottomInset(context, min: 24)),
      child: Gap(14, children: [
        Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: LC.line, borderRadius: BorderRadius.circular(3)))),
        Gap(2, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(h.campus.fullName, style: ts(13, w5, LC.sub)),
          Text(h.location, style: ts(19, w7, LC.ink, ls: -0.19)),
        ]),
        Box(
          color: LC.bg,
          radius: 18,
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(children: [
            Text('청구기호', style: ts(13, w5, LC.sub)),
            const SizedBox(height: 4),
            Text(h.callNo, style: ts(28, w9, LC.ink, height: 1.3)),
          ]),
        ),
        Text('서가 옆면의 청구기호 범위를 보고 찾아가세요. 찾지 못하면 자료실 데스크에 이 화면을 보여 주세요.', style: ts(12.5, w4, LC.sub, height: 1.5)),
      ]),
    )),
  );
}
