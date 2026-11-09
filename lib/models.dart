// Modelos de dados do MyMooscles. Tudo é salvo em um único arquivo JSON local.

int _idCounter = 0;

String newId() {
  _idCounter++;
  return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_idCounter.toRadixString(36)}';
}

double? _toDouble(dynamic v) => v == null ? null : (v as num).toDouble();

DateTime _toDate(dynamic v) => DateTime.parse(v as String);

class Profile {
  String name;
  double? heightCm;
  int? age;
  String sex; // 'M' ou 'F'
  String goal; // chave de goals em logic.dart
  double activity; // fator multiplicador do metabolismo basal
  double? kcalOverride;
  double? proteinOverride;
  String theme; // chave em theme.dart

  Profile({
    this.name = '',
    this.heightCm,
    this.age,
    this.sex = 'M',
    this.goal = 'recomp',
    this.activity = 1.4,
    this.kcalOverride,
    this.proteinOverride,
    this.theme = 'moo',
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'theme': theme,
        'heightCm': heightCm,
        'age': age,
        'sex': sex,
        'goal': goal,
        'activity': activity,
        'kcalOverride': kcalOverride,
        'proteinOverride': proteinOverride,
      };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        name: (j['name'] as String?) ?? '',
        heightCm: _toDouble(j['heightCm']),
        age: (j['age'] as num?)?.toInt(),
        sex: (j['sex'] as String?) ?? 'M',
        goal: (j['goal'] as String?) ?? 'recomp',
        activity: _toDouble(j['activity']) ?? 1.4,
        kcalOverride: _toDouble(j['kcalOverride']),
        proteinOverride: _toDouble(j['proteinOverride']),
        theme: (j['theme'] as String?) ?? 'moo',
      );
}

List<String> _toStrings(dynamic v) => ((v as List?) ?? []).map((e) => e as String).toList();

class ExerciseTemplate {
  String id;
  String name;
  int sets;
  int repMin;
  int repMax;
  double? startLoad;
  String note;
  List<String> alternatives; // variações que podem substituir este exercício
  bool timed; // medido em segundos (prancha, isometria)
  int warmups; // séries de aquecimento sugeridas

  ExerciseTemplate({
    String? id,
    required this.name,
    this.sets = 3,
    this.repMin = 8,
    this.repMax = 12,
    this.startLoad,
    this.note = '',
    List<String>? alternatives,
    this.timed = false,
    this.warmups = 1,
  })  : id = id ?? newId(),
        alternatives = alternatives ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sets': sets,
        'repMin': repMin,
        'repMax': repMax,
        'startLoad': startLoad,
        'note': note,
        'alternatives': alternatives,
        'timed': timed,
        'warmups': warmups,
      };

  factory ExerciseTemplate.fromJson(Map<String, dynamic> j) => ExerciseTemplate(
        id: j['id'] as String,
        name: j['name'] as String,
        sets: (j['sets'] as num?)?.toInt() ?? 3,
        repMin: (j['repMin'] as num?)?.toInt() ?? 8,
        repMax: (j['repMax'] as num?)?.toInt() ?? 12,
        startLoad: _toDouble(j['startLoad']),
        note: (j['note'] as String?) ?? '',
        alternatives: _toStrings(j['alternatives']),
        timed: (j['timed'] as bool?) ?? false,
        warmups: (j['warmups'] as num?)?.toInt() ?? 1,
      );
}

class WorkoutTemplate {
  String id;
  String code;
  String name;
  int weekday; // 1 = segunda ... 7 = domingo; 0 = sem dia fixo
  List<ExerciseTemplate> exercises;

