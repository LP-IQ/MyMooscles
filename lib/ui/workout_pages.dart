import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic.dart';
import '../models.dart';
import '../store.dart';
import '../util.dart';
import 'widgets.dart';

// ---------------------------------------------------------------------------
// Lista de treinos + histórico
// ---------------------------------------------------------------------------

class WorkoutsPage extends StatelessWidget {
  const WorkoutsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final data = store.data;
        final history = [...data.sessions]..sort((a, b) => b.start.compareTo(a.start));
        return Scaffold(
          appBar: AppBar(title: const Text('Treinos')),
          floatingActionButton: FloatingActionButton(
            tooltip: 'Novo treino',
            onPressed: () async {
              final t = WorkoutTemplate(code: _nextCode(data.templates), name: 'Novo treino');
              data.templates.add(t);
              await store.save();
              if (context.mounted) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => TemplateEditPage(template: t)));
              }
            },
            child: const Icon(Icons.add),
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              if (data.draft != null) DraftBanner(draft: data.draft!),
              const SectionTitle('Divisão'),
              for (final t in data.templates)
                ListTile(
                  leading: CircleAvatar(child: Text(t.code.isEmpty ? '?' : t.code)),
                  title: Text(t.name),
                  subtitle: Text('${weekdayNames[t.weekday]} · ${t.exercises.length} exercícios'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => TemplateDetailPage(templateId: t.id))),
                ),
              const SectionTitle('Histórico'),
              if (history.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Nenhum treino registrado ainda.'),
                ),
              for (final s in history.take(60))
                ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text('${s.templateCode} · ${s.templateName}'),
                  subtitle: Text(
                      '${fmtDate(s.start)} · ${s.doneSetCount} séries · ${fmtNum(s.volume / 1000, 1)} t de volume'),
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => SessionViewPage(sessionId: s.id))),
                ),
            ],
          ),
        );
      },
    );
  }

  String _nextCode(List<WorkoutTemplate> ts) {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    for (final ch in letters.split('')) {
      if (!ts.any((t) => t.code == ch)) return ch;
    }
    return '?';
  }
}

class DraftBanner extends StatelessWidget {
  final Session draft;
  const DraftBanner({super.key, required this.draft});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: ListTile(
          leading: const Icon(Icons.play_circle_fill),
          title: Text('Treino em andamento: ${draft.templateCode} · ${draft.templateName}'),
          subtitle: Text('Começou às ${fmtTime(draft.start)} de ${fmtDateShort(draft.start)}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SessionPage())),
        ),
      ),
    );
  }
}

Future<void> startWorkout(BuildContext context, WorkoutTemplate t) async {
  final store = Store.instance;
  if (store.data.draft != null) {
    final replace = await confirmDialog(
      context,
      'Já existe um treino em andamento',
      'Descartar o treino em andamento (${store.data.draft!.templateName}) e começar ${t.name}?',
      ok: 'Descartar e começar',
    );
    if (!replace) return;
  }
  await store.startSession(t);
  if (context.mounted) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SessionPage()));
  }
}

// ---------------------------------------------------------------------------
// Detalhe de um treino (modelo)
// ---------------------------------------------------------------------------

class TemplateDetailPage extends StatelessWidget {
  final String templateId;
  const TemplateDetailPage({super.key, required this.templateId});

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final t = store.templateById(templateId);
        if (t == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('Treino removido.')));
        }
        return Scaffold(
          appBar: AppBar(
            title: Text('${t.code} · ${t.name}'),
            actions: [
              IconButton(
                tooltip: 'Editar',
                icon: const Icon(Icons.edit),
                onPressed: () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) => TemplateEditPage(template: t))),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: t.exercises.isEmpty ? null : () => startWorkout(context, t),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Começar treino'),
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(weekdayNames[t.weekday], style: Theme.of(context).textTheme.bodyMedium),
              ),
              for (final ex in t.exercises) _ExercisePreview(ex: ex),
            ],
          ),
        );
      },
    );
  }
}

class _ExercisePreview extends StatelessWidget {
  final ExerciseTemplate ex;
  const _ExercisePreview({required this.ex});

