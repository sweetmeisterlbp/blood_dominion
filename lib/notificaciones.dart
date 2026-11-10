import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

// ====================== AVISOS (notificaciones locales) ======================
// Avisan al jugador cuando termina una misión o un trabajo de la taberna,
// aunque tenga el juego cerrado. Se programan en el teléfono (sin servidor).
//
// Usa el modo "inexacto": Android puede retrasar el aviso unos minutos para
// ahorrar batería, pero no hace falta ningún permiso especial de alarmas.

class Notificaciones {
  Notificaciones._();
  static final Notificaciones instancia = Notificaciones._();

  // Un id por tipo de aviso: programar otro del mismo tipo reemplaza al anterior.
  static const int idMision = 1;
  static const int idTrabajo = 2;

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();
  bool _listo = false;
  bool _permisoPedido = false;

  // Solo funcionan en Android e iOS.
  static bool get _soportada =>
      !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> iniciar() async {
    if (_listo || !_soportada) return;
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          // En iPhone el permiso se pide más tarde, al primer aviso.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _listo = true;
    } catch (e) {
      debugPrint('Notificaciones: no se pudieron iniciar: $e');
    }
  }

  // Pide permiso al jugador (Android 13+ y iPhone). Se llama al empezar la
  // primera misión o trabajo, que es cuando el aviso tiene sentido.
  Future<void> pedirPermiso() async {
    if (!_listo || _permisoPedido) return;
    _permisoPedido = true;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, sound: true);
    } catch (e) {
      debugPrint('Notificaciones: error al pedir permiso: $e');
    }
  }

  // Programa un aviso para el instante [cuando]. Si ya había uno con el mismo
  // [id], lo reemplaza.
  Future<void> programar(
      int id, String titulo, String cuerpo, DateTime cuando) async {
    if (!_listo) return;
    try {
      await _plugin.cancel(id: id);
      if (!cuando.isAfter(DateTime.now())) return;
      await _plugin.zonedSchedule(
        id: id,
        title: titulo,
        body: cuerpo,
        // Un instante exacto expresado en UTC: no hace falta saber la zona
        // horaria del teléfono.
        scheduledDate: tz.TZDateTime.from(cuando, tz.UTC),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'tareas',
            'Misiones y taberna',
            channelDescription:
            'Avisos cuando termina una misión o un trabajo.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Notificaciones: no se pudo programar: $e');
    }
  }

  Future<void> cancelar(int id) async {
    if (!_listo) return;
    try {
      await _plugin.cancel(id: id);
    } catch (e) {
      debugPrint('Notificaciones: no se pudo cancelar: $e');
    }
  }
}