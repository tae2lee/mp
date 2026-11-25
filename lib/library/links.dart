import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'library_colors.dart';
import 'widgets.dart';

/// 앱 안에 없는 기능(이용안내, 도서관 소개, 공지 본문, 전자책 열람)은 학교 페이지를 브라우저로 바로 연다.
const libraryHome = 'https://chains.ut.ac.kr/index.ax';
const rissHome = 'https://www.riss.kr';

/// 버튼을 누르면 바로 브라우저로 연다. 열 수 없는 기기에서만 주소 복사 창을 띄운다.
Future<void> openExternal(BuildContext context, String url, {String? title}) async {
  var opened = false;
  try {
    opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } on PlatformException {
    opened = false; // 브라우저 앱이 없는 기기
  }
  if (opened || !context.mounted) return;
  await _showUrlSheet(context, url, title: title);
}

Future<void> _showUrlSheet(BuildContext context, String url, {String? title}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => libraryThemed(Container(
      decoration: const BoxDecoration(color: LC.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.fromLTRB(24, 10, 24, bottomInset(sheetContext, min: 24)),
      child: Gap(14, children: [
        Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: LC.line, borderRadius: BorderRadius.circular(3)))),
        Text(title ?? '브라우저를 열지 못했어요. 주소를 복사해 열어 주세요', style: ts(17, w7, LC.ink, ls: -0.17)),
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
