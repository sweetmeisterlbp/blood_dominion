import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'main.dart';
import 'social.dart';

// ====================== MÁS FORMAS DE GANAR ORO ======================
// 1. Misiones diarias: 3 desafíos al día + un bono por completar los 3.
// 2. Torneo semanal de la Arena: premios para los 10 mejores de la semana.
// 3. Premio por defenderte: oro por cada ataque que rechazas (máx. por día).
// Todo el oro crece con tu nivel igual que las misiones (factorOroMision).

// ---------- Números para ajustar la economía ----------
const int oroBonoDiarias = 300; // oro base por completar las 3 diarias
const int oroPorDefensa = 40; // oro base por defender con éxito
const int maxDefensasPremiadasPorDia = 5;
const int puntosTorneoMinimosParaPremio = 3; // al menos una victoria

// Premios del torneo por puesto: (oro base, gemas)
class PremioTorneo {
  final int oro;
  final int gemas;
  const PremioTorneo(this.oro, this.gemas);
}

PremioTorneo? premioTorneoDe(int puesto) {
  if (puesto == 1) return const PremioTorneo(1500, 5);
  if (puesto == 2) return const PremioTorneo(1000, 3);
  if (puesto == 3) return const PremioTorneo(700, 2);
  if (puesto >= 4 && puesto <= 10) return const PremioTorneo(300, 0);
  return null;
}

// ---------- Definición de las misiones diarias ----------

class DefDiaria {
  final String clave; // qué acción cuenta (ver DatosDiarias.sumar)
  final String texto;
  final int meta;
  final int oro; // oro base, se multiplica por el factor de tu nivel
  const DefDiaria(this.clave, this.texto, this.meta, this.oro);
}

const List<DefDiaria> defsDiarias = [
  DefDiaria('pve', 'Gana 3 combates en la Cripta o la Ciudadela', 3, 100), // 0
  DefDiaria('pve', 'Gana 5 combates en la Cripta o la Ciudadela', 5, 140), // 1
  DefDiaria('mision', 'Completa 1 misión', 1, 100), // 2
  DefDiaria('taberna', 'Haz 1 trabajo en la taberna', 1, 100), // 3
  DefDiaria('entrenar', 'Entrena 2 atributos', 2, 100), // 4
  DefDiaria('arenaWin', 'Gana 1 combate en la Arena', 1, 120), // 5
  DefDiaria('arenaAtk', 'Ataca a 2 jugadores en la Arena', 2, 120), // 6
  DefDiaria('jefe', 'Vence a un jefe', 1, 150), // 7
];

// Un desafío de cada grupo, así siempre hay uno fácil y a tu alcance.
const List<List<int>> _gruposDiarias = [
  [0, 1],
  [2, 3, 4],
  [5, 6, 7],
];

IconData _iconoDiaria(String clave) {
  switch (clave) {
    case 'pve':
      return Icons.church;
    case 'mision':
      return Icons.map;
    case 'taberna':
      return Icons.local_bar;
    case 'entrenar':
      return Icons.fitness_center;
    case 'arenaWin':
    case 'arenaAtk':
      return Icons.emoji_events;
    case 'jefe':
      return Icons.whatshot;
    default:
      return Icons.flag;
  }
}

// ====================== DATOS (se guardan en la nube) ======================

class DatosDiarias {
  String dia = '';
  List<int> ids = [0, 2, 5];
  List<int> progreso = [0, 0, 0];
  List<bool> cobradas = [false, false, false];
  bool bonoCobrado = false;
  int defensasPremiadas = 0; // hoy
  String torneoCobrado = ''; // semana del torneo cuyo premio ya cobraste

