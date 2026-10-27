import 'package:flutter/material.dart';

import 'library_colors.dart';
import 'library_repository.dart';
import 'links.dart';
import 'models.dart';
import 'screens/book_detail_screen.dart';
import 'screens/my_library_screen.dart';
import 'screens/notices_screen.dart';
import 'screens/search_screen.dart';
import 'screens/seats_screen.dart';
import 'screens/student_id_sheet.dart';
import 'widgets.dart';

/// 도서관 탭 첫 화면 (Figma 01).
/// 기존 웹뷰의 "아래 절반이 빈 화면"(4-16) 대신 검색·학생증·좌석·대출·공지를 한 화면에 모았다.
class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  final repo = LibraryRepository.instance;
  late Future<List<ReadingRoom>> _rooms;
  late Future<List<Notice>> _notices;
  DateTime _loadedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _rooms = repo.rooms();
    _notices = repo.notices();
    _loadedAt = DateTime.now();
  }

  Future<void> _refresh() async {
    setState(_load);
    await Future.wait([_rooms, _notices]);
  }

  void _push(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('도서관'),
        actions: [
          IconButton(tooltip: '공지사항', icon: const Icon(Icons.notifications_none), onPressed: () => _push(const NoticesScreen())),
          IconButton(tooltip: '내 서재', icon: const Icon(Icons.bookmarks_outlined), onPressed: () => _push(const MyLibraryScreen())),
        ],
      ),
      body: ListenableBuilder(
        listenable: repo,
        builder: (context, _) => RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              // 캠퍼스 선택
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: SegmentedButton<Campus>(
                  showSelectedIcon: false,
                  segments: [for (final c in Campus.values) ButtonSegment(value: c, label: Text(c == Campus.chungju ? '충주 중앙' : c.short))],
                  selected: {repo.campus},
                  onSelectionChanged: (s) => repo.setCampus(s.first),
                ),
              ),
              // 검색창 (누르면 검색 화면)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Material(
                  color: cs.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.primary, width: 1.5)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _push(const SearchScreen()),
                    child: SizedBox(
                      height: 52,
                      child: Row(children: [
                        const SizedBox(width: 16),
                        Icon(Icons.search, color: cs.primary),
                        const SizedBox(width: 10),
                        Text('도서명, 저자, 주제로 검색', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15)),
                      ]),
                    ),
                  ),
                ),
              ),
              const OfflineBanner(),
              // 모바일 학생증
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Material(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => showStudentIdSheet(context),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        Icon(Icons.qr_code_2, color: cs.onPrimary, size: 32),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('모바일 학생증', style: TextStyle(color: cs.onPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                            Text('출입·대출 바코드를 바로 열어요', style: TextStyle(color: cs.onPrimary.withValues(alpha: 0.85), fontSize: 13)),
                          ]),
                        ),
                        Icon(Icons.chevron_right, color: cs.onPrimary),
                      ]),
                    ),
                  ),
                ),
              ),
              if (repo.mySeat != null) _MySeatCard(seat: repo.mySeat!, onTap: () => _push(SeatsScreen(roomId: repo.mySeat!.roomId))),

              // 열람실 현황
              SectionHeader('열람실 실시간 현황', action: '좌석 배치도', onAction: () => _push(const SeatsScreen())),
              _card(FutureBuilder<List<ReadingRoom>>(
                future: _rooms,
                builder: (context, snap) {
                  if (snap.hasError) return EmptyState(icon: Icons.event_seat_outlined, title: '좌석 현황을 불러오지 못했어요', onRetry: _refresh);
                  if (!snap.hasData) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
                  final rooms = snap.data!;
                  final total = rooms.fold<int>(0, (a, r) => a + r.total), free = rooms.fold<int>(0, (a, r) => a + r.free);
                  return Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text('전체 $total석 중 $free석 비어 있어요 · ${hhmm(_loadedAt)} 기준',
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                    ),
                    for (final r in rooms) _RoomRow(room: r, onTap: () => _push(SeatsScreen(roomId: r.id))),
                    const SizedBox(height: 8),
                  ]);
                },
              )),

              // 내 대출 (개선점 8-8: 반납일을 첫 화면에)
              SectionHeader('내 대출 현황', action: '전체 ${repo.loans.length}권', onAction: () => _push(const MyLibraryScreen())),
              _card(repo.loans.isEmpty
                  ? const EmptyState(icon: Icons.menu_book_outlined, title: '대출 중인 책이 없어요')
                  : Column(children: [
                      for (final (i, l) in repo.loans.indexed) ...[
                        if (i > 0) const Divider(indent: 16, endIndent: 16),
                        LoanRow(loan: l, onTap: () => _push(BookDetailScreen(book: l.book))),
                      ],
                    ])),

              // 바로가기
              const SizedBox(height: 16),
              _card(Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(children: [
                  _Quick(icon: Icons.bookmarks_outlined, label: '내 서재', onTap: () => _push(const MyLibraryScreen())),
                  _Quick(icon: Icons.tablet_mac_outlined, label: 'E-Book', onTap: () => _push(const SearchScreen(initialType: BookType.ebook))),
                  _Quick(icon: Icons.edit_note, label: '희망도서', onTap: () => openExternal(context, libraryHome)),
                  _Quick(icon: Icons.public, label: 'RISS', onTap: () => openExternal(context, rissHome)),
                ]),
              )),

              // 공지
              SectionHeader('공지사항', action: '더보기', onAction: () => _push(const NoticesScreen())),
              _card(FutureBuilder<List<Notice>>(
                future: _notices,
                builder: (context, snap) {
                  if (!snap.hasData) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
                  final list = snap.data!.where((n) => n.campus == '공통' || n.campus == repo.campus.short).take(4).toList();
                  if (list.isEmpty) return const EmptyState(icon: Icons.campaign_outlined, title: '새 공지가 없어요');
                  return Column(children: [for (final n in list) NoticeTile(notice: n)]);
                },
              )),

              // 연락처: 이캠퍼스 하단처럼 맨 아래 작고 연한 글씨로
              const _ContactFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(Widget child) => Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Card(child: child));
}

