import 'package:flutter/material.dart';

import '../logic.dart';
import '../models.dart';
import '../store.dart';
import '../util.dart';
import 'widgets.dart';

class BodyPage extends StatefulWidget {
  const BodyPage({super.key});

  @override
  State<BodyPage> createState() => _BodyPageState();
}

class _BodyPageState extends State<BodyPage> {
  int _days = 90; // 0 = tudo
  String _metric = 'peso';

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final t = mt(context);
        final data = store.data;
        final now = DateTime.now();
        final allWeights = weightEntries(data.body);
        var weights = allWeights;
        if (_days > 0) {
          final from = dayOnly(now).subtract(Duration(days: _days));
          weights = allWeights.where((e) => !e.date.isBefore(from)).toList();
        }
        final avg = movingAverage(allWeights)
            .where((e) => weights.isNotEmpty && !e.key.isBefore(weights.first.date))
            .toList();
        final stats = weightStats(data.body, now);
        final waist = latestWith(data.body, (e) => e.waist);
        final firstWaist = _firstWith(data.body, (e) => e.waist);
        final fat = latestWith(data.body, (e) => e.bodyFat);
        final lean = latestWith(data.body, (e) => e.leanMass);
        final entries = [...data.body]..sort((a, b) => b.date.compareTo(a.date));
        final advice = adjustmentAdvice(data, now);
        final change = (stats.last != null && stats.first != null) ? stats.last! - stats.first! : null;
        final waistChange =
            (waist != null && firstWaist != null && firstWaist.id != waist.id) ? waist.waist! - firstWaist.waist! : null;

        String signed(double v, [int d = 2]) => '${v > 0 ? '+' : ''}${fmtNum(v, d)}';

