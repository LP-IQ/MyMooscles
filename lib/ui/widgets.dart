import 'package:flutter/material.dart';

import '../util.dart';

/// Cabeçalho de seção simples.
class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Um número grande com rótulo, usado nos cartões de resumo.
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  const StatTile({super.key, required this.label, required this.value, this.sub});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.bodySmall),
        const SizedBox(height: 2),
        Text(value, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        if (sub != null) Text(sub!, style: t.bodySmall),
      ],
    );
  }
}

/// Campo numérico usado nos diálogos.
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
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      decoration: InputDecoration(labelText: label, suffixText: suffix, border: const OutlineInputBorder()),
    );
  }
}

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
  /// Pontos medidos (desenhados como bolinhas).
  final List<MapEntry<DateTime, double>> points;

  /// Linha suave (por exemplo, média de 7 dias).
  final List<MapEntry<DateTime, double>> line;
  final String unit;
  final double height;

  const SimpleLineChart({
    super.key,
    required this.points,
    required this.line,
    this.unit = 'kg',
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(child: Text('Sem registros ainda', style: Theme.of(context).textTheme.bodyMedium)),
      );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _ChartPainter(
          points: points,
          line: line,
          unit: unit,
          dotColor: cs.primary.withAlpha(110),
          lineColor: cs.primary,
          gridColor: cs.outlineVariant,
          textColor: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<MapEntry<DateTime, double>> points;
  final List<MapEntry<DateTime, double>> line;
  final String unit;
  final Color dotColor;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;

  _ChartPainter({
    required this.points,
    required this.line,
    required this.unit,
    required this.dotColor,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
  });

  void _text(Canvas canvas, String s, Offset at, {bool alignRight = false, bool center = false}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: textColor, fontSize: 10)),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = at.dx;
    if (alignRight) dx -= tp.width;
    if (center) dx -= tp.width / 2;
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
          ..strokeWidth = 2.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.points != points || old.line != line || old.lineColor != lineColor;
}
