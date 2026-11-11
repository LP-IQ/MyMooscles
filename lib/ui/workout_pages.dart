import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic.dart';
import '../models.dart';
import '../rest_alert.dart';
import '../seed.dart';
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
    final last = lastLog(data, ex.id, ex.name);
    final sug = suggest(ex, last?.log);
    return MooCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ex.name, style: t.body(16, weight: FontWeight.w700)),
          Text(
              '${ex.sets} × ${ex.repMin}–${ex.repMax}${ex.timed ? ' s' : ''}${ex.note.isEmpty ? '' : ' · ${ex.note}'}',
              style: t.body(13, color: t.muted)),
          const SizedBox(height: 8),
          SuggestionBox(sug: sug, last: last),
          if (ex.alternatives.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Variações: ${ex.alternatives.join(', ')}', style: t.body(12, color: t.muted)),
          ],
        ],
      ),
    );
  }
}

class SuggestionBox extends StatelessWidget {
  final Suggestion sug;
  final LastLog? last;
  const SuggestionBox({super.key, required this.sug, required this.last});

  @override
  Widget build(BuildContext context) {
    final t = mt(context);
    final color = sug.increase ? t.good : t.acc;
    final l = last;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: t.tint, borderRadius: BorderRadius.circular(t.radiusSmall)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (l != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('Última (${fmtDateShort(l.date)}): ${describeLog(l.log)}', style: t.body(12, color: t.muted)),
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
  late final _warm = TextEditingController(text: '${widget.existing?.warmups ?? 1}');
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late final _alts = TextEditingController(text: (widget.existing?.alternatives ?? const <String>[]).join('\n'));
  late bool _timed = widget.existing?.timed ?? false;

  @override
  void dispose() {
    for (final c in [_name, _sets, _min, _max, _load, _warm, _note, _alts]) {
      c.dispose();
    }
    super.dispose();
  }

  void _ok() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final sets = clampInt(parseInt(_sets.text) ?? 3, 1, 10);
    var mn = clampInt(parseInt(_min.text) ?? 8, 1, 600);
    var mx = clampInt(parseInt(_max.text) ?? 12, 1, 600);
    if (mx < mn) {
      final tmp = mn;
      mn = mx;
      mx = tmp;
    }
    final alts = _alts.text.split('\n').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
    final e = widget.existing ?? ExerciseTemplate(name: name);
    e
      ..name = name
      ..sets = sets
      ..repMin = mn
      ..repMax = mx
      ..startLoad = parseNum(_load.text)
      ..warmups = clampInt(parseInt(_warm.text) ?? 0, 0, 5)
      ..timed = _timed
      ..alternatives = alts
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
                Expanded(child: NumberField(controller: _min, label: _timed ? 'Seg mín.' : 'Reps mín.', decimal: false)),
                const SizedBox(width: 8),
                Expanded(child: NumberField(controller: _max, label: _timed ? 'Seg máx.' : 'Reps máx.', decimal: false)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: NumberField(controller: _load, label: 'Carga inicial', suffix: 'kg')),
                const SizedBox(width: 8),
                Expanded(child: NumberField(controller: _warm, label: 'Aquecimento', decimal: false)),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Por tempo (segundos)'),
              subtitle: const Text('Prancha, isometria. Fica fora do volume.'),
              value: _timed,
              onChanged: (v) => setState(() => _timed = v),
            ),
            MooTextField(controller: _note, label: 'Observação'),
            const SizedBox(height: 12),
            MooTextField(controller: _alts, label: 'Variações (uma por linha)', minLines: 2, maxLines: 6),
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

  bool _complete(ExerciseLog e) => e.skipped || (e.sets.isNotEmpty && e.sets.every((s) => s.done));

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

  DateTime? _restEnd;

  String _restLabel() {
    final d = Store.instance.data.draft;
    if (d == null) return 'Próxima série';
    for (final e in d.exercises) {
      if (e.exerciseId == _open) return 'Próximo: ${e.name}';
    }
    return 'Treino ${d.templateCode}';
  }

  void _startRest([int? seconds]) {
    final secs = seconds ?? _restDefault;
    _restTimer?.cancel();
    _restEnd = DateTime.now().add(Duration(seconds: secs));
    setState(() {
      _restTotal = secs;
      _restLeft = secs;
    });
    RestAlert.instance.start(secs, _restLabel());
    // Conta pelo horário de término: continua certo mesmo se o app ficar em segundo plano.
    _restTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final end = _restEnd;
      final left = end == null ? 0 : (end.difference(DateTime.now()).inMilliseconds / 1000).ceil();
      if (left != _restLeft) setState(() => _restLeft = left < 0 ? 0 : left);
      if (left <= 0) {
        timer.cancel();
        _restEnd = null;
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
      }
    });
  }

  void _addRest(int seconds) {
    final end = _restEnd;
    if (end == null) return;
    final remaining = end.difference(DateTime.now()).inSeconds + seconds;
    final total = _restTotal + seconds;
    _startRest(remaining);
    setState(() => _restTotal = total);
  }

  void _stopRest() {
    _restTimer?.cancel();
    _restEnd = null;
    RestAlert.instance.stop();
    setState(() => _restLeft = 0);
  }

  void _onSetDone(Session s, ExerciseLog e) {
    if (_complete(e)) {
      setState(() => _open = _firstIncomplete(s, after: e.exerciseId)?.exerciseId);
    }
    _startRest();
  }

  Future<void> _editTemplate(Session s) async {
    final tpl = Store.instance.templateById(s.templateId);
    if (tpl == null) {
      showSnack(context, 'Este treino não está mais salvo.');
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => TemplateEditPage(template: tpl)));
    // Exercícios adicionados no treino entram também na sessão em andamento.
    final data = Store.instance.data;
    for (final ex in tpl.exercises) {
      if (!s.exercises.any((e) => e.exerciseId == ex.id)) s.exercises.add(buildExerciseLog(data, ex));
    }
    await Store.instance.saveDraft();
    if (mounted) setState(() {});
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
    _stopRest();
    await Store.instance.finishDraft();
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(done == 0 ? 'Treino descartado.' : 'Treino salvo!')));
  }

  Future<void> _discard() async {
    final ok = await confirmDialog(context, 'Descartar treino?', 'Nada desta sessão será salvo.', ok: 'Descartar');
    if (!ok) return;
    _stopRest();
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
              } else if (v == 'edit') {
                _editTemplate(s);
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
              const PopupMenuItem<String>(value: 'edit', child: Text('Editar treino (exercícios, ordem)')),
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
        onAdd: () => _addRest(30),
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
                        color: s.exercises[i].skipped
                            ? t.muted.withAlpha(110)
                            : (_complete(s.exercises[i]) ? t.acc : t.surf2),
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
                      key: ValueKey(log),
                      log: log,
                      template: _findEx(template, log.exerciseId),
                      open: _open == log.exerciseId,
                      onToggle: () => setState(() => _open = _open == log.exerciseId ? null : log.exerciseId),
                      onChanged: () {
                        store.saveDraft();
                        setState(() {});
                      },
                      onSetDone: () => _onSetDone(s, log),
                      onSkip: () {
                        log.skipped = !log.skipped;
                        store.saveDraft();
                        setState(() {
                          if (log.skipped && _open == log.exerciseId) {
                            _open = _firstIncomplete(s, after: log.exerciseId)?.exerciseId;
                          }
                        });
                      },
                    ),
                  ),
                MooButton(
                  label: 'Adicionar exercício',
                  icon: Icons.add,
                  primary: false,
                  expand: true,
                  onPressed: () => _addExercise(s),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addExercise(Session s) async {
    final r = await showDialog<_NewExercise>(
      context: context,
      builder: (_) => _AddExerciseDialog(templateCode: s.templateCode),
    );
    if (r == null) return;
    await Store.instance.addExerciseToDraft(
      name: r.name,
      sets: r.sets,
      repMin: r.repMin,
      repMax: r.repMax,
      timed: r.timed,
      addToTemplate: r.addToTemplate,
    );
    if (mounted) setState(() => _open = s.exercises.last.exerciseId);
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
  final VoidCallback onSkip;
  const _ExerciseCard({
    super.key,
    required this.log,
    required this.template,
    required this.open,
    required this.onToggle,
    required this.onChanged,
    required this.onSetDone,
    required this.onSkip,
  });

  /// Nome original + variações cadastradas (sem repetir).
  List<String> _variantOptions() {
    final tpl = template;
    return <String>[
      if (tpl != null) tpl.name,
      ...?tpl?.alternatives,
      if (tpl == null) log.name,
      if (tpl == null) ...(defaultAlternatives[log.name] ?? const <String>[]),
      log.name,
    ].toSet().toList();
  }

  Future<void> _chooseVariant(BuildContext context, {bool typeOnly = false}) async {
    final t = mt(context);
    final tpl = template;
    final options = _variantOptions().where((x) => x != log.name).toList();
    final chosen = typeOnly ? '__outro__' : await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text('Trocar ${log.name}', style: t.head(20, weight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Cada variação guarda o próprio histórico de cargas.', style: t.body(13, color: t.muted)),
            const SizedBox(height: 12),
            for (final o in options)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: MooCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  onTap: () => Navigator.pop(ctx, o),
                  child: Row(
                    children: [
                      Expanded(child: Text(o, style: t.body(15, weight: FontWeight.w600))),
                      if (tpl != null && o == tpl.name) Text('original', style: t.body(12, color: t.muted)),
                    ],
                  ),
                ),
              ),
            MooButton(
              label: 'Outro exercício…',
              icon: Icons.edit_outlined,
              primary: false,
              expand: true,
              onPressed: () => Navigator.pop(ctx, '__outro__'),
            ),
          ],
        ),
      ),
    );
    if (chosen == null || !context.mounted) return;
    var name = chosen;
    if (chosen == '__outro__') {
      final c = TextEditingController();
      final typed = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Outro exercício'),
          content: MooTextField(controller: c, label: 'Nome do exercício', autofocus: true),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Trocar')),
          ],
        ),
      );
      if (typed == null || typed.isEmpty) return;
      name = typed;
      // Guarda a variação nova no treino para aparecer da próxima vez.
      if (tpl != null && !tpl.alternatives.contains(typed) && typed != tpl.name) tpl.alternatives.add(typed);
    }
    switchVariant(Store.instance.data, log, template, name);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final t = mt(context);
    final data = Store.instance.data;
    final ex = effectiveTemplate(log, template);
    final last = lastLog(data, log.exerciseId, log.name);
    final sug = suggest(ex, last?.log);
    final doneCount = log.sets.where((s) => s.done).length;
    final complete = log.sets.isNotEmpty && doneCount == log.sets.length;
    final unit = log.timed ? ' s' : '';
    final isVariant = template != null && template!.name != log.name;
    final info = [
      '${ex.sets} × ${ex.repMin}–${ex.repMax}$unit',
      if (isVariant) 'no lugar de ${template!.name}',
      if (ex.note.isNotEmpty && !isVariant) ex.note,
    ].join(' · ');

    Widget status;
    if (log.skipped) {
      status = Text('Pulado', style: t.body(12, weight: FontWeight.w700, color: t.muted));
    } else if (complete) {
      status = Icon(Icons.check_circle, color: t.good);
    } else {
      status = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: t.surf2,
          borderRadius: BorderRadius.circular(999),
          border: t.borderWidth >= 2 ? Border.all(color: t.line, width: 2) : null,
        ),
        child: Text('$doneCount/${log.sets.length}', style: t.body(12, weight: FontWeight.w700)),
      );
    }

    final header = InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(t.radius),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
        child: Row(
          children: [
            Expanded(
              child: Opacity(
                opacity: log.skipped ? 0.55 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(log.name,
                        style: open && !log.skipped ? t.head(20, weight: FontWeight.w800) : t.body(16, weight: FontWeight.w700)),
                    Text(info, style: t.body(13, color: t.muted)),
                    if (!open && !complete && !log.skipped)
                      Text(sug.text, style: t.body(12, color: t.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            status,
            PopupMenuButton<String>(
              tooltip: 'Opções do exercício',
              icon: Icon(Icons.more_vert, color: t.muted),
              onSelected: (v) {
                if (v == 'trocar') _chooseVariant(context);
                if (v == 'pular') onSkip();
                if (v == 'tempo') {
                  log.timed = !log.timed;
                  onChanged();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem<String>(value: 'trocar', child: Text('Trocar exercício')),
                PopupMenuItem<String>(value: 'pular', child: Text(log.skipped ? 'Retomar exercício' : 'Pular hoje')),
                PopupMenuItem<String>(
                    value: 'tempo', child: Text(log.timed ? 'Medir por repetições' : 'Medir por tempo (s)')),
              ],
            ),
          ],
        ),
      ),
    );

    Widget body;
    if (log.skipped) {
      body = Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Row(
          children: [
            Expanded(child: Text('Pulado hoje. Não entra no histórico.', style: t.body(13, color: t.muted))),
            TextButton(onPressed: onSkip, child: const Text('Retomar')),
          ],
        ),
      );
    } else {
      body = Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _VariantStrip(
              current: log.name,
              options: _variantOptions(),
              onPick: (name) {
                switchVariant(Store.instance.data, log, template, name);
                onChanged();
              },
              onOther: () => _chooseVariant(context, typeOnly: true),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SuggestionBox(sug: sug, last: last),
            ),
            const SizedBox(height: 8),
            _WarmupRow(log: log, onChanged: onChanged),
            for (var i = 0; i < log.sets.length; i++)
              _SetRow(
                key: ObjectKey(log.sets[i]),
                index: i,
                set: log.sets[i],
                timed: log.timed,
                repHint: '${ex.repMin}–${ex.repMax}',
                onChanged: onChanged,
                onDone: onSetDone,
                onRemove: () {
                  log.sets.removeAt(i);
                  onChanged();
                },
              ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    final prev = log.sets.isEmpty ? null : log.sets.last;
                    log.sets.add(SetLog(load: prev?.load, uni: prev?.uni ?? false));
                    onChanged();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Série'),
                ),
                Expanded(
                  child: Text('Toque no nº da série: unilateral ou comentário',
                      textAlign: TextAlign.right, style: t.body(11, color: t.muted)),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return DecoratedBox(
      decoration: t.card(),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            if (open) body,
          ],
        ),
      ),
    );
  }
}

