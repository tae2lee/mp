import 'package:flutter/material.dart';

/// 학교 대표색(적갈색). 앱 테마를 만들 때 ColorScheme.fromSeed(seedColor: knutRed) 로 쓴다.
const Color knutRed = Color(0xFFA3162B);

/// Figma 파일(도서관 리디자인)의 색 변수 color/* 를 그대로 옮긴 값
abstract final class LC {
  static const primary = Color(0xFFA3162B);
  static const primarySoft = Color(0xFFFBECEE);
  static const ink = Color(0xFF17191E);
  static const sub = Color(0xFF5B6070);
  static const mute = Color(0xFF9AA0AE);
  static const line = Color(0xFFE6E8EE);
  static const bg = Color(0xFFF4F5F8);
  static const white = Color(0xFFFFFFFF);
  static const green = Color(0xFF0E9F4F);
  static const greenSoft = Color(0xFFE5F6EC);
  static const amber = Color(0xFFD97A00);
  static const amberSoft = Color(0xFFFFF3DF);
  static const blue = Color(0xFF2F6FEB);
  static const blueSoft = Color(0xFFE8F0FE);
  static const seatUsed = Color(0xFFD5D9E0);
}

/// 대출 가능/대출 중, 좌석 상태 같은 "의미 색". 대표색과 따로 둔다.
/// 앱 테마에 extensions 로 넣지 않아도, 밝기(라이트/다크)에 맞는 기본값을 쓴다.
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.good,
    required this.goodContainer,
    required this.warn,
    required this.warnContainer,
    required this.info,
    required this.infoContainer,
    required this.seatUsed,
    required this.seatOff,
  });

  final Color good, goodContainer, warn, warnContainer, info, infoContainer, seatUsed, seatOff;

  static const light = StatusColors(
    good: Color(0xFF0E9F4F),
    goodContainer: Color(0xFFE5F6EC),
    warn: Color(0xFFB86500),
    warnContainer: Color(0xFFFFF3DF),
    info: Color(0xFF2F6FEB),
    infoContainer: Color(0xFFE8F0FE),
    seatUsed: Color(0xFFD63A45),
    seatOff: Color(0xFFD5D9E0),
  );
  static const dark = StatusColors(
    good: Color(0xFF3CCB7F),
    goodContainer: Color(0xFF173325),
    warn: Color(0xFFF2A93B),
    warnContainer: Color(0xFF382A12),
    info: Color(0xFF6E9BFF),
    infoContainer: Color(0xFF1B2A4A),
    seatUsed: Color(0xFFE0485E),
    seatOff: Color(0xFF3A3F4A),
  );

  @override
  StatusColors copyWith() => this;

  @override
  StatusColors lerp(ThemeExtension<StatusColors>? other, double t) => t < 0.5 ? this : (other as StatusColors? ?? this);
}

extension StatusColorsX on BuildContext {
  StatusColors get status {
    final theme = Theme.of(this);
    return theme.extension<StatusColors>() ?? (theme.brightness == Brightness.dark ? StatusColors.dark : StatusColors.light);
  }
}
