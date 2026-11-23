import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../library_colors.dart';
import '../library_repository.dart';
import '../links.dart';
import '../models.dart';
import '../sample_data.dart' show roomSeeds;
import '../widgets.dart';

/// 열람실 좌석 (Figma 04). 30초마다 자동 갱신. 큰 열람실은 배치도를 밀어서 보거나 확대
class SeatsScreen extends StatefulWidget {
  const SeatsScreen({super.key, this.roomId = '1', this.onBack});
  final String roomId;
  final VoidCallback? onBack;

  @override
  State<SeatsScreen> createState() => SeatsScreenState();
}

class SeatsScreenState extends State<SeatsScreen> {
  final repo = LibraryRepository.instance;
  late String _roomId = widget.roomId;
  late Future<RoomDetail> _detail;
  List<ReadingRoom> _roomList = const [];
  int? _selected;
  Timer? _timer;
  MySeat? _lastMySeat;

  @override
  void initState() {
    super.initState();
    _lastMySeat = repo.mySeat;
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => setState(_load));
    repo.addListener(_onRepo);
  }

  @override
  void dispose() {
    _timer?.cancel();
    repo.removeListener(_onRepo);
    super.dispose();
  }

  // 배정·퇴실했을 때만 다시 불러옴
  void _onRepo() {
    if (repo.mySeat == _lastMySeat) return;
    _lastMySeat = repo.mySeat;
    setState(_load);
  }

  void _load() {
    _detail = repo.room(_roomId);
    repo.rooms().then((r) {
      if (mounted) setState(() => _roomList = r);
    });
  }

  /// 홈에서 열람실을 눌렀을 때 그 방으로 바꿈
  void selectRoom(String id) {
    if (id == _roomId) return;
    setState(() {
      _roomId = id;
      _selected = null;
      _load();
    });
  }

  List<(String, String)> get _tabs => _roomList.isNotEmpty
      ? [for (final r in _roomList) (r.id, r.shortName)]
      : [for (final s in roomSeeds) (s.id, s.name)];

  String _roomName(String id) => _tabs.where((t) => t.$1 == id).firstOrNull?.$2 ?? '';

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    return Scaffold(
      backgroundColor: LC.bg,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        LibHeader(children: [
          TitleBar(
            '열람실 좌석',
            onBack: widget.onBack,
            trailing: IconBox('refresh_24', tooltip: '새로고침', onTap: () => setState(_load)),
          ),
          UnderlineTabs(
            labels: [for (final t in tabs) t.$2],
            index: math.max(0, tabs.indexWhere((t) => t.$1 == _roomId)),
            onChanged: (i) => selectRoom(tabs[i].$1),
          ),
        ]),
        Expanded(
          child: FutureBuilder<RoomDetail>(
            future: _detail,
            builder: (context, snap) {
              if (snap.hasError) {
                return EmptyState(icon: Icons.event_seat_outlined, title: '좌석 정보를 불러오지 못했어요', message: '${snap.error}', onRetry: () => setState(_load));
              }
              final d = snap.data;
              if (d == null) return const Center(child: CircularProgressIndicator(color: LC.primary, strokeWidth: 2.5));
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 20), children: [
                    Gap(16, children: [
                      if (repo.lastError != null) const OfflineBanner(),
                      _Summary(detail: d),
                      _mapCard(d),
                    ]),
                  ]),
                ),
                _cta(d),
              ]);
            },
          ),
        ),
      ]),
    );
  }

  Widget _mapCard(RoomDetail d) {
    final nums = d.seats.map((s) => s.no);
    Widget landmark(String text, Color fg, Color bg) => Box(
          color: bg,
          radius: 6,
          padding: const EdgeInsets.symmetric(vertical: 4),
          alignment: Alignment.center,
          child: Text(text, style: ts(11, w7, fg)),
        );
    return CardBox(
      child: Gap(14, children: [
        Row(children: [
          Expanded(child: Text('${d.zone ?? d.room.shortName} 좌석 배치도', style: ts(16, w7, LC.ink, ls: -0.16))),
          if (nums.isNotEmpty) Text('${nums.reduce(math.min)} ~ ${nums.reduce(math.max)}번', style: ts(12.5, w5, LC.mute, ls: -0.125)),
        ]),
        if (d.zone != null) landmark('창가', LC.blue, LC.blueSoft),
        SeatMap(
          seats: d.seats,
          selected: _selected,
          selectable: repo.mySeat == null,
          onSeatTap: (no) => setState(() => _selected = _selected == no ? null : no),
        ),
        if (d.zone != null) landmark('출입구', LC.green, LC.greenSoft),
        const _Legend(),
      ]),
    );
  }

  /// Figma SeatCTA: 선택한 좌석 + 좌석 배정받기
  Widget _cta(RoomDetail d) {
    final mine = repo.mySeat;
    final String caption, title;
    final Widget button;
    if (mine != null) {
      caption = '내 좌석 · ${hhmm(mine.at)}부터';
      title = '${_roomName(mine.roomId)} ${mine.roomId == _roomId ? d.seatLabel(mine.no) : '${mine.no}'}번';
      button = Btn('퇴실하기', kind: BtnKind.outline, onTap: () async {
        await repo.releaseSeat();
        if (mounted) showMessage(context, '내 좌석 표시를 지웠어요. 반납은 키오스크에서 해 주세요.');
      });
    } else {
      caption = '선택한 좌석';
      title = _selected == null ? '좌석을 눌러 선택해 주세요' : '${d.room.shortName} ${d.seatLabel(_selected!)}번';
      button = Btn('좌석 배정받기', onTap: _selected == null
          ? null
          : () async {
              final no = _selected!;
              await repo.assignSeat(_roomId, no);
              _selected = null;
              // 좌석 서버는 조회만 받으므로 실제 배정은 키오스크에서 해야 한다
              if (mounted) showMessage(context, '$no번 좌석을 내 좌석으로 표시했어요. 배정은 도서관 키오스크에서 해 주세요.');
            });
    }
    return Container(
      decoration: const BoxDecoration(color: LC.white, border: Border(top: BorderSide(color: LC.line))),
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(caption, style: ts(12, w5, LC.sub, ls: -0.12)),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(16, w7, _selected == null && mine == null ? LC.mute : LC.ink, ls: -0.16)),
          ]),
        ),
        const SizedBox(width: 12),
        button,
      ]),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.detail});
  final RoomDetail detail;

  @override
  Widget build(BuildContext context) {
    final r = detail.room;
    final color = congestionColor(r.congestion);
    final open = r.isOpenAt(DateTime.now());
    Widget row(String k, String v) => Row(children: [
          Expanded(child: Text(k, style: ts(13, w4, LC.sub, ls: -0.13))),
          Text(v, style: ts(13, w7, LC.ink, ls: -0.13)),
        ]);
    return Box(
      color: LC.white,
      radius: 18,
      padding: const EdgeInsets.all(20),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text('${r.free}', style: ts(44, w9, color, height: 1.1, ls: -0.88)),
            const SizedBox(width: 2),
            Text('석', style: ts(16, w7, color, ls: -0.16)),
          ]),
          Text(open ? '지금 앉을 수 있어요' : '지금은 운영시간이 아니에요', style: ts(12.5, w5, open ? LC.sub : LC.amber, ls: -0.125)),
        ]),
        const SizedBox(width: 20),
        Container(width: 1, height: 64, color: LC.line),
        const SizedBox(width: 20),
        Expanded(
          child: Gap(6, children: [
            row('전체 좌석', '${r.total}석'),
            row('이용 중', '${r.used}석'),
            if (r.hours != null) row('운영 시간', r.hours!),
          ]),
        ),
      ]),
    );
  }
}

