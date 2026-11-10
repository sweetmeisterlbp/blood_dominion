import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'arena.dart';
import 'logros.dart';
import 'main.dart';
import 'bestiario.dart';
import 'diarias.dart';
import 'social.dart';

// Conecta el juego con Firebase (cuenta con correo y contraseña):
//  - cargarPartida(): se llama justo después de iniciar sesión
//  - Guarda solo, unos segundos después de cada cambio
//  - Publica tu perfil para la Arena (collection "perfiles")
//  - procesarAtaques(): descuenta el oro de los ataques PvP que recibiste
//  - cerrarSesion(): guarda, cierra la sesión y deja el juego limpio
// ---------- REINICIO DE CUENTAS ----------
// Para reiniciar a todos: en Firestore, documento config/reinicio, campo
// "version" (número). Súbelo (1, 2, 3...) y cada cuenta con un personaje de
// una versión anterior se reinicia sola la próxima vez que entre.
// Recompensa única para quien perdió su personaje:
const int recompensaReinicioGemas = 1000;
const int recompensaReinicioOro = 5000;

// Cómo se guarda un objeto en el inventario y el equipo: solo el nombre; si
// está afilado, "Nombre|2"; y si tiene apodo, "Nombre|2|Apodo".
String _codObjeto(Objeto o) => o.apodo != null
    ? '${o.nombre}|${o.afilado}|${o.apodo}'
    : o.afilado > 0
    ? '${o.nombre}|${o.afilado}'
    : o.nombre;

class Nube with WidgetsBindingObserver {
  static final Nube _i = Nube._();
  Nube._();

  String? _uid;
  Timer? _espera;
  bool _cargando = false;
  bool _activo = false; // ya está escuchando cambios para guardar
  bool _observando = false;
  bool _procesando = false; // evita aplicar dos veces los ataques recibidos
  // Versiones del historial ya guardadas en la nube (para no reescribirlo
  // en cada guardado, solo cuando hay un combate nuevo)
  int _verPvE = 0;
  int _verArena = 0;
  int _verDef = 0;
  // Número del último reinicio de cuentas (config/reinicio). Si no se pudo
  // leer, no se compara ni se escribe nada (así nadie se reinicia por error).
  static int versionReinicio = 0;
  bool _versionConocida = false;

  DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseFirestore.instance.collection('jugadores').doc(_uid);

  DocumentReference<Map<String, dynamic>> get _docPerfil =>
      FirebaseFirestore.instance.collection('perfiles').doc(_uid);

