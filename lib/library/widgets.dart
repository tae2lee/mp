/// 도서관 탭 공통 위젯. 크기·색·글자는 Figma 파일(도서관 리디자인)의 값을 그대로 쓴다.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import 'library_colors.dart';
import 'library_repository.dart';
import 'models.dart';

// ---------------- 날짜 (intl 패키지 없이) ----------------
const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];
String two(int n) => n.toString().padLeft(2, '0');
String mmdd(DateTime d) => '${two(d.month)}.${two(d.day)}';
String mmddWd(DateTime d) => '${mmdd(d)} (${_weekdays[d.weekday - 1]})';
String hhmm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

int daysUntil(DateTime d) {
  final now = DateTime.now();
  return DateTime(d.year, d.month, d.day).difference(DateTime(now.year, now.month, now.day)).inDays;
}

String ddayText(DateTime due) {
  final d = daysUntil(due);
  if (d < 0) return '연체 ${-d}일';
  if (d == 0) return 'D-DAY';
  return 'D-$d';
}

/// 반납일이 7일 이내면 강조 (Figma: D-5 빨강, D-17 회색)
bool isUrgent(DateTime due) => daysUntil(due) <= 7;

// ---------------- 글자 ----------------
const w4 = FontWeight.w400, w5 = FontWeight.w500, w7 = FontWeight.w700, w9 = FontWeight.w900;

/// Figma 글자 스타일: Noto Sans KR, 줄 높이 [height], 자간 [ls](px)
TextStyle ts(double size, FontWeight weight, Color color, {double height = 1.4, double? ls}) => GoogleFonts.notoSansKr(
      textStyle: const TextStyle(leadingDistribution: TextLeadingDistribution.even),
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: ls,
    );

// ---------------- 테마 · 화면 이동 ----------------
ThemeData _buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: LC.primary, primary: LC.primary, surface: LC.white),
    scaffoldBackgroundColor: LC.bg,
    splashFactory: InkRipple.splashFactory,
  );
  return base.copyWith(
    textTheme: GoogleFonts.notoSansKrTextTheme(base.textTheme),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: LC.primary, selectionHandleColor: LC.primary),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: LC.ink,
      contentTextStyle: ts(14, w5, LC.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

final ThemeData libraryTheme = _buildTheme();

/// 앱 전체 테마(main.dart)와 상관없이 도서관 화면은 Figma 색·글꼴을 쓴다
Widget libraryThemed(Widget child) => AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Theme(data: libraryTheme, child: child),
    );

Future<T?> pushLibrary<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(MaterialPageRoute<T>(builder: (_) => libraryThemed(page)));

// ---------------- 아이콘 (Figma에서 내보낸 SVG) ----------------
class Ico extends StatelessWidget {
  const Ico(this.name, {super.key, this.size = 24, this.color});
  final String name;
  final double size;
  final Color? color; // 지정하면 SVG 선 색을 바꿈

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/library/icons/$name.svg',
        width: size,
        height: size,
        colorFilter: color == null ? null : ColorFilter.mode(color!, BlendMode.srcIn),
      );
}

/// 40×40 터치 영역 안의 아이콘 버튼 (Figma btn/*)
class IconBox extends StatelessWidget {
  const IconBox(this.icon, {super.key, this.onTap, this.size = 24, this.box = 40, this.color, this.tooltip});
  final String icon;
  final VoidCallback? onTap;
  final double size, box;
  final Color? color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    Widget w = SizedBox(
      width: box,
      height: box,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: Center(child: Ico(icon, size: size, color: color))),
      ),
    );
    if (tooltip != null) w = Tooltip(message: tooltip!, child: w);
    return w;
  }
}

// ---------------- 상자 ----------------
/// 색·모서리·테두리·눌림 효과를 한 번에. 테두리는 Figma처럼 안쪽에 그려 크기를 바꾸지 않는다.
class Box extends StatelessWidget {
  const Box({
    super.key,
    required this.child,
    this.color,
    this.radius = 0,
    this.borderRadius,
    this.padding,
    this.border,
    this.onTap,
    this.width,
    this.height,
    this.alignment,
  });