  // Si cambió el día, arma las 3 misiones nuevas. No avisa a nadie: solo calcula.
  void revisar() {
    final hoy = RelojServidor.dia;
    if (dia == hoy) return;
    dia = hoy;
    // Misma semilla para todos: hoy todos tienen las mismas diarias.
    final semilla =
    hoy.codeUnits.fold<int>(7, (a, c) => (a * 31 + c) & 0x7fffffff);
    final r = Random(semilla);
    ids = [
      for (final g in _gruposDiarias)
            () {
          // El jefe solo cuenta si ya hay jefes para tu nivel (el primero es el 5).
          final posibles = g.where((i) => i != 7 || juego.nivel >= 5).toList();
          return posibles[r.nextInt(posibles.length)];
        }()
    ];
    progreso = [0, 0, 0];
    cobradas = [false, false, false];
    bonoCobrado = false;
    defensasPremiadas = 0;
  }

  int oroDe(int i) => (defsDiarias[ids[i]].oro * factorOroMision(juego.nivel)).round();
  int get oroBono => (oroBonoDiarias * factorOroMision(juego.nivel)).round();

  bool completa(int i) => progreso[i] >= defsDiarias[ids[i]].meta;
  bool get todasCobradas => cobradas.every((c) => c);

  // Hay algo para cobrar: se usa para el punto rojo de la pestaña Misiones.
  bool get hayParaCobrar {
    revisar();
    for (var i = 0; i < 3; i++) {
      if (completa(i) && !cobradas[i]) return true;
    }
    return todasCobradas && !bonoCobrado;
  }

  // Suma progreso a las misiones cuya acción coincide con [clave].
  void sumar(String clave, [int n = 1]) {
    revisar();
    var cambio = false;
    for (var i = 0; i < 3; i++) {
      final d = defsDiarias[ids[i]];
      if (d.clave == clave && progreso[i] < d.meta) {
        progreso[i] = min(d.meta, progreso[i] + n);
        cambio = true;
      }
    }
    if (cambio) juego.avisarCambio();
  }

  String? cobrar(int i) {
    revisar();
    if (!completa(i)) return 'Todavía no completaste ese desafío.';
    if (cobradas[i]) return 'Ya cobraste ese desafío.';
    final oro = oroDe(i);
    cobradas[i] = true;
    juego.oro += oro;
    juego.logros.sumarOro(oro);
    juego.revisarLogros();
    juego.avisarCambio();
    return 'Cobraste $oro de oro.';
  }

  String? cobrarBono() {
    revisar();
    if (!todasCobradas) return 'Cobra primero los 3 desafíos.';
    if (bonoCobrado) return 'Ya cobraste el bono de hoy.';
    final oro = oroBono;
    bonoCobrado = true;
    juego.oro += oro;
    juego.logros.sumarOro(oro);
    juego.revisarLogros();
    juego.avisarCambio();
    return '¡Bono por completar las 3! Cobraste $oro de oro.';
  }

  // Oro por rechazar un ataque. Devuelve 0 si ya alcanzaste el máximo de hoy.
  // Se llama al procesar los ataques recibidos (ver nube.dart).
  int premioDefensa() {
    revisar();
    if (defensasPremiadas >= maxDefensasPremiadasPorDia) return 0;
    defensasPremiadas++;
    final oro = (oroPorDefensa * factorOroMision(juego.nivel)).round();
    juego.oro += oro;
    juego.logros.sumarOro(oro);
    return oro;
  }

  Map<String, dynamic> aMapa() => {
    'dia': dia,
    'ids': ids,
    'progreso': progreso,
    'cobradas': cobradas,
    'bonoCobrado': bonoCobrado,
    'defensasPremiadas': defensasPremiadas,
    'torneoCobrado': torneoCobrado,
  };

