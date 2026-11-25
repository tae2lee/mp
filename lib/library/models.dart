/// 도서관 탭 데이터 모델. 중계 서버(/api/...) JSON 과 같은 이름을 쓴다.
library;

enum Campus {
  chungju('중앙도서관', '충주', '27469', '충청북도 충주시 대학로 50', '043-841-5064'),
  jeungpyeong('증평도서관', '증평', '27909', '충청북도 증평군 대학로 61', '043-820-5097'),
  uiwang('의왕도서관', '의왕', '16106', '경기도 의왕시 철도박물관로 157', '031-460-0521');

  const Campus(this.label, this.short, this.zip, this.address, this.tel);
  final String label, short, zip, address, tel;

  /// 화면에 쓰는 정식 이름. 예: 충주 중앙도서관, 증평도서관
  String get fullName => this == Campus.chungju ? '충주 $label' : label;

  static Campus? byName(String? name) => Campus.values.where((c) => c.name == name).firstOrNull;
}

class ReadingRoom {
  const ReadingRoom({
    required this.id,
    required this.name,
    this.tag,
    required this.total,
    required this.used,
    this.floor,
    this.openTime,
    this.closeTime,
  });

  final String id;
  final String name;
  final String? tag; // 예: 콘센트
  final int total;
  final int used; // 이용 불가 좌석도 포함 (좌석 서버의 remain_count 기준으로 계산)
  final String? floor; // 예: 3층
  final String? openTime, closeTime; // 'HHmm' (예: '0500', '2359')

  /// 운영 시간 문자열. 예: 07:00 ~ 23:00
  String? get hours => openTime == null || closeTime == null ? null : '${_hm(openTime!)} ~ ${_hm(closeTime!)}';

  /// 지금 운영 중인지. 시간을 모르면 true
  bool isOpenAt(DateTime t) {
    if (openTime == null || closeTime == null) return true;
    final now = t.hour * 100 + t.minute;
    return now >= int.parse(openTime!) && now <= int.parse(closeTime!);
  }

  static String _hm(String s) => s.length == 4 ? '${s.substring(0, 2)}:${s.substring(2)}' : s;

  int get free => total - used;
  double get rate => total == 0 ? 0 : used / total;

  /// 이용률로 나눈 혼잡도
  Congestion get congestion => rate < 0.5 ? Congestion.low : (rate < 0.8 ? Congestion.mid : Congestion.high);

  String get shortName => name.replaceAll(' 학습 ZONE', '');

  factory ReadingRoom.fromJson(Map<String, dynamic> j) => ReadingRoom(
        id: '${j['id']}',
        name: j['name'] as String,
        tag: j['tag'] as String?,
        total: (j['total'] as num).toInt(),
        used: (j['used'] as num).toInt(),
      );
}

enum Congestion {
  low('여유'),
  mid('보통'),
  high('혼잡');

  const Congestion(this.label);
  final String label;
}

enum SeatStatus { available, used, unavailable }

class Seat {
  const Seat({required this.no, required this.status, this.x, this.y});

  final int no;
  final SeatStatus status;
  final double? x, y; // 좌석 1칸 = 1 단위. 없으면 화면에서 격자로 배치

  Seat copyWith({SeatStatus? status}) => Seat(no: no, status: status ?? this.status, x: x, y: y);

  factory Seat.fromJson(Map<String, dynamic> j) => Seat(
        no: (j['no'] as num).toInt(),
        status: SeatStatus.values.firstWhere((s) => s.name == j['status'], orElse: () => SeatStatus.unavailable),
        x: (j['x'] as num?)?.toDouble(),
        y: (j['y'] as num?)?.toDouble(),
      );
}

class RoomDetail {
  const RoomDetail({required this.room, required this.seats, required this.exactLayout, required this.updatedAt, this.zone});
  final ReadingRoom room;
  final List<Seat> seats;
  final bool exactLayout; // false 면 "예시 배치" 안내를 띄움
  final DateTime updatedAt;

  /// 샘플 배치의 구역 이름(예: A구역). 있으면 좌석 번호를 A-17 처럼 쓰고 창가·출입구를 표시
  final String? zone;

  String seatLabel(int no) => zone == null ? '$no' : '${zone!.substring(0, 1)}-$no';
}

enum HoldingStatus { available, loaned, reference }

class Holding {
  const Holding({required this.campus, required this.location, required this.callNo, required this.status, this.due, this.regNo});
  final Campus campus;
  final String location; // 예: 3층 일반자료실
  final String callNo;
  final HoldingStatus status;
  final DateTime? due;
  final String? regNo; // 등록번호

  /// 층만 (예: 3층)
  String get floor => location.split(' ').first;
}

enum BookType { book, ebook }

class Book {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.year,
    required this.subject,
    this.type = BookType.book,
    this.isbn,
    this.pages,
    this.ebookFormat,
    this.coverColor = 0xFF5B6070,
    this.holdings = const [],
  });

  final String id;
  final String title;
  final String author;
  final int year;
  final String subject;
  final BookType type;
  final String? isbn; // 표지 이미지를 찾을 때 사용
  final int? pages;
  final String? ebookFormat; // 예: EPUB
  final int coverColor; // 표지가 없을 때 쓰는 단색
  final List<Holding> holdings;

  /// 목록에 보여줄 대표 상태
  HoldingStatus? statusFor(Campus? campus) {
    if (type == BookType.ebook) return null;
    final pool = campus == null ? holdings : holdings.where((h) => h.campus == campus).toList();
    final list = pool.isEmpty ? holdings : pool;
    if (list.any((h) => h.status == HoldingStatus.available)) return HoldingStatus.available;
    if (list.isNotEmpty && list.every((h) => h.status == HoldingStatus.reference)) return HoldingStatus.reference;
    return HoldingStatus.loaned;
  }
}

class Loan {
  const Loan({required this.book, required this.loanedAt, required this.due, required this.renewLeft});
  final Book book;
  final DateTime loanedAt;
  final DateTime due;
  final int renewLeft;

  Loan copyWith({DateTime? due, int? renewLeft}) =>
      Loan(book: book, loanedAt: loanedAt, due: due ?? this.due, renewLeft: renewLeft ?? this.renewLeft);
}

class Reservation {
  const Reservation({required this.book, required this.campus, required this.order});
  final Book book;
  final Campus campus;
  final int order;
}

class Notice {
  const Notice({required this.title, required this.date, required this.campus, this.url});
  final String title;
  final DateTime date;
  final String campus; // 공통 / 충주 / 증평 / 의왕
  final String? url;

  factory Notice.fromJson(Map<String, dynamic> j) => Notice(
        title: j['title'] as String,
        date: DateTime.parse(j['date'] as String),
        campus: (j['campus'] as String?) ?? '공통',
        url: j['url'] as String?,
      );
}

class StudentProfile {
  const StudentProfile({required this.name, required this.dept, required this.studentNo});
  final String name, dept, studentNo;
}
