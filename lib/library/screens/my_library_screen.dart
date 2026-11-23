import 'package:flutter/material.dart';

import '../library_colors.dart';
import '../library_repository.dart';
import '../library_tab.dart' show renewWithMessage;
import '../models.dart';
import '../widgets.dart';
import 'book_detail_screen.dart';
import 'notices_screen.dart';

/// 내 서재 (Figma 06): 대출 중 · 예약 · 대출 이력
class MyLibraryScreen extends StatefulWidget {
  const MyLibraryScreen({super.key, this.onBack});
  final VoidCallback? onBack;

  @override
  State<MyLibraryScreen> createState() => _MyLibraryScreenState();
}

class _MyLibraryScreenState extends State<MyLibraryScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final repo = LibraryRepository.instance;
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final loans = repo.loans, resv = repo.reservations;
        return Scaffold(
          backgroundColor: LC.bg,
          body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            LibHeader(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(children: [
                  Expanded(child: Text('내 서재', style: ts(24, w9, LC.ink, ls: -0.48))),
                  IconBox('bell_24', box: 32, tooltip: '공지사항', onTap: () => pushLibrary<void>(context, const NoticesScreen())),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                child: Row(children: [
                  _stat('${loans.length}', '대출 중', LC.ink, () => setState(() => _tab = 0)),
                  const SizedBox(width: 10),
                  _stat('${resv.length}', '예약', LC.ink, () => setState(() => _tab = 1)),
                  const SizedBox(width: 10),
                  _stat('${repo.overdueCount}', '연체', repo.overdueCount == 0 ? LC.green : LC.primary, null),
                ]),
              ),
              UnderlineTabs(
                labels: ['대출 중 ${loans.length}', '예약 ${resv.length}', '대출 이력'],
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
            ]),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 24), children: [
                Gap(12, children: switch (_tab) {
                  0 => [
                      if (loans.isEmpty) const CardBox(child: EmptyState(icon: Icons.menu_book_outlined, title: '대출 중인 책이 없어요')),
                      for (final l in loans) _LoanCard(loan: l),
                      _historyLink(repo.history.length),
                    ],
                  1 => [
                      if (resv.isEmpty) const CardBox(child: EmptyState(icon: Icons.bookmark_border, title: '예약한 책이 없어요')),
                      for (final r in resv) _ReservationCard(reservation: r),
                    ],
                  _ => [
                      for (final b in repo.history) BookItem(book: b, onTap: () => pushLibrary<void>(context, BookDetailScreen(book: b))),
                      if (repo.favorites.isNotEmpty) ...[
                        const Padding(padding: EdgeInsets.only(top: 12), child: SectionTitle('관심도서')),
                        for (final id in repo.favorites)
                          if (repo.bookById(id) case final b?) BookItem(book: b, onTap: () => pushLibrary<void>(context, BookDetailScreen(book: b))),
                      ],
                    ],
                }),
              ]),
            ),
          ]),
        );
      },
    );
  }

  Widget _stat(String n, String label, Color color, VoidCallback? onTap) => Expanded(
        child: Box(
          color: LC.bg,
          radius: 14,
          padding: const EdgeInsets.symmetric(vertical: 12),
          onTap: onTap,
          child: Column(children: [
            Text(n, style: ts(22, w9, color, height: 1.2)),
            Text(label, style: ts(12.5, w5, LC.sub)),
          ]),
        ),
      );

  Widget _historyLink(int count) => Box(
        color: LC.white,
        radius: 18,
        padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
        onTap: () => setState(() => _tab = 2),
        child: Row(children: [
          Box(width: 40, height: 40, radius: 12, color: LC.bg, alignment: Alignment.center, child: const Ico('history_20', size: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('지난 대출 이력', style: ts(15, w7, LC.ink, ls: -0.15)),
              const SizedBox(height: 1),
              Text('이번 학기 $count권 읽었어요', style: ts(12.5, w4, LC.sub, ls: -0.125)),
            ]),
          ),
          const SizedBox(width: 12),
          const Ico('chev_right_18', size: 18),
        ]),
      );
}

/// Figma LoanCard: 표지 · D-day · 제목 · 날짜 · 대출 기간 막대 · 연장하기
class _LoanCard extends StatelessWidget {
  const _LoanCard({required this.loan});
  final Loan loan;

  @override
  Widget build(BuildContext context) {
    final l = loan;
    final urgent = isUrgent(l.due);
    final span = l.due.difference(l.loanedAt).inDays.clamp(1, 365).toInt();
    final passed = DateTime.now().difference(l.loanedAt).inDays.clamp(0, span).toInt();
    return CardBox(
      padding: const EdgeInsets.all(16),
      child: Gap(14, children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => pushLibrary<void>(context, BookDetailScreen(book: l.book)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            BookCover(l.book, width: 60, height: 84),
            const SizedBox(width: 14),
            Expanded(
              child: Gap(6, crossAxisAlignment: CrossAxisAlignment.start, children: [
                DdayTag(l.due, big: true),
                Text(l.book.title, style: ts(16, w7, LC.ink, ls: -0.16)),
                Text('대출 ${mmdd(l.loanedAt)} · 반납예정 ${mmddWd(l.due)}', style: ts(12.5, w4, LC.sub, ls: -0.125)),
              ]),
            ),
          ]),
        ),
        Semantics(label: '대출 기간 ${(passed / span * 100).round()}% 지남', child: ProgressBar(value: passed / span, color: urgent ? LC.primary : LC.green, height: 6)),
        Row(children: [
          Expanded(child: Text('연장 ${l.renewLeft}회 남음', style: ts(12.5, w5, LC.mute, ls: -0.125))),
          const SizedBox(width: 10),
          Btn(
            '연장하기',
            kind: urgent ? BtnKind.primary : BtnKind.outline,
            height: 40,
            radius: 12,
            fontSize: 14,
            onTap: l.renewLeft > 0 ? () => renewWithMessage(context, l) : null,
          ),
        ]),
      ]),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({required this.reservation});
  final Reservation reservation;

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    return CardBox(
      padding: const EdgeInsets.all(16),
      onTap: () => pushLibrary<void>(context, BookDetailScreen(book: r.book)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        BookCover(r.book, width: 60, height: 84),
        const SizedBox(width: 14),
        Expanded(
          child: Gap(6, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Tag('대기 ${r.order}번', color: LC.blue, background: LC.blueSoft, fontSize: 12, weight: w9, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), radius: 6),
            Text(r.book.title, style: ts(16, w7, LC.ink, ls: -0.16)),
            Text('${r.campus.fullName} · 반납되면 알려드려요', style: ts(12.5, w4, LC.sub, ls: -0.125)),
          ]),
        ),
      ]),
    );
  }
}
