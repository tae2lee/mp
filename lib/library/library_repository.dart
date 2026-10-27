/// 도서관 데이터 창구. 화면은 이 클래스만 부른다.
///
/// - 열람실 좌석: 도서관 좌석 서버(http://210.119.152.17)에서 바로 받는다 (기본으로 켜짐)
/// - 공지·표지: knut-library-app/server 중계 서버를 켰을 때만 실시간 (LIBRARY_API)
/// - 검색·내 서재: 아직 샘플
/// 실시간 호출이 실패하면 샘플로 대신 보여 주고 [lastError] 에 이유를 남긴다.
///
/// 상태 관리 패키지 없이 ChangeNotifier(Flutter 기본) 하나로 화면 간 변경을 알린다.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'sample_data.dart' as sample;

class LibraryRepository extends ChangeNotifier {
  LibraryRepository._();
  static final instance = LibraryRepository._();

  /// 중계 서버 주소. 비우면 샘플 모드.
  /// 에뮬레이터에서 PC 의 서버에 붙을 때는 'http://10.0.2.2:8787'
  String apiBase = const String.fromEnvironment('LIBRARY_API', defaultValue: '');
  bool get isLive => apiBase.isNotEmpty;

  /// 마지막 실시간 호출이 실패했을 때의 이유 (화면 상단 안내에 사용)
  String? lastError;

  Campus campus = Campus.chungju;
  StudentProfile profile = sample.sampleProfile;
  MySeat? mySeat;
  final Set<String> favorites = {};
  final List<String> recentSearches = [];
  late List<Loan> _loans = sample.sampleLoans();

  void setCampus(Campus c) {
    campus = c;
    notifyListeners();
  }

  // ---------------- 열람실 ----------------
  //
  // 좌석 현황은 도서관 좌석 서버의 JSON 을 앱이 직접 읽는다 (중계 서버 불필요).
  //   GET /api/did/rooms?caller=nicom                 열람실 목록과 잔여석
  //   GET /api/seat/configs?caller=nicom&room_no=N    좌석별 위치·상태
  // 응답에 이용자 정보(user_id, user_name, phone)가 섞여 오지만 읽지 않고 버린다.
  // 좌석 배정·반납은 이 서버가 받지 않아(조회 전용) 도서관 키오스크에서만 할 수 있다.

  /// 좌석 서버 주소. 비우면 샘플 좌석을 보여 준다.
  /// 빌드할 때 바꾸려면: flutter run --dart-define=SEAT_API=http://...
  String seatApi = const String.fromEnvironment('SEAT_API', defaultValue: 'http://210.119.152.17');
  bool get isSeatLive => seatApi.isNotEmpty;

  Future<List<ReadingRoom>> rooms() => _liveOr(
        () async => [for (final r in await _seatItems('/api/did/rooms?caller=nicom')) _roomFromSeatApi(r)],
        () async => [for (final s in sample.roomSeeds) (await _sampleRoom(s.id)).room],
        enabled: isSeatLive,
      );

  Future<RoomDetail> room(String id) => _liveOr(
        () async {
          final (roomItems, seatItems) = await (
            _seatItems('/api/did/rooms?caller=nicom'),
            _seatItems('/api/seat/configs?caller=nicom&room_no=${Uri.encodeQueryComponent(id)}'),
          ).wait;
          final r = roomItems.where((e) => '${e['room_no']}' == id).firstOrNull;
          if (r == null) throw const HttpException('열람실 정보를 찾지 못했어요');
          return RoomDetail(
            room: _roomFromSeatApi(r),
            seats: _withMySeat(id, _seatsFromSeatApi(seatItems)),
            exactLayout: true,
            updatedAt: DateTime.now(),
          );
        },
        () => _sampleRoom(id),
        enabled: isSeatLive,
      );

