import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'library_colors.dart';
import 'widgets.dart';

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
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => libraryThemed(Container(
      decoration: const BoxDecoration(color: LC.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.fromLTRB(24, 10, 24, bottomInset(sheetContext, min: 24)),
      child: Gap(14, children: [
        Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: LC.line, borderRadius: BorderRadius.circular(3)))),
        Text(title ?? '학교 페이지에서 열어 주세요', style: ts(17, w7, LC.ink, ls: -0.17)),
        Box(
          color: LC.bg,
          radius: 12,
          padding: const EdgeInsets.all(14),
          child: SelectableText(url, style: ts(13.5, w5, LC.sub)),
        ),
        Btn('주소 복사', onTap: () async {
          await Clipboard.setData(ClipboardData(text: url));
          if (sheetContext.mounted) Navigator.pop(sheetContext);
          if (context.mounted) showMessage(context, '주소를 복사했어요');
        }),
      ]),
    )),
  );
}

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
}
