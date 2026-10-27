import 'package:flutter/material.dart';

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
      appBar: AppBar(title: const Text('공지사항')),
      body: FutureBuilder<List<Notice>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.cloud_off,
              title: '공지를 불러오지 못했어요',
              onRetry: () => setState(() => _future = LibraryRepository.instance.notices()),
            );
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) return const EmptyState(icon: Icons.campaign_outlined, title: '새 공지가 없어요');
          return ListView(children: [
            const OfflineBanner(),
            for (final n in list) NoticeTile(notice: n),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('공지 본문은 도서관 홈페이지에서 열려요.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          ]);
        },
      ),
    );
  }
}