/// 좌석 배치도. 좌표 1칸 = 좌석 30 + 간격 6. 카드보다 넓으면 밀어서 보고 두 손가락으로 확대
class SeatMap extends StatelessWidget {
  const SeatMap({super.key, required this.seats, required this.onSeatTap, this.selected, this.selectable = true});
  final List<Seat> seats;
  final int? selected;
  final bool selectable;
  final ValueChanged<int> onSeatTap;

  static const _unit = 36.0, _seat = 30.0;

  @override
  Widget build(BuildContext context) {
    if (seats.isEmpty) return const EmptyState(icon: Icons.event_seat_outlined, title: '좌석 정보가 없어요');
    // 캐럴실처럼 세로 한 줄로만 놓인 방은 가로로 눕혀서 보여 준다
    final rawW = seats.map((s) => s.x ?? 0.0).reduce(math.max);
    final rawH = seats.map((s) => s.y ?? 0.0).reduce(math.max);
    final turn = rawH > (rawW + 1) * 3;
    double px(Seat s) => (turn ? s.y : s.x) ?? 0.0;
    double py(Seat s) => (turn ? s.x : s.y) ?? 0.0;
    final w = (turn ? rawH : rawW) * _unit + _seat;
    final h = (turn ? rawW : rawH) * _unit + _seat;

    final map = SizedBox(
      width: w,
      height: h,
      child: Stack(children: [
        for (final s in seats)
          Positioned(
            left: px(s) * _unit,
            top: py(s) * _unit,
            child: _SeatBox(
              seat: s,
              selected: s.no == selected,
              enabled: selectable && s.status == SeatStatus.available,
              onTap: () => onSeatTap(s.no),
            ),
          ),
      ]),
    );

    return LayoutBuilder(builder: (context, k) {
      if (w <= k.maxWidth && h <= 480) return Center(child: map);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: math.min(h, 420.0),
          child: ClipRect(
            child: InteractiveViewer(
              constrained: false,
              minScale: 0.4,
              maxScale: 2.5,
              boundaryMargin: const EdgeInsets.all(12),
              child: map,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('밀어서 옆 좌석을 보고, 두 손가락으로 확대할 수 있어요', textAlign: TextAlign.center, style: ts(12, w5, LC.mute)),
      ]);
    });
  }
}