  void cargar(dynamic m) {
    if (m is! Map) return;
    try {
      final i = (m['ids'] as List?)?.map((e) => (e as num).toInt()).toList();
      final p = (m['progreso'] as List?)?.map((e) => (e as num).toInt()).toList();
      final c = (m['cobradas'] as List?)?.map((e) => e == true).toList();
      if (i != null && i.length == 3 && i.every((e) => e >= 0 && e < defsDiarias.length)) {
        ids = i;
      }
      if (p != null && p.length == 3) progreso = p;
      if (c != null && c.length == 3) cobradas = c;
      dia = (m['dia'] ?? '') as String;
      bonoCobrado = m['bonoCobrado'] == true;
      defensasPremiadas = ((m['defensasPremiadas'] ?? 0) as num).toInt();
      torneoCobrado = (m['torneoCobrado'] ?? '') as String;
    } catch (_) {}
  }
}

// ====================== PANTALLA: DIARIAS ======================

class PantallaDiarias extends StatelessWidget {
  const PantallaDiarias({super.key});

  String _tiempoRestante() {
    final n = RelojServidor.ahora();
    final manana = DateTime(n.year, n.month, n.day).add(const Duration(days: 1));
    final d = manana.difference(n);
    return '${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}m';
  }

  void _msg(BuildContext context, String? t) {
    if (t == null) return;
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(content: Text(t)));
  }

  @override
  Widget build(BuildContext context) {
    final d = juego.diarias;
    d.revisar();
    return ListenableBuilder(
      listenable: juego,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                  'Desafíos de hoy · se renuevan en ${_tiempoRestante()}',
                  style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
            ),
            for (var i = 0; i < 3; i++) _tarjeta(context, d, i),
            Card(
              child: ListTile(
                leading: const Icon(Icons.stars, color: Color(0xFFFFD54A), size: 30),
                title: const Text('Bono por completar los 3',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${d.oroBono} de oro'),
                trailing: d.bonoCobrado
                    ? const Icon(Icons.check_circle, color: Colors.greenAccent)
                    : ElevatedButton(
                  onPressed: d.todasCobradas
                      ? () => _msg(context, d.cobrarBono())
                      : null,
                  child: const Text('Cobrar'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                  'Defender un ataque también da oro: '
                      '${d.defensasPremiadas}/$maxDefensasPremiadasPorDia premiadas hoy.',
                  style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ),
          ],
        );
      },
    );
  }

  Widget _tarjeta(BuildContext context, DatosDiarias d, int i) {
    final def = defsDiarias[d.ids[i]];
    final prog = d.progreso[i];
    final lista = d.completa(i);
    final cobrada = d.cobradas[i];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(_iconoDiaria(def.clave),
                size: 30, color: lista ? Colors.greenAccent : Colors.white70),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(def.texto,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: prog / def.meta,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 4),
                  Text('$prog / ${def.meta}  ·  ${d.oroDe(i)} de oro',
                      style: const TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            cobrada
                ? const Icon(Icons.check_circle, color: Colors.greenAccent)
                : ElevatedButton(
              onPressed: lista ? () => _msg(context, d.cobrar(i)) : null,
              child: const Text('Cobrar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ====================== TORNEO SEMANAL ======================
// Cada victoria en la Arena suma puntos a tu semana. Semana = lunes a domingo
// (hora del servidor). Al terminar, los 10 primeros cobran premio.

class Torneo {
  // Lunes de la semana actual (o de la que sea [t]), como texto: 2026-11-02.
  static DateTime _lunes([DateTime? t]) {
    final n = t ?? RelojServidor.ahora();
    final d = DateTime(n.year, n.month, n.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  static String _id(DateTime l) =>
      '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';

  static String get semanaActual => _id(_lunes());
  static String get semanaPasada =>
      _id(_lunes().subtract(const Duration(days: 7)));

  static Duration get restante {
    final fin = _lunes().add(const Duration(days: 7));
    return fin.difference(RelojServidor.ahora());
  }

  // Puntos por ganar en la Arena: más si el rival es de tu nivel o más fuerte.
  static int puntosPorVictoria(int nivelRival, int miNivel) {
    final dif = nivelRival - miNivel;
    if (dif >= 0) return 3;
    if (dif >= -3) return 2;
    return 1;
  }

  static CollectionReference<Map<String, dynamic>> _col(String semana) =>
      FirebaseFirestore.instance
          .collection('torneo')
          .doc(semana)
          .collection('jugadores');

  // Suma puntos a tu semana. Si falla (sin internet), no pasa nada grave.
  static Future<void> sumar(int puntos) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _col(semanaActual).doc(uid).set({
        'nombre': juego.nombre,
        'nivel': juego.nivel,
        'alin': juego.alineamiento,
        'puntos': FieldValue.increment(puntos),
        'victorias': FieldValue.increment(1),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('Torneo: no se pudo sumar: $e');
    }
  }
}

class _FilaTorneo {
  final String uid;
  final String nombre;
  final int nivel;
  final int alin;
  final int puntos;
  const _FilaTorneo(this.uid, this.nombre, this.nivel, this.alin, this.puntos);
}

class PantallaTorneo extends StatefulWidget {
  const PantallaTorneo({super.key});

  @override
  State<PantallaTorneo> createState() => _PantallaTorneoState();
}

class _PantallaTorneoState extends State<PantallaTorneo> {
  bool _cargando = true;
  bool _error = false;
  List<_FilaTorneo> _top = [];
  int _misPuntos = 0;
  int _miPuesto = 0; // 0 = todavía no sumaste
  int _puestoSemanaPasada = 0; // 0 = fuera del top 10
  bool _cobrando = false;

  String get _yo => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  List<_FilaTorneo> _filas(QuerySnapshot<Map<String, dynamic>> s) => s.docs
      .map((d) => _FilaTorneo(
      d.id,
      (d.data()['nombre'] ?? 'Jugador') as String,
      ((d.data()['nivel'] ?? 1) as num).toInt(),
      ((d.data()['alin'] ?? 0) as num).toInt(),
      ((d.data()['puntos'] ?? 0) as num).toInt()))
      .toList();

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = false;
    });
    try {
      const t = Duration(seconds: 15);
      final actual = await Torneo._col(Torneo.semanaActual)
          .orderBy('puntos', descending: true)
          .limit(20)
          .get()
          .timeout(t);
      final top = _filas(actual);

      // Mis puntos y mi puesto
      int mis = 0;
      for (final f in top) {
        if (f.uid == _yo) mis = f.puntos;
      }
      if (mis == 0 && _yo.isNotEmpty) {
        final d = await Torneo._col(Torneo.semanaActual).doc(_yo).get().timeout(t);
        mis = ((d.data()?['puntos'] ?? 0) as num).toInt();
      }
      int puesto = 0;
      if (mis > 0) {
        final arriba = await Torneo._col(Torneo.semanaActual)
            .where('puntos', isGreaterThan: mis)
            .count()
            .get()
            .timeout(t);
        puesto = (arriba.count ?? 0) + 1;
      }

      // ¿Quedé en el top 10 la semana pasada?
      int pasado = 0;
      final prev = await Torneo._col(Torneo.semanaPasada)
          .orderBy('puntos', descending: true)
          .limit(10)
          .get()
          .timeout(t);
      final filasPrev = _filas(prev);
      for (var i = 0; i < filasPrev.length; i++) {
        if (filasPrev[i].uid == _yo &&
            filasPrev[i].puntos >= puntosTorneoMinimosParaPremio) {
          pasado = i + 1;
        }
      }

      if (!mounted) return;
      setState(() {
        _top = top;
        _misPuntos = mis;
        _miPuesto = puesto;
        _puestoSemanaPasada = pasado;
        _cargando = false;
      });
    } catch (e) {
      debugPrint('Torneo: error al cargar: $e');
      if (mounted) {
        setState(() {
          _cargando = false;
          _error = true;
        });
      }
    }
  }

  void _cobrar() {
    if (_cobrando) return;
    final premio = premioTorneoDe(_puestoSemanaPasada);
    final d = juego.diarias;
    if (premio == null || d.torneoCobrado == Torneo.semanaPasada) return;
    setState(() => _cobrando = true);
    final f = factorOroMision(juego.nivel);
    final oro = (premio.oro * f).round();
    d.torneoCobrado = Torneo.semanaPasada;
    juego.oro += oro;
    juego.gemas += premio.gemas;
    juego.logros.sumarOro(oro);
    juego.revisarLogros();
    juego.avisarCambio();
    setState(() => _cobrando = false);
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
        content: Text(
            '¡Premio del torneo! Puesto $_puestoSemanaPasada: $oro de oro'
                '${premio.gemas > 0 ? ' y ${premio.gemas} esquirlas' : ''}.')));
  }

  @override
  Widget build(BuildContext context) {
    final r = Torneo.restante;
    final puedeCobrar = _puestoSemanaPasada > 0 &&
        premioTorneoDe(_puestoSemanaPasada) != null &&
        juego.diarias.torneoCobrado != Torneo.semanaPasada;
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Torneo semanal de la Arena',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                      'Termina en ${r.inDays}d ${r.inHours % 24}h ${(r.inMinutes % 60).toString().padLeft(2, '0')}m. '
                          'Cada victoria en la Arena suma puntos: 3 si el rival es de tu nivel o más, '
                          '2 si es hasta 3 niveles menor, 1 si es mucho menor.',
                      style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 8),
                  Text(
                      _miPuesto > 0
                          ? 'Tú: $_misPuntos puntos · puesto $_miPuesto'
                          : 'Tú: aún no sumas puntos. ¡Gana en la Arena!',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Color(0xFFFFD54A))),
                ],
              ),
            ),
          ),
          if (puedeCobrar)
            Card(
              color: const Color(0xFF2A4A1E),
              child: ListTile(
                leading: const Icon(Icons.emoji_events, color: Color(0xFFFFD54A)),
                title: Text('¡Quedaste en el puesto $_puestoSemanaPasada la semana pasada!'),
                subtitle: Text(() {
                  final p = premioTorneoDe(_puestoSemanaPasada)!;
                  final oro = (p.oro * factorOroMision(juego.nivel)).round();
                  return '$oro de oro${p.gemas > 0 ? ' y ${p.gemas} esquirlas' : ''}';
                }()),
                trailing: ElevatedButton(
                    onPressed: _cobrando ? null : _cobrar,
                    child: const Text('Cobrar')),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Premios (se multiplican por tu nivel)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  for (final e in const [
                    ['1.º', '1500 de oro base + 5 esquirlas'],
                    ['2.º', '1000 de oro base + 3 esquirlas'],
                    ['3.º', '700 de oro base + 2 esquirlas'],
                    ['4.º a 10.º', '300 de oro base'],
                  ])
                    Text('${e[0]}: ${e[1]}', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Clasificación de esta semana',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                    tooltip: 'Actualizar',
                    icon: const Icon(Icons.refresh),
                    onPressed: _cargando ? null : _cargar),
              ],
            ),
          ),
          if (_cargando)
            const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()))
          else if (_error)
            const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                    'No se pudo cargar el torneo. Revisa tu conexión y desliza hacia abajo para reintentar.',
                    textAlign: TextAlign.center))
          else if (_top.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Nadie ha sumado puntos esta semana. ¡Sé el primero!',
                      textAlign: TextAlign.center))
            else
              for (var i = 0; i < _top.length; i++)
                Card(
                  color: _top[i].uid == _yo ? const Color(0xFF3A1A24) : null,
                  child: ListTile(
                    dense: true,
                    leading: Text('${i + 1}',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: i < 3 ? const Color(0xFFFFD54A) : Colors.white70)),
                    title: NombreConTitulo(_top[i].nombre, _top[i].alin, tamano: 14),
                    subtitle: Text('Nivel ${_top[i].nivel}'),
                    trailing: Text('${_top[i].puntos} pts',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () => mostrarPerfilJugador(context, _top[i].uid),
                  ),
                ),
        ],
      ),
    );
  }
}