        return ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            PageHeader(
              'Corpo',
              kicker: 'Peso e medidas',
              trailing: PillButton(label: 'Registrar', icon: Icons.add, onPressed: () => openBodyEntry(context)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
              child: MooCard(
                child: Wrap(
                  spacing: 22,
                  runSpacing: 14,
                  children: [
                    StatTile(
                      label: stats.lastDate == null ? 'Último peso' : 'Último · ${fmtDateShort(stats.lastDate!)}',
                      value: stats.last == null ? '—' : fmtNum(stats.last!, 2),
                      unit: stats.last == null ? null : 'kg',
                    ),
                    StatTile(
                      label: 'Média 7 dias',
                      value: stats.avg7 == null ? '—' : fmtNum(stats.avg7!, 2),
                      unit: stats.avg7 == null ? null : 'kg',
                      sub: stats.weeklyChange == null ? null : '${signed(stats.weeklyChange!)} kg na semana',
                    ),
                    StatTile(
                      label: 'Desde o início',
                      value: change == null ? '—' : signed(change),
                      unit: change == null ? null : 'kg',
                      sub: stats.firstDate == null ? null : 'desde ${fmtDateShort(stats.firstDate!)}',
                      highlight: true,
                    ),
                    StatTile(
                      label: 'Cintura',
                      value: waist == null ? '—' : fmtNum(waist.waist!),
                      unit: waist == null ? null : 'cm',
                      sub: waistChange != null
                          ? '${signed(waistChange, 1)} cm desde ${fmtDateShort(firstWaist!.date)}'
                          : (waist == null ? 'meça toda sexta' : fmtDateShort(waist.date)),
                    ),
                    if (fat != null)
                      StatTile(
                        label: 'Gordura',
                        value: fmtNum(fat.bodyFat!),
                        unit: '%',
                        sub: 'bioimpedância ${fmtDateShort(fat.date)}',
                      ),
                    if (lean != null)
                      StatTile(
                        label: 'Massa magra',
                        value: fmtNum(lean.leanMass!, 1),
                        unit: 'kg',
                        sub: fmtDateShort(lean.date),
                      ),
                  ],
                ),
              ),
            ),
            if (advice != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                child: MooCard(
                  color: t.tint,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.insights, color: t.acc),
                      const SizedBox(width: 10),
                      Expanded(child: Text(advice, style: t.body(14, weight: FontWeight.w600))),
                    ],
                  ),
                ),
              ),
            SectionTitle(
              'Evolução',
              icon: Icons.show_chart,
              trailing: Wrap(
                spacing: 6,
                children: [
                  for (final opt in const [(30, '30d'), (90, '90d'), (0, 'Tudo')])
                    ChoiceChip(
                      label: Text(opt.$2),
                      selected: _days == opt.$1,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() => _days = opt.$1),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                children: [
                  for (final m in const [
                    ('peso', 'Peso'),
                    ('cintura', 'Cintura'),
                    ('gordura', 'Gordura %'),
                    ('soma_dobras', 'Soma das dobras'),
                    ('rcq', 'Cintura/quadril'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(m.$2),
                        selected: _metric == m.$1,
                        onSelected: (_) => setState(() => _metric = m.$1),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: MooCard(
                padding: const EdgeInsets.fromLTRB(8, 14, 14, 8),
                child: Builder(builder: (context) {
                  if (_metric == 'peso') {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SimpleLineChart(
                          points: weights.map((e) => MapEntry(e.date, e.weight!)).toList(),
                          line: avg,
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 6, 0, 0),
                          child: Text('Pontos: pesagens · Linha: média de 7 dias', style: t.body(12, color: t.muted)),
                        ),
                      ],
                    );
                  }
                  final from = _days > 0 ? dayOnly(now).subtract(Duration(days: _days)) : DateTime(2000);
                  final pts = <MapEntry<DateTime, double>>[];
                  final sorted = [...data.body]..sort((a, b) => a.date.compareTo(b.date));
                  for (final e in sorted) {
                    final v = metricValue(e, _metric, data.profile.heightCm);
                    if (v != null && !e.date.isBefore(from)) pts.add(MapEntry(e.date, v));
                  }
                  return SimpleLineChart(points: pts, line: pts);
                }),
              ),
            ),
            const SectionTitle('Medidas', icon: Icons.straighten),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: MeasuresCard(body: data.body, heightCm: data.profile.heightCm),
            ),
            const SectionTitle('Registros', icon: Icons.list_alt),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text('Nenhum registro. Toque em "Registrar" para adicionar peso, cintura ou bioimpedância.',
                    style: t.body(14, color: t.muted)),
              ),
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Dismissible(
                  key: ValueKey(e.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(t.radius),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onErrorContainer),
                  ),
                  confirmDismiss: (_) =>
                      confirmDialog(context, 'Apagar registro?', 'Registro de ${fmtDate(e.date)}.', ok: 'Apagar'),
                  onDismissed: (_) => store.deleteBody(e),
                  child: MooCard(
                    padding: const EdgeInsets.all(14),
                    onTap: () => openBodyEntry(context, existing: e),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_entryTitle(e), style: t.body(15, weight: FontWeight.w700)),
                              Text([fmtDate(e.date), if (e.note.isNotEmpty) e.note].join(' · '),
                                  style: t.body(13, color: t.muted)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: t.muted),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  BodyEntry? _firstWith(List<BodyEntry> body, double? Function(BodyEntry) f) {
    BodyEntry? best;
    for (final e in body) {
      if (f(e) == null) continue;
      if (best == null || e.date.isBefore(best.date)) best = e;
    }
    return best;
  }

  String _entryTitle(BodyEntry e) {
    final parts = <String>[];
    if (e.weight != null) parts.add('${fmtNum(e.weight!, 2)} kg');
    if (e.waist != null) parts.add('cintura ${fmtNum(e.waist!)} cm');
    if (e.bodyFat != null) parts.add('gordura ${fmtNum(e.bodyFat!)}%');
    if (e.leanMass != null) parts.add('magra ${fmtNum(e.leanMass!, 2)} kg');
    if (e.visceral != null) parts.add('visceral ${fmtNum(e.visceral!)}');
    if (e.extra.isNotEmpty) parts.add('+${e.extra.length} medidas');
    return parts.isEmpty ? 'Registro' : parts.join(' · ');
  }
}

Future<void> openBodyEntry(BuildContext context, {BodyEntry? existing}) {
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => BodyEntryPage(existing: existing), fullscreenDialog: true),
  );
}

class BodyEntryPage extends StatefulWidget {
  final BodyEntry? existing;
  const BodyEntryPage({super.key, this.existing});

  @override
  State<BodyEntryPage> createState() => _BodyEntryPageState();
}

