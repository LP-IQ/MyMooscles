import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'logic.dart';
import 'models.dart';
import 'seed.dart';
import 'util.dart';

/// Guarda todos os dados em um arquivo JSON no armazenamento interno do app.
/// Atualizações do APK assinadas com a mesma chave mantêm este arquivo.
class Store extends ChangeNotifier {
  Store._();
  static final Store instance = Store._();

  late AppData data;
  File? _file;
  Future<void> _pending = Future.value();

  Future<void> load() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/mymooscles_data.json');
    _file = file;
    if (await file.exists()) {
      try {
        final raw = await file.readAsString();
        data = AppData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        if (data.version < 2) {
          migrate(data);
          await _write();
        }
      } catch (_) {
        // Arquivo corrompido: guarda uma cópia e recomeça, sem apagar nada.
        await file.copy('${dir.path}/mymooscles_data_erro_${DateTime.now().millisecondsSinceEpoch}.json');
        data = seedData();
        await _write();
      }
    } else {
      data = seedData();
      await _write();
    }
  }

  Future<void> _write() async {
    final f = _file;
    if (f == null) return;
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(data.toJson()), flush: true);
    await tmp.rename(f.path);
  }

  /// Notifica a interface e grava em disco (gravações ficam em fila).
  Future<void> save() {
    notifyListeners();
    _pending = _pending.then((_) => _write()).catchError((Object e) {
      debugPrint('Falha ao salvar: $e');
    });
    return _pending;
  }

  // ---- Corpo -------------------------------------------------------------

  Future<void> addBody(BodyEntry e) {
    data.body.add(e);
    data.body.sort((a, b) => a.date.compareTo(b.date));
    return save();
  }

  Future<void> deleteBody(BodyEntry e) {
    data.body.removeWhere((x) => x.id == e.id);
    return save();
  }

  // ---- Treinos -----------------------------------------------------------

  WorkoutTemplate? templateById(String id) {
    for (final t in data.templates) {
      if (t.id == id) return t;
    }
    return null;
  }

  WorkoutTemplate? templateForWeekday(int weekday) {
    for (final t in data.templates) {
      if (t.weekday == weekday) return t;
    }
    return null;
  }

  Future<Session> startSession(WorkoutTemplate t) async {
    final s = buildSession(data, t);
    data.draft = s;
    await save();
    return s;
  }

  Future<void> saveDraft() => save();

  Future<void> finishDraft() {
    final d = data.draft;
    if (d != null) {
      d.end = DateTime.now();
      // Guarda só os exercícios com alguma série feita.
      d.exercises.removeWhere((e) => e.doneSets.isEmpty);
      for (final e in d.exercises) {
        e.sets.removeWhere((s) => !s.done || s.reps == null);
        e.skipped = false;
      }
      if (d.exercises.isNotEmpty) data.sessions.add(d);
      data.draft = null;
    }
    return save();
  }

  Future<void> discardDraft() {
    data.draft = null;
    return save();
  }

  Future<void> deleteSession(Session s) {
    data.sessions.removeWhere((x) => x.id == s.id);
    return save();
  }

  /// Adiciona um exercício à sessão em andamento (e, se pedido, ao treino salvo).
  Future<void> addExerciseToDraft({
    required String name,
    required int sets,
    required int repMin,
    required int repMax,
    required bool timed,
    required bool addToTemplate,
  }) {
    final d = data.draft;
    if (d == null) return Future.value();
    final tpl = templateById(d.templateId);
    final ex = ExerciseTemplate(
      name: name,
      sets: sets,
      repMin: repMin,
      repMax: repMax,
      timed: timed,
      warmups: 0,
      alternatives: List<String>.from(defaultAlternatives[name] ?? const <String>[]),
    );
    if (addToTemplate && tpl != null) tpl.exercises.add(ex);
    d.exercises.add(buildExerciseLog(data, ex));
    return save();
  }

  // ---- Diário alimentar --------------------------------------------------

  List<FoodEntry> foodOn(DateTime day) => data.food.where((f) => sameDay(f.date, day)).toList();

  FoodEntry? mealEntry(DateTime day, Meal meal) {
    for (final f in data.food) {
      if (f.mealKey == meal.key && sameDay(f.date, day)) return f;
    }
    return null;
  }

  /// status null remove o check-in da refeição naquele dia.
  Future<void> setMealStatus(DateTime day, Meal meal, String? status, {String? text}) {
    final existing = mealEntry(day, meal);
    if (status == null) {
      if (existing != null) data.food.remove(existing);
    } else if (existing != null) {
      existing.status = status;
      if (text != null) existing.text = text;
    } else {
      data.food.add(FoodEntry(date: dayOnly(day), mealKey: meal.key, status: status, text: text ?? ''));
    }
    return save();
  }

  Future<void> addFood(FoodEntry e) {
    data.food.add(e);
    return save();
  }

  Future<void> deleteFood(FoodEntry e) {
    data.food.removeWhere((x) => x.id == e.id);
    return save();
  }

  // ---- Backup ------------------------------------------------------------

  String exportJson() => const JsonEncoder.withIndent(' ').convert(data.toJson());

  /// Lança exceção se o texto não for um backup válido.
  Future<void> importJson(String text) {
    final parsed = AppData.fromJson(jsonDecode(text) as Map<String, dynamic>);
    migrate(parsed);
    data = parsed;
    return save();
  }
}
