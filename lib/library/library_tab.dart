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

/// 도서관 탭 (Figma 01~06). 아래 탭: 홈 · 검색 · 학생증 · 열람실 · 내서재
class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  int _index = 0;
  final _searchFocus = FocusNode();
  final _seatsKey = GlobalKey<SeatsScreenState>();

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  void _go(int i) {
    if (i != 1) _searchFocus.unfocus();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return libraryThemed(Scaffold(
      backgroundColor: LC.bg,
      body: IndexedStack(index: _index, children: [
        LibraryHome(
          onSearch: () {
            _go(1);
            _searchFocus.requestFocus();
          },
          onSeats: (roomId) {
            if (roomId != null) _seatsKey.currentState?.selectRoom(roomId);
            _go(2);
          },
          onMyLibrary: () => _go(3),
        ),
        SearchScreen(focusNode: _searchFocus, onBack: () => _go(0)),
        SeatsScreen(key: _seatsKey, onBack: () => _go(0)),
        MyLibraryScreen(onBack: () => _go(0)),
      ]),
      bottomNavigationBar: LibraryBottomNav(
        index: _index,
        onTap: _go,
        onStudentId: () => showStudentIdSheet(context),
      ),
    ));
  }
}

/// Figma BottomNav: 가운데 빨간 원이 모바일 학생증
class LibraryBottomNav extends StatelessWidget {
  const LibraryBottomNav({super.key, required this.index, required this.onTap, required this.onStudentId});
  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onStudentId;

  @override
  Widget build(BuildContext context) {
    Widget tab(int i, String icon, String label) {
      final on = i == index;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(i),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Ico('nav_${icon}_${on ? 'on' : 'off'}', size: 24),
              const SizedBox(height: 3),
              Text(label, style: ts(11, on ? w7 : w5, on ? LC.primary : LC.mute)),
            ]),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(color: LC.white, border: Border(top: BorderSide(color: LC.line))),
      padding: EdgeInsets.fromLTRB(8, 8, 8, bottomInset(context)),
      child: SizedBox(
        height: 50,
        child: Row(children: [
          tab(0, 'home', '홈'),
          tab(1, 'search', '검색'),
          Expanded(
            child: Center(
              child: Tooltip(
                message: '모바일 학생증',
                child: Box(width: 48, height: 48, radius: 24, color: LC.primary, alignment: Alignment.center, onTap: onStudentId, child: const Ico('nav_barcode', size: 22)),
              ),
            ),
          ),
          tab(2, 'seat', '열람실'),
          tab(3, 'book', '내서재'),
        ]),
      ),
    );
  }
}

/// 도서관 홈 (Figma 01)
class LibraryHome extends StatefulWidget {
  const LibraryHome({super.key, required this.onSearch, required this.onSeats, required this.onMyLibrary});
  final VoidCallback onSearch, onMyLibrary;
  final void Function(String? roomId) onSeats;

  @override
  State<LibraryHome> createState() => _LibraryHomeState();
}

