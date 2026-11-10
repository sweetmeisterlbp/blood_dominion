import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'batalla.dart';
import 'boton_oscuro.dart';
import 'logros.dart';
import 'main.dart';
import 'diarias.dart';
import 'social.dart';
import 'nube.dart';

// ====================== ARENA (PvP) ======================
// Cómo funciona:
//  - Cada jugador publica un PERFIL (collection "perfiles") con sus atributos
//    y equipo. Lo actualiza Nube junto con cada guardado.
//  - Al atacar, tu celular simula la pelea contra el perfil del rival.
//  - Si ganas, te llevas el 10% de su oro. Si pierdes, pierdes el 10% del tuyo.
//  - El ataque queda en la bandeja del rival ("perfiles/{uid}/ataques"); él
//    descuenta el oro la próxima vez que abra el juego o la Arena.
//  - Tras ser atacado, el rival queda protegido 1 hora.
//  - Al terminar el combate se abre la pantalla de batalla (batalla.dart):
//    video de entrada + resultado animado.
//
// LIMITACIÓN: la pelea se calcula en el celular del atacante, así que un
// jugador con conocimientos podría hacer trampa. Para evitarlo hay que mover
// el combate a Cloud Functions (plan Blaze). La estructura ya está pensada
// para que ese cambio sea sencillo.

// Todos pueden pelear contra todos, sin importar el nivel.
// Cuántos rivales se muestran a la vez (si hay menos jugadores, salen todos).
const int rivalesPvpPorBusqueda = 6;
// Máximo de perfiles que se leen de Firebase en cada búsqueda.
const int maxPerfilesConsulta = 60;
// Si pierdes un combate de la Arena, pierdes este porcentaje de TU oro.
const double porcentajePerdidaOroPvp = 0.10;

// ---------- Datos PvP del jugador (se guardan con Nube) ----------

class DatosPvp {
  int ultimoAtaqueMs = 0; // cuándo atacaste por última vez
  final Map<String, int> rivalesAtacados = {}; // uid del rival -> cuándo
  int victorias = 0;
  int derrotas = 0;
  int rachaPvp = 0; // victorias seguidas en este momento
  int mejorRachaPvp = 0; // tu mejor racha de victorias
  // Estadísticas para el ranking (suman durante toda la vida del personaje).
  // Arena (PvP): las victorias y derrotas ya están arriba.
  int pvpEmpates = 0;
  int pvpOroGanado = 0; // oro robado a otros jugadores
  int pvpOroPerdido = 0; // oro perdido al perder o al ser robado
  int pvpDano = 0; // daño infligido a otros jugadores
  // Cripta y Ciudadela (PvE)
  int pveVictorias = 0;
  int pveEmpates = 0;
  int pveDerrotas = 0;
  int pveOroGanado = 0;
  int pveDano = 0;
  // Últimos combates de la Arena (el más nuevo primero). Se guardan con Nube.
  final List<RegistroCombate> historial = [];
  int versionHistorial = 0; // sube con cada combate: Nube sabe cuándo guardar
  // Ataques que otros jugadores te hicieron (el más nuevo primero). Se guardan.
  final List<RegistroCombate> defensas = [];
  int versionDefensas = 0;
  final List<String> avisos = []; // ataques que recibiste (no se guardan)
  ResultadoPvp? ultimo; // último combate (no se guarda)
}

DatosPvp datosPvp = DatosPvp();

// ---------- Perfil público de otro jugador ----------

class PerfilRival {
  final String uid;
  final String nombre;
  final int nivel;
  final Raza raza;
  final int oro;
  final int protegidoHasta;
  final int victorias;
  final int derrotas;
  final int alineamiento; // puntos de bien (+) o mal (-)
  final int poder, vigor, agilidad, maestria, guardia, aguante;
  final int habArmadura, habUnaMano, habDosManos;
  // Atributos de arriba = SOLO los entrenados (visibles para todos).
  // [bonos] = lo que suma su equipo: se usa en la pelea pero no se muestra.
  final Map<String, int> bonos;
  final String? arma, escudo, armadura;
  final int armaAfilado; // afilados del arma (0 a 3)
  // Estadísticas y logros publicados por el jugador (puede ser null)
  final Map<String, dynamic>? perfilLogros;