  /// 좌석 서버의 열람실 1건 → ReadingRoom
  /// 예: {room_no:3, name:'제3협업 학습 ZONE (콘센트)', floor_name:'3층', total_count:108, remain_count:87, open_time:'0500', close_time:'2359'}
  ReadingRoom _roomFromSeatApi(Map<String, dynamic> r) {
    final raw = '${r['name'] ?? ''}'.trim();
    final tag = RegExp(r'\(([^)]*)\)\s*$').firstMatch(raw)?.group(1);
    final total = _int(r['total_count']);
    // usage_count 는 '이용 불가' 좌석을 빼고 세는 경우가 있어, 잔여석(remain_count)으로 사용 좌석을 계산
    final remain = r['remain_count'] == null ? total - _int(r['usage_count']) : _int(r['remain_count']);
    return ReadingRoom(
      id: '${r['room_no']}',
      name: raw.replaceFirst(RegExp(r'\s*\([^)]*\)\s*$'), ''),
      tag: tag,
      total: total,
      used: (total - remain).clamp(0, total),
      floor: r['floor_name'] as String?,
      openTime: r['open_time'] as String?,
      closeTime: r['close_time'] as String?,
    );
  }

  /// 좌석 서버의 좌석 목록 → Seat 목록. 필요한 칸만 읽는다(이용자 정보는 버림).
  /// 좌표(x_pos, y_pos)는 2부터 시작하므로 왼쪽 위가 (0, 0)이 되게 옮긴다.
  List<Seat> _seatsFromSeatApi(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const [];
    final minX = items.map((s) => _int(s['x_pos'])).reduce((a, b) => a < b ? a : b);
    final minY = items.map((s) => _int(s['y_pos'])).reduce((a, b) => a < b ? a : b);
    return [
      for (final s in items)
        Seat(
          no: _int(s['number']),
          // 좌석 서버 화면(room.min.js)과 같은 규칙: seat_type 9 = 이용 불가, use_type 1 = 이용중
          status: _int(s['seat_type']) == 9
              ? SeatStatus.unavailable
              : (_int(s['use_type']) == 1 ? SeatStatus.used : SeatStatus.available),
          x: (_int(s['x_pos']) - minX).toDouble(),
          y: (_int(s['y_pos']) - minY).toDouble(),
        ),
    ]..sort((a, b) => a.no.compareTo(b.no));
  }

  static int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  /// 좌석 서버 응답 {"result":{"CODE":"200","items":[...]}} 에서 items 만 꺼냄
  Future<List<Map<String, dynamic>>> _seatItems(String path) async {
    final j = await _getUrl(Uri.parse('$seatApi$path'));
    final result = j['result'];
    if (result is! Map || '${result['CODE']}' != '200') {
      throw const HttpException('좌석 서버가 정상 응답을 주지 않았어요');
    }
    return [for (final e in (result['items'] as List? ?? const [])) (e as Map).cast<String, dynamic>()];
  }

  Future<RoomDetail> _sampleRoom(String id) async {
    final seed = sample.roomSeeds.firstWhere((r) => r.id == id);
    final layout = sample.layoutFor(id);
    final status = sample.snapshotStatus(id);
    final seats = _withMySeat(id, [
      for (final e in layout.entries) Seat(no: e.key, status: status[e.key]!, x: e.value.$1, y: e.value.$2),
    ]);
    final free = seats.where((s) => s.status == SeatStatus.available).length;
    return RoomDetail(
      room: ReadingRoom(id: id, name: seed.name, tag: seed.tag, total: seed.total, used: seed.total - free),
      seats: seats,
      exactLayout: id == '3',
      updatedAt: DateTime.now(),
    );
  }

  List<Seat> _withMySeat(String roomId, List<Seat> seats) {
    final mine = mySeat;
    if (mine == null || mine.roomId != roomId) return seats;
    return [for (final s in seats) s.no == mine.no ? s.copyWith(status: SeatStatus.mine) : s];
  }

  /// 내 좌석 표시 (기기 메모리에만 저장. 실제 배정·반납은 키오스크에서)
  Future<void> assignSeat(String roomId, int no) async {
    mySeat = MySeat(roomId: roomId, no: no, at: DateTime.now());
    notifyListeners();
  }

  Future<void> releaseSeat() async {
    mySeat = null;
    notifyListeners();
  }

  // ---------------- 공지 ----------------

  Future<List<Notice>> notices() => _liveOr(
        () async {
          final j = await _get('/api/notices');
          return [for (final n in j['items'] as List) Notice.fromJson(n as Map<String, dynamic>)];
        },
        () async => sample.sampleNotices,
      );

  // ---------------- 검색 ----------------

