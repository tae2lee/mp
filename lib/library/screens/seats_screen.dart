import 'dart:async';

import 'package:flutter/material.dart';

import '../library_colors.dart';
import '../library_repository.dart';
import '../links.dart';
import '../models.dart';
import '../sample_data.dart' show roomSeeds;
import '../widgets.dart';

/// 열람실 좌석 (Figma 04). 30초마다 자동 갱신, 두 손가락으로 배치도 확대.
class SeatsScreen extends StatefulWidget {
  const SeatsScreen({super.key, this.roomId = '3'});
  final String roomId;

  @override
  State<SeatsScreen> createState() => _SeatsScreenState();
}

class _SeatsScreenState extends State<SeatsScreen> {
  final repo = LibraryRepository.instance;
  late String _roomId = widget.roomId;
  late Future<RoomDetail> _detail;
  late Future<List<ReadingRoom>> _rooms;
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
    _rooms = repo.rooms();
  }

  void _selectRoom(String id) => setState(() {
        _roomId = id;
        _selected = null;
        _load();
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('열람실 좌석'),
        actions: [IconButton(tooltip: '새로고침', icon: const Icon(Icons.refresh), onPressed: () => setState(_load))],
      ),
      body: Column(children: [
        // 열람실 선택 (잔여 좌석 수 함께 표시)
        SizedBox(
          height: 56,
          child: FutureBuilder<List<ReadingRoom>>(
            future: _rooms,
            builder: (context, snap) {
              // 좌석 서버의 열람실 목록을 쓰고, 불러오기 전에는 기본 목록으로 칩만 먼저 보여 줌
              final rooms = snap.data;
              final chips = rooms != null && rooms.isNotEmpty
                  ? [for (final r in rooms) (r.id, r.shortName, '${r.free}')]
                  : [for (final s in roomSeeds) (s.id, s.name.replaceAll(' 학습 ZONE', ''), '')];
              return ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  for (final (id, name, free) in chips)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(free.isEmpty ? name : '$name $free'),
                        selected: id == _roomId,
                        onSelected: (_) => _selectRoom(id),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const OfflineBanner(),
        Expanded(
          child: FutureBuilder<RoomDetail>(
            future: _detail,
            builder: (context, snap) {
              if (snap.hasError) {
                return EmptyState(icon: Icons.event_seat_outlined, title: '좌석 정보를 불러오지 못했어요', message: '${snap.error}', onRetry: () => setState(_load));
              }
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final d = snap.data!;
              return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), children: [
                _Summary(detail: d),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('좌석 배치도', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      if (!d.exactLayout)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('이 열람실의 좌석 배치는 예시예요. 좌석 번호와 사용 여부는 실제와 같아요.',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
                        ),
                      const SizedBox(height: 12),
                      SeatMap(
                        seats: d.seats,
                        selected: _selected,
                        selectable: repo.mySeat == null,
                        onSeatTap: (no) => setState(() => _selected = _selected == no ? null : no),
                      ),
                      const SizedBox(height: 12),
                      const _Legend(),
                    ]),
                  ),
                ),
              ]);
            },
          ),
        ),
      ]),
      bottomNavigationBar: _bottomBar(context),
    );
  }

  Widget _bottomBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mine = repo.mySeat;
    final Widget label;
    final Widget button;
    if (mine != null) {
      label = _twoLine(context, '내 좌석', '${mine.no}번 · ${hhmm(mine.at)}부터');
      button = OutlinedButton(
        onPressed: () async {
          await repo.releaseSeat();
          if (context.mounted) showMessage(context, '내 좌석 표시를 지웠어요. 반납은 키오스크에서 해 주세요.');
        },
        child: const Text('표시 지우기'),
      );
    } else if (_selected != null) {
      label = _twoLine(context, '선택한 좌석', '$_selected번');
      button = FilledButton(
        onPressed: () async {
          final no = _selected!;
          await repo.assignSeat(_roomId, no);
          _selected = null;
          // 좌석 서버는 조회만 받으므로 실제 배정은 키오스크에서 해야 한다
          if (context.mounted) showMessage(context, '$no번을 내 좌석으로 표시했어요. 배정은 도서관 키오스크에서 해 주세요.');
        },
        child: const Text('내 좌석으로 표시'),
      );
    } else {
      label = Text('초록색 좌석을 누르면 선택돼요', style: TextStyle(color: cs.onSurfaceVariant));
      button = const FilledButton(onPressed: null, child: Text('내 좌석으로 표시'));
    }
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(color: cs.surface, border: Border(top: BorderSide(color: cs.outlineVariant))),
        padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
        child: Row(children: [Expanded(child: label), button]),
      ),
    );
  }

  Widget _twoLine(BuildContext context, String a, String b) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(a, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
          Text(b, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      );
}

class _Summary extends StatelessWidget {
  const _Summary({required this.detail});
  final RoomDetail detail;