  const PerfilRival({
    required this.uid,
    required this.nombre,
    required this.nivel,
    required this.raza,
    required this.oro,
    required this.protegidoHasta,
    required this.victorias,
    required this.derrotas,
    this.alineamiento = 0,
    required this.poder,
    required this.vigor,
    required this.agilidad,
    required this.maestria,
    required this.guardia,
    required this.aguante,
    required this.habArmadura,
    required this.habUnaMano,
    required this.habDosManos,
    required this.bonos,
    this.arma,
    this.armaAfilado = 0,
    this.escudo,
    this.armadura,
    this.perfilLogros,
  });

  static int _n(dynamic v) => (v as num?)?.toInt() ?? 0;

  factory PerfilRival.desdeMapa(String uid, Map<String, dynamic> d) {
    final r = max(0, min(_n(d['raza']), Raza.values.length - 1));
    final bonos = <String, int>{};
    final b = d['bonos'];
    if (b is Map) {
      b.forEach((k, v) => bonos[k.toString()] = _n(v));
    }
    return PerfilRival(
      uid: uid,
      nombre: (d['nombre'] ?? 'Aventurero') as String,
      nivel: max(1, _n(d['nivel'])),
      raza: Raza.values[r],
      oro: _n(d['oro']),
      protegidoHasta: _n(d['protegidoHasta']),
      victorias: _n(d['victorias']),
      derrotas: _n(d['derrotas']),
      alineamiento: _n(d['alineamiento']),
      poder: _n(d['poder']),
      vigor: _n(d['vigor']),
      agilidad: _n(d['agilidad']),
      maestria: _n(d['maestria']),
      guardia: _n(d['guardia']),
      aguante: _n(d['aguante']),
      habArmadura: _n(d['habArmadura']),
      habUnaMano: _n(d['habUnaMano']),
      habDosManos: _n(d['habDosManos']),
      bonos: bonos,
      arma: d['arma'] as String?,
      armaAfilado: max(0, min(_n(d['armaAfilado']), 3)),
      escudo: d['escudo'] as String?,
      armadura: d['armadura'] as String?,
      perfilLogros: d['perfilLogros'] is Map
          ? Map<String, dynamic>.from(d['perfilLogros'] as Map)
          : null,
    );
  }

  static Objeto? _objeto(String? nombre, [int afilado = 0]) {
    if (nombre == null) return null;
    for (final o in catalogo) {
      if (o.nombre == nombre) return afilado > 0 ? o.conAfilado(afilado) : o;
    }
    return null;
  }

  // Atributo entrenado + lo que da su equipo (nunca menos de 0)
  int _t(String clave, int base) => max(0, base + (bonos[clave] ?? 0));

  Combatiente get comoCombatiente => Combatiente(
    nombre: nombre,
    nivel: nivel,
    esJugador: true,
    poder: _t('Poder', poder),
    vigor: _t('Vigor', vigor),
    agilidad: _t('Agilidad', agilidad),
    maestria: _t('Maestría de combate', maestria),
    guardia: _t('Guardia', guardia),
    aguante: _t('Aguante', aguante),
    habArmadura: habArmadura,
    habUnaMano: habUnaMano,
    habDosManos: habDosManos,
    arma: _objeto(arma, armaAfilado),
    escudo: _objeto(escudo),
    armadura: _objeto(armadura),
    pasivas: {raza.pasiva},
  );

  // Oro que te llevarías si ganas
  int get oroRobable => (oro * porcentajeRoboOro).floor();
}

// ---------- Resultado de un combate PvP ----------

class ResultadoPvp {
  final String rival;
  final bool gano;
  final bool perdio;
  final int oroGanado; // lo que ganas tú (con el bono de Ambición)
  final int oroRobado; // lo que pierde el rival (sin bono)
  final int cambioFama;
  final int rondas;
  final int danoHecho;
  final int danoRecibido;
  final int vidaRestante;
  final List<String> log;
  final String equipoRival; // se revela al terminar la pelea
  final FichaCombate fichaYo; // tu tarjeta antes de pelear (para el historial)
  final FichaCombate fichaRival;
  String texto;