class _BodyEntryPageState extends State<BodyEntryPage> {
  late DateTime _date;
  final _weight = TextEditingController();
  final _waist = TextEditingController();
  final _fat = TextEditingController();
  final _lean = TextEditingController();
  final _visceral = TextEditingController();
  final _note = TextEditingController();
  final Map<String, TextEditingController> _extra = {
    for (final d in measureDefs) d.key: TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _date = e?.date ?? DateTime.now();
    String f(double? v, [int d = 2]) => v == null ? '' : fmtNum(v, d);
    _weight.text = f(e?.weight);
    _waist.text = f(e?.waist, 1);
    _fat.text = f(e?.bodyFat, 1);
    _lean.text = f(e?.leanMass);
    _visceral.text = f(e?.visceral, 1);
    _note.text = e?.note ?? '';
    if (e != null) {
      for (final entry in e.extra.entries) {
        _extra[entry.key]?.text = fmtNum(entry.value, 1);
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_weight, _waist, _fat, _lean, _visceral, _note, ..._extra.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) {
      setState(() => _date = DateTime(d.year, d.month, d.day, _date.hour, _date.minute));
    }
  }

  Future<void> _save() async {
    final weight = parseNum(_weight.text);
    final waist = parseNum(_waist.text);
    final fat = parseNum(_fat.text);
    final lean = parseNum(_lean.text);
    final visceral = parseNum(_visceral.text);
    final extra = <String, double>{};
    for (final entry in _extra.entries) {
      final v = parseNum(entry.value.text);
      if (v != null) extra[entry.key] = v;
    }
    if ([weight, waist, fat, lean, visceral].every((v) => v == null) && extra.isEmpty) {
      showSnack(context, 'Preencha pelo menos um valor.');
      return;
    }
    final store = Store.instance;
    final e = widget.existing;
    if (e != null) {
      e
        ..date = _date
        ..weight = weight
        ..waist = waist
        ..bodyFat = fat
        ..leanMass = lean
        ..visceral = visceral
        ..extra = extra
        ..note = _note.text.trim();
      store.data.body.sort((a, b) => a.date.compareTo(b.date));
      await store.save();
    } else {
      await store.addBody(BodyEntry(
        date: _date,
        weight: weight,
        waist: waist,
        bodyFat: fat,
        leanMass: lean,
        visceral: visceral,
        extra: extra,
        note: _note.text.trim(),
      ));
    }
    if (mounted) Navigator.pop(context);
  }

  Widget _groupTile(BuildContext context, String group) {
    final t = mt(context);
    final defs = measureDefs.where((d) => d.group == group).toList();
    final filled = defs.where((d) => _extra[d.key]!.text.trim().isNotEmpty).length;
    final rows = <Widget>[];
    for (var i = 0; i < defs.length; i += 2) {
      final a = defs[i];
      final b = i + 1 < defs.length ? defs[i + 1] : null;
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Expanded(child: NumberField(controller: _extra[a.key]!, label: a.label, suffix: a.unit)),
            const SizedBox(width: 10),
            Expanded(
              child: b == null
                  ? const SizedBox.shrink()
                  : NumberField(controller: _extra[b.key]!, label: b.label, suffix: b.unit),
            ),
          ],
        ),
      ));
    }
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(top: 4),
      shape: const Border(),
      collapsedShape: const Border(),
      initiallyExpanded: filled > 0,
      title: Text(group, style: t.body(15, weight: FontWeight.w700)),
      subtitle: Text(filled == 0 ? '${defs.length} campos' : '$filled de ${defs.length} preenchidos',
          style: t.body(12, color: t.muted)),
      children: rows,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = mt(context);
    return Scaffold(
      appBar: mooAppBar(context, widget.existing == null ? 'Novo registro' : 'Editar registro'),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: MooButton(label: 'Salvar', icon: Icons.check, expand: true, onPressed: _save),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          MooCard(
            padding: const EdgeInsets.all(14),
            onTap: _pickDate,
            child: Row(
              children: [
                Icon(Icons.event, color: t.acc),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fmtDate(_date), style: t.body(16, weight: FontWeight.w700)),
                      Text('Toque para mudar a data', style: t.body(13, color: t.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          NumberField(controller: _weight, label: 'Peso', suffix: 'kg', autofocus: widget.existing == null),
          const SizedBox(height: 12),
          NumberField(controller: _waist, label: 'Cintura (altura do umbigo)', suffix: 'cm'),
          const SizedBox(height: 22),
          Text('BIOIMPEDÂNCIA (OPCIONAL)', style: t.kicker()),
          const SizedBox(height: 10),
          NumberField(controller: _fat, label: 'Gordura corporal', suffix: '%'),
          const SizedBox(height: 12),
          NumberField(controller: _lean, label: 'Massa magra (LBM)', suffix: 'kg'),
          const SizedBox(height: 12),
          NumberField(controller: _visceral, label: 'Gordura visceral (índice)'),
          const SizedBox(height: 22),
          Text('AVALIAÇÃO COMPLETA (OPCIONAL)', style: t.kicker()),
          const SizedBox(height: 4),
          for (final g in measureGroups) _groupTile(context, g),
          const SizedBox(height: 12),
          MooTextField(controller: _note, label: 'Observação'),
          const SizedBox(height: 16),
          Text(
            'Dica: pese-se ao acordar, depois do banheiro e antes de comer. Cintura toda sexta, em jejum.',
            style: t.body(13, color: t.muted),
          ),
        ],
      ),
    );
  }
}