  WorkoutTemplate({
    String? id,
    required this.code,
    required this.name,
    this.weekday = 0,
    List<ExerciseTemplate>? exercises,
  })  : id = id ?? newId(),
        exercises = exercises ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'weekday': weekday,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  factory WorkoutTemplate.fromJson(Map<String, dynamic> j) => WorkoutTemplate(
        id: j['id'] as String,
        code: (j['code'] as String?) ?? '',
        name: j['name'] as String,
        weekday: (j['weekday'] as num?)?.toInt() ?? 0,
        exercises: ((j['exercises'] as List?) ?? [])
            .map((e) => ExerciseTemplate.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class SetLog {
  double? load;
  int? reps; // repetições, ou segundos quando o exercício é por tempo
  bool done;
  bool uni; // unilateral: carga de um lado só
  String note;

  SetLog({this.load, this.reps, this.done = false, this.uni = false, this.note = ''});

  Map<String, dynamic> toJson() => {'load': load, 'reps': reps, 'done': done, 'uni': uni, 'note': note};

  factory SetLog.fromJson(Map<String, dynamic> j) => SetLog(
        load: _toDouble(j['load']),
        reps: (j['reps'] as num?)?.toInt(),
        done: (j['done'] as bool?) ?? false,
        uni: (j['uni'] as bool?) ?? false,
        note: (j['note'] as String?) ?? '',
      );
}

class ExerciseLog {
  String exerciseId;
  String name; // nome realmente feito (pode ser uma variação)
  List<SetLog> sets;
  bool skipped;
  bool timed;
  int warmupsTotal;
  int warmupsDone;
  int? repMin; // usados quando o exercício não vem de um treino salvo
  int? repMax;

  ExerciseLog({
    required this.exerciseId,
    required this.name,
    List<SetLog>? sets,
    this.skipped = false,
    this.timed = false,
    this.warmupsTotal = 0,
    this.warmupsDone = 0,
    this.repMin,
    this.repMax,
  }) : sets = sets ?? [];

  List<SetLog> get doneSets => sets.where((s) => s.done && s.reps != null).toList();

  double get volume => timed
      ? 0.0
      : doneSets.fold(0.0, (a, s) => a + (s.load ?? 0) * (s.reps ?? 0) * (s.uni ? 2 : 1));

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'name': name,
        'sets': sets.map((s) => s.toJson()).toList(),
        'skipped': skipped,
        'timed': timed,
        'warmupsTotal': warmupsTotal,
        'warmupsDone': warmupsDone,
        'repMin': repMin,
        'repMax': repMax,
      };

  factory ExerciseLog.fromJson(Map<String, dynamic> j) => ExerciseLog(
        exerciseId: j['exerciseId'] as String,
        name: j['name'] as String,
        sets: ((j['sets'] as List?) ?? []).map((s) => SetLog.fromJson(s as Map<String, dynamic>)).toList(),
        skipped: (j['skipped'] as bool?) ?? false,
        timed: (j['timed'] as bool?) ?? false,
        warmupsTotal: (j['warmupsTotal'] as num?)?.toInt() ?? 0,
        warmupsDone: (j['warmupsDone'] as num?)?.toInt() ?? 0,
        repMin: (j['repMin'] as num?)?.toInt(),
        repMax: (j['repMax'] as num?)?.toInt(),
      );
}

class Session {
  String id;
  String templateId;
  String templateCode;
  String templateName;
  DateTime start;
  DateTime? end;
  List<ExerciseLog> exercises;
  String note;

  Session({
    String? id,
    required this.templateId,
    required this.templateCode,
    required this.templateName,
    required this.start,
    this.end,
    List<ExerciseLog>? exercises,
    this.note = '',
  })  : id = id ?? newId(),
        exercises = exercises ?? [];

  int get doneSetCount => exercises.fold(0, (a, e) => a + e.doneSets.length);

  /// Volume = soma de carga × repetições (unilateral conta os dois lados; exercícios por tempo ficam fora).
  double get volume => exercises.fold(0.0, (a, e) => a + e.volume);

  Map<String, dynamic> toJson() => {
        'id': id,
        'templateId': templateId,
        'templateCode': templateCode,
        'templateName': templateName,
        'start': start.toIso8601String(),
        'end': end?.toIso8601String(),
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'note': note,
      };

  factory Session.fromJson(Map<String, dynamic> j) => Session(
        id: j['id'] as String,
        templateId: (j['templateId'] as String?) ?? '',
        templateCode: (j['templateCode'] as String?) ?? '',
        templateName: (j['templateName'] as String?) ?? '',
        start: _toDate(j['start']),
        end: j['end'] == null ? null : _toDate(j['end']),
        exercises: ((j['exercises'] as List?) ?? [])
            .map((e) => ExerciseLog.fromJson(e as Map<String, dynamic>))
            .toList(),
        note: (j['note'] as String?) ?? '',
      );
}

class BodyEntry {
  String id;
  DateTime date;
  double? weight;
  double? waist;
  double? bodyFat;
  double? leanMass;
  double? visceral;
  String note;

  BodyEntry({
    String? id,
    required this.date,
    this.weight,
    this.waist,
    this.bodyFat,
    this.leanMass,
    this.visceral,
    this.note = '',
  }) : id = id ?? newId();

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'weight': weight,
        'waist': waist,
        'bodyFat': bodyFat,
        'leanMass': leanMass,
        'visceral': visceral,
        'note': note,
      };

  factory BodyEntry.fromJson(Map<String, dynamic> j) => BodyEntry(
        id: j['id'] as String,
        date: _toDate(j['date']),
        weight: _toDouble(j['weight']),
        waist: _toDouble(j['waist']),
        bodyFat: _toDouble(j['bodyFat']),
        leanMass: _toDouble(j['leanMass']),
        visceral: _toDouble(j['visceral']),
        note: (j['note'] as String?) ?? '',
      );
}

class Meal {
  String time;
  String title;
  String description;
  double? kcal;
  double? protein;