  ResultadoPvp({
    required this.rival,
    required this.gano,
    required this.perdio,
    required this.oroGanado,
    required this.oroRobado,
    required this.cambioFama,
    required this.rondas,
    required this.danoHecho,
    required this.danoRecibido,
    required this.vidaRestante,
    required this.log,
    required this.equipoRival,
    required this.fichaYo,
    required this.fichaRival,
    required this.texto,
  });
}

// Resultado de buscar rivales: los que se muestran y cuántos hay en total
class BusquedaPvp {
  final List<PerfilRival> lista;
  final int total;
  const BusquedaPvp(this.lista, this.total);
}

// ---------- Lógica de la Arena ----------

class Arena {
  // Segundos que faltan para poder atacar a [uidRival] (0 = ya puedes)
  static int esperaSegundos(String uidRival) {
    final ahora = DateTime.now().millisecondsSinceEpoch;
    final general = (juego.premium
        ? esperaEntreAtaquesPremium
        : esperaEntreAtaques)
        .inMilliseconds;
    final faltaGeneral = datosPvp.ultimoAtaqueMs + general - ahora;
    final faltaRival = (datosPvp.rivalesAtacados[uidRival] ?? 0) +
        esperaMismoRival.inMilliseconds -
        ahora;
    final falta = max(faltaGeneral, faltaRival);
    return falta <= 0 ? 0 : (falta / 1000).ceil();
  }

  // Segundos hasta tu próximo ataque a cualquier rival (solo la espera general)
  static int esperaGeneralSegundos() {
    final ahora = DateTime.now().millisecondsSinceEpoch;
    final general = (juego.premium
        ? esperaEntreAtaquesPremium
        : esperaEntreAtaques)
        .inMilliseconds;
    final falta = datosPvp.ultimoAtaqueMs + general - ahora;
    return falta <= 0 ? 0 : (falta / 1000).ceil();
  }

  // Busca rivales entre TODOS los jugadores (sin límite de nivel).
  // Si hay [rivalesPvpPorBusqueda] o menos, salen todos; si hay más, al azar.
  static Future<BusquedaPvp> buscarRivales() async {
    final miUid = FirebaseAuth.instance.currentUser?.uid;
    if (miUid == null) return const BusquedaPvp([], 0);
    // Tras un reinicio de cuentas, los perfiles de antes no aparecen
    Query<Map<String, dynamic>> consulta =
    FirebaseFirestore.instance.collection('perfiles');
    if (Nube.versionReinicio > 0) {
      consulta = consulta.where('versionReinicio',
          isGreaterThanOrEqualTo: Nube.versionReinicio);
    }
    final snap = await consulta
        .limit(maxPerfilesConsulta)
        .get()
        .timeout(const Duration(seconds: 15));
    final todos = snap.docs
        .map((d) => PerfilRival.desdeMapa(d.id, d.data()))
        .where((p) => p.uid != miUid)
        .toList();
    final total = todos.length;
    todos.shuffle(azar);
    final lista = todos.take(rivalesPvpPorBusqueda).toList()
      ..sort((a, b) => a.nivel.compareTo(b.nivel));
    return BusquedaPvp(lista, total);
  }