/// Tabela com a última medida de cada item e a diferença em relação à primeira.
class MeasuresCard extends StatelessWidget {
  final List<BodyEntry> body;
  final double? heightCm;
  const MeasuresCard({super.key, required this.body, required this.heightCm});

  @override
  Widget build(BuildContext context) {
    final t = mt(context);
    final sections = <(String, List<(String, String, String)>)>[
      ('Índices', [('rca', 'Cintura/altura', 'alvo < 0,50'), ('rcq', 'Cintura/quadril', 'alvo < 0,90'), ('soma_dobras', 'Soma das dobras', 'mm')]),
      ('Tronco', [('cintura', 'Cintura', 'cm'), for (final d in measureDefs.where((d) => d.group == 'Tronco')) (d.key, d.label, d.unit)]),
      for (final g in measureGroups.where((g) => g != 'Tronco' && g != 'Bioimpedância'))
        (g, [for (final d in measureDefs.where((d) => d.group == g)) (d.key, d.label, d.unit)]),
      ('Bioimpedância', [
        ('gordura', 'Gordura', '%'),
        ('magra', 'Massa magra', 'kg'),
        ('visceral', 'Gordura visceral', ''),
        for (final d in measureDefs.where((d) => d.group == 'Bioimpedância')) (d.key, d.label, d.unit),
      ]),
    ];
    final children = <Widget>[];
    for (final sec in sections) {
      final rows = <Widget>[];
      for (final item in sec.$2) {
        final r = metricRange(body, item.$1, heightCm);
        if (r == null) continue;
        final isRatio = item.$1 == 'rca' || item.$1 == 'rcq';
        final unit = isRatio ? '' : item.$3;
        final dec = isRatio ? 2 : 1;
        final delta = r.last.id == r.first.id ? null : r.lastValue - r.firstValue;
        rows.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.$2, style: t.body(14, weight: FontWeight.w600)),
                    Text(isRatio ? '${item.$3} · ${fmtDateShort(r.last.date)}' : fmtDateShort(r.last.date),
                        style: t.body(11, color: t.muted)),
                  ],
                ),
              ),
              Text('${fmtNum(r.lastValue, dec)}${unit.isEmpty ? '' : ' $unit'}', style: t.head(16)),
              SizedBox(
                width: 72,
                child: Text(
                  delta == null ? '' : '${delta > 0 ? '+' : ''}${fmtNum(delta, dec)}',
                  textAlign: TextAlign.right,
                  style: t.body(13, weight: FontWeight.w600, color: t.muted),
                ),
              ),
            ],
          ),
        ));
      }
      if (rows.isEmpty) continue;
      if (children.isNotEmpty) children.add(Divider(height: 22, color: t.isDark ? const Color(0xFF33363D) : const Color(0xFFE3E6EB)));
      children.add(Text(sec.$1.toUpperCase(), style: t.kicker()));
      children.add(const SizedBox(height: 4));
      children.addAll(rows);
    }
    if (children.isEmpty) {
      return MooCard(
        child: Text(
            'Sem medidas ainda. Em "Registrar", abra "Avaliação completa" para lançar tórax, abdome, quadril, braços, coxas, panturrilhas, dobras, pressão e FC.',
            style: t.body(14, color: t.muted)),
      );
    }
    return MooCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Spacer(),
              Text('última', style: t.body(11, color: t.muted)),
              SizedBox(width: 72, child: Text('vs 1ª', textAlign: TextAlign.right, style: t.body(11, color: t.muted))),
            ],
          ),
          ...children,
        ],
      ),
    );
  }
}