  // Carga la partida de la cuenta que inició sesión.
  // Si falla (sin internet, reglas, etc.) lanza el error: así NO se guarda
  // nada encima de tu partida real por accidente.
  static Future<void> cargarPartida() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('No hay sesión iniciada');
    _i._uid = user.uid;
    debugPrint('Nube: sesión OK, uid = ${user.uid}');
    await _i._cargar();
    _i._verPvE = juego.versionHistorial;
    _i._verArena = datosPvp.versionHistorial;
    _i._verDef = datosPvp.versionDefensas;
    if (!_i._activo) {
      juego.addListener(_i._programarGuardado);
      _i._activo = true;
    }
    if (!_i._observando) {
      WidgetsBinding.instance.addObserver(_i);
      _i._observando = true;
    }
    // Ataques PvP que recibiste mientras no estabas (si falla, no importa)
    await procesarAtaques();
    // Cuenta que ya tenía personaje cuando se reinició: recompensa (una vez)
    if (juego.personajeCreado) await entregarRecompensaReinicio();
    // Asegura que tu perfil de la Arena exista aunque no cambies nada
    _i._programarGuardado();
    debugPrint('Nube: partida cargada, guardado automático activo');
  }

  // ¿Tiene esta cuenta una recompensa del reinicio sin cobrar? (solo consulta)
  static Future<bool> recompensaReinicioPendiente() async {
    final uid = _i._uid;
    if (uid == null) return false;
    try {
      final s = await FirebaseFirestore.instance
          .collection('afectados')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 15));
      return s.exists && s.data()?['recompensaReclamada'] == false;
    } catch (e) {
      debugPrint('Nube: no se pudo consultar la recompensa del reinicio: $e');
      return false;
    }
  }

  // Recompensa del reinicio. Devuelve true UNA sola vez por cuenta afectada.
  static Future<bool> reclamarRecompensaReinicio() async {
    final uid = _i._uid;
    if (uid == null) return false;
    try {
      final ref = FirebaseFirestore.instance.collection('afectados').doc(uid);
      final s = await ref.get().timeout(const Duration(seconds: 15));
      if (!s.exists || s.data()?['recompensaReclamada'] != false) return false;
      await ref.update({
        'recompensaReclamada': true,
        'fechaRecompensa': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 15));
      return true;
    } catch (e) {
      debugPrint('Nube: no se pudo reclamar la recompensa del reinicio: $e');
      return false;
    }
  }

  // Si la cuenta tiene recompensa pendiente, se la suma al personaje.
  static Future<void> entregarRecompensaReinicio() async {
    if (await reclamarRecompensaReinicio()) {
      juego.gemas += recompensaReinicioGemas;
      juego.oro += recompensaReinicioOro;
      juego.avisarCambio();
      debugPrint('Nube: recompensa de reinicio entregada');
    }
  }

  // Guarda, cierra la sesión y reinicia el juego en memoria.
  static Future<void> cerrarSesion() async {
    _i._espera?.cancel();
    await _i._guardar();
    if (_i._activo) {
      juego.removeListener(_i._programarGuardado);
      _i._activo = false;
    }
    _i._uid = null;
    juego = EstadoJuego();
    datosPvp = DatosPvp();
    await FirebaseAuth.instance.signOut();
  }

  // ---------- ELIMINAR CUENTA ----------
  // Lo exige Google Play: el jugador puede borrar su cuenta y sus datos desde el
  // juego. Pide la contraseña, borra los datos en Firestore y luego la cuenta.
  // Devuelve null si todo salió bien, o un mensaje de error.
  static Future<String?> eliminarCuenta(String password) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'No hay sesión iniciada.';
    final uid = user.uid;
    final correo = user.email;

    // 1) Confirmar que eres tú (Firebase lo exige para borrar una cuenta)
    try {
      if (correo != null) {
        await user.reauthenticateWithCredential(
            EmailAuthProvider.credential(email: correo, password: password));
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return 'La contraseña no es correcta.';
      }
      if (e.code == 'too-many-requests') {
        return 'Demasiados intentos. Espera un momento.';
      }
      if (e.code == 'network-request-failed') {
        return 'Sin conexión. Revisa tu internet.';
      }
      return 'No se pudo comprobar tu contraseña (${e.code}).';
    } catch (_) {
      return 'No se pudo conectar. Revisa tu internet.';
    }

    // 2) Para el guardado automático, para que no vuelva a crear tus datos
    _i._espera?.cancel();
    final estabaActivo = _i._activo;
    if (estabaActivo) {
      juego.removeListener(_i._programarGuardado);
      _i._activo = false;
    }
    Social.instancia.detener();

    // 3) Borra tus datos
    try {
      await _i._borrarDatosDe(uid);
    } catch (e) {
      if (estabaActivo) {
        juego.addListener(_i._programarGuardado);
        _i._activo = true;
      }
      return 'No se pudieron borrar todos tus datos. Revisa tu conexión e '
          'inténtalo otra vez.';
    }

    // 4) Borra la cuenta
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      return 'Tus datos se borraron, pero no se pudo cerrar la cuenta '
          '(${e.code}). Inténtalo otra vez.';
    } catch (_) {
      return 'Tus datos se borraron, pero no se pudo cerrar la cuenta. '
          'Inténtalo otra vez.';
    }

    // 5) Deja el juego limpio. Al borrarse la cuenta, la app vuelve sola a la
    // pantalla de inicio de sesión.
    _i._uid = null;
    juego = EstadoJuego();
    datosPvp = DatosPvp();
    return null;
  }

  // Borra todo lo que hay de este jugador en Firestore.
  Future<void> _borrarDatosDe(String uid) async {
    final db = FirebaseFirestore.instance;
    const espera = Duration(seconds: 20);

    Future<void> borrarTodo(Query<Map<String, dynamic>> q) async {
      final s = await q.get().timeout(espera);
      for (final d in s.docs) {
        await d.reference.delete().timeout(espera);
      }
    }

    // Tu entrada en la lista de amigos de cada amigo, y tu propia lista
    final amigos = await db
        .collection('amigos')
        .doc(uid)
        .collection('lista')
        .get()
        .timeout(espera);
    for (final a in amigos.docs) {
      try {
        await db
            .collection('amigos')
            .doc(a.id)
            .collection('lista')
            .doc(uid)
            .delete()
            .timeout(espera);
      } catch (_) {}
      await a.reference.delete().timeout(espera);
    }

    // Chats privados donde participas (mensajes y chat)
    final chats = await db
        .collection('chats')
        .where('participantes', arrayContains: uid)
        .get()
        .timeout(espera);
    for (final ch in chats.docs) {
      await borrarTodo(ch.reference.collection('mensajes'));
      await ch.reference.delete().timeout(espera);
    }

    // Tus comentarios enviados al desarrollador
    await borrarTodo(db.collection('comentarios').where('uid', isEqualTo: uid));

    // Tus mensajes del chat global
    await borrarTodo(db.collection('chat_global').where('uid', isEqualTo: uid));

    // Solicitudes de amistad recibidas y lista de bloqueados
    await borrarTodo(
        db.collection('solicitudes').doc(uid).collection('entrantes'));
    await borrarTodo(db.collection('bloqueados').doc(uid).collection('lista'));

    // Torneo (semana actual y pasada)
    for (final semana in [Torneo.semanaActual, Torneo.semanaPasada]) {
      try {
        await db
            .collection('torneo')
            .doc(semana)
            .collection('jugadores')
            .doc(uid)
            .delete()
            .timeout(espera);
      } catch (_) {}
    }

    // Ataques recibidos, perfil público, registro de reinicio y la partida
    await borrarTodo(db.collection('perfiles').doc(uid).collection('ataques'));
    await db.collection('perfiles').doc(uid).delete().timeout(espera);
    try {
      await db.collection('afectados').doc(uid).delete().timeout(espera);
    } catch (_) {}
    await db.collection('jugadores').doc(uid).delete().timeout(espera);
  }

  // Aplica los ataques que otros jugadores te hicieron: descuenta el oro
  // robado y deja avisos para mostrarlos en la Arena.
  static Future<void> procesarAtaques() async {
    final uid = _i._uid;
    if (uid == null || _i._procesando) return;
    _i._procesando = true;
    try {
      final col = FirebaseFirestore.instance
          .collection('perfiles')
          .doc(uid)
          .collection('ataques');
      final snap = await col.get().timeout(const Duration(seconds: 15));
      if (snap.docs.isEmpty) return;
      for (final d in snap.docs) {
        final x = d.data();
        final nombre = (x['atacanteNombre'] ?? 'Alguien') as String;
        final robado = ((x['oroRobado'] ?? 0) as num).toInt();
        final gano = x['ganoAtacante'] == true;
        int perdido = 0;
        int premio = 0;
        if (gano) {
          perdido = min(robado, juego.oro);
          juego.logros.registrarDefensa(exito: false, oroPerdido: perdido);
          juego.oro -= perdido;
          datosPvp.pvpOroPerdido += perdido; // para el ranking
          datosPvp.avisos.add('$nombre te atacó y te robó $perdido de oro.');
        } else {
          juego.logros.registrarDefensa(exito: true, oroPerdido: 0);
          // Premio por defenderte (hasta $maxDefensasPremiadasPorDia al día)
          premio = juego.diarias.premioDefensa();
          datosPvp.avisos.add(premio > 0
              ? '$nombre te atacó y fue derrotado. Ganaste $premio de oro por defenderte.'
              : '$nombre te atacó y fue derrotado. No perdiste nada.');
        }
        // Guarda el combate completo en tu historial de Defensas.
        try {
          if (x['registro'] is Map) {
            final reg = RegistroCombate.fromMap(
                Map<String, dynamic>.from(x['registro'] as Map))
                .conOro(gano ? -perdido : premio);
            datosPvp.defensas.insert(0, reg);
            if (datosPvp.defensas.length > maxHistorialCombates) {
              datosPvp.defensas.removeRange(
                  maxHistorialCombates, datosPvp.defensas.length);
            }
            datosPvp.versionDefensas++;
          }
        } catch (e) {
          debugPrint('Nube: no se pudo guardar la defensa: $e');
        }
        await d.reference.delete();
      }
      juego.revisarLogros();
      juego.avisarCambio();
    } catch (e) {
      debugPrint('Nube: no se pudieron procesar los ataques: $e');
    } finally {
      _i._procesando = false;
    }
  }

  // Guarda al mandar la app a segundo plano
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _espera?.cancel();
      _guardar();
    }
  }

  void _programarGuardado() {
    if (_cargando) return;
    _espera?.cancel();
    _espera = Timer(const Duration(seconds: 3), _guardar);
  }

  // ---------------- GUARDAR ----------------

  Future<void> _guardar() async {
    if (_uid == null || !_activo || !juego.personajeCreado) return;
    try {
      await _doc
          .set(_aMapa(), SetOptions(merge: true))
          .timeout(const Duration(seconds: 15));
      // Perfil público para la Arena (merge: no pisa "protegidoHasta")
      await _docPerfil
          .set(_aPerfil(), SetOptions(merge: true))
          .timeout(const Duration(seconds: 15));
      // Historial de combates: solo cuando cambió (son varios KB)
      if (juego.versionHistorial != _verPvE ||
          datosPvp.versionHistorial != _verArena ||
          datosPvp.versionDefensas != _verDef) {
        final vPvE = juego.versionHistorial;
        final vArena = datosPvp.versionHistorial;
        final vDef = datosPvp.versionDefensas;
        await _doc.set({
          'historialPvE': juego.historialPvE.map((r) => r.toMap()).toList(),
          'historialArena': datosPvp.historial.map((r) => r.toMap()).toList(),
          'historialDefensas':
          datosPvp.defensas.map((r) => r.toMap()).toList(),
        }, SetOptions(merge: true)).timeout(const Duration(seconds: 15));
        _verPvE = vPvE;
        _verArena = vArena;
        _verDef = vDef;
      }
      debugPrint('Nube: guardado OK');
    } catch (e) {
      debugPrint('Nube: error al guardar: $e');
    }
  }

  // Lo que ven los demás jugadores de ti. Los atributos son SOLO los que
  // entrenaste; lo que suma tu equipo va aparte en "bonos" (se usa en la
  // pelea, pero la pantalla de la Arena no lo muestra).
  Map<String, dynamic> _aPerfil() {
    final j = juego;
    return {
      'nombre': j.nombre,
      'nivel': j.nivel,
      'xp': j.xp,
      if (_versionConocida) 'versionReinicio': versionReinicio,
      'raza': j.raza.index,
      'genero': j.genero.index,
      'alineamiento': j.alineamiento,
      if (_uid != null) 'codigo': codigoJugador(_uid!),
      'oro': j.oro,
      'poder': j.atributos['Poder']!,
      'vigor': j.atributos['Vigor']!,
      'agilidad': j.atributos['Agilidad']!,
      'maestria': j.atributos['Maestría de combate']!,
      'guardia': j.atributos['Guardia']!,
      'aguante': j.atributos['Aguante']!,
      'bonos': {for (final k in j.atributos.keys) k: j.bonoEquipo(k)},
      'habArmadura': j.habArmadura,
      'habUnaMano': j.habUnaMano,
      'habDosManos': j.habDosManos,
      'arma': j.equipado[Ranura.arma]?.nombre,
      'armaAfilado': j.equipado[Ranura.arma]?.afilado ?? 0,
      'escudo': j.equipado[Ranura.escudo]?.nombre,
      'armadura': j.equipado[Ranura.armadura]?.nombre,
      'victorias': datosPvp.victorias,
      'derrotas': datosPvp.derrotas,
      'mejorRachaPvp': datosPvp.mejorRachaPvp,
      // Contadores del ranking: PvP (Arena) y PvE (Cripta y Ciudadela)
      'rkPvpV': datosPvp.victorias,
      'rkPvpE': datosPvp.pvpEmpates,
      'rkPvpD': datosPvp.derrotas,
      'rkPvpOroG': datosPvp.pvpOroGanado,
      'rkPvpOroP': datosPvp.pvpOroPerdido,
      'rkPvpDano': datosPvp.pvpDano,
      'rkPveV': datosPvp.pveVictorias,
      'rkPveE': datosPvp.pveEmpates,
      'rkPveD': datosPvp.pveDerrotas,
      'rkPveOroG': datosPvp.pveOroGanado,
      'rkPveDano': datosPvp.pveDano,
      // Ranking del domingo del Inmortal: un campo distinto por domingo
      if (j.inmortalDia.isNotEmpty) campoInmortal(j.inmortalDia): j.inmortalDano,
      // Estadísticas y logros que ven los demás jugadores
      'perfilLogros': j.logros.comoPerfil(j).toMap(),
      'actualizado': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> _aMapa() {
    final j = juego;
    return {
      'email': FirebaseAuth.instance.currentUser?.email,
      'nombre': j.nombre,
      'nivel': j.nivel,
      'oro': j.oro,
      'gemas': j.gemas,
      'xp': j.xp,
      'puntosLibres': j.puntosLibres,
      'alineamiento': j.alineamiento,
      'genero': j.genero.index,
      'raza': j.raza.index,
      'personajeCreado': j.personajeCreado,
      if (_versionConocida) 'versionReinicio': versionReinicio,
      'premium': j.premium,
      // Premium: el instante (UTC, en milisegundos) en que termina
      'premiumHastaMs': j.premiumHasta?.millisecondsSinceEpoch,
      'bloquesHoy': j.bloquesHoy,
      'diaMisiones': j.diaMisiones,
      // Bazar: día de la última renovación y objetos que quedan a la venta
      'bazarDia': j.bazarDia,
      'bazarOfertas': j.bazarOfertas,
      'bazarRebaja': j.bazarRebaja,
      // Jefes: intentos de hoy y jefes ya vencidos
      'jefesDia': j.jefesDia,
      'jefesHoy': j.jefesHoy,
      'jefesVencidos': j.jefesVencidos,
      // Dados de la taberna: partidas de hoy
      'dadosDia': j.dadosDia,
      'dadosPartidas': j.dadosPartidas,
      // Evento del Inmortal (domingos)
      'inmortalDia': j.inmortalDia,
      'inmortalDano': j.inmortalDano,
      'inmortalOro': j.inmortalOro,
      // Anuncios
      'sinAnuncios': j.sinAnuncios,
      'bloquesBonusHoy': j.bloquesBonusHoy,
      'anunciosVistosHoy': j.anunciosVistosHoy,
      'diaBonus': j.diaBonus,
      'diarias': j.diarias.aMapa(),
      'bestiario': j.bestiario.aMapa(),
      // Recompensa diaria y tutorial
      'diaRecompensa': j.diaRecompensa,
      'rachaDiaria': j.rachaDiaria,
      'cambiosRaza': j.cambiosRaza,
      'tutorialVisto': j.tutorialVisto,
      'vida': j.vida,
      'habArmadura': j.habArmadura,
      'habUnaMano': j.habUnaMano,
      'habDosManos': j.habDosManos,
      'atributos': Map<String, int>.from(j.atributos),
      'puntosEntrenados': Map<String, int>.from(j.puntosEntrenados),
      'inventario': j.inventario.map(_codObjeto).toList(),
      'equipado': {
        for (final r in Ranura.values)
          r.name: j.equipado[r] == null ? null : _codObjeto(j.equipado[r]!),
      },
      // Misión en curso
      'misionEsBien': j.misionEsBien,
      'misionBloques': j.misionBloques,
      'misionLugar': j.misionDestino?.lugar,
      'misionTermina': j.misionTermina?.millisecondsSinceEpoch,
      // Trabajo en curso
      'trabajoNombre': j.trabajoActual?.nombre,
      'trabajoDescripcion': j.trabajoActual?.descripcion,
      'trabajoEsBien': j.trabajoEsBien,
      'trabajoHoras': j.trabajoHoras,
      'trabajoPago': j.trabajoPago,
      'trabajoTermina': j.trabajoTermina?.millisecondsSinceEpoch,
      // Arena (PvP)
      'ultimoAtaquePvpMs': datosPvp.ultimoAtaqueMs,
      'rivalesAtacados': Map<String, int>.from(datosPvp.rivalesAtacados),
      'victoriasPvp': datosPvp.victorias,
      'derrotasPvp': datosPvp.derrotas,
      'rachaPvp': datosPvp.rachaPvp,
      'mejorRachaPvp': datosPvp.mejorRachaPvp,
      'pvpEmpates': datosPvp.pvpEmpates,
      'pvpOroGanado': datosPvp.pvpOroGanado,
      'pvpOroPerdido': datosPvp.pvpOroPerdido,
      'pvpDano': datosPvp.pvpDano,
      'pveVictorias': datosPvp.pveVictorias,
      'pveEmpates': datosPvp.pveEmpates,
      'pveDerrotas': datosPvp.pveDerrotas,
      'pveOroGanado': datosPvp.pveOroGanado,
      'pveDano': datosPvp.pveDano,
      // Estadísticas y logros
      'logros': j.logros.aMapaGuardado(),
      'actualizado': FieldValue.serverTimestamp(),
    };
  }

  // ---------------- REINICIO DE CUENTAS ----------------

  // Lee config/reinicio. Si falla, nadie se reinicia en esta sesión.
  Future<void> _leerVersionReinicio() async {
    try {
      final s = await FirebaseFirestore.instance
          .collection('config')
          .doc('reinicio')
          .get()
          .timeout(const Duration(seconds: 15));
      versionReinicio = ((s.data()?['version'] ?? 0) as num).toInt();
      _versionConocida = true;
    } catch (e) {
      _versionConocida = false;
      debugPrint('Nube: no se pudo leer config/reinicio: $e');
    }
  }

  // Borra el personaje de esta cuenta (queda anotado en "afectados" para la
  // recompensa). Si algo falla, lanza el error y el personaje sigue intacto.
  Future<void> _reiniciarCuenta(Map<String, dynamic> d) async {
    final ref = FirebaseFirestore.instance.collection('afectados').doc(_uid);
    final previo = await ref.get().timeout(const Duration(seconds: 15));
    final reinicioPrevio = ((previo.data()?['reinicio'] ?? 0) as num).toInt();
    if (!previo.exists || reinicioPrevio < versionReinicio) {
      await ref.set({
        'email': FirebaseAuth.instance.currentUser?.email,
        'nombre': d['nombre'],
        'nivel': d['nivel'],
        'oro': d['oro'],
        'gemas': d['gemas'],
        'reinicio': versionReinicio,
        'fecha': FieldValue.serverTimestamp(),
        'recompensaReclamada': false,
      }).timeout(const Duration(seconds: 15));
    }
    // Ataques pendientes: no deben cobrarse al personaje nuevo
    final ataques = await _docPerfil
        .collection('ataques')
        .get()
        .timeout(const Duration(seconds: 15));
    for (final a in ataques.docs) {
      await a.reference.delete();
    }
    // Perfil de la Arena y partida
    await _docPerfil.delete().timeout(const Duration(seconds: 15));
    await _doc.set({
      'email': FirebaseAuth.instance.currentUser?.email,
      'personajeCreado': false,
      'versionReinicio': versionReinicio,
      // Lo que se pagó con dinero real NO se pierde en el reinicio
      if (d['premium'] != null) 'premium': d['premium'],
      if (d['premiumHastaMs'] != null) 'premiumHastaMs': d['premiumHastaMs'],
      if (d['sinAnuncios'] == true) 'sinAnuncios': true,
      'actualizado': FieldValue.serverTimestamp(),
    }).timeout(const Duration(seconds: 15)); // sin merge: borra lo anterior
    debugPrint('Nube: cuenta reiniciada (versión $versionReinicio)');
  }

  // ---------------- CARGAR ----------------

  Future<void> _cargar() async {
    await _leerVersionReinicio();
    final snap = await _doc.get().timeout(const Duration(seconds: 15));
    if (!snap.exists) return; // cuenta nueva: verá la creación de personaje
    final d = snap.data()!;
    // Personaje de antes del último reinicio: se descarta y verá la creación
    final versionCuenta = ((d['versionReinicio'] ?? 0) as num).toInt();
    if (_versionConocida &&
        d['personajeCreado'] == true &&
        versionCuenta < versionReinicio) {
      await _reiniciarCuenta(d);
      return;
    }
    _cargando = true;
    try {
      final j = juego;
      j.nombre = d['nombre'] ?? j.nombre;
      j.nivel = d['nivel'] ?? j.nivel;
      j.oro = d['oro'] ?? j.oro;
      j.gemas = d['gemas'] ?? 0;
      j.xp = d['xp'] ?? 0;
      j.puntosLibres = d['puntosLibres'] ?? 0;
      j.alineamiento = d['alineamiento'] ?? 0;
      j.genero = Genero.values[(d['genero'] ?? 0) as int];
      j.raza = Raza.values[(d['raza'] ?? 0) as int];
      j.personajeCreado = d['personajeCreado'] ?? false;
      final premiumMs = d['premiumHastaMs'];
      j.premiumHasta = premiumMs is num
          ? DateTime.fromMillisecondsSinceEpoch(premiumMs.toInt(),
          isUtc: true)
          : null;
      j.bloquesHoy = d['bloquesHoy'] ?? 0;
      j.diaMisiones = d['diaMisiones'] ?? '';
      j.bazarDia = d['bazarDia'] ?? '';
      j.bazarOfertas = [
        for (final x in (d['bazarOfertas'] ?? const []) as List) x.toString()
      ];
      j.bazarRebaja = [
        for (final x in (d['bazarRebaja'] ?? const []) as List) x.toString()
      ];
      j.jefesDia = (d['jefesDia'] ?? '') as String;
      j.jefesHoy = [
        for (final x in (d['jefesHoy'] ?? const []) as List) x.toString()
      ];
      j.jefesVencidos = [
        for (final x in (d['jefesVencidos'] ?? const []) as List) x.toString()
      ];
      j.dadosDia = (d['dadosDia'] ?? '') as String;
      j.dadosPartidas = ((d['dadosPartidas'] ?? 0) as num).toInt();
      j.inmortalDia = (d['inmortalDia'] ?? '') as String;
      j.inmortalDano = (d['inmortalDano'] ?? 0) as int;
      j.inmortalOro = (d['inmortalOro'] ?? 0) as int;
      // Anuncios. "Sin anuncios" nunca se pierde si la tienda ya lo restauró.
      j.sinAnuncios = j.sinAnuncios || (d['sinAnuncios'] == true);
      j.bloquesBonusHoy = (d['bloquesBonusHoy'] ?? 0) as int;
      j.anunciosVistosHoy = (d['anunciosVistosHoy'] ?? 0) as int;
      j.diaBonus = (d['diaBonus'] ?? '') as String;
      j.diaRecompensa = (d['diaRecompensa'] ?? '') as String;
      j.rachaDiaria = (d['rachaDiaria'] ?? 0) as int;
      j.cambiosRaza = ((d['cambiosRaza'] ?? 0) as num).toInt();
      // Las cuentas que ya existían no necesitan el tutorial.
      j.tutorialVisto = (d['tutorialVisto'] ?? true) as bool;
      j.habArmadura = d['habArmadura'] ?? 0;
      j.habUnaMano = d['habUnaMano'] ?? 0;
      j.habDosManos = d['habDosManos'] ?? 0;

      final atr = Map<String, dynamic>.from(d['atributos'] ?? {});
      for (final k in j.atributos.keys.toList()) {
        if (atr[k] != null) j.atributos[k] = atr[k] as int;
      }
      final ent = Map<String, dynamic>.from(d['puntosEntrenados'] ?? {});
      for (final k in j.puntosEntrenados.keys.toList()) {
        if (ent[k] != null) j.puntosEntrenados[k] = ent[k] as int;
      }

      // Inventario y equipo, buscando cada objeto por nombre en el catálogo
      // Un objeto afilado se guarda como "Nombre|2" (ver _codObjeto).
      Objeto? buscar(String? n) {
        if (n == null) return null;
        final partes = n.split('|');
        final nombre = partes[0];
        final afilado = partes.length > 1
            ? (int.tryParse(partes[1]) ?? 0).clamp(0, 3)
            : 0;
        final apodo = partes.length > 2 ? partes.sublist(2).join('|') : null;
        for (final o in catalogo) {
          if (o.nombre != nombre) continue;
          var r = afilado > 0 ? o.conAfilado(afilado) : o;
          if (apodo != null && apodo.isNotEmpty) r = r.conApodo(apodo);
          return r;
        }
        return null;
      }

      j.inventario.clear();
      for (final n in List<String>.from(d['inventario'] ?? [])) {
        final o = buscar(n);
        if (o != null) j.inventario.add(o);
      }
      final eq = Map<String, dynamic>.from(d['equipado'] ?? {});
      for (final r in Ranura.values) {
        j.equipado[r] = buscar(eq[r.name] as String?);
      }

      // Vida (después de atributos y equipo porque la vida máxima depende de ellos)
      j.vidaActual = d['vida'] ?? j.vidaMaxima;

      // Misión en curso
      final lugar = d['misionLugar'] as String?;
      final mTermina = d['misionTermina'] as int?;
      if (lugar != null && mTermina != null) {
        for (final dest in destinos) {
          if (dest.lugar == lugar) j.misionDestino = dest;
        }
        j.misionEsBien = d['misionEsBien'] ?? true;
        j.misionBloques = d['misionBloques'] ?? 0;
        j.misionTermina = DateTime.fromMillisecondsSinceEpoch(mTermina);
      }

      // Trabajo en curso
      final tNombre = d['trabajoNombre'] as String?;
      final tTermina = d['trabajoTermina'] as int?;
      if (tNombre != null && tTermina != null) {
        j.trabajoActual = Trabajo(tNombre, d['trabajoDescripcion'] ?? '');
        j.trabajoEsBien = d['trabajoEsBien'] ?? true;
        j.trabajoHoras = d['trabajoHoras'] ?? 0;
        j.trabajoPago = d['trabajoPago'] ?? 0;
        j.trabajoTermina = DateTime.fromMillisecondsSinceEpoch(tTermina);
      }

      // Avisos de fin de misión / trabajo (por si se reinstaló la app)
      j.reprogramarAvisos();

      // Arena (PvP)
      datosPvp.ultimoAtaqueMs = ((d['ultimoAtaquePvpMs'] ?? 0) as num).toInt();
      datosPvp.victorias = ((d['victoriasPvp'] ?? 0) as num).toInt();
      datosPvp.derrotas = ((d['derrotasPvp'] ?? 0) as num).toInt();
      datosPvp.rachaPvp = ((d['rachaPvp'] ?? 0) as num).toInt();
      datosPvp.mejorRachaPvp = ((d['mejorRachaPvp'] ?? 0) as num).toInt();
      datosPvp.pvpEmpates = ((d['pvpEmpates'] ?? 0) as num).toInt();
      datosPvp.pvpOroGanado = ((d['pvpOroGanado'] ?? 0) as num).toInt();
      datosPvp.pvpOroPerdido = ((d['pvpOroPerdido'] ?? 0) as num).toInt();
      datosPvp.pvpDano = ((d['pvpDano'] ?? 0) as num).toInt();
      datosPvp.pveVictorias = ((d['pveVictorias'] ?? 0) as num).toInt();
      datosPvp.pveEmpates = ((d['pveEmpates'] ?? 0) as num).toInt();
      datosPvp.pveDerrotas = ((d['pveDerrotas'] ?? 0) as num).toInt();
      datosPvp.pveOroGanado = ((d['pveOroGanado'] ?? 0) as num).toInt();
      datosPvp.pveDano = ((d['pveDano'] ?? 0) as num).toInt();

      // Historial de combates (si alguno está dañado, se salta)
      List<RegistroCombate> leerHistorial(dynamic lista) {
        final r = <RegistroCombate>[];
        if (lista is List) {
          for (final e in lista) {
            try {
              r.add(RegistroCombate.fromMap(Map<String, dynamic>.from(e as Map)));
            } catch (_) {}
          }
        }
        return r;
      }

      j.historialPvE
        ..clear()
        ..addAll(leerHistorial(d['historialPvE']));
      datosPvp.historial
        ..clear()
        ..addAll(leerHistorial(d['historialArena']));
      datosPvp.defensas
        ..clear()
        ..addAll(leerHistorial(d['historialDefensas']));
      datosPvp.rivalesAtacados.clear();
      final riv = Map<String, dynamic>.from(d['rivalesAtacados'] ?? {});
      riv.forEach((k, v) => datosPvp.rivalesAtacados[k] = (v as num).toInt());

      // Estadísticas y logros (las condecoraciones especiales se leen de
      // "medallas/{uid}", que el jugador no puede modificar)
      j.diarias.cargar(d['diarias']);
      j.bestiario.cargar(d['bestiario']);
      j.bestiario.migrarSiHaceFalta();
      j.logros.cargarDeMapa(d['logros'],
          especialesNube: await cargarEspecialesDe(_uid!));
    } finally {
      _cargando = false;
    }
  }
}