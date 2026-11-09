import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic.dart';
import '../models.dart';
import '../store.dart';
import '../util.dart';
import 'widgets.dart';

// ---------------------------------------------------------------------------
// Ações comuns
// ---------------------------------------------------------------------------

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

Future<void> pickWorkout(BuildContext context) async {
  final data = Store.instance.data;
  final chosen = await showModalBottomSheet<WorkoutTemplate>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final t = mt(ctx);
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('Escolha o treino', style: t.head(20, weight: FontWeight.w800)),
            ),
            for (final x in data.templates)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: MooCard(
                  padding: const EdgeInsets.all(12),
                  onTap: () => Navigator.pop(ctx, x),
                  child: Row(
                    children: [
                      CodeBadge(x.code, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(x.name, style: t.body(15, weight: FontWeight.w700)),
                            Text(weekdayNames[x.weekday], style: t.body(13, color: t.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
  if (chosen != null && context.mounted) await startWorkout(context, chosen);
}

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
        final t = mt(context);
        final data = store.data;
        final history = [...data.sessions]..sort((a, b) => b.start.compareTo(a.start));
        return ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            PageHeader(
              'Treinos',
              kicker: 'Sua divisão',
              trailing: PillButton(
                label: 'Novo',
                icon: Icons.add,
                onPressed: () async {
                  final tpl = WorkoutTemplate(code: _nextCode(data.templates), name: 'Novo treino');
                  data.templates.add(tpl);
                  await store.save();
                  if (context.mounted) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => TemplateEditPage(template: tpl)));
                  }
                },
              ),
            ),
            if (data.draft != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 4),
                child: DraftBanner(draft: data.draft!),
              ),
            for (final tpl in data.templates)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
                child: MooCard(
                  padding: const EdgeInsets.all(14),
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => TemplateDetailPage(templateId: tpl.id))),
                  child: Row(
                    children: [
                      CodeBadge(tpl.code, size: 44),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tpl.name, style: t.body(16, weight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text('${weekdayNames[tpl.weekday]} · ${tpl.exercises.length} exercícios',
                                style: t.body(13, color: t.muted)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: t.muted),
                    ],
                  ),
                ),
              ),
            const SectionTitle('Histórico', icon: Icons.history),
            if (history.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text('Nenhum treino registrado ainda.', style: t.body(14, color: t.muted)),
              ),
            for (final s in history.take(60))
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: MooCard(
                  padding: const EdgeInsets.all(14),
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => SessionViewPage(sessionId: s.id))),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: t.good),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${s.templateCode} · ${s.templateName}', style: t.body(15, weight: FontWeight.w700)),
                            Text(
                                '${fmtDate(s.start)} · ${s.doneSetCount} séries · ${fmtNum(s.volume / 1000, 1)} t',
                                style: t.body(13, color: t.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _nextCode(List<WorkoutTemplate> ts) {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    for (final ch in letters.split('')) {
      if (!ts.any((x) => x.code == ch)) return ch;
    }
    return '?';
  }
}

class DraftBanner extends StatelessWidget {
  final Session draft;
  const DraftBanner({super.key, required this.draft});

  @override
  Widget build(BuildContext context) {
    final t = mt(context);
    return MooCard(
      color: t.acc,
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SessionPage())),
      child: Row(
        children: [
          Icon(Icons.play_circle_fill, color: t.onAcc, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Treino em andamento', style: t.body(12, weight: FontWeight.w700, color: t.onAcc)),
                Text('${draft.templateCode} · ${draft.templateName}',
                    style: t.head(18, weight: FontWeight.w800, color: t.onAcc)),
                Text('Começou às ${fmtTime(draft.start)} · toque para continuar',
                    style: t.body(13, color: t.onAcc)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: t.onAcc),
        ],
      ),
    );
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
        final t = mt(context);
        final tpl = store.templateById(templateId);
        if (tpl == null) {
          return Scaffold(appBar: mooAppBar(context, ''), body: const Center(child: Text('Treino removido.')));
        }
        return Scaffold(
          appBar: mooAppBar(
            context,
            tpl.name,
            subtitle: 'Treino ${tpl.code} · ${weekdayNames[tpl.weekday]}',
            actions: [
              IconButton(
                tooltip: 'Editar treino',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) => TemplateEditPage(template: tpl))),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
              child: MooButton(
                label: 'Começar treino',
                icon: Icons.play_arrow_rounded,
                expand: true,
                onPressed: tpl.exercises.isEmpty ? null : () => startWorkout(context, tpl),
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            children: [
              for (final ex in tpl.exercises)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ExercisePreview(ex: ex),
                ),
              if (tpl.exercises.isEmpty)
                Text('Sem exercícios. Toque no lápis para adicionar.', style: t.body(14, color: t.muted)),
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
    final t = mt(context);
    final data = Store.instance.data;
    final last = lastLogFor(data, ex.id);
    final lastDate = lastDateFor(data, ex.id);
    final sug = suggest(ex, last);
    return MooCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ex.name, style: t.body(16, weight: FontWeight.w700)),
          Text('${ex.sets} × ${ex.repMin}–${ex.repMax}${ex.note.isEmpty ? '' : ' · ${ex.note}'}',
              style: t.body(13, color: t.muted)),
          const SizedBox(height: 8),
          _SuggestionBox(sug: sug, last: last, lastDate: lastDate),
        ],
      ),
    );
  }
}

