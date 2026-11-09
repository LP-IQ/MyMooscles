import 'dart:math' as math;

import 'models.dart';
import 'util.dart';

// ---------------------------------------------------------------------------
// Objetivos
// ---------------------------------------------------------------------------

class Goal {
  final String key;
  final String label;
  final String description;
  final double kcalDelta; // somado ao gasto diário estimado
  final double weeklyMin; // ritmo-alvo de mudança de peso (kg/semana)
  final double weeklyMax;

  const Goal(this.key, this.label, this.description, this.kcalDelta, this.weeklyMin, this.weeklyMax);
}

const goals = <Goal>[
  Goal('emagrecer', 'Emagrecer',
      'Prioridade é baixar o peso. Musculação continua para segurar o músculo.', -750.0, -1.0, -0.5),
  Goal('recomp', 'Perder gordura e ganhar músculo',
      'Déficit moderado, proteína alta e progressão de carga.', -600.0, -0.8, -0.3),
  Goal('definicao', 'Definir',
      'Já está mais magro: déficit menor para tirar a gordura final sem perder músculo.', -400.0, -0.5, -0.2),
  Goal('hipertrofia', 'Ganhar massa',
      'Pequeno superávit para crescer com o mínimo de gordura.', 250.0, 0.1, 0.3),
  Goal('manter', 'Manter', 'Manter o peso e seguir evoluindo as cargas.', 0.0, -0.2, 0.2),
];

Goal goalFor(String key) => goals.firstWhere((g) => g.key == key, orElse: () => goals[1]);

final activityLevels = <double, String>{
  1.2: 'Sedentário (sem treino)',
  1.3: 'Leve (treina 2–3x)',
  1.4: 'Moderado (treina 4–5x, trabalho sentado)',
  1.55: 'Ativo (treina 5x + cardio regular)',
  1.7: 'Muito ativo (trabalho físico)',
};

// ---------------------------------------------------------------------------
// Metas de nutrição
// ---------------------------------------------------------------------------

class Targets {
  final double? bmr;
  final double? tdee;
  final double? kcal;
  final double? protein;
  final double? fat;
  final double? carbs;
  final String? missing;

  const Targets({this.bmr, this.tdee, this.kcal, this.protein, this.fat, this.carbs, this.missing});
}

BodyEntry? latestWith(List<BodyEntry> body, double? Function(BodyEntry) field) {
  BodyEntry? best;
  for (final e in body) {
    if (field(e) == null) continue;
    if (best == null || e.date.isAfter(best.date)) best = e;
  }
  return best;
}

Targets computeTargets(AppData data) {
  final p = data.profile;
  final w = latestWith(data.body, (e) => e.weight)?.weight;
  if (w == null || p.heightCm == null || p.age == null) {
    return const Targets(missing: 'Preencha altura e idade no Plano e registre seu peso na aba Corpo.');
  }
  final bmr = 10 * w + 6.25 * p.heightCm! - 5 * p.age! + (p.sex == 'F' ? -161 : 5);
  final tdee = bmr * p.activity;
  final goal = goalFor(p.goal);
  final kcal = p.kcalOverride ?? (tdee + goal.kcalDelta);
  final lean = latestWith(data.body, (e) => e.leanMass)?.leanMass;
  final protein = p.proteinOverride ?? (lean != null ? 2.5 * lean : 1.8 * w);
  final fat = 0.6 * w;
  final carbs = math.max(0.0, (kcal - protein * 4 - fat * 9) / 4);
  return Targets(bmr: bmr, tdee: tdee, kcal: kcal, protein: protein, fat: fat, carbs: carbs);
}

// ---------------------------------------------------------------------------
// Progressão de carga (dupla progressão)
// ---------------------------------------------------------------------------

class Suggestion {
  final double? load;
  final String text;
  final bool increase;

  const Suggestion(this.load, this.text, {this.increase = false});
}

double roundHalf(double v) => (v * 2).roundToDouble() / 2;

