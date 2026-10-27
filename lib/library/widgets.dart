import 'package:flutter/material.dart';

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

// ---------------- 상태 배지 ----------------
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, required this.color, required this.background, this.dot = true});

  final String label;
  final Color color, background;
  final bool dot;

  factory StatusBadge.holding(BuildContext context, HoldingStatus? s) {
    final c = context.status;
    return switch (s) {
      HoldingStatus.available => StatusBadge('대출가능', color: c.good, background: c.goodContainer),
      HoldingStatus.loaned => StatusBadge('대출중', color: c.warn, background: c.warnContainer),
      HoldingStatus.reference => StatusBadge('열람전용', color: Theme.of(context).colorScheme.onSurfaceVariant, background: Theme.of(context).colorScheme.surfaceContainerHigh),
      null => StatusBadge('전자자료', color: c.info, background: c.infoContainer),
    };
  }

  factory StatusBadge.congestion(BuildContext context, Congestion level) {
    final c = context.status;
    final cs = Theme.of(context).colorScheme;
    return switch (level) {
      Congestion.low => StatusBadge(level.label, color: c.good, background: c.goodContainer, dot: false),
      Congestion.mid => StatusBadge(level.label, color: c.warn, background: c.warnContainer, dot: false),
      Congestion.high => StatusBadge(level.label, color: cs.primary, background: cs.primaryContainer, dot: false),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (dot) ...[
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
        ],
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

Color congestionColor(BuildContext context, Congestion level) => switch (level) {
      Congestion.low => context.status.good,
      Congestion.mid => context.status.warn,
      Congestion.high => Theme.of(context).colorScheme.primary,
    };

// ---------------- 섹션 제목 ----------------
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 8, 8),
      child: Row(children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
        if (action != null)
          TextButton(
            onPressed: onAction,
            child: Row(mainAxisSize: MainAxisSize.min, children: [Text(action!), const Icon(Icons.chevron_right, size: 18)]),
          ),
      ]),
    );
  }
}

// ---------------- 빈 화면 · 오류 (개선점 8-9) ----------------
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.onRetry});
  final IconData icon;
  final String title;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 40, color: cs.onSurfaceVariant),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleSmall, textAlign: TextAlign.center),
        if (message != null) ...[
          const SizedBox(height: 4),
          Text(message!, style: TextStyle(color: cs.onSurfaceVariant), textAlign: TextAlign.center),
        ],
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('다시 시도')),
        ],
      ]),
    );
  }
}

/// 실시간 서버 호출이 실패해 샘플을 보여 줄 때 상단 안내
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = LibraryRepository.instance;
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        if (repo.lastError == null) return const SizedBox.shrink();
        final c = context.status;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: c.warnContainer, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(Icons.cloud_off, size: 18, color: c.warn),
            const SizedBox(width: 8),
            Expanded(child: Text('실시간 데이터를 가져오지 못해 샘플을 보여줘요. (${repo.lastError})', style: TextStyle(color: c.warn, fontSize: 13))),
          ]),
        );
      },
    );
  }
}

// ---------------- 책 표지 ----------------
class BookCover extends StatelessWidget {
  const BookCover(this.book, {super.key, this.width = 64});
  final Book book;
  final double width;

  @override
  Widget build(BuildContext context) {
    final height = width * 1.42;
    final fallback = Container(
      width: width,
      height: height,
      color: Color(book.coverColor),
      alignment: Alignment.bottomLeft,
      padding: EdgeInsets.all(width * 0.08),
      child: width >= 56
          ? Text(book.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: width * 0.12, fontWeight: FontWeight.w700, height: 1.2))
          : null,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(width >= 100 ? 8 : 5),
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

// ---------------- 검색 결과 한 줄 ----------------
class BookTile extends StatelessWidget {
  const BookTile({super.key, required this.book, this.campus, this.onTap});
  final Book book;
  final Campus? campus;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = book.statusFor(campus);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            BookCover(book, width: 64),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                StatusBadge.holding(context, status),
                const SizedBox(height: 6),
                Text(book.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.35)),
                const SizedBox(height: 2),
                Text('${book.author} · ${book.year}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.place_outlined, size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(locationLine(book, campus), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// "충주 3층 일반자료실 · 005.1 유25ㅊ" 또는 "반납예정 10.08 · 충주 ..."
String locationLine(Book book, Campus? campus) {
  if (book.type == BookType.ebook) return '온라인 열람 · 전자책';
  final pool = campus == null ? book.holdings : book.holdings.where((h) => h.campus == campus).toList();
  final list = pool.isEmpty ? book.holdings : pool;
  final av = list.where((h) => h.status == HoldingStatus.available).firstOrNull;
  if (av != null) return '${av.campus.short} ${av.location} · ${av.callNo}';
  final loaned = list.where((h) => h.due != null).toList()..sort((a, b) => a.due!.compareTo(b.due!));
  if (loaned.isNotEmpty) return '반납예정 ${mmdd(loaned.first.due!)} · ${loaned.first.campus.short} ${loaned.first.location}';
  final h = list.first;
  return '${h.campus.short} ${h.location} · ${h.callNo}';
}
