import 'package:flutter/material.dart';

import '../library_colors.dart';
import '../library_repository.dart';
import '../library_tab.dart' show NoticeTile;
import '../models.dart';
import '../widgets.dart';

class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key});

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  late Future<List<Notice>> _future = LibraryRepository.instance.notices();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LC.bg,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const LibHeader(children: [TitleBar('공지사항')]),
        Expanded(
          child: FutureBuilder<List<Notice>>(
            future: _future,
            builder: (context, snap) {
              if (snap.hasError) {
                return EmptyState(
                  icon: Icons.cloud_off,
                  title: '공지를 불러오지 못했어요',
                  onRetry: () => setState(() => _future = LibraryRepository.instance.notices()),
                );
              }
              if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: LC.primary, strokeWidth: 2.5));
              final list = snap.data!;
              if (list.isEmpty) return const EmptyState(icon: Icons.campaign_outlined, title: '새 공지가 없어요');
              return ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 24), children: [
                Gap(12, children: [
                  const OfflineBanner(),
                  CardBox(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                    child: Column(children: [for (final (i, n) in list.indexed) NoticeTile(notice: n, divider: i > 0)]),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text('공지 본문은 도서관 홈페이지에서 열려요.', style: ts(12.5, w4, LC.mute)),
                  ),
                ]),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}
