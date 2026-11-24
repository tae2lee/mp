import 'dart:async';

import 'package:flutter/material.dart';

import '../barcode.dart';
import '../library_colors.dart';
import '../library_repository.dart';
import '../models.dart';
import '../widgets.dart';

/// 모바일 학생증 바텀시트 (Figma 05).
/// 기존 앱의 HCE 학생증은 동작하지 않아 리뉴얼에서 제외됐으므로(통합본 9장),
/// 여기서는 학번을 Code 128 바코드로 보여 주기만 한다. 게이트가 읽는 형식은 도서관에 확인 필요.
Future<void> showStudentIdSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => libraryThemed(const _StudentIdSheet()),
  );
}

class _StudentIdSheet extends StatefulWidget {
  const _StudentIdSheet();

  @override
  State<_StudentIdSheet> createState() => _StudentIdSheetState();
}

class _StudentIdSheetState extends State<_StudentIdSheet> {
  static const _period = 180; // 3분마다 새 바코드 (시연용 표시)
  int _left = _period;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _left = _left <= 1 ? _period : _left - 1));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = LibraryRepository.instance;
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final p = repo.profile;
        return Container(
          decoration: const BoxDecoration(color: LC.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          padding: EdgeInsets.fromLTRB(24, 10, 24, bottomInset(context, min: 36)),
          child: Gap(18, children: [
            Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: LC.line, borderRadius: BorderRadius.circular(3)))),
            Row(children: [
              Expanded(child: Text('모바일 학생증', style: ts(19, w7, LC.ink, ls: -0.19))),
              Tooltip(
                message: '닫기',
                child: Box(width: 32, height: 32, radius: 16, color: LC.bg, alignment: Alignment.center, onTap: () => Navigator.pop(context), child: const Ico('x_16', size: 16)),
              ),
            ]),
            // 길게 누르면 학생증 정보 수정
            GestureDetector(
              onLongPress: () => _edit(context, p),
              child: Row(children: [
                Box(
                  width: 56,
                  height: 56,
                  radius: 28,
                  color: LC.primarySoft,
                  alignment: Alignment.center,
                  child: Text(p.name.isEmpty ? '?' : p.name.substring(0, 1), style: ts(22, w9, LC.primary)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.name, maxLines: 1, style: ts(18, w7, LC.ink, ls: -0.18)),
                    const SizedBox(height: 2),
                    Text('${p.dept} · ${p.studentNo}', maxLines: 1, style: ts(13, w4, LC.sub, ls: -0.13)),
                  ]),
                ),
                const SizedBox(width: 14),
                Tag('재학', color: LC.green, background: LC.greenSoft, fontSize: 12, padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3), radius: 6),
              ]),
            ),
            Box(
              color: LC.white,
              radius: 18,
              border: const BorderSide(color: LC.line),
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
              child: Gap(10, crossAxisAlignment: CrossAxisAlignment.center, children: [
                SizedBox(width: 290, child: Code128Barcode(p.studentNo, height: 92, color: LC.ink, padding: EdgeInsets.zero, fill: true)),
                Text(p.studentNo.split('').join(' '), style: ts(15, w7, LC.ink)),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Ico('clock_16', size: 16),
                  const SizedBox(width: 6),
                  Text.rich(TextSpan(children: [
                    TextSpan(text: '${two(_left ~/ 60)}:${two(_left % 60)}', style: ts(14, w7, LC.primary)),
                    TextSpan(text: ' 후 새 바코드로 바뀌어요', style: ts(13, w5, LC.sub, ls: -0.13)),
                  ])),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: '바코드 새로 받기',
                    child: Box(
                      width: 24,
                      height: 24,
                      radius: 12,
                      color: LC.bg,
                      alignment: Alignment.center,
                      onTap: () => setState(() => _left = _period),
                      child: const Ico('refresh_14_sheet', size: 14),
                    ),
                  ),
                ]),
              ]),
            ),
            Box(
              color: LC.bg,
              radius: 12,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                const Ico('sun_18', size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('화면 밝기를 잠시 최대로 올렸어요. 출입 게이트나 대출기 리더기에 바코드를 대 주세요.',
                      style: ts(12.5, w4, LC.sub, height: 1.5, ls: -0.125)),
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
      builder: (context) => libraryThemed(AlertDialog(
        backgroundColor: LC.white,
        title: Text('학생증 정보', style: ts(18, w7, LC.ink)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: '이름')),
          TextField(controller: dept, decoration: const InputDecoration(labelText: '학과')),
          TextField(controller: no, decoration: const InputDecoration(labelText: '학번'), keyboardType: TextInputType.number),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('저장')),
        ],
      )),
    );
    if (ok == true) {
      LibraryRepository.instance.updateProfile(StudentProfile(name: name.text.trim(), dept: dept.text.trim(), studentNo: no.text.trim()));
    }
    name.dispose();
    dept.dispose();
    no.dispose();
  }
}