  Future<List<Book>> search(String query, {BookType? type, bool availableOnly = false, Campus? campus}) async {
    // 실시간 검색은 서버의 parseSearch 를 채운 뒤 연결 (server/src/library.js)
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final q = query.replaceAll(' ', '').toLowerCase();
    return sample.sampleBooks.where((b) {
      if (q.isNotEmpty && !'${b.title}${b.author}${b.subject}'.replaceAll(' ', '').toLowerCase().contains(q)) return false;
      if (type != null && b.type != type) return false;
      if (campus != null && b.type == BookType.book && !b.holdings.any((h) => h.campus == campus)) return false;
      if (availableOnly && b.type == BookType.book && b.statusFor(campus) != HoldingStatus.available) return false;
      return true;
    }).toList();
  }

  Book? bookById(String id) => sample.sampleBooks.where((b) => b.id == id).firstOrNull;

  void addRecent(String q) {
    recentSearches
      ..remove(q)
      ..insert(0, q);
    if (recentSearches.length > 8) recentSearches.removeLast();
    notifyListeners();
  }

  void toggleFavorite(String bookId) {
    favorites.contains(bookId) ? favorites.remove(bookId) : favorites.add(bookId);
    notifyListeners();
  }

  // ---------------- 내 서재 (로그인 연동 전: 샘플 계정) ----------------

  List<Loan> get loans => List.unmodifiable(_loans);
  List<Reservation> get reservations => sample.sampleReservations();

  /// 연장 (시연 동작: 반납일 +7일)
  Loan renew(Book book) {
    final i = _loans.indexWhere((l) => l.book.id == book.id);
    final loan = _loans[i];
    if (loan.renewLeft <= 0) throw StateError('남은 연장 횟수가 없어요');
    _loans[i] = loan.copyWith(due: loan.due.add(const Duration(days: 7)), renewLeft: loan.renewLeft - 1);
    notifyListeners();
    return _loans[i];
  }

  void updateProfile(StudentProfile p) {
    profile = p;
    notifyListeners();
  }

  // ---------------- 표지 ----------------

  final Map<String, Future<String?>> _coverCache = {};

  /// 표지 이미지 주소. 서버가 카카오·국립중앙도서관에서 찾아 준다.
  /// 이미지 파일은 저장하지 않고 주소만 앱 실행 동안 기억한다.
  Future<String?> coverUrl(Book book) {
    if (!isLive) return Future.value(null);
    return _coverCache.putIfAbsent(book.id, () async {
      try {
        final params = book.isbn != null ? 'isbn=${book.isbn}' : 'title=${Uri.encodeQueryComponent(book.title)}&author=${Uri.encodeQueryComponent(book.author)}';
        final j = await _get('/api/covers?$params');
        return j['url'] as String?;
      } catch (_) {
        return null; // 표지가 없으면 단색 표지를 보여 줌
      }
    });
  }

  // ---------------- 공통 ----------------

  /// live 를 시도하고 실패하면 fallback(샘플). enabled 를 안 주면 중계 서버 설정(isLive)을 따른다.
  Future<T> _liveOr<T>(Future<T> Function() live, Future<T> Function() fallback, {bool? enabled}) async {
    if (!(enabled ?? isLive)) return fallback();
    try {
      final r = await live();
      if (lastError != null) {
        lastError = null;
        notifyListeners();
      }
      return r;
    } catch (e) {
      final msg = switch (e) {
        TimeoutException() => '서버 응답이 늦어요',
        SocketException() => '서버에 연결할 수 없어요',
        HttpException(:final message) => message,
        FormatException() => '서버 응답을 읽지 못했어요',
        _ => '$e',
      };
      // 같은 오류로 다시 알리면 화면이 또 불러오기를 반복하므로 바뀔 때만 알림
      if (msg != lastError) {
        lastError = msg;
        notifyListeners();
      }
      return fallback();
    }
  }

  Future<Map<String, dynamic>> _get(String path) => _getUrl(Uri.parse('$apiBase$path'));

  Future<Map<String, dynamic>> _getUrl(Uri url) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final req = await client.getUrl(url);
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final res = await req.close().timeout(const Duration(seconds: 8));
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) throw HttpException('서버 응답 ${res.statusCode}');
      return jsonDecode(body) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }
}
