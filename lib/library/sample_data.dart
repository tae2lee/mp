/// 샘플 데이터
/// - 열람실 이름·좌석 수, 제3협업 학습 ZONE 배치(427~534), 공지, 캠퍼스 연락처:
///   2026-09-29 도서관 홈페이지·좌석 현황 화면 캡처 기준
/// - 열람실별 좌석 번호: 1~300 / 301~426 / 427~534 / 캐럴실 1~12 (2026-10-27 좌석 서버 확인)
/// - 실제 좌석 서버(210.119.152.17)에 연결되지 않을 때만 쓰인다
/// - 도서: 서명·저자는 실제 도서, 청구기호·소장 위치·대출 상태는 시연용.
///   isbn 을 채우면 표지를 더 정확하게 찾는다(비우면 서명+저자로 찾음).
library;

import 'dart:math';

import 'models.dart';

class RoomSeed {
  const RoomSeed(this.id, this.name, this.tag, this.total, this.start);
  final String id, name;
  final String? tag;
  final int total, start;
}

const roomSeeds = [
  RoomSeed('1', '제1집중 학습 ZONE', '콘센트', 300, 1),
  RoomSeed('2', '제2집중 학습 ZONE', null, 126, 301),
  RoomSeed('3', '제3협업 학습 ZONE', '콘센트', 108, 427),
  RoomSeed('4', '캐럴실', null, 12, 1), // 캐럴실은 1~12번 (좌석 서버 확인)
];

/// 캡처 기준 사용 중(빨강) / 이용 불가(회색) 좌석
const zone3Used = [438, 451, 453, 484, 486, 498, 516, 522, 534];
const zone3Unavailable = [436, 437];
const otherRoomsUsed = {'1': 25, '2': 1, '4': 3};

/// 제3협업 학습 ZONE 실제 배치: (x, y, 위에서 아래로 나열한 열들)
const _zone3Blocks = <(int, int, List<List<int>>)>[
  (6, 0, [[427, 428, 429], [430, 431, 432]]),
  (11, 0, [[433, 434, 435], [436, 437, 438]]),
  (6, 4, [[439, 440, 441], [442, 443, 444]]),
  (11, 4, [[445, 446, 447], [448, 449, 450]]),
  (0, 8, [[451, 452, 453], [454, 455, 456]]),
  (3, 8, [[457, 458, 459], [460, 461, 462]]),
  (6, 8, [[463, 466], [464, 467], [465, 468]]),
  (10, 8, [[469, 472], [470, 473], [471, 474]]),
  (14, 8, [[475, 476, 477], [478, 479, 480]]),
  (17, 8, [[481, 482, 483], [484, 485, 486]]),
  (0, 12, [[487, 488, 489], [490, 491, 492]]),
  (3, 12, [[493, 494, 495], [496, 497, 498]]),
  (14, 12, [[499, 500, 501], [502, 503, 504]]),
  (17, 12, [[505, 506, 507], [508, 509, 510]]),
  (0, 16, [[511, 512, 513], [514, 515, 516]]),
  (3, 16, [[517, 518, 519], [520, 521, 522]]),
  (14, 16, [[523, 524, 525], [526, 527, 528]]),
  (17, 16, [[529, 530, 531], [532, 533, 534]]),
];

/// 좌석 번호 → (x, y). 배치를 모르는 열람실은 2×3 책상 묶음 격자(예시 배치)
Map<int, (double, double)> layoutFor(String roomId) {
  final out = <int, (double, double)>{};
  if (roomId == '3') {
    for (final (bx, by, cols) in _zone3Blocks) {
      for (var ci = 0; ci < cols.length; ci++) {
        for (var ri = 0; ri < cols[ci].length; ri++) {
          out[cols[ci][ri]] = ((bx + ci).toDouble(), (by + ri).toDouble());
        }
      }
    }
    return out;
  }
  final seed = roomSeeds.firstWhere((r) => r.id == roomId);
  if (roomId == '4') {
    for (var i = 0; i < seed.total; i++) {
      out[seed.start + i] = ((i % 6) * 1.25, (i ~/ 6) * 2.0);
    }
    return out;
  }
  for (var i = 0; i < seed.total; i++) {
    final b = i ~/ 6, k = i % 6;
    out[seed.start + i] = (((b % 6) * 3 + k ~/ 3).toDouble(), ((b ~/ 6) * 4 + k % 3).toDouble());
  }
  return out;
}

