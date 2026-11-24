/// Code 128 바코드. 웹 버전(app/js/barcode.js)과 같은 규칙.
/// 숫자만 있고 자릿수가 짝수면 Code C, 그 외 Code B.
library;

import 'package:flutter/material.dart';

const _patterns = [
  '212222', '222122', '222221', '121223', '121322', '131222', '122213', '122312', '132212', '221213',
  '221312', '231212', '112232', '122132', '122231', '113222', '123122', '123221', '223211', '221132',
  '221231', '213212', '223112', '312131', '311222', '321122', '321221', '312212', '322112', '322211',
  '212123', '212321', '232121', '111323', '131123', '131321', '112313', '132113', '132311', '211313',
  '231113', '231311', '112133', '112331', '132131', '113123', '113321', '133121', '313121', '211331',
  '231131', '213113', '213311', '213131', '311123', '311321', '331121', '312113', '312311', '332111',
  '314111', '221411', '431111', '111224', '111422', '121124', '121421', '141122', '141221', '112214',
  '112412', '122114', '122411', '142112', '142211', '241211', '221114', '413111', '241112', '134111',
  '111242', '121142', '121241', '114212', '124112', '124211', '411212', '421112', '421211', '212141',
  '214121', '412121', '111143', '111341', '131141', '114113', '114311', '411113', '411311', '113141',
  '114131', '311141', '411131', '211412', '211214', '211232', '2331112',
];

List<int> code128Values(String text) {
  final values = <int>[];
  if (RegExp(r'^\d+$').hasMatch(text) && text.length.isEven) {
    values.add(105);
    for (var i = 0; i < text.length; i += 2) {
      values.add(int.parse(text.substring(i, i + 2)));
    }
  } else {
    values.add(104);
    for (final c in text.codeUnits) {
      if (c < 32 || c > 126) throw FormatException('바코드에 쓸 수 없는 문자', text);
      values.add(c - 32);
    }
  }
  var sum = values.first;
  for (var i = 1; i < values.length; i++) {
    sum += values[i] * i;
  }
  return values..addAll([sum % 103, 106]);
}

/// 막대·공백 폭(모듈 수)을 번갈아 나열
List<int> code128Modules(String text) =>
    [for (final v in code128Values(text)) for (final ch in _patterns[v].split('')) int.parse(ch)];

class Code128Barcode extends StatelessWidget {
  const Code128Barcode(this.data, {super.key, this.height = 90, this.color = Colors.black, this.padding = const EdgeInsets.symmetric(horizontal: 12), this.fill = false});
  final String data;
  final double height;
  final Color color;
  final EdgeInsetsGeometry padding;

  /// true 면 폭을 꽉 채움(막대 폭이 소수 픽셀이 될 수 있음). false 면 선명하게 정수 픽셀로 맞춤
  final bool fill;

  @override
  Widget build(BuildContext context) {
    List<int> modules;
    try {
      modules = code128Modules(data);
    } on FormatException {
      return SizedBox(height: height, child: const Center(child: Text('학번 형식을 확인해 주세요')));
    }
    return Semantics(
      label: '바코드 $data',
      // 리더기가 읽을 수 있게 다크 모드에서도 흰 바탕에 검은 막대
      child: Container(
        color: Colors.white,
        padding: padding,
        height: height,
        child: CustomPaint(size: Size.infinite, painter: _BarcodePainter(modules, color, fill)),
      ),
    );
  }
}

class _BarcodePainter extends CustomPainter {
  _BarcodePainter(this.modules, this.color, this.fill);
  final List<int> modules;
  final Color color;
  final bool fill;

  @override
  void paint(Canvas canvas, Size size) {
    final total = modules.fold<int>(0, (a, b) => a + b);
    // 막대가 흐려지지 않게 모듈 폭을 정수 픽셀에 가깝게 맞춤
    final unit = fill ? size.width / total : (size.width / total).floorToDouble().clamp(1.0, 6.0).toDouble();
    var x = (size.width - unit * total) / 2;
    final paint = Paint()..color = color;
    for (var i = 0; i < modules.length; i++) {
      final w = modules[i] * unit;
      if (i.isEven) canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), paint);
      x += w;
    }
  }

  @override
  bool shouldRepaint(_BarcodePainter old) => old.modules != modules || old.color != color || old.fill != fill;
}