class _SuggestionBox extends StatelessWidget {
  final Suggestion sug;
  final ExerciseLog? last;
  final DateTime? lastDate;
  const _SuggestionBox({required this.sug, required this.last, required this.lastDate});

  @override
  Widget build(BuildContext context) {
    final t = mt(context);
    final color = sug.increase ? t.good : (t.key == 'noturno' ? t.acc : t.acc);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: t.tint, borderRadius: BorderRadius.circular(t.radiusSmall)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (last != null && lastDate != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('Última (${fmtDateShort(lastDate!)}): ${describeSets(last!.sets)}',
                  style: t.body(12, color: t.muted)),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(sug.increase ? Icons.trending_up : Icons.lightbulb_outline, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(child: Text(sug.text, style: t.body(14, weight: FontWeight.w700, color: color))),
            ],
          ),
        ],
      ),
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

  WorkoutTemplate get tpl => widget.template;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _persist() async {
    tpl.name = _name.text.trim().isEmpty ? 'Treino' : _name.text.trim();
    tpl.code = _code.text.trim().toUpperCase();
    await Store.instance.save();
    if (mounted) setState(() {});
  }

  Future<void> _editExercise({ExerciseTemplate? ex}) async {
    final result = await showDialog<ExerciseTemplate>(
      context: context,
      builder: (_) => _ExerciseDialog(existing: ex),
    );
    if (result == null) return;
    if (ex == null) tpl.exercises.add(result);
    await _persist();
  }

  void _move(int i, int delta) {
    final j = i + delta;
    if (j < 0 || j >= tpl.exercises.length) return;
    final ex = tpl.exercises.removeAt(i);
    tpl.exercises.insert(j, ex);
    _persist();
  }

  Future<void> _deleteTemplate() async {
    final ok = await confirmDialog(context, 'Apagar treino?',
        'O histórico de sessões continua salvo. Só o modelo "${tpl.name}" é removido.',
        ok: 'Apagar');
    if (!ok) return;
    final store = Store.instance;
    store.data.templates.removeWhere((x) => x.id == tpl.id);
    await store.save();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = mt(context);
    return Scaffold(
      appBar: mooAppBar(context, 'Editar treino', actions: [
        IconButton(tooltip: 'Apagar treino', icon: const Icon(Icons.delete_outline), onPressed: _deleteTemplate),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: MooButton(label: 'Adicionar exercício', icon: Icons.add, expand: true, onPressed: () => _editExercise()),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          Row(
            children: [
              SizedBox(
                width: 84,
                child: MooTextField(
                  controller: _code,
                  label: 'Letra',
                  capitalization: TextCapitalization.characters,
                  onChanged: (_) => _persist(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: MooTextField(controller: _name, label: 'Nome', onChanged: (_) => _persist())),
            ],
          ),
          const SizedBox(height: 14),
          Text('Dia da semana', style: t.body(13, weight: FontWeight.w700, color: t.muted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < weekdayNames.length; i++)
                ChoiceChip(
                  label: Text(i == 0 ? 'Livre' : weekdayShort[i]),
                  selected: tpl.weekday == i,
                  onSelected: (_) {
                    tpl.weekday = i;
                    _persist();
                  },
                ),
            ],
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < tpl.exercises.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: MooCard(
                padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                onTap: () => _editExercise(ex: tpl.exercises[i]),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tpl.exercises[i].name, style: t.body(15, weight: FontWeight.w700)),
                          Text(
                            '${tpl.exercises[i].sets} × ${tpl.exercises[i].repMin}–${tpl.exercises[i].repMax}'
                            '${tpl.exercises[i].startLoad == null ? '' : ' · início ${fmtNum(tpl.exercises[i].startLoad!)} kg'}'
                            '${tpl.exercises[i].note.isEmpty ? '' : '\n${tpl.exercises[i].note}'}',
                            style: t.body(13, color: t.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                        tooltip: 'Subir',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.arrow_upward),
                        onPressed: i == 0 ? null : () => _move(i, -1)),
                    IconButton(
                        tooltip: 'Descer',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.arrow_downward),
                        onPressed: i == tpl.exercises.length - 1 ? null : () => _move(i, 1)),
                    IconButton(
                      tooltip: 'Remover',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close),
                      onPressed: () async {
                        final ok = await confirmDialog(context, 'Remover exercício?', tpl.exercises[i].name,
                            ok: 'Remover');
                        if (ok) {
                          tpl.exercises.removeAt(i);
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
            MooTextField(controller: _name, label: 'Nome', autofocus: widget.existing == null),
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
            MooTextField(controller: _note, label: 'Observação'),
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
  Timer? _restTimer;
  Timer? _clock;
  int _restLeft = 0;
  int _restDefault = 90;
  int _restTotal = 90;
  String? _open; // exercício aberto (acordeão)

  @override
  void initState() {
    super.initState();
    final s = Store.instance.data.draft;
    if (s != null) _open = _firstIncomplete(s)?.exerciseId;
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _clock?.cancel();
    super.dispose();
  }

  bool _complete(ExerciseLog e) => e.sets.isNotEmpty && e.sets.every((s) => s.done);

  ExerciseLog? _firstIncomplete(Session s, {String? after}) {
    var passed = after == null;
    for (final e in s.exercises) {
      if (!passed) {
        if (e.exerciseId == after) passed = true;
        continue;
      }
      if (!_complete(e)) return e;
    }
    if (after != null) {
      for (final e in s.exercises) {
        if (!_complete(e)) return e;
      }
    }
    return null;
  }

  void _startRest([int? seconds]) {
    final secs = seconds ?? _restDefault;
    _restTimer?.cancel();
    setState(() {
      _restTotal = secs;
      _restLeft = secs;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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

  void _stopRest() {
    _restTimer?.cancel();
    setState(() => _restLeft = 0);
  }

  void _onSetDone(Session s, ExerciseLog e) {
    _startRest();
    if (_complete(e)) {
      setState(() => _open = _firstIncomplete(s, after: e.exerciseId)?.exerciseId);
    }
  }

  Future<void> _finish(Session s) async {
    final done = s.doneSetCount;
    final ok = await confirmDialog(
      context,
      'Finalizar treino?',
      done == 0 ? 'Nenhuma série marcada como feita. O treino será descartado.' : '$done séries feitas serão salvas.',
      ok: 'Finalizar',
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await Store.instance.finishDraft();
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(done == 0 ? 'Treino descartado.' : 'Treino salvo! Moo!')));
  }

  Future<void> _discard() async {
    final ok = await confirmDialog(context, 'Descartar treino?', 'Nada desta sessão será salvo.', ok: 'Descartar');
    if (!ok) return;
    await Store.instance.discardDraft();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = mt(context);
    final store = Store.instance;
    final s = store.data.draft;
    if (s == null) {
      return Scaffold(appBar: mooAppBar(context, ''), body: const Center(child: Text('Nenhum treino em andamento.')));
    }
    final template = store.templateById(s.templateId);
    final minutes = DateTime.now().difference(s.start).inMinutes;
    return Scaffold(
      appBar: mooAppBar(
        context,
        s.templateName,
        subtitle: 'Treino ${s.templateCode} · começou ${fmtTime(s.start)} · $minutes min',
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Mais opções',
            onSelected: (v) {
              if (v == 'discard') {
                _discard();
              } else {
                final secs = int.tryParse(v);
                if (secs != null) setState(() => _restDefault = secs);
              }
            },
            itemBuilder: (_) => [
              for (final secs in [60, 90, 120, 180])
                CheckedPopupMenuItem<String>(
                  value: '$secs',
                  checked: _restDefault == secs,
                  child: Text('Descanso padrão: ${secs < 120 ? '$secs s' : '${secs ~/ 60} min'}'),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(value: 'discard', child: Text('Descartar treino')),
            ],
          ),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        restLeft: _restLeft,
        restTotal: _restTotal,
        restDefault: _restDefault,
        onStart: () => _startRest(),
        onAdd: () => setState(() {
          _restLeft += 30;
          _restTotal += 30;
        }),
        onStop: _stopRest,
        onFinish: () => _finish(s),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
            child: Row(
              children: [
                for (var i = 0; i < s.exercises.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: _complete(s.exercises[i]) ? t.acc : t.surf2,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
              children: [
                for (final log in s.exercises)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ExerciseCard(
                      key: ValueKey(log.exerciseId),
                      log: log,
                      template: _findEx(template, log.exerciseId),
                      open: _open == log.exerciseId,
                      onToggle: () => setState(() => _open = _open == log.exerciseId ? null : log.exerciseId),
                      onChanged: () {
                        store.saveDraft();
                        setState(() {});
                      },
                      onSetDone: () => _onSetDone(s, log),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ExerciseTemplate? _findEx(WorkoutTemplate? tpl, String id) {
    if (tpl == null) return null;
    for (final e in tpl.exercises) {
      if (e.id == id) return e;
    }
    return null;
  }
}

class _BottomBar extends StatelessWidget {
  final int restLeft;
  final int restTotal;
  final int restDefault;
  final VoidCallback onStart;
  final VoidCallback onAdd;
  final VoidCallback onStop;
  final VoidCallback onFinish;
  const _BottomBar({
    required this.restLeft,
    required this.restTotal,
    required this.restDefault,
    required this.onStart,
    required this.onAdd,
    required this.onStop,
    required this.onFinish,
  });

  String _fmt(int secs) => '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final t = mt(context);
    final running = restLeft > 0;
    final topBorder = t.borderWidth >= 2
        ? BorderSide(color: t.line, width: 2)
        : BorderSide(color: t.isDark ? const Color(0xFF24272E) : t.line, width: 1);
    final radius = BorderRadius.circular(t.radiusSmall);
    return Container(
      decoration: BoxDecoration(color: t.navBg, border: Border(top: topBorder)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
          child: Row(
            children: [
              Expanded(
                child: Material(
                  color: t.timerBg,
                  borderRadius: radius,
                  child: InkWell(
                    borderRadius: radius,
                    onTap: running ? onStop : onStart,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                      child: Row(
                        children: [
                          Icon(Icons.timer_outlined, color: t.timerFg),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(running ? 'Descanso · toque p/ parar' : 'Descanso · toque p/ iniciar',
                                    style: t.body(11, weight: FontWeight.w600, color: t.timerFg)),
                                Text(_fmt(running ? restLeft : restDefault),
                                    style: t.head(22, color: running ? t.timerFg : t.timerFg.withAlpha(150))),
                                if (running) ...[
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      minHeight: 3,
                                      value: restTotal <= 0 ? 0.0 : (restLeft / restTotal).clamp(0.0, 1.0).toDouble(),
                                      color: t.timerFg,
                                      backgroundColor: t.timerFg.withAlpha(50),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (running)
                            TextButton(
                              onPressed: onAdd,
                              style: TextButton.styleFrom(foregroundColor: t.timerFg),
                              child: Text('+30 s', style: t.body(13, weight: FontWeight.w700, color: t.timerFg)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              MooButton(label: 'Finalizar', icon: Icons.check, primary: t.key != 'noturno', onPressed: onFinish),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final ExerciseLog log;
  final ExerciseTemplate? template;
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onChanged;
  final VoidCallback onSetDone;
  const _ExerciseCard({
    super.key,
    required this.log,
    required this.template,
    required this.open,
    required this.onToggle,
    required this.onChanged,
    required this.onSetDone,
  });

  @override
  Widget build(BuildContext context) {
    final t = mt(context);
    final data = Store.instance.data;
    final ex = template;
    final last = lastLogFor(data, log.exerciseId);
    final lastDate = lastDateFor(data, log.exerciseId);
    final sug = ex == null ? null : suggest(ex, last);
    final doneCount = log.sets.where((s) => s.done).length;
    final complete = log.sets.isNotEmpty && doneCount == log.sets.length;
    final repHint = ex == null ? 'reps' : '${ex.repMin}–${ex.repMax}';
    final info = ex == null ? '' : '${ex.sets} × ${ex.repMin}–${ex.repMax}${ex.note.isEmpty ? '' : ' · ${ex.note}'}';

    final header = InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(t.radius),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(log.name, style: open ? t.head(20, weight: FontWeight.w800) : t.body(16, weight: FontWeight.w700)),
                  if (info.isNotEmpty) Text(info, style: t.body(13, color: t.muted)),
                  if (!open && sug != null && !complete)
                    Text(sug.text, style: t.body(12, color: t.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            complete
                ? Icon(Icons.check_circle, color: t.good)
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: t.surf2,
                      borderRadius: BorderRadius.circular(999),
                      border: t.borderWidth >= 2 ? Border.all(color: t.line, width: 2) : null,
                    ),
                    child: Text('$doneCount/${log.sets.length}', style: t.body(12, weight: FontWeight.w700)),
                  ),
            Icon(open ? Icons.expand_less : Icons.expand_more, color: t.muted),
          ],
        ),
      ),
    );

    return DecoratedBox(
      decoration: t.card(),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            if (open)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (sug != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _SuggestionBox(sug: sug, last: last, lastDate: lastDate),
                      ),
                      const SizedBox(height: 8),
                    ],
                    for (var i = 0; i < log.sets.length; i++)
                      _SetRow(
                        key: ObjectKey(log.sets[i]),
                        index: i,
                        set: log.sets[i],
                        repHint: repHint,
                        onChanged: onChanged,
                        onDone: onSetDone,
                      ),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            final prev = log.sets.isEmpty ? null : log.sets.last;
                            log.sets.add(SetLog(load: prev?.load));
                            onChanged();
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Série'),
                        ),
                        if (log.sets.isNotEmpty)
                          TextButton.icon(
                            onPressed: () {
                              log.sets.removeLast();
                              onChanged();
                            },
                            icon: const Icon(Icons.remove),
                            label: const Text('Remover'),
                          ),
                      ],
                    ),
                  ],
                ),
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

  Widget _field(BuildContext context, TextEditingController c, String label, String? hint, bool decimal,
      ValueChanged<String> onChanged) {
    final t = mt(context);
    return TextField(
      controller: c,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      textAlign: TextAlign.center,
      style: t.head(20),
      decoration: t.input(label, hint: hint, dense: true),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = mt(context);
    final s = widget.set;
    final radius = BorderRadius.circular(10);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: s.done && t.key == 'noturno' ? t.surf2 : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text('${widget.index + 1}',
                textAlign: TextAlign.center, style: t.body(15, weight: FontWeight.w700, color: t.muted)),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _field(context, _load, 'kg', null, true, (v) {
              s.load = parseNum(v);
              widget.onChanged();
            }),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _field(context, _reps, 'reps', widget.repHint, false, (v) {
              s.reps = parseInt(v);
              widget.onChanged();
            }),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: s.done ? 'Desmarcar série ${widget.index + 1}' : 'Marcar série ${widget.index + 1} como feita',
            child: Material(
              color: s.done ? t.acc : Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: radius,
                side: BorderSide(
                  color: s.done
                      ? (t.borderWidth >= 2 ? t.line : t.acc)
                      : (t.borderWidth >= 2 ? t.line : (t.isDark ? const Color(0xFF3A3F48) : t.line)),
                  width: 2,
                ),
              ),
              child: InkWell(
                borderRadius: radius,
                onTap: () {
                  if (!s.done && s.reps == null) {
                    showSnack(context, 'Informe as repetições antes de marcar a série.');
                    return;
                  }
                  s.done = !s.done;
                  FocusScope.of(context).unfocus();
                  widget.onChanged();
                  if (s.done) widget.onDone();
                },
                child: SizedBox(
                  width: 52,
                  height: 48,
                  child: Icon(Icons.check_rounded, size: 26, color: s.done ? t.onAcc : t.muted),
                ),
              ),
            ),
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
    final t = mt(context);
    final store = Store.instance;
    Session? found;
    for (final x in store.data.sessions) {
      if (x.id == sessionId) found = x;
    }
    final session = found;
    if (session == null) {
      return Scaffold(appBar: mooAppBar(context, ''), body: const Center(child: Text('Sessão removida.')));
    }
    final duration = session.end == null ? null : session.end!.difference(session.start).inMinutes;
    return Scaffold(
      appBar: mooAppBar(
        context,
        session.templateName,
        subtitle: 'Treino ${session.templateCode} · ${fmtDate(session.start)}',
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
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          MooCard(
            child: Wrap(
              spacing: 22,
              runSpacing: 12,
              children: [
                StatTile(
                    label: 'Horário',
                    value: '${fmtTime(session.start)}${session.end == null ? '' : '–${fmtTime(session.end!)}'}'),
                if (duration != null) StatTile(label: 'Duração', value: '$duration', unit: 'min'),
                StatTile(label: 'Séries', value: '${session.doneSetCount}'),
                StatTile(label: 'Volume', value: fmtNum(session.volume, 0), unit: 'kg'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final e in session.exercises)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: MooCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.name, style: t.body(15, weight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(describeSets(e.sets), style: t.body(14, color: t.muted)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