class _LibraryHomeState extends State<LibraryHome> {
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) => Stack(children: [
        RefreshIndicator(
          color: LC.primary,
          onRefresh: _refresh,
          child: ListView(padding: EdgeInsets.zero, children: [
            _header(context),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
              child: Gap(28, children: [
                _studentIdCard(context),
                _roomsSection(),
                _loansSection(context),
                _quickMenu(context),
                _noticesSection(context),
              ]),
            ),
            const _ContactFooter(),
          ]),
        ),
        // 스크롤해도 상태 표시줄 뒤는 흰색으로
        Positioned(top: 0, left: 0, right: 0, height: MediaQuery.paddingOf(context).top, child: const ColoredBox(color: LC.white)),
      ]),
    );
  }

  Widget _header(BuildContext context) => LibHeader(bottomRadius: 24, bottomPadding: 20, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
          child: Row(children: [
            IconBox('chev_left', tooltip: '뒤로', onTap: () => Navigator.maybePop(context)),
            const SizedBox(width: 4),
            Expanded(child: Text('도서관', style: ts(24, w9, LC.ink, ls: -0.48))),
            IconBox('btn_bell_dot', size: 40, tooltip: '알림', onTap: () => pushLibrary<void>(context, const NoticesScreen())),
          ]),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 0), child: _campusSegment()),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Box(
            height: 52,
            color: LC.white,
            radius: 14,
            border: const BorderSide(color: LC.primary, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            onTap: widget.onSearch,
            child: Row(children: [
              const Ico('search_20', size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text('도서명, 저자, ISBN 검색', style: ts(15, w4, LC.mute, ls: -0.15))),
            ]),
          ),
        ),
      ]);

  Widget _campusSegment() => Box(
        color: LC.bg,
        radius: 12,
        padding: const EdgeInsets.all(4),
        child: Row(children: [
          for (final (i, c) in Campus.values.indexed) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Box(
                color: c == repo.campus ? LC.white : null,
                radius: 9,
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                onTap: () => repo.setCampus(c),
                child: Text(
                  c == repo.campus ? c.fullName : c.short,
                  maxLines: 1,
                  style: ts(13, c == repo.campus ? w7 : w5, c == repo.campus ? LC.ink : LC.sub),
                ),
              ),
            ),
          ],
        ]),
      );

  Widget _studentIdCard(BuildContext context) => Box(
        color: LC.primary,
        radius: 18,
        padding: const EdgeInsets.all(18),
        onTap: () => showStudentIdSheet(context),
        child: Row(children: [
          Box(
            width: 44,
            height: 44,
            radius: 12,
            color: LC.white.withValues(alpha: 0.16),
            alignment: Alignment.center,
            child: const Ico('nav_barcode', size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('모바일 학생증', style: ts(16, w7, LC.white, ls: -0.16)),
              const SizedBox(height: 2),
              Text('출입·대출 바코드를 바로 열어요', style: ts(12.5, w4, LC.white, ls: -0.125)),
            ]),
          ),
          const SizedBox(width: 14),
          Box(color: LC.white, radius: 16, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), child: Text('열기', style: ts(13, w7, LC.primary))),
        ]),
      );

  Widget _roomsSection() => Gap(12, children: [
        SectionTitle('열람실 실시간 현황', action: '좌석 배치도', onTap: () => widget.onSeats(null)),
        if (repo.lastError != null) const OfflineBanner(),
        CardBox(
          child: FutureBuilder<List<ReadingRoom>>(
            future: _rooms,
            builder: (context, snap) {
              if (snap.hasError) return EmptyState(icon: Icons.event_seat_outlined, title: '좌석 현황을 불러오지 못했어요', onRetry: _refresh);
              final rooms = snap.data;
              return Gap(18, children: [
                Row(children: [
                  Expanded(child: Text('${mmddWd(_loadedAt)} ${hhmm(_loadedAt)} 기준', style: ts(12, w5, LC.mute, ls: -0.12))),
                  const SizedBox(width: 4),
                  GestureDetector(onTap: _refresh, child: const Ico('refresh_14', size: 14)),
                ]),
                if (rooms == null)
                  const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(color: LC.primary, strokeWidth: 2.5)))
                else
                  for (final r in rooms) _RoomRow(room: r, onTap: () => widget.onSeats(r.id)),
              ]);
            },
          ),
        ),
      ]);

  Widget _loansSection(BuildContext context) => Gap(12, children: [
        SectionTitle('내 대출 현황', action: '전체 ${repo.loans.length}권', onTap: widget.onMyLibrary),
        CardBox(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: repo.loans.isEmpty
              ? const EmptyState(icon: Icons.menu_book_outlined, title: '대출 중인 책이 없어요')
              : Column(children: [
                  for (final (i, l) in repo.loans.indexed)
                    LoanRow(loan: l, divider: i > 0, onTap: () => pushLibrary<void>(context, BookDetailScreen(book: l.book))),
                ]),
        ),
      ]);

  Widget _quickMenu(BuildContext context) {
    Widget item(String icon, String label, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Column(children: [
              Box(width: 48, height: 48, radius: 14, color: LC.bg, alignment: Alignment.center, child: Ico(icon, size: 22)),
              const SizedBox(height: 8),
              Text(label, maxLines: 1, style: ts(12.5, w5, LC.ink)),
            ]),
          ),
        );
    // Figma QuickMenu: 높이 100 고정, 위 18
    return Box(
      height: 100,
      color: LC.white,
      radius: 18,
      padding: const EdgeInsets.fromLTRB(6, 18, 6, 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        item('quick_monitor', '전자자료', () => pushLibrary<void>(context, const SearchScreen(initialType: BookType.ebook))),
        item('quick_info', '이용안내', () => openExternal(context, libraryHome)),
        item('quick_mega', '공지사항', () => pushLibrary<void>(context, const NoticesScreen())),
        item('quick_building', '도서관 소개', () => openExternal(context, libraryHome)),
      ]),
    );
  }

  Widget _noticesSection(BuildContext context) => Gap(12, children: [
        SectionTitle('공지사항', action: '더보기', onTap: () => pushLibrary<void>(context, const NoticesScreen())),
        CardBox(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: FutureBuilder<List<Notice>>(
            future: _notices,
            builder: (context, snap) {
              if (!snap.hasData) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: LC.primary, strokeWidth: 2.5)));
              final list = snap.data!.take(2).toList();
              if (list.isEmpty) return const EmptyState(icon: Icons.campaign_outlined, title: '새 공지가 없어요');
              return Column(children: [for (final (i, n) in list.indexed) NoticeTile(notice: n, divider: i > 0)]);
            },
          ),
        ),
      ]);
}

