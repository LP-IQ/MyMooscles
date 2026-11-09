import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'logic.dart';
import 'models.dart';
import 'seed.dart';

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
    final file = File('${dir.path}/gymapp_data.json');
    _file = file;
    if (await file.exists()) {
      try {
        final raw = await file.readAsString();
        data = AppData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // Arquivo corrompido: guarda uma cópia e recomeça, sem apagar nada.
        await file.copy('${dir.path}/gymapp_data_erro_${DateTime.now().millisecondsSinceEpoch}.json');
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

  // ---- Backup ------------------------------------------------------------

  String exportJson() => const JsonEncoder.withIndent(' ').convert(data.toJson());

  /// Lança exceção se o texto não for um backup válido.
  Future<void> importJson(String text) {
    final parsed = AppData.fromJson(jsonDecode(text) as Map<String, dynamic>);
    data = parsed;
    return save();
  }
}