class _RoomRow extends StatelessWidget {
  const _RoomRow({required this.room, required this.onTap});
  final ReadingRoom room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = congestionColor(context, room.congestion);
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(room.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 6),
            StatusBadge.congestion(context, room.congestion),
            const Spacer(),
            Text.rich(TextSpan(style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13), children: [
              const TextSpan(text: '잔여 '),
              TextSpan(text: '${room.free}', style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w900)),
              TextSpan(text: ' / ${room.total}석'),
            ])),
          ]),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: room.rate.clamp(0.02, 1.0).toDouble(),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
            color: color,
            backgroundColor: cs.surfaceContainerHigh,
            semanticsLabel: '${room.name} 이용률',
            semanticsValue: '${(room.rate * 100).round()}%',
          ),
        ]),
      ),
    );
  }
}

class _ContactFooter extends StatelessWidget {
  const _ContactFooter();

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 11,
      height: 1.6,
      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Divider(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6)),
        const SizedBox(height: 8),
        for (final c in Campus.values) Text('[${c.label}] ${c.zip} ${c.address} TEL ${c.tel}', style: style),
      ]),
    );
  }
}

class _MySeatCard extends StatelessWidget {
  const _MySeatCard({required this.seat, required this.onTap});
  final MySeat seat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.status;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        child: ListTile(
          onTap: onTap,
          leading: Icon(Icons.event_seat, color: c.info),
          title: Text('내 좌석 ${seat.no}번', style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('${hhmm(seat.at)}부터 이용 중'),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}

class _Quick extends StatelessWidget {
  const _Quick({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: cs.onSurface),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

/// 대출 한 줄: 표지, 제목, D-day, 반납일, 연장 버튼
class LoanRow extends StatelessWidget {
  const LoanRow({super.key, required this.loan, this.onTap});
  final Loan loan;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final urgent = daysUntil(loan.due) <= 3;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          BookCover(loan.book, width: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(loan.book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Row(children: [
                StatusBadge(ddayText(loan.due),
                    color: urgent ? cs.primary : cs.onSurfaceVariant, background: urgent ? cs.primaryContainer : cs.surfaceContainerHigh, dot: false),
                const SizedBox(width: 6),
                Flexible(child: Text('반납예정 ${mmddWd(loan.due)}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13))),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: loan.renewLeft > 0 ? () => renewWithMessage(context, loan) : null,
            child: const Text('연장'),
          ),
        ]),
      ),
    );
  }
}

void renewWithMessage(BuildContext context, Loan loan) {
  try {
    final l = LibraryRepository.instance.renew(loan.book);
    showMessage(context, '반납예정일이 ${mmddWd(l.due)}로 연장됐어요 (샘플)');
  } on StateError catch (e) {
    showMessage(context, e.message);
  }
}

class NoticeTile extends StatelessWidget {
  const NoticeTile({super.key, required this.notice});
  final Notice notice;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      onTap: () => openExternal(context, notice.url ?? libraryHome),
      leading: StatusBadge(notice.campus, color: cs.onSurfaceVariant, background: cs.surfaceContainerHigh, dot: false),
      title: Text(notice.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(mmdd(notice.date), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
    );
  }
}