  // Simula la pelea SIN cambiar nada del juego todavía
  static ResultadoPvp simular(PerfilRival r) {
    final fichaYo =
    FichaCombate.de(juego.comoCombatiente, perfil: juego.raza.nombre);
    final res = simularCombate(juego.comoCombatiente, r.comoCombatiente,
        vidaA: juego.vida);
    final gano = res.vidaA > 0 && res.vidaB <= 0;
    final perdio = res.vidaA <= 0;
    final c = r.comoCombatiente;
    final equipo = 'Equipo de ${r.nombre}: arma ${c.arma?.nombre ?? 'ninguna'}${(c.arma?.afilado ?? 0) > 0 ? ' (Filo +${c.arma!.afilado})' : ''}, '
        'escudo ${c.escudo?.nombre ?? 'ninguno'}, '
        'armadura ${c.armadura?.nombre ?? 'ninguna'}.';
    int oroGanado = 0;
    int oroRobado = 0;
    int fama = 0;
    String texto;
    if (perdio) {
      // Si TÚ llegas a 0 de vida, pierdes: nunca cuenta como victoria.
      fama = cambioFamaCombate(juego.nivel, r.nivel, false);
      final perdidaOro = (juego.oro * porcentajePerdidaOroPvp).floor();
      oroGanado = -perdidaOro; // negativo: es oro que pierdes
      final oroTxt = perdidaOro > 0
          ? 'Perdiste $perdidaOro de oro.'
          : 'No perdiste oro.';
      final famaTxt = fama < 0
          ? 'Perdiste ${-fama} de fama.'
          : 'No perdiste fama: el rival era mucho más fuerte que tú.';
      texto = '${r.nombre} te derrotó en ${res.rondas} rondas. '
          'Hiciste ${res.danoA} de daño y recibiste ${res.danoB}. '
          '$oroTxt $famaTxt Necesitas descansar para recuperar la vida.';
    } else if (gano) {
      oroRobado = r.oroRobable;
      oroGanado = juego.conBonoAmbicion(oroRobado);
      fama = juego.conBonoAmbicion(cambioFamaCombate(juego.nivel, r.nivel, true));
      final famaTxt = fama > 0
          ? 'Ganaste $fama de fama.'
          : fama < 0
          ? 'Perdiste ${-fama} de fama por vencer a un rival mucho más débil.'
          : 'No ganaste fama: el rival era demasiado débil.';
      texto = 'Venciste a ${r.nombre} en ${res.rondas} rondas. '
          'Hiciste ${res.danoA} de daño y recibiste ${res.danoB}. '
          'Le robaste $oroGanado de oro. $famaTxt';
    } else {
      texto = 'El combate contra ${r.nombre} se alargó demasiado y terminó en '
          'empate. No ganaste ni perdiste nada.';
    }
    return ResultadoPvp(
      rival: r.nombre,
      gano: gano,
      perdio: perdio,
      oroGanado: oroGanado,
      oroRobado: oroRobado,
      cambioFama: fama,
      rondas: res.rondas,
      danoHecho: res.danoA,
      danoRecibido: res.danoB,
      vidaRestante: res.vidaA,
      log: res.log,
      equipoRival: equipo,
      fichaYo: fichaYo,
      fichaRival: FichaCombate.de(c, perfil: r.raza.nombre),
      texto: texto,
    );
  }

  // Aplica el resultado a tu personaje
  static void aplicar(PerfilRival r, ResultadoPvp res) {
    final j = juego;
    final nivelAntes = j.nivel;
    j.fijarVida(res.vidaRestante);
    datosPvp.pvpDano += res.danoHecho;
    j.diarias.sumar('arenaAtk');
    if (res.gano) {
      j.diarias.sumar('arenaWin');
      Torneo.sumar(Torneo.puntosPorVictoria(r.nivel, nivelAntes));
      j.oro += res.oroGanado;
      datosPvp.pvpOroGanado += res.oroGanado;
      j.xp = max(0, j.xp + res.cambioFama);
      datosPvp.victorias++;
      datosPvp.rachaPvp++;
      datosPvp.mejorRachaPvp = max(datosPvp.mejorRachaPvp, datosPvp.rachaPvp);
      j.revisarNivel();
    } else if (res.perdio) {
      final oroAntes = j.oro;
      j.oro = max(0, j.oro + res.oroGanado); // oroGanado es negativo aquí
      datosPvp.pvpOroPerdido += oroAntes - j.oro;
      j.xp = max(0, j.xp + res.cambioFama);
      datosPvp.derrotas++;
      datosPvp.rachaPvp = 0;
    } else {
      datosPvp.rachaPvp = 0; // empate
      datosPvp.pvpEmpates++;
    }
    final ahora = DateTime.now().millisecondsSinceEpoch;
    datosPvp.ultimoAtaqueMs = ahora;
    datosPvp.rivalesAtacados[r.uid] = ahora;
    j.logros.registrarPvp(
        gano: res.gano, derrota: res.perdio, oroRobado: res.oroRobado);
    j.revisarLogros();
    if (j.nivel > nivelAntes) res.texto += ' ¡Subiste al nivel ${j.nivel}!';
    // Historial de la Arena (los últimos [maxHistorialCombates])
    datosPvp.historial.insert(
      0,
      RegistroCombate(
        fecha: DateTime.now(),
        lugar: 'Arena',
        resultado: res.gano ? 'victoria' : (res.perdio ? 'derrota' : 'empate'),
        yo: res.fichaYo,
        rival: res.fichaRival,
        rondas: res.rondas,
        danoHecho: res.danoHecho,
        danoRecibido: res.danoRecibido,
        oro: res.oroGanado,
        fama: res.cambioFama,
        puntosInclinacion: 0,
        inclinacionBien: true,
        subioNivel: j.nivel > nivelAntes,
        log: List<String>.from(res.log),
      ),
    );
    if (datosPvp.historial.length > maxHistorialCombates) {
      datosPvp.historial
          .removeRange(maxHistorialCombates, datosPvp.historial.length);
    }
    datosPvp.versionHistorial++;
    datosPvp.ultimo = res;
    j.avisarCambio();
  }