  final Widget child;
  final Color? color;
  final double radius;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final BorderSide? border;
  final VoidCallback? onTap;
  final double? width, height;
  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(radius);
    Widget c = child;
    if (alignment != null) {
      c = Align(alignment: alignment!, widthFactor: width == null ? 1 : null, heightFactor: height == null ? 1 : null, child: c);
    }
    if (padding != null) c = Padding(padding: padding!, child: c);
    if (onTap != null) {
      c = Material(type: MaterialType.transparency, child: InkWell(onTap: onTap, borderRadius: br, child: c));
    }
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: color, borderRadius: br),
      foregroundDecoration: border == null ? null : BoxDecoration(border: Border.fromBorderSide(border!), borderRadius: br),
      child: c,
    );
  }
}

/// 흰 카드 (Figma Card: radius 18)
class CardBox extends StatelessWidget {
  const CardBox({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.onTap});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Box(color: LC.white, radius: 18, padding: padding, onTap: onTap, child: child);
}

/// 카드 안 줄 사이 1px 선
const rowDivider = Border(top: BorderSide(color: LC.line));

// ---------------- 배지 ----------------
/// 작은 사각 배지 (혼잡도, D-day, 캠퍼스)
class Tag extends StatelessWidget {
  const Tag(this.text,
      {super.key,
      required this.color,
      required this.background,
      this.fontSize = 11,
      this.weight = w7,
      this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      this.radius = 5});
  final String text;
  final Color color, background;
  final double fontSize;
  final FontWeight weight;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(radius)),
        child: Text(text, style: ts(fontSize, weight, color), maxLines: 1),
      );
}

/// 대출 상태 배지 (Figma Badge: 점 + 글자)
class HoldingBadge extends StatelessWidget {
  const HoldingBadge(this.status, {super.key});
  final HoldingStatus? status; // null = 전자자료

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg, dot) = switch (status) {
      HoldingStatus.available => ('대출가능', LC.green, LC.greenSoft, 'dot_green'),
      HoldingStatus.loaned => ('대출중', LC.amber, LC.amberSoft, 'dot_amber'),
      HoldingStatus.reference => ('열람전용', LC.sub, LC.bg, null),
      null => ('전자자료', LC.blue, LC.blueSoft, 'dot_blue'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        dot == null
            ? Container(width: 6, height: 6, decoration: const BoxDecoration(color: LC.sub, shape: BoxShape.circle))
            : Ico(dot, size: 6),
        const SizedBox(width: 4),
        Text(label, style: ts(11, w7, fg)),
      ]),
    );
  }
}

Color congestionColor(Congestion level) => switch (level) {
      Congestion.low => LC.green,
      Congestion.mid => LC.amber,
      Congestion.high => LC.primary,
    };

class CongestionTag extends StatelessWidget {
  const CongestionTag(this.level, {super.key});
  final Congestion level;

  @override
  Widget build(BuildContext context) => Tag(
        level.label,
        color: congestionColor(level),
        background: switch (level) {
          Congestion.low => LC.greenSoft,
          Congestion.mid => LC.amberSoft,
          Congestion.high => LC.primarySoft,
        },
      );
}

/// D-day 배지. [big] 은 내 서재 카드용(12px)
class DdayTag extends StatelessWidget {
  const DdayTag(this.due, {super.key, this.big = false});
  final DateTime due;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final urgent = isUrgent(due);
    return Tag(
      ddayText(due),
      color: urgent ? LC.primary : LC.sub,
      background: urgent ? LC.primarySoft : LC.bg,
      fontSize: big ? 12 : 11,
      weight: big ? w9 : w7,
      padding: big ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2) : const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      radius: big ? 6 : 5,
    );
  }
}

// ---------------- 버튼 ----------------
enum BtnKind { primary, outline, soft }

/// Figma Button. 기본은 높이 52, 모서리 14, 15px 굵은 글자
class Btn extends StatelessWidget {
  const Btn(
    this.label, {
    super.key,
    this.onTap,
    this.kind = BtnKind.primary,
    this.icon,
    this.height = 52,
    this.radius = 14,
    this.fontSize = 15,
    this.padding = const EdgeInsets.symmetric(horizontal: 18),
  });