class _SeatBox extends StatelessWidget {
  const _SeatBox({required this.seat, required this.selected, required this.enabled, required this.onTap});
  final Seat seat;
  final bool selected, enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, BorderSide? border, String label) = selected || seat.status == SeatStatus.mine
        ? (LC.primary, LC.white, null, selected ? '선택됨' : '내 좌석')
        : switch (seat.status) {
            SeatStatus.available => (LC.white, LC.green, const BorderSide(color: LC.green, width: 1.5), '선택 가능'),
            SeatStatus.used => (LC.seatUsed, LC.mute, null, '사용 중'),
            _ => (LC.bg, LC.seatUsed, null, '이용 불가'),
          };
    return Semantics(
      button: enabled,
      label: '${seat.no}번 $label',
      child: Box(
        width: 30,
        height: 30,
        radius: 7,
        color: bg,
        border: border,
        alignment: Alignment.center,
        onTap: enabled ? onTap : null,
        child: Text('${seat.no}', style: ts(10.5, w7, fg, height: 1), textScaler: TextScaler.noScaling, maxLines: 1),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String t, {BorderSide? border}) => Row(mainAxisSize: MainAxisSize.min, children: [
          Box(width: 14, height: 14, radius: 4, color: c, border: border, child: const SizedBox()),
          const SizedBox(width: 6),
          Text(t, style: ts(12, w5, LC.sub)),
        ]);
    return Wrap(alignment: WrapAlignment.center, spacing: 16, runSpacing: 6, children: [
      item(LC.white, '선택 가능', border: const BorderSide(color: LC.green)),
      item(LC.seatUsed, '사용 중'),
      item(LC.primary, '선택한 좌석'),
    ]);
  }
}