  Meal({required this.time, required this.title, required this.description, this.kcal, this.protein});

  /// Identifica a refeição no diário alimentar.
  String get key => '$time $title';

  Map<String, dynamic> toJson() =>
      {'time': time, 'title': title, 'description': description, 'kcal': kcal, 'protein': protein};

  factory Meal.fromJson(Map<String, dynamic> j) => Meal(
        time: (j['time'] as String?) ?? '',
        title: (j['title'] as String?) ?? '',
        description: (j['description'] as String?) ?? '',
        kcal: _toDouble(j['kcal']),
        protein: _toDouble(j['protein']),
      );
}

/// Registro do diário alimentar: check-in de uma refeição do plano ou um extra.
class FoodEntry {
  String id;
  DateTime date; // dia (sem hora)
  String mealKey; // Meal.key; vazio para extras
  String status; // 'ok' (seguiu), 'troca' (trocou), 'pulou', 'extra'
  String text;
  double? kcal;
  double? protein;

  FoodEntry({
    String? id,
    required this.date,
    this.mealKey = '',
    required this.status,
    this.text = '',
    this.kcal,
    this.protein,
  }) : id = id ?? newId();

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'mealKey': mealKey,
        'status': status,
        'text': text,
        'kcal': kcal,
        'protein': protein,
      };

  factory FoodEntry.fromJson(Map<String, dynamic> j) => FoodEntry(
        id: j['id'] as String,
        date: _toDate(j['date']),
        mealKey: (j['mealKey'] as String?) ?? '',
        status: (j['status'] as String?) ?? 'ok',
        text: (j['text'] as String?) ?? '',
        kcal: _toDouble(j['kcal']),
        protein: _toDouble(j['protein']),
      );
}

class AppData {
  int version;
  Profile profile;
  List<WorkoutTemplate> templates;
  List<Session> sessions;
  List<BodyEntry> body;
  List<Meal> meals;
  List<FoodEntry> food;
  String notes;
  Session? draft;

  AppData({
    this.version = 2,
    required this.profile,
    required this.templates,
    required this.sessions,
    required this.body,
    required this.meals,
    List<FoodEntry>? food,
    this.notes = '',
    this.draft,
  }) : food = food ?? [];

  Map<String, dynamic> toJson() => {
        'version': version,
        'profile': profile.toJson(),
        'templates': templates.map((t) => t.toJson()).toList(),
        'sessions': sessions.map((s) => s.toJson()).toList(),
        'body': body.map((b) => b.toJson()).toList(),
        'meals': meals.map((m) => m.toJson()).toList(),
        'food': food.map((f) => f.toJson()).toList(),
        'notes': notes,
        'draft': draft?.toJson(),
      };

  factory AppData.fromJson(Map<String, dynamic> j) => AppData(
        version: (j['version'] as num?)?.toInt() ?? 1,
        profile: Profile.fromJson((j['profile'] as Map<String, dynamic>?) ?? {}),
        templates: ((j['templates'] as List?) ?? [])
            .map((t) => WorkoutTemplate.fromJson(t as Map<String, dynamic>))
            .toList(),
        sessions: ((j['sessions'] as List?) ?? [])
            .map((s) => Session.fromJson(s as Map<String, dynamic>))
            .toList(),
        body: ((j['body'] as List?) ?? []).map((b) => BodyEntry.fromJson(b as Map<String, dynamic>)).toList(),
        meals: ((j['meals'] as List?) ?? []).map((m) => Meal.fromJson(m as Map<String, dynamic>)).toList(),
        food: ((j['food'] as List?) ?? []).map((f) => FoodEntry.fromJson(f as Map<String, dynamic>)).toList(),
        notes: (j['notes'] as String?) ?? '',
        draft: j['draft'] == null ? null : Session.fromJson(j['draft'] as Map<String, dynamic>),
      );
}
