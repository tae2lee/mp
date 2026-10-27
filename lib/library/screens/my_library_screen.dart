import 'package:flutter/material.dart';

import '../library_colors.dart';
import '../library_repository.dart';
import '../library_tab.dart' show renewWithMessage;
import '../widgets.dart';
import 'book_detail_screen.dart';

/// 내 서재 (Figma 06). 기존 메뉴의 영어 "My Library"를 한국어로 바꿈 (개선점 4-17).
class MyLibraryScreen extends StatelessWidget {
  const MyLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = LibraryRepository.instance;
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final loans = repo.loans, resv = repo.reservations;
        final favs = [for (final id in repo.favorites) ?repo.bookById(id)];
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('내 서재'),
              bottom: TabBar(tabs: [
                Tab(text: '대출 중 ${loans.length}'),
                Tab(text: '예약 ${resv.length}'),
                Tab(text: '관심도서 ${favs.length}'),
              ]),
            ),
            body: Column(children: [
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: context.status.infoContainer, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Icon(Icons.info_outline, size: 18, color: context.status.info),
                  const SizedBox(width: 8),
                  Expanded(child: Text('도서관 계정 연동 전이라 대출·예약은 샘플 기록이에요.', style: TextStyle(color: context.status.info, fontSize: 13))),
                ]),
              ),
              Expanded(
                child: TabBarView(children: [
                  // 대출 중
                  loans.isEmpty
                      ? const EmptyState(icon: Icons.menu_book_outlined, title: '대출 중인 책이 없어요')
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: loans.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final l = loans[i];
                            final urgent = daysUntil(l.due) <= 3;
                            final span = l.due.difference(l.loanedAt).inDays.clamp(1, 365).toInt();
                            final passed = DateTime.now().difference(l.loanedAt).inDays.clamp(0, span).toInt();
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  InkWell(
                                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => BookDetailScreen(book: l.book))),
                                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      BookCover(l.book, width: 60),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          StatusBadge(ddayText(l.due),
                                              color: urgent ? cs.primary : cs.onSurfaceVariant,
                                              background: urgent ? cs.primaryContainer : cs.surfaceContainerHigh,
                                              dot: false),
                                          const SizedBox(height: 6),
                                          Text(l.book.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                          const SizedBox(height: 2),
                                          Text('대출 ${mmdd(l.loanedAt)} · 반납예정 ${mmddWd(l.due)}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                                        ]),
                                      ),
                                    ]),
                                  ),
                                  const SizedBox(height: 14),
                                  LinearProgressIndicator(
                                    value: passed / span,
                                    minHeight: 6,
                                    borderRadius: BorderRadius.circular(3),
                                    color: urgent ? cs.primary : context.status.good,
                                    backgroundColor: cs.surfaceContainerHigh,
                                    semanticsLabel: '대출 기간 경과',
                                  ),
                                  const SizedBox(height: 10),
                                  Row(children: [
                                    Expanded(child: Text('연장 ${l.renewLeft}회 남음', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13))),
                                    urgent
                                        ? FilledButton(onPressed: l.renewLeft > 0 ? () => renewWithMessage(context, l) : null, child: const Text('연장하기'))
                                        : OutlinedButton(onPressed: l.renewLeft > 0 ? () => renewWithMessage(context, l) : null, child: const Text('연장하기')),
                                  ]),
                                ]),
                              ),
                            );
                          },
                        ),
                  // 예약
                  resv.isEmpty
                      ? const EmptyState(icon: Icons.bookmark_border, title: '예약한 책이 없어요')
                      : ListView(padding: const EdgeInsets.all(16), children: [
                          for (final r in resv)
                            Card(
                              child: ListTile(
                                leading: BookCover(r.book, width: 40),
                                title: Text(r.book.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text('${r.campus.label} · 대기 ${r.order}번 · 반납되면 알려드려요'),
                              ),
                            ),
                        ]),
                  // 관심도서
                  favs.isEmpty
                      ? const EmptyState(icon: Icons.star_border, title: '관심도서가 없어요', message: '도서 상세에서 별표를 누르면 여기에 모여요')
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: favs.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, i) => BookTile(
                            book: favs[i],
                            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => BookDetailScreen(book: favs[i]))),
                          ),
                        ),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }
}