  @override
  Widget build(BuildContext context) {
    final data = Store.instance.data;
    final last = lastLogFor(data, ex.id);
    final lastDate = lastDateFor(data, ex.id);
    final sug = suggest(ex, last);
    final lines = <String>[
      '${ex.sets} × ${ex.repMin}–${ex.repMax}${ex.note.isEmpty ? '' : ' · ${ex.note}'}',
      if (last != null && lastDate != null) 'Última (${fmtDateShort(lastDate)}): ${describeSets(last.sets)}',
      sug.text,
    ];
    return ListTile(
      title: Text(ex.name),
      subtitle: Text(lines.join('\n')),
      isThreeLine: lines.length > 2,
      trailing: sug.increase ? const Icon(Icons.trending_up, color: Colors.green) : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Edição de um treino (modelo)
// ---------------------------------------------------------------------------

class TemplateEditPage extends StatefulWidget {
  final WorkoutTemplate template;
  const TemplateEditPage({super.key, required this.template});

  @override
  State<TemplateEditPage> createState() => _TemplateEditPageState();
}

class _TemplateEditPageState extends State<TemplateEditPage> {
  late final TextEditingController _name = TextEditingController(text: widget.template.name);
  late final TextEditingController _code = TextEditingController(text: widget.template.code);

  WorkoutTemplate get t => widget.template;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _persist() async {
    t.name = _name.text.trim().isEmpty ? 'Treino' : _name.text.trim();
    t.code = _code.text.trim().toUpperCase();
    await Store.instance.save();
    if (mounted) setState(() {});
  }

  Future<void> _editExercise({ExerciseTemplate? ex}) async {
    final result = await showDialog<ExerciseTemplate>(
      context: context,
      builder: (_) => _ExerciseDialog(existing: ex),
    );
    if (result == null) return;
    if (ex == null) t.exercises.add(result);
    await _persist();
  }

  void _move(int i, int delta) {
    final j = i + delta;
    if (j < 0 || j >= t.exercises.length) return;
    final ex = t.exercises.removeAt(i);
    t.exercises.insert(j, ex);
    _persist();
  }

  Future<void> _deleteTemplate() async {
    final ok = await confirmDialog(context, 'Apagar treino?',
        'O histórico de sessões continua salvo. Só o modelo "${t.name}" é removido.',
        ok: 'Apagar');
    if (!ok) return;
    final store = Store.instance;
    store.data.templates.removeWhere((x) => x.id == t.id);
    await store.save();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Editar treino'),
          actions: [
            IconButton(tooltip: 'Apagar treino', icon: const Icon(Icons.delete_outline), onPressed: _deleteTemplate),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _editExercise(),
          icon: const Icon(Icons.add),
          label: const Text('Exercício'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Row(
              children: [
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Letra', border: OutlineInputBorder()),
                    onChanged: (_) => _persist(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder()),
                    onChanged: (_) => _persist(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Dia da semana: '),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: t.weekday,
                  items: [
                    for (var i = 0; i < weekdayNames.length; i++)
                      DropdownMenuItem(value: i, child: Text(weekdayNames[i])),
                  ],
                  onChanged: (v) {
                    t.weekday = v ?? 0;
                    _persist();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < t.exercises.length; i++)
              Card(
                child: ListTile(
                  title: Text(t.exercises[i].name),
                  subtitle: Text(
                      '${t.exercises[i].sets} × ${t.exercises[i].repMin}–${t.exercises[i].repMax}'
                      '${t.exercises[i].startLoad == null ? '' : ' · início ${fmtNum(t.exercises[i].startLoad!)} kg'}'
                      '${t.exercises[i].note.isEmpty ? '' : '\n${t.exercises[i].note}'}'),
                  onTap: () => _editExercise(ex: t.exercises[i]),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.arrow_upward),
                          onPressed: i == 0 ? null : () => _move(i, -1)),
                      IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.arrow_downward),
                          onPressed: i == t.exercises.length - 1 ? null : () => _move(i, 1)),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close),
                        onPressed: () async {
                          final ok = await confirmDialog(
                              context, 'Remover exercício?', t.exercises[i].name, ok: 'Remover');
                          if (ok) {
                            t.exercises.removeAt(i);
                            await _persist();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
    );
  }
}

int clampInt(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

class _ExerciseDialog extends StatefulWidget {
  final ExerciseTemplate? existing;
  const _ExerciseDialog({this.existing});

  @override
  State<_ExerciseDialog> createState() => _ExerciseDialogState();
}

class _ExerciseDialogState extends State<_ExerciseDialog> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _sets = TextEditingController(text: '${widget.existing?.sets ?? 3}');
  late final _min = TextEditingController(text: '${widget.existing?.repMin ?? 8}');
  late final _max = TextEditingController(text: '${widget.existing?.repMax ?? 12}');
  late final _load = TextEditingController(
      text: widget.existing?.startLoad == null ? '' : fmtNum(widget.existing!.startLoad!));
  late final _note = TextEditingController(text: widget.existing?.note ?? '');

  @override
  void dispose() {
    for (final c in [_name, _sets, _min, _max, _load, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  void _ok() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final sets = clampInt(parseInt(_sets.text) ?? 3, 1, 10);
    var mn = clampInt(parseInt(_min.text) ?? 8, 1, 100);
    var mx = clampInt(parseInt(_max.text) ?? 12, 1, 100);
    if (mx < mn) {
      final tmp = mn;
      mn = mx;
      mx = tmp;
    }
    final e = widget.existing ?? ExerciseTemplate(name: name);
    e
      ..name = name
      ..sets = sets
      ..repMin = mn
      ..repMax = mx
      ..startLoad = parseNum(_load.text)
      ..note = _note.text.trim();
    Navigator.pop(context, e);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Novo exercício' : 'Editar exercício'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: widget.existing == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: NumberField(controller: _sets, label: 'Séries', decimal: false)),
                const SizedBox(width: 8),
                Expanded(child: NumberField(controller: _min, label: 'Reps mín.', decimal: false)),
                const SizedBox(width: 8),
                Expanded(child: NumberField(controller: _max, label: 'Reps máx.', decimal: false)),
              ],
            ),
            const SizedBox(height: 12),
            NumberField(controller: _load, label: 'Carga inicial (opcional)', suffix: 'kg'),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Observação', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _ok, child: const Text('OK')),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sessão em andamento
// ---------------------------------------------------------------------------

class SessionPage extends StatefulWidget {
  const SessionPage({super.key});

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> {
  Timer? _timer;
  int _restLeft = 0;
  int _restTotal = 90;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startRest([int seconds = 90]) {
    _timer?.cancel();
    setState(() {
      _restTotal = seconds;
      _restLeft = seconds;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _restLeft--);
      if (_restLeft <= 0) {
        timer.cancel();
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
      }
    });
  }

  Future<void> _finish(Session s) async {
    final done = s.doneSetCount;
    final ok = await confirmDialog(
      context,
      'Finalizar treino?',
      done == 0 ? 'Nenhuma série marcada como feita. O treino será descartado.' : '$done séries feitas serão salvas.',
      ok: 'Finalizar',
    );
    if (!ok) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await Store.instance.finishDraft();
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(done == 0 ? 'Treino descartado.' : 'Treino salvo!')));
  }

  Future<void> _discard() async {
    final ok = await confirmDialog(context, 'Descartar treino?', 'Nada desta sessão será salvo.', ok: 'Descartar');
    if (!ok) return;
    await Store.instance.discardDraft();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    final s = store.data.draft;
    if (s == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Nenhum treino em andamento.')));
    }
    final template = store.templateById(s.templateId);
    return Scaffold(
      appBar: AppBar(
        title: Text('${s.templateCode} · ${s.templateName}'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'discard') _discard();
            },
            itemBuilder: (_) => const [PopupMenuItem(value: 'discard', child: Text('Descartar treino'))],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _restLeft > 0
                    ? InkWell(
                        onTap: () => setState(() => _restLeft += 30),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Descanso: ${_restLeft ~/ 60}:${(_restLeft % 60).toString().padLeft(2, '0')}  (toque: +30 s)'),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(value: _restTotal <= 0 ? 0.0 : (_restLeft / _restTotal).clamp(0.0, 1.0).toDouble()),
                          ],
                        ),
                      )
                    : Wrap(
                        spacing: 8,
                        children: [
                          ActionChip(label: const Text('60 s'), onPressed: () => _startRest(60)),
                          ActionChip(label: const Text('90 s'), onPressed: () => _startRest(90)),
                          ActionChip(label: const Text('2 min'), onPressed: () => _startRest(120)),
                        ],
                      ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _finish(s),
                icon: const Icon(Icons.check),
                label: const Text('Finalizar'),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          for (final log in s.exercises)
            _ExerciseCard(
              log: log,
              template: _findEx(template, log.exerciseId),
              onChanged: () => store.saveDraft(),
              onSetDone: () => _startRest(_restTotal),
            ),
        ],
      ),
    );
  }

  ExerciseTemplate? _findEx(WorkoutTemplate? t, String id) {
    if (t == null) return null;
    for (final e in t.exercises) {
      if (e.id == id) return e;
    }
    return null;
  }
}

class _ExerciseCard extends StatefulWidget {
  final ExerciseLog log;
  final ExerciseTemplate? template;
  final VoidCallback onChanged;
  final VoidCallback onSetDone;
  const _ExerciseCard({required this.log, required this.template, required this.onChanged, required this.onSetDone});

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  @override
  Widget build(BuildContext context) {
    final data = Store.instance.data;
    final ex = widget.template;
    final last = lastLogFor(data, widget.log.exerciseId);
    final lastDate = lastDateFor(data, widget.log.exerciseId);
    final sug = ex == null ? null : suggest(ex, last);
    final t = Theme.of(context).textTheme;
    final repHint = ex == null ? 'reps' : '${ex.repMin}–${ex.repMax}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.log.name, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            if (ex != null)
              Text('${ex.sets} × ${ex.repMin}–${ex.repMax}${ex.note.isEmpty ? '' : ' · ${ex.note}'}', style: t.bodySmall),
            if (last != null && lastDate != null)
              Text('Última (${fmtDateShort(lastDate)}): ${describeSets(last.sets)}', style: t.bodySmall),
            if (sug != null)
              Text(sug.text,
                  style: t.bodySmall?.copyWith(
                      color: sug.increase ? Colors.green.shade700 : Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            for (var i = 0; i < widget.log.sets.length; i++)
              _SetRow(
                key: ObjectKey(widget.log.sets[i]),
                index: i,
                set: widget.log.sets[i],
                repHint: repHint,
                onChanged: widget.onChanged,
                onDone: widget.onSetDone,
              ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    final prev = widget.log.sets.isEmpty ? null : widget.log.sets.last;
                    setState(() => widget.log.sets.add(SetLog(load: prev?.load)));
                    widget.onChanged();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Série'),
                ),
                if (widget.log.sets.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      setState(() => widget.log.sets.removeLast());
                      widget.onChanged();
                    },
                    icon: const Icon(Icons.remove),
                    label: const Text('Remover'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SetRow extends StatefulWidget {
  final int index;
  final SetLog set;
  final String repHint;
  final VoidCallback onChanged;
  final VoidCallback onDone;
  const _SetRow({
    super.key,
    required this.index,
    required this.set,
    required this.repHint,
    required this.onChanged,
    required this.onDone,
  });

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  late final TextEditingController _load =
      TextEditingController(text: widget.set.load == null ? '' : fmtNum(widget.set.load!));
  late final TextEditingController _reps =
      TextEditingController(text: widget.set.reps == null ? '' : '${widget.set.reps}');

  @override
  void dispose() {
    _load.dispose();
    _reps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.set;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 28, child: Text('${widget.index + 1}', style: Theme.of(context).textTheme.titleSmall)),
          Expanded(
            child: TextField(
              controller: _load,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  isDense: true, labelText: 'kg', border: OutlineInputBorder()),
              onChanged: (v) {
                s.load = parseNum(v);
                widget.onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _reps,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  isDense: true, labelText: 'reps', hintText: widget.repHint, border: const OutlineInputBorder()),
              onChanged: (v) {
                s.reps = parseInt(v);
                widget.onChanged();
              },
            ),
          ),
          const SizedBox(width: 4),
          Checkbox(
            value: s.done,
            onChanged: (v) {
              if (s.reps == null && v == true) {
                showSnack(context, 'Informe as repetições antes de marcar a série.');
                return;
              }
              setState(() => s.done = v ?? false);
              widget.onChanged();
              if (s.done) {
                FocusScope.of(context).unfocus();
                widget.onDone();
              }
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Visualizar uma sessão salva
// ---------------------------------------------------------------------------

class SessionViewPage extends StatelessWidget {
  final String sessionId;
  const SessionViewPage({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    Session? s;
    for (final x in store.data.sessions) {
      if (x.id == sessionId) s = x;
    }
    final session = s;
    if (session == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Sessão removida.')));
    }
    final duration = session.end == null ? null : session.end!.difference(session.start).inMinutes;
    return Scaffold(
      appBar: AppBar(
        title: Text('${session.templateCode} · ${fmtDate(session.start)}'),
        actions: [
          IconButton(
            tooltip: 'Apagar',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await confirmDialog(context, 'Apagar sessão?', 'Esta sessão sai do histórico.', ok: 'Apagar');
              if (!ok) return;
              await store.deleteSession(session);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(session.templateName, style: Theme.of(context).textTheme.titleMedium),
          Text([
            '${fmtTime(session.start)}${session.end == null ? '' : '–${fmtTime(session.end!)}'}',
            if (duration != null) '$duration min',
            '${session.doneSetCount} séries',
            '${fmtNum(session.volume, 0)} kg de volume',
          ].join(' · ')),
          const SizedBox(height: 12),
          for (final e in session.exercises)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(e.name),
              subtitle: Text(describeSets(e.sets)),
            ),
        ],
      ),
    );
  }
}
