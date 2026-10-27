import 'package:flutter/material.dart';

import '../library_colors.dart';
import '../barcode.dart';
import '../library_repository.dart';
import '../models.dart';

/// 모바일 학생증 바텀시트 (Figma 05).
/// 기존 앱의 HCE 학생증은 동작하지 않아 리뉴얼에서 제외됐으므로(통합본 9장),
/// 여기서는 학번을 Code 128 바코드로 보여 주기만 한다. 게이트가 읽는 형식은 도서관에 확인 필요.
Future<void> showStudentIdSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => const _StudentIdSheet(),
  );
}

class _StudentIdSheet extends StatelessWidget {
  const _StudentIdSheet();

  @override
  Widget build(BuildContext context) {
    final repo = LibraryRepository.instance;
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final p = repo.profile;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text('모바일 학생증', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
              TextButton(onPressed: () => _edit(context, p), child: const Text('정보 수정')),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: cs.primaryContainer,
                child: Text(p.name.isEmpty ? '?' : p.name.substring(0, 1),
                    style: TextStyle(color: cs.onPrimaryContainer, fontSize: 22, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  Text('${p.dept} · ${p.studentNo}', style: TextStyle(color: cs.onSurfaceVariant)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: context.status.goodContainer, borderRadius: BorderRadius.circular(6)),
                child: Text('재학', style: TextStyle(color: context.status.good, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.fromLTRB(8, 20, 8, 14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: cs.outlineVariant)),
              child: Column(children: [
                Code128Barcode(p.studentNo, height: 92),
                const SizedBox(height: 8),
                Text(p.studentNo.split('').join(' '),
                    style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 2)),
              ]),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.light_mode_outlined, size: 18, color: context.status.warn),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('출입 게이트나 대출기 리더기에 바코드를 대 주세요. 잘 안 읽히면 화면 밝기를 올려 주세요.',
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                ),
              ]),
            ),
          ]),
        );
      },
    );
  }

  Future<void> _edit(BuildContext context, StudentProfile p) async {
    final name = TextEditingController(text: p.name);
    final dept = TextEditingController(text: p.dept);
    final no = TextEditingController(text: p.studentNo);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('학생증 정보'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: '이름')),
          TextField(controller: dept, decoration: const InputDecoration(labelText: '학과')),
          TextField(controller: no, decoration: const InputDecoration(labelText: '학번'), keyboardType: TextInputType.number),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('저장')),
        ],
      ),
    );
    if (ok == true) {
      LibraryRepository.instance.updateProfile(StudentProfile(name: name.text.trim(), dept: dept.text.trim(), studentNo: no.text.trim()));
    }
    name.dispose();
    dept.dispose();
    no.dispose();
  }
}