  @override
  Widget build(BuildContext context) {
    final r = detail.room;
    final cs = Theme.of(context).colorScheme;
    final color = congestionColor(context, r.congestion);
    final open = r.isOpenAt(DateTime.now());
    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Expanded(child: Text(k, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13))),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(TextSpan(children: [
              TextSpan(text: '${r.free}', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: color, height: 1.1)),
              TextSpan(text: '석', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
            ])),
            Text(open ? '지금 앉을 수 있어요' : '지금은 운영시간이 아니에요',
                style: TextStyle(color: open ? cs.onSurfaceVariant : context.status.warn, fontSize: 13)),
          ]),
          const SizedBox(width: 20),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.tag == null ? r.name : '${r.name} · ${r.tag}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              row('전체 좌석', '${r.total}석'),
              row('사용 좌석', '${r.used}석'),
              row('이용률', '${(r.rate * 100).toStringAsFixed(1)}%'),
              if (r.hours != null) row(r.floor == null ? '운영 시간' : '운영 시간 (${r.floor})', r.hours!),
              row('기준 시각', hhmm(detail.updatedAt)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// 좌석 배치도. 좌표(x, y)는 좌석 1칸 단위. InteractiveViewer 로 확대·이동.
class SeatMap extends StatelessWidget {
  const SeatMap({super.key, required this.seats, required this.onSeatTap, this.selected, this.selectable = true});
  final List<Seat> seats;
  final int? selected;
  final bool selectable;
  final ValueChanged<int> onSeatTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sc = context.status;
    if (seats.isEmpty) return const EmptyState(icon: Icons.event_seat_outlined, title: '좌석 정보가 없어요');
    // 캐럴실처럼 세로 한 줄로만 놓인 방은 가로로 눕혀서 보여 준다
    final rawW = seats.map((s) => s.x ?? 0).reduce((a, b) => a > b ? a : b) + 1;
    final rawH = seats.map((s) => s.y ?? 0).reduce((a, b) => a > b ? a : b) + 1;
    final turn = rawH > rawW * 3;
    double px(Seat s) => (turn ? s.y : s.x) ?? 0;
    double py(Seat s) => (turn ? s.x : s.y) ?? 0;
    final maxX = turn ? rawH : rawW;
    final maxY = turn ? rawW : rawH;

    return LayoutBuilder(builder: (context, constraints) {
      // 화면 폭에 맞추되 너무 작아지지 않게. 더 크게 보려면 두 손가락으로 확대
      final unit = (constraints.maxWidth / maxX).clamp(18.0, 44.0).toDouble();
      final w = maxX * unit, h = maxY * unit;
      return Container(
        height: h.clamp(160.0, 420.0).toDouble(),
        decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: InteractiveViewer(
          constrained: false,
          minScale: 1,
          maxScale: 3,
          boundaryMargin: const EdgeInsets.all(24),
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(children: [
              for (final s in seats)
                Positioned(
                  left: px(s) * unit,
                  top: py(s) * unit,
                  width: unit - 3,
                  height: unit - 3,
                  child: _SeatButton(
                    seat: s,
                    selected: s.no == selected,
                    enabled: selectable && s.status == SeatStatus.available,
                    fontSize: s.no >= 100 ? unit * 0.3 : unit * 0.36,
                    colors: (available: sc.good, used: sc.seatUsed, off: sc.seatOff, mine: sc.info, selected: cs.onSurface, onSelected: cs.surface, ring: cs.primary),
                    onTap: () => onSeatTap(s.no),
                  ),
                ),
            ]),
          ),
        ),
      );
    });
  }
}

typedef _SeatColors = ({Color available, Color used, Color off, Color mine, Color selected, Color onSelected, Color ring});

class _SeatButton extends StatelessWidget {
  const _SeatButton({required this.seat, required this.selected, required this.enabled, required this.fontSize, required this.colors, required this.onTap});
  final Seat seat;
  final bool selected, enabled;
  final double fontSize;
  final _SeatColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = selected
        ? (colors.selected, colors.onSelected, '선택됨')
        : switch (seat.status) {
            SeatStatus.available => (colors.available, Colors.white, '이용 가능'),
            SeatStatus.used => (colors.used, Colors.white, '이용중'),
            SeatStatus.unavailable => (colors.off, Colors.black54, '이용 불가'),
            SeatStatus.mine => (colors.mine, Colors.white, '내 좌석'),
          };
    return Semantics(
      button: enabled,
      label: '${seat.no}번 $label',
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: selected ? BorderSide(color: colors.ring, width: 2) : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: enabled ? onTap : null,
          child: Center(
            child: Text('${seat.no}', style: TextStyle(color: fg, fontSize: fontSize, fontWeight: FontWeight.w700), textScaler: TextScaler.noScaling),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final sc = context.status;
    Widget item(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 6),
          Text(t, style: const TextStyle(fontSize: 12)),
        ]);
    return Wrap(alignment: WrapAlignment.center, spacing: 14, runSpacing: 6, children: [
      item(sc.good, '이용 가능'),
      item(sc.seatUsed, '이용중'),
      item(sc.seatOff, '이용 불가'),
      item(sc.info, '내 좌석'),
    ]);
  }
}
