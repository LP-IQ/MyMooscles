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
              'Peso',
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: MooCard(
                padding: const EdgeInsets.fromLTRB(8, 14, 14, 8),
                child: Column(
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
                ),
              ),
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
  }

  @override
  void dispose() {
    for (final c in [_weight, _waist, _fat, _lean, _visceral, _note]) {
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
    if ([weight, waist, fat, lean, visceral].every((v) => v == null)) {
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
        note: _note.text.trim(),
      ));
    }
    if (mounted) Navigator.pop(context);
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
          Text('BIOIMPEDÂNCIA (OPCIONAL)', style: t.label()),
          const SizedBox(height: 10),
          NumberField(controller: _fat, label: 'Gordura corporal', suffix: '%'),
          const SizedBox(height: 12),
          NumberField(controller: _lean, label: 'Massa magra (LBM)', suffix: 'kg'),
          const SizedBox(height: 12),
          NumberField(controller: _visceral, label: 'Gordura visceral (índice)'),
          const SizedBox(height: 12),
          TextInput(controller: _note, label: 'Observação'),
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