  final String label;
  final VoidCallback? onTap;
  final BtnKind kind;
  final String? icon;
  final double? height; // null 이면 글자 높이 + padding
  final double radius, fontSize;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (kind) {
      BtnKind.primary => (LC.primary, LC.white, null),
      BtnKind.outline => (LC.white, LC.ink, const BorderSide(color: LC.line)),
      BtnKind.soft => (LC.primarySoft, LC.primary, null),
    };
    final box = Box(
      height: height,
      alignment: Alignment.center,
      color: bg,
      radius: radius,
      border: border,
      padding: padding,
      onTap: onTap,
      child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
        if (icon != null) ...[Ico(icon!, size: 18), const SizedBox(width: 6)],
        Text(label, style: ts(fontSize, w7, fg), maxLines: 1),
      ]),
    );
    return onTap == null ? Opacity(opacity: 0.4, child: box) : box;
  }
}

// ---------------- 머리말 ----------------
/// 흰 머리말. 상태 표시줄 높이만큼 위를 띄운다
class LibHeader extends StatelessWidget {
  const LibHeader({super.key, required this.children, this.bottomRadius = 0, this.bottomPadding = 0});
  final List<Widget> children;
  final double bottomRadius, bottomPadding;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: LC.white,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(bottomRadius)),
        ),
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top, bottom: bottomPadding),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
}

/// 뒤로 · 가운데 제목 · 오른쪽 버튼 (높이 52)
class TitleBar extends StatelessWidget {
  const TitleBar(this.title, {super.key, this.onBack, this.trailing});
  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            IconBox('chev_left', tooltip: '뒤로', onTap: onBack ?? () => Navigator.maybePop(context)),
            Expanded(child: Text(title, textAlign: TextAlign.center, style: ts(17, w7, LC.ink, ls: -0.17), maxLines: 1)),
            trailing ?? const SizedBox(width: 40),
          ]),
        ),
      );
}

/// 밑줄 탭 (열람실 탭, 내 서재 탭)
class UnderlineTabs extends StatelessWidget {
  const UnderlineTabs({super.key, required this.labels, required this.index, required this.onChanged});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          for (final (i, label) in labels.indexed)
            Expanded(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () => onChanged(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    foregroundDecoration: i == index ? const BoxDecoration(border: Border(bottom: BorderSide(color: LC.primary, width: 2.5))) : null,
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ts(14.5, i == index ? w7 : w5, i == index ? LC.ink : LC.mute)),
                  ),
                ),
              ),
            ),
        ]),
      );
}

/// 섹션 제목 + 오른쪽 "더보기 >" (Figma: 18px 제목, 13px 링크)
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onTap});
  final String title;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(children: [
          Expanded(child: Text(title, style: ts(18, w7, LC.ink, ls: -0.18))),
          if (action != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(action!, style: ts(13, w5, LC.sub, ls: -0.13)),
                const SizedBox(width: 2),
                const Ico('chev_right_14', size: 14),
              ]),
            ),
        ]),
      );
}

/// 세로로 쌓고 사이를 [gap] 만큼 띄움 (Figma auto layout gap)
class Gap extends StatelessWidget {
  const Gap(this.gap, {super.key, required this.children, this.crossAxisAlignment = CrossAxisAlignment.stretch});
  final double gap;
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: crossAxisAlignment,
        children: [
          for (final (i, c) in children.indexed) ...[if (i > 0) SizedBox(height: gap), c],
        ],
      );
}

// ---------------- 빈 화면 · 오류 ----------------
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.onRetry});
  final IconData icon;
  final String title;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 36, color: LC.mute),
          const SizedBox(height: 10),
          Text(title, style: ts(15, w7, LC.ink), textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(message!, style: ts(13, w4, LC.sub), textAlign: TextAlign.center),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            Btn('다시 시도', kind: BtnKind.outline, height: 40, radius: 12, fontSize: 14, onTap: onRetry),
          ],
        ]),
      );
}