/// Modelo efetivo de um exercício da sessão: o do treino salvo (ajustado para a variação feita)
/// ou um modelo montado a partir do próprio registro, quando o exercício foi adicionado na hora.
ExerciseTemplate effectiveTemplate(ExerciseLog log, ExerciseTemplate? tpl) {
  if (tpl != null && tpl.name == log.name && tpl.timed == log.timed) return tpl;
  return ExerciseTemplate(
    id: log.exerciseId,
    name: log.name,
    sets: tpl?.sets ?? math.max(1, log.sets.length),
    repMin: tpl?.repMin ?? log.repMin ?? 8,
    repMax: tpl?.repMax ?? log.repMax ?? 12,
    startLoad: null,
    note: tpl?.note ?? '',
    timed: log.timed,
    warmups: tpl?.warmups ?? 0,
  );
}

/// Dupla progressão: quando as séries na carga mais alta batem o topo da faixa, sobe a carga.
/// Séries unilaterais têm progressão própria (usadas só quando não há séries normais).
Suggestion suggest(ExerciseTemplate ex, ExerciseLog? last) {
  final done = last?.doneSets ?? <SetLog>[];
  if (ex.timed) {
    final range = ex.repMax >= 20 ? '${ex.repMin}–${ex.repMax} s' : '30–60 s';
    if (done.isEmpty) return Suggestion(null, 'Por tempo: busque $range por série.');
    final best = done.map((s) => s.reps ?? 0).reduce(math.max);
    return Suggestion(done.last.load, 'Última: até $best s. Tente +5 s por série.');
  }
  final bi = done.where((s) => s.load != null && !s.uni).toList();
  final uni = done.where((s) => s.load != null && s.uni).toList();
  final base = bi.isNotEmpty ? bi : uni;
  final prefix = (bi.isEmpty && uni.isNotEmpty) ? 'Unilateral: ' : '';
  if (base.isEmpty) {
    if (ex.startLoad != null) {
      return Suggestion(ex.startLoad,
          'Comece com ${fmtNum(ex.startLoad!)} kg e busque ${ex.repMin}–${ex.repMax} reps.');
    }
    return const Suggestion(null, 'Teste a carga: termine cada série com 1–2 reps na reserva.');
  }
  final top = base.map((s) => s.load!).reduce(math.max);
  final working = base.where((s) => s.load == top).toList();
  final allAtTop = working.every((s) => (s.reps ?? 0) >= ex.repMax);
  if (allAtTop) {
    var inc = top * 0.05;
    if (inc < 1) inc = 1;
    final next = roundHalf(top + inc);
    return Suggestion(next,
        '${prefix}subir para ${fmtNum(next)} kg (fez ${ex.repMax}+ reps com ${fmtNum(top)} kg).'.capitalized,
        increase: true);
  }
  final anyBelow = working.any((s) => (s.reps ?? 0) < ex.repMin);
  if (anyBelow) {
    return Suggestion(top,
        '${prefix}manter ${fmtNum(top)} kg. Se ficar abaixo de ${ex.repMin} reps de novo, reduza ~5%.'.capitalized);
  }
  return Suggestion(top, '${prefix}manter ${fmtNum(top)} kg e tentar +1 rep por série.'.capitalized);
}

extension _Cap on String {
  String get capitalized => isEmpty ? this : this[0].toUpperCase() + substring(1);
}

/// Texto curto das séries feitas: "50×12  32U×8" ou "90 s" (U = unilateral).
String describeLog(ExerciseLog e) => e.doneSets.map((s) {
      if (e.timed) {
        final kg = (s.load != null && s.load! > 0) ? '${fmtNum(s.load!)} kg · ' : '';
        return '$kg${s.reps} s';
      }
      return '${s.load == null ? '—' : fmtNum(s.load!)}${s.uni ? 'U' : ''}×${s.reps}';
    }).join('  ');

// ---------------------------------------------------------------------------
// Estatísticas de peso
// ---------------------------------------------------------------------------

class WeightStats {
  final double? last;
  final DateTime? lastDate;
  final double? avg7;
  final double? avgPrev7;
  final double? first;
  final DateTime? firstDate;
  final int daysOfData;

