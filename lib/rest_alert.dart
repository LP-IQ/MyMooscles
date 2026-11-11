import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Cronômetro de descanso fora do app: uma notificação com contagem regressiva
/// (aparece na tela bloqueada) e um alerta agendado para o fim do descanso.
class RestAlert {
  RestAlert._();
  static final RestAlert instance = RestAlert._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _askedPermission = false;

  static const _countdownId = 101;
  static const _endId = 102;

  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Notificações indisponíveis: $e');
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<void> _askPermissionOnce() async {
    if (_askedPermission) return;
    _askedPermission = true;
    try {
      await _android?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Permissão de notificação: $e');
    }
  }

  /// Mostra a contagem regressiva e agenda o aviso de fim. Chame de novo para reiniciar.
  Future<void> start(int seconds, String label) async {
    if (!_ready || seconds <= 0) return;
    await _askPermissionOnce();
    final end = DateTime.now().add(Duration(seconds: seconds));
    try {
      await _plugin.cancel(_endId);
      await _plugin.show(
        _countdownId,
        'Descanso',
        label,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'descanso',
            'Cronômetro de descanso',
            channelDescription: 'Contagem regressiva do descanso entre séries',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            playSound: false,
            enableVibration: false,
            showWhen: true,
            when: end.millisecondsSinceEpoch,
            usesChronometer: true,
            chronometerCountDown: true,
            timeoutAfter: seconds * 1000,
            visibility: NotificationVisibility.public,
            category: AndroidNotificationCategory.stopwatch,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Falha na contagem: $e');
    }

    const endDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'fim_descanso',
        'Fim do descanso',
        channelDescription: 'Avisa quando o descanso acaba',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        autoCancel: true,
        timeoutAfter: 60000,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.alarm,
      ),
    );
    final at = tz.TZDateTime.from(end, tz.UTC);
    try {
      await _plugin.zonedSchedule(
        _endId,
        'Descanso acabou',
        'Hora da próxima série · $label',
        at,
        endDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Alarme exato indisponível ($e); usando aproximado');
      try {
        await _plugin.zonedSchedule(
          _endId,
          'Descanso acabou',
          'Hora da próxima série · $label',
          at,
          endDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (e2) {
        debugPrint('Falha ao agendar o fim do descanso: $e2');
      }
    }
  }

  Future<void> stop() async {
    if (!_ready) return;
    try {
      await _plugin.cancel(_countdownId);
      await _plugin.cancel(_endId);
    } catch (e) {
      debugPrint('Falha ao cancelar: $e');
    }
  }
}