/// 실시간 서버 호출이 실패해 샘플을 보여 줄 때 안내
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, this.margin = EdgeInsets.zero});
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final repo = LibraryRepository.instance;
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        if (repo.lastError == null) return const SizedBox.shrink();
        return Padding(
          padding: margin,
          child: Box(
            color: LC.amberSoft,
            radius: 12,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              const Icon(Icons.cloud_off_outlined, size: 18, color: LC.amber),
              const SizedBox(width: 10),
              Expanded(child: Text('실시간 데이터를 가져오지 못해 샘플을 보여줘요. (${repo.lastError})', style: ts(12.5, w5, LC.amber, height: 1.5))),
            ]),
          ),
        );
      },
    );
  }
}

// ---------------- 책 표지 ----------------
/// 표지 이미지가 있으면 보여 주고, 없으면 Figma처럼 단색 사각형
class BookCover extends StatelessWidget {
  const BookCover(this.book, {super.key, required this.width, required this.height, this.radius = 6});
  final Book book;
  final double width, height, radius;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(width: width, height: height, color: Color(book.coverColor));
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: FutureBuilder<String?>(
        future: LibraryRepository.instance.coverUrl(book),
        builder: (context, snap) {
          final url = snap.data;
          if (url == null) return fallback;
          return Image.network(
            url,
            width: width,
            height: height,
            fit: BoxFit.cover,
            cacheWidth: (width * MediaQuery.devicePixelRatioOf(context)).round(),
            errorBuilder: (_, _, _) => fallback,
            loadingBuilder: (_, child, progress) => progress == null ? child : fallback,
          );
        },
      ),
    );
  }
}

// ---------------- 검색 결과 카드 (Figma BookItem) ----------------
class BookItem extends StatelessWidget {
  const BookItem({super.key, required this.book, this.campus, this.onTap});
  final Book book;
  final Campus? campus;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Box(
        color: LC.white,
        radius: 16,
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          BookCover(book, width: 68, height: 96),
          const SizedBox(width: 14),
          Expanded(
            child: Gap(5, crossAxisAlignment: CrossAxisAlignment.start, children: [
              HoldingBadge(book.statusFor(campus)),
              Text(book.title, style: ts(15, w7, LC.ink, height: 1.35, ls: -0.15)),
              Text('${book.author} 지음 · ${book.year}', style: ts(12.5, w4, LC.sub, ls: -0.125)),
              Row(children: [
                const Ico('pin_14', size: 14),
                const SizedBox(width: 4),
                Expanded(child: Text(locationLine(book, campus), maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12, w5, LC.sub, ls: -0.12))),
              ]),
            ]),
          ),
        ]),
      );
}

/// "충주 중앙도서관 3층 · 004.73 김78ㅇ" 또는 "반납예정 10.08 · 충주 중앙도서관 3층"
String locationLine(Book book, Campus? campus) {
  if (book.type == BookType.ebook) return '온라인 열람 · 전자책${book.ebookFormat == null ? '' : ' (${book.ebookFormat})'}';
  if (book.holdings.isEmpty) return '소장 정보 없음';
  final pool = campus == null ? book.holdings : book.holdings.where((h) => h.campus == campus).toList();
  final list = pool.isEmpty ? book.holdings : pool;
  final av = list.where((h) => h.status == HoldingStatus.available).firstOrNull;
  if (av != null) return '${av.campus.fullName} ${av.floor} · ${av.callNo}';
  final loaned = list.where((h) => h.due != null).toList()..sort((a, b) => a.due!.compareTo(b.due!));
  if (loaned.isNotEmpty) return '반납예정 ${mmdd(loaned.first.due!)} · ${loaned.first.campus.fullName} ${loaned.first.floor}';
  final h = list.first;
  return '${h.campus.fullName} ${h.floor} · ${h.callNo}';
}

/// 가로 막대 그래프 (열람실 이용률, 대출 기간)
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, required this.color, this.height = 8});
  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, k) => Container(
          width: k.maxWidth,
          height: height,
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(color: LC.bg, borderRadius: BorderRadius.circular(height / 2)),
          child: Container(
            width: k.maxWidth * value.clamp(0.0, 1.0),
            height: height,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height / 2)),
          ),
        ),
      );
}

/// 하단 안전 영역(제스처 바) 높이. 없으면 Figma 하단 여백에 가깝게 최소값을 둔다
double bottomInset(BuildContext context, {double min = 12}) => math.max(MediaQuery.viewPaddingOf(context).bottom, min);