  // Ataca a un rival. Devuelve un mensaje solo si no se pudo atacar.
  static Future<String?> atacar(PerfilRival r) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'No hay sesión iniciada.';
    if (r.uid == user.uid) return 'No puedes atacarte a ti mismo.';
    if (juego.trabajando) {
      return 'Estás trabajando en la taberna. Termina o abandona el trabajo para pelear.';
    }
    if (juego.vida < juego.vidaMaxima * vidaMinimaParaPelear) {
      return 'Estás demasiado herido para pelear. Descansa un poco.';
    }
    final espera = esperaSegundos(r.uid);
    if (espera > 0) {
      return 'Aún no puedes atacar a ${r.nombre}. Espera ${formatoTiempo(espera)}.';
    }
    try {
      final ref = FirebaseFirestore.instance.collection('perfiles').doc(r.uid);
      // Se vuelve a leer el perfil para usar su oro y su protección actuales
      final snap = await ref.get().timeout(const Duration(seconds: 15));
      if (!snap.exists) return 'Ese jugador ya no está disponible.';
      final fresco = PerfilRival.desdeMapa(r.uid, snap.data()!);
      final ahora = DateTime.now().millisecondsSinceEpoch;
      if (fresco.protegidoHasta > ahora) {
        return '${fresco.nombre} está protegido. Prueba con otro rival.';
      }

      final res = simular(fresco);

      // El combate visto desde el lado del rival (para su pestaña "Defensas").
      // El oro realmente perdido lo completa él al procesar el ataque.
      final registroDefensa = RegistroCombate(
        fecha: DateTime.now(),
        lugar: 'Defensa',
        resultado: res.perdio ? 'victoria' : (res.gano ? 'derrota' : 'empate'),
        yo: res.fichaRival,
        rival: res.fichaYo,
        rondas: res.rondas,
        danoHecho: res.danoRecibido,
        danoRecibido: res.danoHecho,
        oro: 0,
        fama: 0,
        puntosInclinacion: 0,
        inclinacionBien: true,
        subioNivel: false,
        log: List<String>.from(res.log),
      );

      // Primero se avisa al rival: si esto falla, el combate NO cuenta.
      await ref.collection('ataques').add({
        'registro': registroDefensa.toMap(),
        'atacanteUid': user.uid,
        'atacanteNombre': juego.nombre,
        'atacanteNivel': juego.nivel,
        'oroRobado': res.oroRobado,
        'ganoAtacante': res.gano,
        'ms': ahora,
      }).timeout(const Duration(seconds: 15));

      aplicar(fresco, res);

      // Protección del rival durante una hora (si falla, no pasa nada grave)
      try {
        await ref.update({
          'protegidoHasta': ahora + proteccionTrasSerAtacado.inMilliseconds,
        }).timeout(const Duration(seconds: 15));
      } catch (e) {
        debugPrint('Arena: no se pudo proteger al rival: $e');
      }
      return null;
    } catch (e) {
      debugPrint('Arena: error al atacar: $e');
      return 'No se pudo atacar. Revisa tu conexión e inténtalo de nuevo.';
    }
  }
}