/// Faixa rolável com o exercício original e as variações; toque para trocar.
class _VariantStrip extends StatelessWidget {
  final String current;
  final List<String> options;
  final ValueChanged<String> onPick;
  final VoidCallback onOther;
  const _VariantStrip({required this.current, required this.options, required this.onPick, required this.onOther});

  @override
  Widget build(BuildContext context) {
    final t = mt(context);
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        children: [
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(o),
                selected: o == current,
                visualDensity: VisualDensity.compact,
                onSelected: (_) {
                  if (o != current) onPick(o);
                },
              ),
            ),
          ActionChip(
            avatar: Icon(Icons.add, size: 18, color: t.text),
            label: const Text('Outro'),
            visualDensity: VisualDensity.compact,
            onPressed: onOther,
          ),
        ],
      ),
    );
  }
}

/// Quadradinhos das séries de aquecimento (carga leve, não contam no volume).
class _WarmupRow extends StatelessWidget {
  final ExerciseLog log;
  final VoidCallback onChanged;
  const _WarmupRow({required this.log, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = mt(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 6),
      child: Row(
        children: [
          Icon(Icons.local_fire_department_outlined, size: 16, color: t.muted),
          const SizedBox(width: 4),
          Text('Aquecimento', style: t.body(12, weight: FontWeight.w600, color: t.muted)),
          const SizedBox(width: 8),
          for (var i = 0; i < log.warmupsTotal; i++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Semantics(
                button: true,
                label: 'Aquecimento ${i + 1}',
                checked: i < log.warmupsDone,
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () {
                    log.warmupsDone = i < log.warmupsDone ? i : i + 1;
                    onChanged();
                  },
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: i < log.warmupsDone ? t.muted : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: t.muted, width: 2),
                    ),
                    child: i < log.warmupsDone ? Icon(Icons.check, size: 16, color: t.surf) : null,
                  ),
                ),
              ),
            ),
          const Spacer(),
          IconButton(
            tooltip: 'Menos aquecimento',
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            onPressed: log.warmupsTotal == 0
                ? null
                : () {
                    log.warmupsTotal--;
                    if (log.warmupsDone > log.warmupsTotal) log.warmupsDone = log.warmupsTotal;
                    onChanged();
                  },
            icon: const Icon(Icons.remove),
          ),
          IconButton(
            tooltip: 'Mais aquecimento',
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            onPressed: log.warmupsTotal >= 5
                ? null
                : () {
                    log.warmupsTotal++;
                    onChanged();
                  },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _SetRow extends StatefulWidget {
  final int index;
  final SetLog set;
  final bool timed;
  final String repHint;
  final VoidCallback onChanged;
  final VoidCallback onDone;
  final VoidCallback onRemove;
  const _SetRow({
    super.key,
    required this.index,
    required this.set,
    required this.timed,
    required this.repHint,
    required this.onChanged,
    required this.onDone,
    required this.onRemove,
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

  Future<void> _options() async {
    final s = widget.set;
    final t = mt(context);
    final note = TextEditingController(text: s.note);
    var uni = s.uni;
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Série ${widget.index + 1}', style: t.head(20, weight: FontWeight.w800)),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Unilateral'),
                subtitle: const Text('Carga de um lado só. Progressão separada; no volume conta os dois lados.'),
                value: uni,
                onChanged: (v) => setSheet(() => uni = v),
              ),
              const SizedBox(height: 8),
              MooTextField(controller: note, label: 'Comentário', hint: 'ex.: drop, falha, dor no punho', maxLines: 3),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: MooButton(
                      label: 'Remover série',
                      icon: Icons.delete_outline,
                      primary: false,
                      expand: true,
                      onPressed: () => Navigator.pop(ctx, 'remove'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MooButton(
                      label: 'Pronto',
                      icon: Icons.check,
                      expand: true,
                      onPressed: () => Navigator.pop(ctx, 'ok'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (action == 'remove') {
      widget.onRemove();
      return;
    }
    // Fechar arrastando também salva o que foi alterado.
    s.uni = uni;
    s.note = note.text.trim();
    widget.onChanged();
    if (mounted) setState(() {});
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Semantics(
                button: true,
                label: 'Opções da série ${widget.index + 1}',
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _options,
                  child: SizedBox(
                    width: 34,
                    height: 48,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${widget.index + 1}', style: t.body(15, weight: FontWeight.w700, color: t.muted)),
                        if (s.uni)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(color: t.acc, borderRadius: BorderRadius.circular(4)),
                            child: Text('UNI', style: t.body(9, weight: FontWeight.w800, color: t.onAcc)),
                          )
                        else if (s.note.isNotEmpty)
                          Icon(Icons.chat_bubble_outline, size: 12, color: t.muted),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: _field(context, _load, s.uni ? 'kg (1 lado)' : 'kg', null, true, (v) {
                  s.load = parseNum(v);
                  widget.onChanged();
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _field(context, _reps, widget.timed ? 'seg' : 'reps', widget.repHint, false, (v) {
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
                        showSnack(context, widget.timed
                            ? 'Informe os segundos antes de marcar a série.'
                            : 'Informe as repetições antes de marcar a série.');
                        return;
                      }
                      setState(() => s.done = !s.done);
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
          if (s.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(38, 2, 0, 0),
              child: Text(s.note, style: t.body(12, color: t.muted).copyWith(fontStyle: FontStyle.italic)),
            ),
        ],
      ),
    );
  }
}

/// Dados de um exercício adicionado durante o treino.
class _NewExercise {
  final String name;
  final int sets;
  final int repMin;
  final int repMax;
  final bool timed;
  final bool addToTemplate;
  const _NewExercise(this.name, this.sets, this.repMin, this.repMax, this.timed, this.addToTemplate);
}

class _AddExerciseDialog extends StatefulWidget {
  final String templateCode;
  const _AddExerciseDialog({required this.templateCode});

  @override
  State<_AddExerciseDialog> createState() => _AddExerciseDialogState();
}

class _AddExerciseDialogState extends State<_AddExerciseDialog> {
  final _name = TextEditingController();
  final _sets = TextEditingController(text: '3');
  final _min = TextEditingController(text: '10');
  final _max = TextEditingController(text: '12');
  bool _timed = false;
  bool _keep = false;

  @override
  void dispose() {
    for (final c in [_name, _sets, _min, _max]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar exercício'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MooTextField(controller: _name, label: 'Nome', autofocus: true),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: NumberField(controller: _sets, label: 'Séries', decimal: false)),
                const SizedBox(width: 8),
                Expanded(child: NumberField(controller: _min, label: _timed ? 'Seg mín.' : 'Reps mín.', decimal: false)),
                const SizedBox(width: 8),
                Expanded(child: NumberField(controller: _max, label: _timed ? 'Seg máx.' : 'Reps máx.', decimal: false)),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Por tempo (segundos)'),
              value: _timed,
              onChanged: (v) => setState(() => _timed = v),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Salvar também no treino ${widget.templateCode}'),
              value: _keep,
              onChanged: (v) => setState(() => _keep = v ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            var mn = clampInt(parseInt(_min.text) ?? 10, 1, 600);
            var mx = clampInt(parseInt(_max.text) ?? 12, 1, 600);
            if (mx < mn) {
              final tmp = mn;
              mn = mx;
              mx = tmp;
            }
            Navigator.pop(
              context,
              _NewExercise(name, clampInt(parseInt(_sets.text) ?? 3, 1, 10), mn, mx, _timed, _keep),
            );
          },
          child: const Text('Adicionar'),
        ),
      ],
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
                    Text(describeLog(e), style: t.body(14, color: t.muted)),
                    if (e.warmupsDone > 0)
                      Text('+ ${e.warmupsDone} de aquecimento', style: t.body(12, color: t.muted)),
                    for (var i = 0; i < e.sets.length; i++)
                      if (e.sets[i].note.isNotEmpty)
                        Text('Série ${i + 1}: ${e.sets[i].note}',
                            style: t.body(12, color: t.muted).copyWith(fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
