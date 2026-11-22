// Texto que solo salta de línea entre palabras, nunca a mitad de una.
//
// Flutter parte una palabra cuando no cabe completa en el ancho (con la fuente del
// sistema grande pasa con "registrarse", "notificaciones"…). Este widget mide la
// palabra más larga y, solo si no cabe, reduce el tamaño lo justo para que quepa.
// En los demás casos respeta el tamaño de letra del sistema.

import 'dart:math' as math;

import 'package:flutter/material.dart';

class EbWrapText extends StatelessWidget {
  const EbWrapText(this.text, {super.key, this.style, this.textAlign, this.maxLines, this.semanticsLabel});

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final resolved = DefaultTextStyle.of(context).style.merge(style);
    final scaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        var effective = scaler;
        if (constraints.hasBoundedWidth) {
          final longest = _longestWordWidth(resolved, scaler, Directionality.of(context));
          // Pequeño margen para el redondeo de subpíxeles
          final available = constraints.maxWidth - 1;
          if (longest > available && longest > 0) {
            final fontSize = resolved.fontSize ?? 14;
            final current = scaler.scale(fontSize) / fontSize;
            effective = TextScaler.linear(current * available / longest);
          }
        }
        return Text(
          text,
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: maxLines == null ? null : TextOverflow.ellipsis,
          textScaler: effective,
          semanticsLabel: semanticsLabel,
        );
      },
    );
  }

  double _longestWordWidth(TextStyle style, TextScaler scaler, TextDirection direction) {
    var longest = 0.0;
    for (final word in text.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      final painter = TextPainter(
        text: TextSpan(text: word, style: style),
        textScaler: scaler,
        textDirection: direction,
        maxLines: 1,
      )..layout();
      longest = math.max(longest, painter.width);
      painter.dispose();
    }
    return longest;
  }
}