String formatoTiempo(int segundos) {
  final h = segundos ~/ 3600;
  final m = (segundos % 3600) ~/ 60;
  final s = segundos % 60;
  if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

// ====================== PANTALLA DE LA ARENA ======================

class PantallaArena extends StatefulWidget {
  const PantallaArena({super.key});

  @override
  State<PantallaArena> createState() => _PantallaArenaState();
}

class _PantallaArenaState extends State<PantallaArena> {
  Timer? _reloj;
  List<PerfilRival> _rivales = [];
  int _total = 0; // jugadores disponibles en total
  bool _buscando = false;
  bool _atacando = false;
  String? _mensajeBusqueda;

  // Actualizar solo cuesta oro si hay más jugadores de los que se muestran
  bool get _actualizarCuesta =>
      _rivales.isNotEmpty && _total > rivalesPvpPorBusqueda;

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    // Al entrar: descuenta el oro de ataques recibidos y muestra los rivales
    Nube.procesarAtaques().then((_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _buscar(gratis: true);
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _buscar({bool gratis = false}) async {
    final cobra = !gratis && _actualizarCuesta;
    if (cobra && juego.oro < costoActualizarBusqueda) {
      _aviso('Necesitas $costoActualizarBusqueda de oro para actualizar la búsqueda');
      return;
    }
    setState(() {
      _buscando = true;
      _mensajeBusqueda = null;
    });
    try {
      final b = await Arena.buscarRivales();
      if (!mounted) return;
      if (cobra) {
        juego.oro -= costoActualizarBusqueda;
        juego.avisarCambio();
      }
      setState(() {
        _rivales = b.lista;
        _total = b.total;
        _mensajeBusqueda = b.lista.isEmpty
            ? 'Todavía no hay otros jugadores en la Arena. '
            'Cuando alguien más entre al juego, aparecerá aquí.'
            : null;
      });
    } catch (e) {
      debugPrint('Arena: error al buscar: $e');
      if (mounted) {
        setState(() => _mensajeBusqueda =
        'No se pudo buscar rivales. Revisa tu conexión y las reglas de Firestore.');
      }
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  Future<void> _atacar(PerfilRival r) async {
    setState(() => _atacando = true);
    final msg = await Arena.atacar(r);
    if (!mounted) return;
    setState(() => _atacando = false);
    if (msg != null) {
      _aviso(msg);
      return;
    }
    // El combate recién terminado quedó primero en el historial:
    // se abre el video de entrada y el resultado animado.
    if (datosPvp.historial.isNotEmpty) {
      await mostrarBatalla(context, datosPvp.historial.first);
      if (!mounted) return;
    }
    // Después de pelear la lista se renueva gratis (el rival queda protegido)
    await _buscar(gratis: true);
  }

  Widget _tarjetaEstado() {
    final vida = juego.vida;
    final maxima = juego.vidaMaxima;
    final espera = Arena.esperaGeneralSegundos();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Arena',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'Pelea contra cualquier jugador, sin importar su nivel. Ves sus '
                  'atributos, pero no su equipo: lo descubres durante la pelea. '
                  'Si ganas, te llevas el 10% de su oro. Si pierdes, pierdes el 10% de tu oro. '
                  'Tras ser atacado, un jugador queda protegido 1 hora.',
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Text('Victorias: ${datosPvp.victorias}   |   Derrotas: ${datosPvp.derrotas}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Racha: ${datosPvp.rachaPvp}   |   Mejor racha: ${datosPvp.mejorRachaPvp}',
                style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Text('Vida: $vida / $maxima', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: vida / maxima,
                minHeight: 12,
                color: Colors.green,
                backgroundColor: const Color(0xFF3A2A30),
              ),
            ),
            if (espera > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                    'Próximo ataque disponible en ${formatoTiempo(espera)}',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.amberAccent)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaAvisos() {
    return Card(
      color: const Color(0xFF3A1416),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Te atacaron mientras no estabas',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            for (final a in datosPvp.avisos)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(a, style: const TextStyle(fontSize: 12)),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => datosPvp.avisos.clear()),
                child: const Text('Entendido'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Un rival: se ven sus atributos y habilidades, NO su equipo
  Widget _tarjetaRival(PerfilRival r) {
    final ahora = DateTime.now().millisecondsSinceEpoch;
    final proteccion =
    r.protegidoHasta > ahora ? ((r.protegidoHasta - ahora) / 1000).ceil() : 0;
    final espera = Arena.esperaSegundos(r.uid);
    final puedeVida = juego.vida >= juego.vidaMaxima * vidaMinimaParaPelear;
    final puede = !_atacando &&
        proteccion == 0 &&
        espera == 0 &&
        puedeVida &&
        !juego.trabajando;
    const chico = TextStyle(fontSize: 12);
    final String textoBoton = proteccion > 0
        ? 'Protegido ${formatoTiempo(proteccion)}'
        : espera > 0
        ? 'Espera ${formatoTiempo(espera)}'
        : 'Atacar';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  // Tocar el nombre abre la ficha del jugador.
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => mostrarPerfilJugador(context, r.uid),
                    child:
                    NombreConTitulo(r.nombre, r.alineamiento, tamano: 15),
                  ),
                ),
                Text('  -  ${r.raza.nombre}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Nivel ${r.nivel}  |  Pasiva: ${r.raza.pasiva.nombre}',
                style: chico),
            Text(
                'Poder ${r.poder}  |  Vigor ${r.vigor}  |  Agilidad ${r.agilidad}  |  Maestría ${r.maestria}  |  Guardia ${r.guardia}  |  Aguante ${r.aguante}',
                style: chico),
            Text(
                'Habilidad: armadura/escudo ${r.habArmadura}  |  una mano ${r.habUnaMano}  |  dos manos ${r.habDosManos}',
                style: chico),
            const Text('Equipo: oculto hasta el combate',
                style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.amberAccent)),
            Text('Récord: ${r.victorias} victorias, ${r.derrotas} derrotas',
                style: chico),
            const SizedBox(height: 6),
            // El botín y la fama en juego se revelan solo después de pelear.
            const Text('Botín y fama: se revelan al pelear',
                style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.amberAccent)),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.emoji_events, size: 18),
                label: const Text('Ver perfil y logros'),
                onPressed: () => abrirPerfilPublico(context, r.uid, {
                  'nombre': r.nombre,
                  'nivel': r.nivel,
                  'raza': r.raza.index,
                  'perfilLogros': r.perfilLogros,
                }),
              ),
            ),
            const SizedBox(height: 4),
            BotonOscuro(
              texto: textoBoton,
              alto: 44,
              color: ColorBoton.rojo,
              onPressed: puede ? () => _atacar(r) : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hijos = <Widget>[_tarjetaEstado()];

    if (datosPvp.avisos.isNotEmpty) hijos.add(_tarjetaAvisos());

    hijos.add(Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rivales',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(
            _total > rivalesPvpPorBusqueda
                ? 'Hay $_total jugadores. Se muestran $rivalesPvpPorBusqueda al azar; '
                'actualizar la lista cuesta $costoActualizarBusqueda de oro.'
                : 'Estos son todos los jugadores disponibles.',
            style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
          ),
        ],
      ),
    ));

    hijos.add(Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: _buscando
          ? const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(),
        ),
      )
          : BotonOscuro(
        texto: _actualizarCuesta
            ? 'Actualizar lista ($costoActualizarBusqueda oro)'
            : 'Actualizar lista',
        alto: 48,
        color: ColorBoton.morado,
        onPressed: _atacando ? null : () => _buscar(),
      ),
    ));

    if (_mensajeBusqueda != null) {
      hijos.add(Padding(
        padding: const EdgeInsets.all(8),
        child: Text(_mensajeBusqueda!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ));
    }

    for (final r in _rivales) {
      hijos.add(_tarjetaRival(r));
    }
    hijos.add(const SizedBox(height: 16));

    return ListView(padding: const EdgeInsets.all(12), children: hijos);
  }
}