class _RoomRow extends StatelessWidget {
  const _RoomRow({required this.room, required this.onTap});
  final ReadingRoom room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = congestionColor(room.congestion);
    final small = ts(12.5, w5, LC.sub, ls: -0.125);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Gap(8, children: [
        Row(children: [
          Flexible(child: Text(room.shortName, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(15, w7, LC.ink, ls: -0.15))),
          const SizedBox(width: 6),
          CongestionTag(room.congestion),
          const Expanded(child: SizedBox()),
          Text.rich(TextSpan(children: [
            TextSpan(text: '잔여 ', style: small),
            TextSpan(text: '${room.free}', style: ts(17, w9, color)),
            TextSpan(text: ' / ${room.total}석', style: small),
          ])),
        ]),
        Semantics(
          label: '${room.shortName} 이용률 ${(room.rate * 100).round()}%',
          child: ProgressBar(value: room.rate, color: color),
        ),
      ]),
    );
  }
}

/// 이캠퍼스 하단처럼 맨 아래 작고 연한 글씨로 캠퍼스 연락처
class _ContactFooter extends StatelessWidget {
  const _ContactFooter();

  @override
  Widget build(BuildContext context) {
    final style = ts(11, w4, LC.mute.withValues(alpha: 0.8), height: 1.6);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Divider(color: LC.line, height: 1, thickness: 1),
        const SizedBox(height: 12),
        for (final c in Campus.values) Text('[${c.label}] ${c.zip} ${c.address} TEL ${c.tel}', style: style),
      ]),
    );
  }
}

/// 대출 한 줄 (Figma LoanRow): 표지, 제목, D-day, 반납일, 연장 버튼
class LoanRow extends StatelessWidget {
  const LoanRow({super.key, required this.loan, this.onTap, this.divider = false});
  final Loan loan;
  final VoidCallback? onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          foregroundDecoration: divider ? const BoxDecoration(border: rowDivider) : null,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            BookCover(loan.book, width: 40, height: 56, radius: 4),
            const SizedBox(width: 12),
            Expanded(
              child: Gap(3, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(loan.book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(14.5, w7, LC.ink, ls: -0.145)),
                Row(children: [
                  DdayTag(loan.due),
                  const SizedBox(width: 6),
                  Flexible(child: Text('반납예정 ${mmddWd(loan.due)}', maxLines: 1, style: ts(12.5, w4, LC.sub, ls: -0.125))),
                ]),
              ]),
            ),
            const SizedBox(width: 12),
            Btn(
              '연장',
              kind: BtnKind.outline,
              height: null,
              radius: 10,
              fontSize: 13,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              onTap: loan.renewLeft > 0 ? () => renewWithMessage(context, loan) : null,
            ),
          ]),
        ),
      );
}

void renewWithMessage(BuildContext context, Loan loan) {
  try {
    final l = LibraryRepository.instance.renew(loan.book);
    showMessage(context, '반납예정일이 ${mmddWd(l.due)}로 연장됐어요 (샘플)');
  } on StateError catch (e) {
    showMessage(context, e.message);
  }
}

/// 공지 한 줄: 캠퍼스 · 제목 · 날짜
class NoticeTile extends StatelessWidget {
  const NoticeTile({super.key, required this.notice, this.divider = false});
  final Notice notice;
  final bool divider;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => openExternal(context, notice.url ?? libraryHome),
        child: Container(
          foregroundDecoration: divider ? const BoxDecoration(border: rowDivider) : null,
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(children: [
            Tag(notice.campus, color: LC.sub, background: LC.bg, padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2)),
            const SizedBox(width: 10),
            Expanded(child: Text(notice.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(14, w5, LC.ink, ls: -0.14))),
            const SizedBox(width: 10),
            Text(mmdd(notice.date), style: ts(12, w4, LC.mute, ls: -0.12)),
          ]),
        ),
      );
}