/// 캡처 시점의 좌석 상태. 제3협업은 캡처 그대로, 나머지는 사용 좌석 수만 맞춘 고정 난수
Map<int, SeatStatus> snapshotStatus(String roomId) {
  final layout = layoutFor(roomId);
  final status = {for (final no in layout.keys) no: SeatStatus.available};
  if (roomId == '3') {
    for (final n in zone3Used) {
      status[n] = SeatStatus.used;
    }
    for (final n in zone3Unavailable) {
      status[n] = SeatStatus.unavailable;
    }
  } else {
    final rnd = Random(int.parse(roomId) * 97 + 13);
    final nums = layout.keys.toList();
    var left = otherRoomsUsed[roomId] ?? 0;
    while (left > 0) {
      final n = nums[rnd.nextInt(nums.length)];
      if (status[n] == SeatStatus.available) {
        status[n] = SeatStatus.used;
        left--;
      }
    }
  }
  return status;
}

final sampleNotices = [
  Notice(title: '[중앙, 증평, 의왕] 2026학년도 독후감', date: DateTime(2026, 9, 28), campus: '공통'),
  Notice(title: '증평도서관 추천도서 "AI 시대에서 살아남기"', date: DateTime(2026, 9, 17), campus: '증평'),
  Notice(title: '2026년 대학도서관평가 이용자 만족도', date: DateTime(2026, 9, 16), campus: '공통'),
  Notice(title: '<KISS> 2026학년도 9-11월 온라인 교육', date: DateTime(2026, 9, 15), campus: '공통'),
  Notice(title: '<EndNote> 설문참여 이벤트', date: DateTime(2026, 9, 14), campus: '공통'),
];

const popularKeywords = ['ZAP', '히가시노 게이고', '토익'];

DateTime _day(int offset) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).add(Duration(days: offset));
}

Holding _h(Campus c, String loc, String callNo, HoldingStatus s, [int? dueIn]) =>
    Holding(campus: c, location: loc, callNo: callNo, status: s, due: dueIn == null ? null : _day(dueIn));

