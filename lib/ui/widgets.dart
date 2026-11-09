import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import '../util.dart';

MooTheme mt(BuildContext context) => MooThemeScope.of(context);

// ---------------------------------------------------------------------------
// Estrutura
// ---------------------------------------------------------------------------

/// Barra superior no estilo do tema (sem a sombra/tinta padrão do Material 3).
PreferredSizeWidget mooAppBar(BuildContext context, String title, {String? subtitle, List<Widget>? actions}) {
  final t = mt(context);
  return AppBar(
    backgroundColor: t.bg,
    foregroundColor: t.text,
    surfaceTintColor: Colors.transparent,
    scrolledUnderElevation: 0,
    elevation: 0,
    titleSpacing: 4,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (subtitle != null) Text(subtitle, style: t.body(12, weight: FontWeight.w600, color: t.muted)),
        Text(title, style: t.head(20, weight: FontWeight.w800), overflow: TextOverflow.ellipsis),
      ],
    ),
    actions: actions,
  );
}

/// Título de página grande, usado no topo das abas.
class PageHeader extends StatelessWidget {
  final String title;
  final String? kicker;
  final Widget? trailing;
  const PageHeader(this.title, {super.key, this.kicker, this.trailing});

  @override
  Widget build(BuildContext context) {
    final t = mt(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (kicker != null) Text(kicker!.toUpperCase(), style: t.label()),
                Text(title, style: t.head(30, weight: FontWeight.w800)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Cartão do tema (borda, cantos e sombra "carimbada" nos temas Moo).
class MooCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;
  const MooCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.onTap,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final t = mt(context);
    final radius = BorderRadius.circular(t.radius);
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: t.card(color: color),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Botão principal/secundário no estilo do tema.
class MooButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool primary;
  final bool expand;
  final bool compact;
  const MooButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.primary = true,
    this.expand = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = mt(context);
    final enabled = onPressed != null;
    final bg = primary ? t.acc : Colors.transparent;
    final fg = primary ? t.onAcc : t.text;
    final borderColor = primary
        ? (t.borderWidth >= 2 ? t.line : t.acc)
        : (t.borderWidth >= 2 ? t.line : (t.isDark ? const Color(0xFF3A3F48) : t.line));
    final radius = BorderRadius.circular(t.radiusSmall);
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: compact ? 18 : 20, color: fg), const SizedBox(width: 8)],
        Flexible(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: t.body(compact ? 14 : 15, weight: FontWeight.w700, color: fg)),
        ),
      ],
    );
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Container(
        constraints: BoxConstraints(minHeight: compact ? 40 : 48),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: radius,
          border: Border.all(color: borderColor, width: t.borderWidth >= 2 ? 2 : 1),
          boxShadow: primary ? t.shadowFor(3) : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onPressed,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 18, vertical: compact ? 8 : 12),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão-pílula pequeno (ex.: "Pesar hoje").
class PillButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  const PillButton({super.key, required this.label, this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final t = mt(context);
    final radius = BorderRadius.circular(999);
    return Container(
      constraints: const BoxConstraints(minHeight: 36),
      decoration: BoxDecoration(
        color: t.surf2,
        borderRadius: radius,
        border: t.borderWidth >= 2 ? Border.all(color: t.line, width: 2) : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 16, color: t.text), const SizedBox(width: 6)],
                Text(label, style: t.body(13, weight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Selo com a letra do treino (A, B, C...).
class CodeBadge extends StatelessWidget {
  final String code;
  final double size;
  const CodeBadge(this.code, {super.key, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final t = mt(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.acc,
        borderRadius: BorderRadius.circular(t.radiusSmall),
        border: t.borderWidth >= 2 ? Border.all(color: t.line, width: 2) : null,
      ),
      child: Text(code.isEmpty ? '?' : code, style: t.head(size * 0.5, weight: FontWeight.w800, color: t.onAcc)),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  final IconData? icon;
  const SectionTitle(this.text, {super.key, this.trailing, this.icon});

  @override
  Widget build(BuildContext context) {
    final t = mt(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 10),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 20, color: t.text), const SizedBox(width: 8)],
          Expanded(child: Text(text, style: t.head(18, weight: FontWeight.w700))),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Título interno de um cartão, com ícone opcional.
class CardTitle extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Widget? trailing;
  const CardTitle(this.text, {super.key, this.icon, this.trailing});

  @override
  Widget build(BuildContext context) {
    final t = mt(context);
    return Row(
      children: [
        if (icon != null) ...[Icon(icon, size: 18, color: t.text), const SizedBox(width: 8)],
        Expanded(child: Text(text, style: t.body(15, weight: FontWeight.w700))),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Número grande com rótulo.
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final String? sub;
  final bool highlight;
  final bool dim;
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.sub,
    this.highlight = false,
    this.dim = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = mt(context);
    final color = dim ? t.muted : (highlight && t.key == 'noturno' ? t.acc : t.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: t.body(12, color: t.muted)),
        const SizedBox(height: 2),
        Text.rich(TextSpan(children: [
          TextSpan(text: value, style: t.head(26, color: color)),
          if (unit != null) TextSpan(text: ' $unit', style: t.body(14, weight: FontWeight.w600, color: t.muted)),
        ])),
        if (sub != null) Text(sub!, style: t.body(12, color: t.muted)),
      ],
    );
  }
}

/// Campo numérico com o visual do tema.
class NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? suffix;
  final bool decimal;
  final bool autofocus;
  const NumberField({
    super.key,
    required this.controller,
    required this.label,
    this.suffix,
    this.decimal = true,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = mt(context);
    return TextField(
      controller: controller,
      autofocus: autofocus,
      style: t.body(16, weight: FontWeight.w600),
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      decoration: t.input(label, suffix: suffix),
    );
  }
}

class TextInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int minLines;
  final int maxLines;
  final bool autofocus;
  final TextCapitalization capitalization;
  final ValueChanged<String>? onChanged;
  const TextInput({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.minLines = 1,
    this.maxLines = 1,
    this.autofocus = false,
    this.capitalization = TextCapitalization.sentences,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = mt(context);
    return TextField(
      controller: controller,
      autofocus: autofocus,
      minLines: minLines,
      maxLines: maxLines,
      textCapitalization: capitalization,
      onChanged: onChanged,
      style: t.body(15),
      decoration: t.input(label, hint: hint),
    );
  }
}

/// Manchas de vaca decorativas (temas Moo).
class CowSpots extends StatelessWidget {
  final double width;
  final double height;
  const CowSpots({super.key, this.width = 130, this.height = 96});

  @override
  Widget build(BuildContext context) {
    final t = mt(context);
    return IgnorePointer(
      child: CustomPaint(size: Size(width, height), painter: _CowPainter(t.line)),
    );
  }
}

class _CowPainter extends CustomPainter {
  final Color color;
  _CowPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 120;
    final sy = size.height / 90;
    final p = Paint()..color = color;
    final a = Path()
      ..moveTo(20 * sx, 10 * sy)
      ..cubicTo(34 * sx, 2 * sy, 50 * sx, 12 * sy, 46 * sx, 26 * sy)
      ..cubicTo(42 * sx, 40 * sy, 24 * sx, 38 * sy, 18 * sx, 30 * sy)
      ..cubicTo(12 * sx, 22 * sy, 8 * sx, 17 * sy, 20 * sx, 10 * sy)
      ..close();
    final b = Path()
      ..moveTo(78 * sx, 40 * sy)
      ..cubicTo(88 * sx, 34 * sy, 104 * sx, 40 * sy, 102 * sx, 52 * sy)
      ..cubicTo(100 * sx, 64 * sy, 84 * sx, 66 * sy, 78 * sx, 60 * sy)
      ..cubicTo(72 * sx, 54 * sy, 70 * sx, 46 * sy, 78 * sx, 40 * sy)
      ..close();
    canvas.drawPath(a, p);
    canvas.drawPath(b, p);
    canvas.drawCircle(Offset(62 * sx, 14 * sy), 6 * math.min(sx, sy), p);
  }

  @override
  bool shouldRepaint(covariant _CowPainter old) => old.color != color;
}

// ---------------------------------------------------------------------------
// Diálogos e avisos
// ---------------------------------------------------------------------------

Future<bool> confirmDialog(BuildContext context, String title, String message, {String ok = 'Confirmar'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ok)),
      ],
    ),
  );
  return r ?? false;
}

void showSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

// ---------------------------------------------------------------------------
// Gráfico de linha simples (sem dependências externas)
// ---------------------------------------------------------------------------

class SimpleLineChart extends StatelessWidget {
  final List<MapEntry<DateTime, double>> points;
  final List<MapEntry<DateTime, double>> line;
  final double height;

  const SimpleLineChart({super.key, required this.points, required this.line, this.height = 200});

  @override
  Widget build(BuildContext context) {
    final t = mt(context);
    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(child: Text('Sem registros ainda', style: t.body(14, color: t.muted))),
      );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _ChartPainter(
          points: points,
          line: line,
          dotColor: t.text.withAlpha(90),
          lineColor: t.acc,
          gridColor: t.isDark ? const Color(0xFF33363D) : const Color(0xFFE3E6EB),
          textColor: t.muted,
          font: t.bodyFont,
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<MapEntry<DateTime, double>> points;
  final List<MapEntry<DateTime, double>> line;
  final Color dotColor;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;
  final String font;

  _ChartPainter({
    required this.points,
    required this.line,
    required this.dotColor,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
    required this.font,
  });

  void _text(Canvas canvas, String s, Offset at, {bool alignRight = false}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: textColor, fontSize: 10, fontFamily: font)),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = at.dx;
    if (alignRight) dx -= tp.width;
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = 40.0;
    const right = 8.0;
    const top = 8.0;
    const bottom = 22.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;

    final all = [...points.map((e) => e.value), ...line.map((e) => e.value)];
    var minV = all.reduce((a, b) => a < b ? a : b);
    var maxV = all.reduce((a, b) => a > b ? a : b);
    if (maxV - minV < 1) {
      minV -= 0.5;
      maxV += 0.5;
    }
    final pad = (maxV - minV) * 0.1;
    minV -= pad;
    maxV += pad;

    final t0 = points.first.key.millisecondsSinceEpoch.toDouble();
    var t1 = points.last.key.millisecondsSinceEpoch.toDouble();
    if (t1 - t0 < 1) t1 = t0 + 86400000;

    double x(DateTime d) => left + (d.millisecondsSinceEpoch - t0) / (t1 - t0) * w;
    double y(double v) => top + (1 - (v - minV) / (maxV - minV)) * h;

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final v = minV + (maxV - minV) * i / 4;
      final yy = y(v);
      canvas.drawLine(Offset(left, yy), Offset(left + w, yy), grid);
      _text(canvas, fmtNum(v), Offset(left - 4, yy), alignRight: true);
    }
    _text(canvas, fmtDateShort(points.first.key), Offset(left, size.height - 8));
    if (points.length > 1) {
      _text(canvas, fmtDateShort(points.last.key), Offset(left + w, size.height - 8), alignRight: true);
    }

    final dot = Paint()..color = dotColor;
    for (final p in points) {
      canvas.drawCircle(Offset(x(p.key), y(p.value)), 3.5, dot);
    }

    if (line.length > 1) {
      final path = Path()..moveTo(x(line.first.key), y(line.first.value));
      for (final p in line.skip(1)) {
        path.lineTo(x(p.key), y(p.value));
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.points != points || old.line != line || old.lineColor != lineColor;
}