  const WeightStats({
    this.last,
    this.lastDate,
    this.avg7,
    this.avgPrev7,
    this.first,
    this.firstDate,
    this.daysOfData = 0,
  });

  double? get weeklyChange => (avg7 != null && avgPrev7 != null) ? avg7! - avgPrev7! : null;
}

List<BodyEntry> weightEntries(List<BodyEntry> body) {
  final w = body.where((e) => e.weight != null).toList();
  w.sort((a, b) => a.date.compareTo(b.date));
  return w;
}

double? _mean(Iterable<double> v) {
  if (v.isEmpty) return null;
  return v.reduce((a, b) => a + b) / v.length;
}

WeightStats weightStats(List<BodyEntry> body, DateTime now) {
  final w = weightEntries(body);
  if (w.isEmpty) return const WeightStats();
  final today = dayOnly(now);
  final start7 = today.subtract(const Duration(days: 6));
  final start14 = today.subtract(const Duration(days: 13));
  final last7 = w.where((e) => !dayOnly(e.date).isBefore(start7)).map((e) => e.weight!);
  final prev7 = w
      .where((e) => !dayOnly(e.date).isBefore(start14) && dayOnly(e.date).isBefore(start7))
      .map((e) => e.weight!);
  return WeightStats(
    last: w.last.weight,
    lastDate: w.last.date,
    avg7: _mean(last7),
    avgPrev7: _mean(prev7),
    first: w.first.weight,
    firstDate: w.first.date,
    daysOfData: dayOnly(w.last.date).difference(dayOnly(w.first.date)).inDays + 1,
  );
}

/// Média móvel de 7 dias para cada pesagem (usada no gráfico).
List<MapEntry<DateTime, double>> movingAverage(List<BodyEntry> weights) {
  final out = <MapEntry<DateTime, double>>[];
  for (final e in weights) {
    final from = dayOnly(e.date).subtract(const Duration(days: 6));
    final window = weights
        .where((x) => !dayOnly(x.date).isBefore(from) && !x.date.isAfter(e.date))
        .map((x) => x.weight!);
    out.add(MapEntry(e.date, _mean(window)!));
  }
  return out;
}

/// Orientação de ajuste depois de pelo menos 2 semanas de pesagens.
String? adjustmentAdvice(AppData data, DateTime now) {
  final s = weightStats(data.body, now);
  final change = s.weeklyChange;
  if (change == null || s.daysOfData < 14) return null;
  final g = goalFor(data.profile.goal);
  final c = fmtNum(change, 2);
  if (change > g.weeklyMax) {
    if (g.kcalDelta < 0) {
      return 'Média semanal variou $c kg, abaixo do ritmo-alvo. Reduza 150–200 kcal por dia ou some ~2.000 passos.';
    }
    return 'Média semanal variou $c kg, acima do ritmo-alvo. Reduza 100–150 kcal por dia.';
  }
  if (change < g.weeklyMin) {
    return 'Média semanal variou $c kg, rápido demais. Some 150–200 kcal por dia, de preferência perto do treino.';
  }
  return 'Média semanal variou $c kg: dentro do ritmo-alvo. Mantenha o plano.';
}

// ---------------------------------------------------------------------------
// Sessões
// ---------------------------------------------------------------------------

typedef LastLog = ({ExerciseLog log, DateTime date});

/// Último registro com séries feitas deste exercício/variação.
/// Procura primeiro o mesmo exercício do treino com o mesmo nome; depois o mesmo nome em qualquer treino.
LastLog? lastLog(AppData data, String exerciseId, String name) {
  final sorted = [...data.sessions]..sort((a, b) => b.start.compareTo(a.start));
  for (final s in sorted) {
    for (final e in s.exercises) {
      if (e.exerciseId == exerciseId && e.name == name && e.doneSets.isNotEmpty) return (log: e, date: s.start);
    }
  }
  for (final s in sorted) {
    for (final e in s.exercises) {
      if (e.name == name && e.doneSets.isNotEmpty) return (log: e, date: s.start);
    }
  }
  return null;
}