final sampleBooks = <Book>[
  Book(id: 'b01', title: '나미야 잡화점의 기적', author: '히가시노 게이고', year: 2012, subject: '일본소설', coverColor: 0xFF2C5F8A, holdings: [
    _h(Campus.chungju, '2층 문학자료실', '833.6 히12ㄴ', HoldingStatus.available),
    _h(Campus.jeungpyeong, '2층 자료실', '833.6 히12ㄴ c.2', HoldingStatus.loaned, 6),
  ]),
  Book(id: 'b02', title: '용의자 X의 헌신', author: '히가시노 게이고', year: 2006, subject: '일본소설', coverColor: 0xFF5A2A6B, holdings: [
    _h(Campus.chungju, '2층 문학자료실', '833.6 히12ㅇ', HoldingStatus.loaned, 9),
  ]),
  Book(id: 'b03', title: '백야행', author: '히가시노 게이고', year: 2004, subject: '일본소설', coverColor: 0xFF5F6B75, holdings: [
    _h(Campus.chungju, '2층 문학자료실', '833.6 히12ㅂ', HoldingStatus.available),
    _h(Campus.uiwang, '1층 자료실', '833.6 히12ㅂ', HoldingStatus.available),
  ]),
  Book(id: 'b04', title: '처음 배우는 플러터', author: '유동환', year: 2020, subject: '모바일 프로그래밍', coverColor: 0xFF1F4E8C, holdings: [
    _h(Campus.chungju, '3층 일반자료실', '005.1 유25ㅊ', HoldingStatus.loaned, 3),
  ]),
  Book(id: 'b05', title: 'Do it! 플러터 앱 프로그래밍', author: '조준수', year: 2021, subject: '모바일 프로그래밍', coverColor: 0xFF0F766E, holdings: [
    _h(Campus.chungju, '3층 일반자료실', '005.1 조76ㄷ', HoldingStatus.available),
    _h(Campus.chungju, '3층 일반자료실', '005.1 조76ㄷ c.2', HoldingStatus.available),
  ]),
  Book(id: 'b06', title: '데이터베이스 개론', author: '김연희', year: 2019, subject: '데이터베이스', coverColor: 0xFF2E7D5B, holdings: [
    _h(Campus.chungju, '3층 일반자료실', '005.74 김64ㄷ', HoldingStatus.loaned, 15),
    _h(Campus.jeungpyeong, '2층 자료실', '005.74 김64ㄷ', HoldingStatus.available),
  ]),
  Book(id: 'b07', title: '이것이 자바다', author: '신용권', year: 2022, subject: '프로그래밍 언어', coverColor: 0xFFC2410C, holdings: [
    _h(Campus.chungju, '3층 일반자료실', '005.133 신66ㅇ', HoldingStatus.available),
  ]),
  Book(id: 'b08', title: '혼자 공부하는 파이썬', author: '윤인성', year: 2022, subject: '프로그래밍 언어', coverColor: 0xFFB7791F, holdings: [
    _h(Campus.chungju, '3층 일반자료실', '005.133 윤68ㅎ', HoldingStatus.loaned, 11),
    _h(Campus.uiwang, '1층 자료실', '005.133 윤68ㅎ', HoldingStatus.available),
  ]),
  Book(id: 'b09', title: '인공지능: 현대적 접근방식', author: '스튜어트 러셀, 피터 노빅', year: 2021, subject: '인공지능', coverColor: 0xFF6D3FB5, holdings: [
    _h(Campus.chungju, '3층 일반자료실', '004.73 러57ㅇ', HoldingStatus.reference),
  ]),
  Book(id: 'b10', title: '코스모스', author: '칼 세이건', year: 2006, subject: '천문학', coverColor: 0xFF1B2A4A, holdings: [
    _h(Campus.chungju, '4층 인문사회자료실', '443 세68ㅋ', HoldingStatus.available),
  ]),
  Book(id: 'b11', title: '사피엔스', author: '유발 하라리', year: 2015, subject: '인류학', coverColor: 0xFFA3162B, holdings: [
    _h(Campus.chungju, '4층 인문사회자료실', '909 하292ㅅ', HoldingStatus.loaned, 4),
    _h(Campus.jeungpyeong, '2층 자료실', '909 하292ㅅ', HoldingStatus.available),
  ]),
  Book(id: 'b12', title: '데미안', author: '헤르만 헤세', year: 2009, subject: '독일소설', coverColor: 0xFF3F6212, holdings: [
    _h(Campus.uiwang, '1층 자료실', '853 헤56ㄷ', HoldingStatus.available),
  ]),
  const Book(id: 'e01', title: '혼자 공부하는 파이썬 (전자책)', author: '윤인성', year: 2022, subject: '프로그래밍 언어', type: BookType.ebook, coverColor: 0xFF2F6FEB),
  const Book(id: 'e02', title: '사피엔스 (전자책)', author: '유발 하라리', year: 2015, subject: '인류학', type: BookType.ebook, coverColor: 0xFF2F6FEB),
];

List<Loan> sampleLoans() {
  Book b(String id) => sampleBooks.firstWhere((x) => x.id == id);
  return [
    Loan(book: b('b04'), loanedAt: _day(-11), due: _day(3), renewLeft: 1),
    Loan(book: b('b06'), loanedAt: _day(-6), due: _day(15), renewLeft: 1),
  ];
}

List<Reservation> sampleReservations() => [
      Reservation(book: sampleBooks.firstWhere((x) => x.id == 'b02'), campus: Campus.chungju, order: 1),
    ];

const sampleProfile = StudentProfile(name: '김교통', dept: '컴퓨터공학과', studentNo: '2023123456');
