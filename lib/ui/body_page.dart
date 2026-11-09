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
        final data = store.data;
        final now = DateTime.now();
        var weights = weightEntries(data.body);
        if (_days > 0) {
          final from = dayOnly(now).subtract(Duration(days: _days));
          weights = weights.where((e) => !e.date.isBefore(from)).toList();
        }
        final avg = movingAverage(weightEntries(data.body))
            .where((e) => weights.isNotEmpty && !e.key.isBefore(weights.first.date))
            .toList();
        final stats = weightStats(data.body, now);
        final waist = latestWith(data.body, (e) => e.waist);
        final firstWaist = _firstWith(data.body, (e) => e.waist);
        final fat = latestWith(data.body, (e) => e.bodyFat);
        final entries = [...data.body]..sort((a, b) => b.date.compareTo(a.date));
        final advice = adjustmentAdvice(data, now);

        return Scaffold(
          appBar: AppBar(title: const Text('Corpo')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => openBodyEntry(context),
            icon: const Icon(Icons.add),
            label: const Text('Registrar'),
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 16,
                      children: [
                        StatTile(
                          label: 'Último peso',
                          value: stats.last == null ? '—' : '${fmtNum(stats.last!, 2)} kg',
                          sub: stats.lastDate == null ? null : fmtDate(stats.lastDate!),
                        ),
                        StatTile(
                          label: 'Média 7 dias',
                          value: stats.avg7 == null ? '—' : '${fmtNum(stats.avg7!, 2)} kg',
                          sub: stats.weeklyChange == null
                              ? null
                              : '${stats.weeklyChange! > 0 ? '+' : ''}${fmtNum(stats.weeklyChange!, 2)} kg na semana',
                        ),
                        StatTile(
                          label: 'Desde o início',
                          value: (stats.last == null || stats.first == null)
                              ? '—'
                              : '${stats.last! - stats.first! > 0 ? '+' : ''}${fmtNum(stats.last! - stats.first!, 2)} kg',
                          sub: stats.firstDate == null ? null : 'desde ${fmtDate(stats.firstDate!)}',
                        ),
                        StatTile(
                          label: 'Cintura',
                          value: waist == null ? '—' : '${fmtNum(waist.waist!)} cm',
                          sub: (waist != null && firstWaist != null && firstWaist.id != waist.id)
                              ? '${waist.waist! - firstWaist.waist! > 0 ? '+' : ''}${fmtNum(waist.waist! - firstWaist.waist!)} cm desde ${fmtDateShort(firstWaist.date)}'
                              : (waist == null ? null : fmtDate(waist.date)),
                        ),
                        if (fat != null)
                          StatTile(
                            label: 'Gordura (bioimpedância)',
                            value: '${fmtNum(fat.bodyFat!)}%',
                            sub: fmtDate(fat.date),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (advice != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Card(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: ListTile(leading: const Icon(Icons.insights), title: Text(advice)),
                  ),
                ),
              SectionTitle(
                'Peso',
                trailing: DropdownButton<int>(
                  value: _days,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 30, child: Text('30 dias')),
                    DropdownMenuItem(value: 90, child: Text('90 dias')),
                    DropdownMenuItem(value: 0, child: Text('Tudo')),
                  ],
                  onChanged: (v) => setState(() => _days = v ?? 90),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SimpleLineChart(
                  points: weights.map((e) => MapEntry(e.date, e.weight!)).toList(),
                  line: avg,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text('Pontos: pesagens. Linha: média dos últimos 7 dias.',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
              const SectionTitle('Registros'),
              if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Nenhum registro. Toque em "Registrar" para adicionar peso, cintura ou bioimpedância.'),
                ),
              for (final e in entries)
                Dismissible(
                  key: ValueKey(e.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Theme.of(context).colorScheme.errorContainer,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child: const Icon(Icons.delete),
                  ),
                  confirmDismiss: (_) => confirmDialog(context, 'Apagar registro?', 'Registro de ${fmtDate(e.date)}.',
                      ok: 'Apagar'),
                  onDismissed: (_) => store.deleteBody(e),
                  child: ListTile(
                    title: Text(_entryTitle(e)),
                    subtitle: Text([fmtDate(e.date), if (e.note.isNotEmpty) e.note].join(' · ')),
                    onTap: () => openBodyEntry(context, existing: e),
                  ),
                ),
            ],
          ),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Novo registro' : 'Editar registro'),
        actions: [TextButton(onPressed: _save, child: const Text('Salvar'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(fmtDate(_date)),
            subtitle: const Text('Toque para mudar a data'),
            onTap: _pickDate,
          ),
          const SizedBox(height: 8),
          NumberField(controller: _weight, label: 'Peso', suffix: 'kg', autofocus: widget.existing == null),
          const SizedBox(height: 12),
          NumberField(controller: _waist, label: 'Cintura (altura do umbigo)', suffix: 'cm'),
          const SizedBox(height: 20),
          Text('Bioimpedância (opcional)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          NumberField(controller: _fat, label: 'Gordura corporal', suffix: '%'),
          const SizedBox(height: 12),
          NumberField(controller: _lean, label: 'Massa magra (LBM)', suffix: 'kg'),
          const SizedBox(height: 12),
          NumberField(controller: _visceral, label: 'Gordura visceral (índice)'),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Observação', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Text(
            'Dica: pese-se ao acordar, depois do banheiro e antes de comer. Cintura toda sexta, em jejum.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
