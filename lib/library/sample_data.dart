/// 샘플 데이터
/// - 열람실·좌석 배치·대출·공지: Figma(도서관 리디자인) 화면에 있는 값 그대로
/// - 열람실 샘플은 실제 좌석 서버(210.119.152.17)에 연결되지 않을 때만 쓰인다
/// - 도서: 서명·저자는 실제 도서, 청구기호·소장 위치·대출 상태는 시연용.
///   isbn 을 채우면 표지를 더 정확하게 찾는다(비우면 서명+저자로 찾음).
library;

import 'dart:math';

import 'models.dart';

class RoomSeed {
  const RoomSeed(this.id, this.name, this.tag, this.total, this.used, {this.open = '0700', this.close = '2300'});
  final String id, name;
  final String? tag;
  final int total, used; // 열람실 전체 좌석과 사용 좌석 (배치도는 그중 A구역 48석만)
  final String open, close;
}

/// Figma 01·04 화면과 같은 값. 실제 좌석 서버에 연결되지 않을 때만 쓰인다
const roomSeeds = [
  RoomSeed('1', '제1열람실', null, 120, 78),
  RoomSeed('2', '제2열람실', null, 96, 88),
  RoomSeed('3', '노트북열람실', null, 48, 23),
];

const sampleZone = 'A구역';

/// Figma 04 'A구역 좌석 배치도': 한 줄 8석(4석마다 통로), 3줄씩 두 묶음
/// 좌표 1칸 = 좌석 30 + 간격 6. 통로 14, 묶음 사이 8+6
Map<int, (double, double)> layoutFor(String roomId) {
  const aisle = 14 / 36, block = 14 / 36;
  return {
    for (var i = 0; i < 48; i++)
      i + 1: ((i % 8) + (i % 8 >= 4 ? aisle : 0.0), (i ~/ 8) + (i ~/ 8 >= 3 ? block : 0.0)),
  };
}

/// Figma 04 그대로의 빈 좌석 (제1열람실). 다른 방은 사용 비율만 맞춘 고정 난수
const _figmaFree = {3, 6, 10, 13, 16, 17, 20, 23, 24, 27, 30, 31, 34, 37, 38, 41, 44, 45, 48};

Map<int, SeatStatus> snapshotStatus(String roomId) {
  if (roomId == '1') {
    return {for (var n = 1; n <= 48; n++) n: _figmaFree.contains(n) ? SeatStatus.available : SeatStatus.used};
  }
  final seed = roomSeeds.firstWhere((r) => r.id == roomId);
  final rnd = Random(int.parse(roomId) * 97 + 13);
  return {for (var n = 1; n <= 48; n++) n: rnd.nextDouble() < seed.used / seed.total ? SeatStatus.used : SeatStatus.available};
}

final sampleNotices = [
  Notice(title: '증평도서관 추천도서 "AI 시대에서 살아남기"', date: DateTime(2026, 9, 24), campus: '증평'),
  Notice(title: '중간고사 기간 열람실 연장 운영 안내', date: DateTime(2026, 9, 22), campus: '충주'),
  Notice(title: '[중앙, 증평, 의왕] 2026학년도 독후감 공모', date: DateTime(2026, 9, 18), campus: '공통'),
  Notice(title: '2026년 대학도서관평가 이용자 만족도 조사', date: DateTime(2026, 9, 16), campus: '공통'),
  Notice(title: '<KISS> 2026학년도 9-11월 온라인 교육', date: DateTime(2026, 9, 15), campus: '공통'),
];

const popularKeywords = ['인공지능', '히가시노 게이고', '토익', '플러터'];

DateTime _day(int offset) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).add(Duration(days: offset));
}

Holding _h(Campus c, String loc, String callNo, HoldingStatus s, [int? dueIn, String? regNo]) =>
    Holding(campus: c, location: loc, callNo: callNo, status: s, due: dueIn == null ? null : _day(dueIn), regNo: regNo);

final sampleBooks = <Book>[
  // Figma 02·03 화면의 책 (가상의 책)
  Book(id: 'f01', title: 'AI 시대에서 살아남기', author: '김지훈', year: 2025, subject: '컴퓨터과학 · 인공지능', isbn: '979-11-0000-000-0', pages: 248, coverColor: 0xFF0F766E, holdings: [
    _h(Campus.chungju, '3층 일반자료실', '004.73 김78ㅇ', HoldingStatus.available, null, 'EM0123456'),
    _h(Campus.jeungpyeong, '2층 자료실', '004.73 김78ㅇ', HoldingStatus.loaned, 11, 'JM0045678'),
  ]),
  Book(id: 'f02', title: '처음 배우는 인공지능', author: '박서연', year: 2024, subject: '컴퓨터과학 · 인공지능', coverColor: 0xFF1F4E8C, holdings: [
    _h(Campus.chungju, '3층 일반자료실', '004.73 박54ㅊ', HoldingStatus.loaned, 11, 'EM0119876'),
  ]),
  const Book(id: 'f03', title: '인공지능과 윤리: 기술은 누구의 편인가', author: '이도현', year: 2023, subject: '인공지능 · 윤리', type: BookType.ebook, ebookFormat: 'EPUB', coverColor: 0xFF6D3FB5),
  Book(id: 'f04', title: '파이썬으로 배우는 인공지능 입문', author: '최민준', year: 2022, subject: '컴퓨터과학 · 인공지능', coverColor: 0xFFC2410C, holdings: [
    _h(Campus.chungju, '4층 일반자료실', '005.133 최38ㅍ', HoldingStatus.available, null, 'EM0098765'),
  ]),

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
  // Figma 06: 09.18 대출 → 10.02 반납(D-5), 09.23 대출 → 10.14 반납(D-17)
  return [
    Loan(book: b('b04'), loanedAt: _day(-9), due: _day(5), renewLeft: 1),
    Loan(book: b('b06'), loanedAt: _day(-4), due: _day(17), renewLeft: 1),
  ];
}

/// 지난 대출 이력 (Figma 06 '이번 학기 7권 읽었어요')
List<Book> sampleHistory() => [for (final id in ['b05', 'b07', 'b10', 'b11', 'b12', 'b01', 'b03']) sampleBooks.firstWhere((x) => x.id == id)];

List<Reservation> sampleReservations() => [
      Reservation(book: sampleBooks.firstWhere((x) => x.id == 'b02'), campus: Campus.chungju, order: 1),
    ];

const sampleProfile = StudentProfile(name: '김교통', dept: '컴퓨터공학과', studentNo: '2023123456');
