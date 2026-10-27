import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 앱 안에 아직 없는 기능(희망도서, 전자책 열람 등)은 학교 페이지 주소를 알려 준다.
///
/// 지금은 외부 패키지 없이 주소를 보여 주고 복사하는 창만 띄운다.
/// 브라우저로 바로 열려면 `flutter pub add url_launcher` 후 아래 주석의 코드로 바꾸면 된다.
///
///   import 'package:url_launcher/url_launcher.dart';
///   await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
const libraryHome = 'https://chains.ut.ac.kr/index.ax';
const rissHome = 'https://www.riss.kr';

Future<void> openExternal(BuildContext context, String url, {String? title}) {
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title ?? '학교 페이지에서 열어 주세요', style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
          child: SelectableText(url),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: url));
            if (sheetContext.mounted) Navigator.pop(sheetContext);
            if (context.mounted) showMessage(context, '주소를 복사했어요');
          },
          icon: const Icon(Icons.copy),
          label: const Text('주소 복사'),
        ),
      ]),
    ),
  );
}

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
}
