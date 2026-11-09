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

class ExerciseTemplate {
  String id;
  String name;
  int sets;
  int repMin;
  int repMax;
  double? startLoad;
  String note;

  ExerciseTemplate({
    String? id,
    required this.name,
    this.sets = 3,
    this.repMin = 8,
    this.repMax = 12,
    this.startLoad,
    this.note = '',
  }) : id = id ?? newId();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sets': sets,
        'repMin': repMin,
        'repMax': repMax,
        'startLoad': startLoad,
        'note': note,
      };

  factory ExerciseTemplate.fromJson(Map<String, dynamic> j) => ExerciseTemplate(
        id: j['id'] as String,
        name: j['name'] as String,
        sets: (j['sets'] as num?)?.toInt() ?? 3,
        repMin: (j['repMin'] as num?)?.toInt() ?? 8,
        repMax: (j['repMax'] as num?)?.toInt() ?? 12,
        startLoad: _toDouble(j['startLoad']),
        note: (j['note'] as String?) ?? '',
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
  int? reps;
  bool done;

  SetLog({this.load, this.reps, this.done = false});

  Map<String, dynamic> toJson() => {'load': load, 'reps': reps, 'done': done};

  factory SetLog.fromJson(Map<String, dynamic> j) => SetLog(
        load: _toDouble(j['load']),
        reps: (j['reps'] as num?)?.toInt(),
        done: (j['done'] as bool?) ?? false,
      );
}

class ExerciseLog {
  String exerciseId;
  String name;
  List<SetLog> sets;

  ExerciseLog({required this.exerciseId, required this.name, List<SetLog>? sets})
      : sets = sets ?? [];

  List<SetLog> get doneSets => sets.where((s) => s.done && s.reps != null).toList();

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'name': name,
        'sets': sets.map((s) => s.toJson()).toList(),
      };

  factory ExerciseLog.fromJson(Map<String, dynamic> j) => ExerciseLog(
        exerciseId: j['exerciseId'] as String,
        name: j['name'] as String,
        sets: ((j['sets'] as List?) ?? [])
            .map((s) => SetLog.fromJson(s as Map<String, dynamic>))
            .toList(),
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

  double get volume => exercises.fold(
      0.0,
      (a, e) => a +
          e.doneSets.fold(0.0, (b, s) => b + (s.load ?? 0) * (s.reps ?? 0)));

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

  Meal({required this.time, required this.title, required this.description});

  Map<String, dynamic> toJson() => {'time': time, 'title': title, 'description': description};

  factory Meal.fromJson(Map<String, dynamic> j) => Meal(
        time: (j['time'] as String?) ?? '',
        title: (j['title'] as String?) ?? '',
        description: (j['description'] as String?) ?? '',
      );
}

class AppData {
  int version;
  Profile profile;
  List<WorkoutTemplate> templates;
  List<Session> sessions;
  List<BodyEntry> body;
  List<Meal> meals;
  String notes;
  Session? draft;

  AppData({
    this.version = 1,
    required this.profile,
    required this.templates,
    required this.sessions,
    required this.body,
    required this.meals,
    this.notes = '',
    this.draft,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'profile': profile.toJson(),
        'templates': templates.map((t) => t.toJson()).toList(),
        'sessions': sessions.map((s) => s.toJson()).toList(),
        'body': body.map((b) => b.toJson()).toList(),
        'meals': meals.map((m) => m.toJson()).toList(),
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
        body: ((j['body'] as List?) ?? [])
            .map((b) => BodyEntry.fromJson(b as Map<String, dynamic>))
            .toList(),
        meals: ((j['meals'] as List?) ?? [])
            .map((m) => Meal.fromJson(m as Map<String, dynamic>))
            .toList(),
        notes: (j['notes'] as String?) ?? '',
        draft: j['draft'] == null ? null : Session.fromJson(j['draft'] as Map<String, dynamic>),
      );
}