/// Séries iniciais: repete a estrutura da última vez (normal/unilateral e cargas),
/// já com a carga nova quando a sugestão é subir.
List<SetLog> prefillSets(ExerciseTemplate ex, ExerciseLog? last, Suggestion sug) {
  final done = last?.doneSets ?? <SetLog>[];
  if (done.isEmpty) return List.generate(ex.sets, (_) => SetLog(load: sug.load));
  final bi = done.where((s) => s.load != null && !s.uni).toList();
  final baseUni = bi.isEmpty;
  final base = done.where((s) => s.load != null && s.uni == baseUni).toList();
  final top = base.isEmpty ? null : base.map((s) => s.load!).reduce(math.max);
  final count = math.max(ex.sets, done.length);
  return List.generate(count, (i) {
    final src = i < done.length ? done[i] : done.last;
    var load = src.load;
    if (sug.increase && src.uni == baseUni && top != null && load == top) load = sug.load;
    return SetLog(load: load, uni: src.uni);
  });
}

ExerciseLog buildExerciseLog(AppData data, ExerciseTemplate ex) {
  final last = lastLog(data, ex.id, ex.name);
  final sug = suggest(ex, last?.log);
  return ExerciseLog(
    exerciseId: ex.id,
    name: ex.name,
    sets: prefillSets(ex, last?.log, sug),
    timed: ex.timed,
    warmupsTotal: ex.warmups,
    repMin: ex.repMin,
    repMax: ex.repMax,
  );
}

Session buildSession(AppData data, WorkoutTemplate t) {
  final session = Session(
    templateId: t.id,
    templateCode: t.code,
    templateName: t.name,
    start: DateTime.now(),
  );
  for (final ex in t.exercises) {
    session.exercises.add(buildExerciseLog(data, ex));
  }
  return session;
}

/// Troca o exercício por uma variação; se nenhuma série foi feita ainda, refaz as séries sugeridas.
void switchVariant(AppData data, ExerciseLog log, ExerciseTemplate? tpl, String name) {
  log.name = name;
  if (log.sets.any((s) => s.done)) return;
  final eff = effectiveTemplate(log, tpl);
  final last = lastLog(data, log.exerciseId, name);
  log.sets = prefillSets(eff, last?.log, suggest(eff, last?.log));
}

int sessionsThisWeek(AppData data, DateTime now) {
  final monday = dayOnly(now).subtract(Duration(days: now.weekday - 1));
  return data.sessions.where((s) => !dayOnly(s.start).isBefore(monday)).length;
}

// ---------------------------------------------------------------------------
// Diário alimentar
// ---------------------------------------------------------------------------

class FoodSummary {
  final double kcal;
  final double protein;
  final int followed; // refeições "seguiu"
  final int checked; // refeições com algum check-in
  final int meals; // refeições no plano
  final int extras;
  const FoodSummary(this.kcal, this.protein, this.followed, this.checked, this.meals, this.extras);
}

/// Estimativa do dia: refeições seguidas contam os valores do cardápio; trocas contam o que foi
/// informado (ou o valor do cardápio, se nada foi informado); extras somam o que foi informado.
FoodSummary foodSummary(AppData data, DateTime day) {
  var kcal = 0.0;
  var protein = 0.0;
  var followed = 0;
  var checked = 0;
  var extras = 0;
  final entries = data.food.where((f) => sameDay(f.date, day)).toList();
  for (final m in data.meals) {
    FoodEntry? e;
    for (final f in entries) {
      if (f.mealKey == m.key) e = f;
    }
    if (e == null) continue;
    checked++;
    if (e.status == 'ok') {
      followed++;
      kcal += m.kcal ?? 0;
      protein += m.protein ?? 0;
    } else if (e.status == 'troca') {
      kcal += e.kcal ?? m.kcal ?? 0;
      protein += e.protein ?? m.protein ?? 0;
    }
  }
  for (final f in entries.where((f) => f.status == 'extra')) {
    extras++;
    kcal += f.kcal ?? 0;
    protein += f.protein ?? 0;
  }
  return FoodSummary(kcal, protein, followed, checked, data.meals.length, extras);
}
