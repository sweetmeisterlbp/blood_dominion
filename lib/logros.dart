import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'main.dart';

// ====================== ESTADÍSTICAS Y LOGROS ======================
// Todo lo de estadísticas, logros, condecoraciones y perfil público vive aquí.
//
//  - Estadisticas: contadores (peleas, victorias, daño, oro, misiones...)
//  - todosLosLogros: la lista de logros. Para cambiar una meta, edita aquí.
//  - DatosLogros: lo que guarda cada jugador (estadísticas + logros ganados)
//  - SeccionLogrosPerfil: estadísticas + logros dentro del perfil
//  - PantallaPerfilPublico: lo que ven los demás jugadores
//
// Las condecoraciones especiales (Betatester, Fundador...) NO las escribe la
// app: se leen de la colección "medallas/{uid}" (campo "lista"), que solo tú
// puedes modificar desde la consola de Firebase.

// ---------- Contadores ----------

class Estadisticas {
  final Map<String, int> _m = {};

  int operator [](String k) => _m[k] ?? 0;
  void sumar(String k, [int n = 1]) => _m[k] = (_m[k] ?? 0) + n;
  void fijar(String k, [int v = 1]) => _m[k] = v;
  void maximo(String k, int v) {
    if (v > (_m[k] ?? 0)) _m[k] = v;
  }

  Map<String, int> toMap() => Map<String, int>.from(_m);

  void cargar(dynamic mapa) {
    _m.clear();
    if (mapa is Map) {
      mapa.forEach((k, v) => _m[k.toString()] = (v as num).toInt());
    }
  }
}

// ---------- Definición de logros ----------

const List<Color> coloresNivel = [
  Color(0xFFCD7F32), // bronce
  Color(0xFFC0C0C0), // plata
  Color(0xFFFFD54F), // oro
  Color(0xFF80DEEA), // diamante
  Color(0xFFCE93D8), // leyenda
];
const List<String> nombresNivel = [
  'Bronce',
  'Plata',
  'Oro',
  'Diamante',
  'Leyenda'
];

// Oro que se cobra al ganar cada nivel de un logro (Bronce...Leyenda).
// Los logros de un solo nivel pagan [oroLogroUnico]. Para cambiar premios, edita aquí.
const List<int> oroPorNivel = [200, 600, 2000, 6000, 20000];
const int oroLogroUnico = 400;

class Logro {
  final String id;
  final String nombre;
  // En la descripción, "%" se reemplaza por la meta del siguiente nivel.
  final String descripcion;
  final String stat; // contador con el que se mide
  final List<int> metas; // una meta = logro único; varias = con niveles
  final IconData icono;
  final bool secreto;
  const Logro(this.id, this.nombre, this.descripcion, this.stat, this.metas,
      this.icono,
      {this.secreto = false});

  bool get unico => metas.length == 1;

  // Oro que da haber alcanzado el nivel [nivel] (1 = Bronce...)
  int oroDeNivel(int nivel) =>
      unico ? oroLogroUnico : oroPorNivel[min(nivel, oroPorNivel.length) - 1];

  // Nivel alcanzado (0 = ninguno) con ese valor del contador
  int nivelCon(int valor) => metas.where((m) => valor >= m).length;

  String textoMeta(int nivelActual) {
    final i = min(nivelActual, metas.length - 1);
    return descripcion.replaceAll('%', fmt(metas[i]));
  }
}

const List<Logro> todosLosLogros = [
  // ---- Combate ----
  Logro('primera_sangre', 'Primera sangre', 'Gana tu primera pelea',
      'victorias', [1], Icons.bloodtype),
  Logro('guerrero', 'Guerrero', 'Gana % peleas', 'victorias',
      [10, 50, 250, 1000], Icons.military_tech),
  Logro('imparable', 'Imparable', 'Gana % peleas seguidas', 'mejorRacha',
      [3, 7, 15, 30], Icons.local_fire_department),
  Logro('castigador', 'Castigador', 'Haz % de daño en total', 'danoHecho',
      [1000, 10000, 100000, 1000000], Icons.gavel),
  Logro('golpe_devastador', 'Golpe devastador',
      'Asesta un golpe de % de daño o más', 'golpeMax', [50, 150, 400, 1000],
      Icons.flash_on),
  Logro('critico_mortal', 'Crítico mortal', 'Asesta % golpes críticos',
      'criticos', [25, 100, 500, 2000], Icons.gps_fixed),
  Logro('cazador_gigantes', 'Cazador de gigantes',
      'Vence a alguien % niveles por encima del tuyo', 'mayorDif',
      [3, 5, 10, 20], Icons.landscape),
  Logro('superviviente', 'Superviviente',
      'Gana una pelea con menos del 10 por ciento de vida', 'supervivientes', [1],
      Icons.healing),
  // ---- Cripta y Ciudadela ----
  Logro('exterminador', 'Exterminador de no muertos',
      'Vence % enemigos en la Cripta', 'vencidosCripta',
      [25, 100, 500, 2000], Icons.dark_mode),
  Logro('profanador', 'Profanador', 'Vence % enemigos en la Ciudadela',
      'vencidosCiudadela', [25, 100, 500, 2000], Icons.brightness_high),
  Logro('cazador_leyendas', 'Cazador de leyendas',
      'Vence a % perfiles raros distintos (Fantasma, Señor de la guerra...)',
      'raros', [1, 2, 3, 5], Icons.auto_awesome),
  Logro('rey_hordas', 'Rey de las hordas',
      'Vence al Rey de las hordas oscuras', 'reyHordas', [1],
      Icons.workspace_premium),
  Logro('avatar_caido', 'Avatar caído', 'Vence al Avatar de la Luz',
      'avatarLuz', [1], Icons.light_mode),
  // ---- Arena (PvP) ----
  Logro('gladiador', 'Gladiador', 'Gana % peleas en la Arena', 'pvpVic',
      [5, 25, 100, 500], Icons.shield),
  Logro('ladron_arena', 'Ladrón de la Arena',
      'Roba % de oro en total en la Arena', 'oroRobado',
      [1000, 10000, 100000, 1000000], Icons.savings),
  Logro('gran_botin', 'Gran botín',
      'Roba % de oro o más en una sola pelea', 'mejorRobo',
      [500, 5000, 50000, 500000], Icons.diamond),
  Logro('intocable', 'Intocable', 'Defiéndete con éxito de % ataques',
      'defensas', [5, 25, 100], Icons.security),
  // ---- Misiones y taberna ----
  Logro('aventurero', 'Aventurero', 'Completa % misiones', 'misiones',
      [10, 50, 250, 1000], Icons.map),
  Logro('corazon_noble', 'Corazón noble', 'Completa % misiones por el bien',
      'misionesBien', [10, 50, 250, 1000], Icons.favorite),
  Logro('alma_oscura', 'Alma oscura', 'Completa % misiones por el mal',
      'misionesMal', [10, 50, 250, 1000], Icons.whatshot),
  Logro('camino_dividido', 'Camino dividido',
      'Completa % misiones de cada lado (bien y mal)', 'equilibrio', [10],
      Icons.call_split),
  Logro('mala_suerte', 'Pura mala suerte', 'Sufre mala suerte % veces',
      'malaSuerte', [5], Icons.cloud),
  Logro('trabajador', 'Trabajador', 'Trabaja % horas en la taberna', 'horas',
      [12, 100, 500, 2000], Icons.local_bar),
  Logro('cazatesoros', 'Cazatesoros', 'Encuentra % esquirlas en total',
      'gemasHalladas', [5, 25, 100, 500], Icons.diamond_outlined),
  // ---- Progreso y economía ----
  Logro('subiendo', 'Subiendo', 'Llega al nivel %', 'nivelMax',
      [10, 25, 50, 100, 200], Icons.trending_up),
  Logro('fortuna', 'Fortuna', 'Acumula % de oro', 'oroMax',
      [10000, 100000, 1000000, 10000000], Icons.monetization_on),
  Logro('mercader', 'Mercader', 'Compra y vende % objetos', 'comerciados',
      [10, 50, 250, 1000], Icons.store),
  Logro('entrenado', 'Entrenado', 'Compra % puntos de atributo',
      'entrenados', [50, 250, 1000], Icons.fitness_center),
  Logro('arsenal_completo', 'Arsenal completo',
      'Ten algo equipado en todas las casillas', 'arsenal', [1],
      Icons.backpack),
  Logro('coleccionista', 'Coleccionista', 'Posee % objetos distintos',
      'distintos', [10, 25, 50, 100], Icons.collections_bookmark),
  Logro('camino_extremo', 'Camino extremo',
      'Llega a % puntos de bien o de mal', 'inclinMax',
      [100, 500, 1000, 5000, 10000],
      Icons.balance),
  // ---- Constancia ----
  Logro('fiel', 'Fiel', 'Alcanza una racha diaria de % días', 'rachaMax',
      [7, 30, 100, 365], Icons.event_available),
  Logro('veterano', 'Veterano', 'Juega durante % días', 'diasJugados',
      [30, 100, 365], Icons.history),
  Logro('mecenas', 'Mecenas', 'Ten premium', 'premiumVisto', [1],
      Icons.workspace_premium),
  // ---- Secretos (no muestran su condición hasta desbloquearlos) ----
  Logro('tropiezo', 'Tropiezo épico',
      'Pierde contra un enemigo de nivel 1', 'tropiezo', [1],
      Icons.sentiment_very_dissatisfied,
      secreto: true),
  Logro('insomne', 'Insomne', 'Juega entre las 3 y las 5 de la madrugada',
      'insomne', [1], Icons.bedtime,
      secreto: true),
  Logro('tacano', 'Tacaño', 'Vende un objeto por 1 de oro', 'tacano', [1],
      Icons.money_off,
      secreto: true),
  Logro('cansado', 'Cansado de todo',
      'Gana una pelea después de que ambos se cansaran', 'agotador', [1],
      Icons.hotel,
      secreto: true),
  Logro('empate_eterno', 'Empate eterno', 'Termina % peleas en empate',
      'empates', [3], Icons.balance,
      secreto: true),
];

// ---------- Condecoraciones especiales (se dan a mano) ----------

class Especial {
  final String id;
  final String nombre;
  final String descripcion;
  final IconData icono;
  const Especial(this.id, this.nombre, this.descripcion, this.icono);
}

const List<Especial> todasLasEspeciales = [
  Especial('betatester', 'Betatester', 'Ayudó a probar el juego',
      Icons.bug_report),
  Especial('fundador', 'Fundador', 'Uno de los primeros jugadores',
      Icons.flag),
  Especial('cazador_bugs', 'Cazador de bugs',
      'Reportó un fallo importante', Icons.pest_control),
  Especial('campeon_temporada', 'Campeón de temporada',
      'Ganó un evento especial', Icons.emoji_events),
];

// Perfiles de enemigo que cuentan como "raros"
const List<String> perfilesRaros = [
  'Fantasma',
  'Señor de la guerra',
  'Sanguijuela',
  'Rompeescudos',
  'Cañón de cristal',
];

// 1234567 -> 1.234.567
String fmt(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return (n < 0 ? '-' : '') + b.toString();
}

// ---------- Datos del jugador ----------

class DatosLogros {
  final Estadisticas stats = Estadisticas();
  final Map<String, int> desbloqueados = {}; // id -> nivel ganado
  // id -> nivel hasta el que ya cobraste el oro. Lo ganado y no cobrado se cobra
  // en Inicio › Logros (así también cobran los logros que ya tenías de antes).
  final Map<String, int> cobrados = {};
  String? titulo; // nombre del último logro ganado
  List<String> especiales = []; // solo se leen de la nube, nunca se escriben
  final List<String> avisos = []; // mensajes pendientes (no se guardan)

  // ----- Registro de eventos -----

  void sumarOro(int oro) => stats.sumar('oroGanado', max(0, oro));

  void registrarCombate({
    required bool victoria,
    required bool derrota,
    required int rondas,
    required int danoHecho,
    required int danoRecibido,
    required int criticos,
    required int golpeMax,
    required int difNivel,
    required int nivelEnemigo,
    required String perfil,
    required String nombreEnemigo,
    required bool enCripta,
    required bool superviviente,
    required bool agotador,
  }) {
    final s = stats;
    s.sumar('peleas');
    s.sumar('danoHecho', danoHecho);
    s.sumar('danoRecibido', danoRecibido);
    s.sumar('criticos', criticos);
    s.maximo('golpeMax', golpeMax);
    s.maximo('rondasMax', rondas);
    if (victoria) {
      s.sumar('victorias');
      s.sumar('racha');
      s.maximo('mejorRacha', s['racha']);
      s.maximo('mayorDif', difNivel);
      s.maximo('nivelEnemigoMax', nivelEnemigo);
      if (s['victoriaRapida'] == 0 || rondas < s['victoriaRapida']) {
        s.fijar('victoriaRapida', max(1, rondas));
      }
      s.sumar(enCripta ? 'vencidosCripta' : 'vencidosCiudadela');
      if (perfilesRaros.contains(perfil)) s.fijar('raro_$perfil');
      if (nombreEnemigo.contains('Rey de las hordas')) s.fijar('reyHordas');
      if (nombreEnemigo.contains('Avatar de la Luz')) s.fijar('avatarLuz');
      if (superviviente) s.sumar('supervivientes');
      if (agotador) s.sumar('agotador');
    } else if (derrota) {
      s.sumar('derrotas');
      s.fijar('racha', 0);
      if (nivelEnemigo == 1) s.fijar('tropiezo');
    } else {
      s.sumar('empates');
      s.fijar('racha', 0);
    }
  }

  void registrarMision(
      {required bool bien,
        required int oro,
        required int gemas,
        required bool malaSuerte}) {
    final s = stats;
    if (malaSuerte) {
      s.sumar('malaSuerte');
      return;
    }
    s.sumar('misiones');
    s.sumar(bien ? 'misionesBien' : 'misionesMal');
    s.maximo('mejorOroMision', oro);
    s.sumar('gemasHalladas', gemas);
    sumarOro(oro);
  }

  void registrarTaberna(
      {required int horas, required int oro, required int gemas}) {
    stats.sumar('turnosTaberna');
    stats.sumar('horas', horas);
    stats.sumar('gemasHalladas', gemas);
    sumarOro(oro);
  }

  // Un ataque tuyo en la Arena
  void registrarPvp(
      {required bool gano, required bool derrota, required int oroRobado}) {
    final s = stats;
    s.sumar('pvpPeleas');
    if (gano) {
      s.sumar('pvpVic');
      s.sumar('oroRobado', oroRobado);
      s.maximo('mejorRobo', oroRobado);
    } else if (derrota) {
      s.sumar('pvpDer');
    }
  }

  // Alguien te atacó en la Arena. [exito] = te defendiste (el atacante perdió)
  void registrarDefensa({required bool exito, required int oroPerdido}) {
    stats.sumar('atacado');
    if (exito) {
      stats.sumar('defensas');
    } else {
      stats.sumar('oroPerdido', oroPerdido);
    }
  }

  // ----- Revisión: recalcula lo que depende del estado y otorga logros -----

  void actualizar(EstadoJuego j) {
    final s = stats;
    s.maximo('nivelMax', j.nivel);
    s.maximo('oroMax', j.oro);
    s.maximo('inclinMax', j.alineamiento.abs());
    s.maximo('inclinBienMax', max(0, j.alineamiento));
    s.maximo('inclinMalMax', max(0, -j.alineamiento));
    s.maximo('rachaMax', j.rachaDiaria);
    s.maximo('distintos', j.inventario.map((o) => o.nombre).toSet().length);
    if (Ranura.values.every((r) => j.equipado[r] != null)) s.fijar('arsenal');
    if (j.premium) s.fijar('premiumVisto');

    final ahora = DateTime.now();
    if (s['primerDia'] == 0) s.fijar('primerDia', ahora.millisecondsSinceEpoch);
    s.fijar('diasJugados',
        (ahora.millisecondsSinceEpoch - s['primerDia']) ~/ 86400000);
    if (ahora.hour >= 3 && ahora.hour < 5) s.fijar('insomne');

    s.fijar('equilibrio', min(s['misionesBien'], s['misionesMal']));
    s.fijar('comerciados', s['comprados'] + s['vendidos']);
    int raros = 0;
    for (final p in perfilesRaros) {
      if (s['raro_$p'] > 0) raros++;
    }
    s.fijar('raros', raros);

    for (final l in todosLosLogros) {
      final nuevo = l.nivelCon(s[l.stat]);
      final viejo = desbloqueados[l.id] ?? 0;
      if (nuevo > viejo) {
        desbloqueados[l.id] = nuevo;
        titulo = l.nombre;
        // El oro no se paga solo: se cobra en Inicio › Logros
        int premio = 0;
        for (int n = viejo + 1; n <= nuevo; n++) {
          premio += l.oroDeNivel(n);
        }
        avisos.add(l.unico
            ? '¡Logro desbloqueado: ${l.nombre}! Cóbralo: +${fmt(premio)} de oro'
            : '¡Logro: ${l.nombre} (${nombresNivel[nuevo - 1]})! Cóbralo: +${fmt(premio)} de oro');
      }
    }
  }

  // ----- Cobro de premios -----

  // Oro ganado en un logro que todavía no has cobrado
  int oroPendiente(Logro l) {
    final ganado = desbloqueados[l.id] ?? 0;
    final cobrado = cobrados[l.id] ?? 0;
    int oro = 0;
    for (int n = cobrado + 1; n <= ganado; n++) {
      oro += l.oroDeNivel(n);
    }
    return oro;
  }

  int get oroPendienteTotal =>
      todosLosLogros.fold<int>(0, (s, l) => s + oroPendiente(l));

  // Cobra un logro. Devuelve el oro cobrado (0 si no había nada).
  int cobrar(Logro l, EstadoJuego j) {
    final oro = oroPendiente(l);
    if (oro <= 0) return 0;
    cobrados[l.id] = desbloqueados[l.id] ?? 0;
    j.oro += oro;
    sumarOro(oro);
    j.avisarCambio();
    return oro;
  }

  int cobrarTodo(EstadoJuego j) {
    int total = 0;
    for (final l in todosLosLogros) {
      final oro = oroPendiente(l);
      if (oro <= 0) continue;
      cobrados[l.id] = desbloqueados[l.id] ?? 0;
      total += oro;
    }
    if (total > 0) {
      j.oro += total;
      sumarOro(total);
      j.avisarCambio();
    }
    return total;
  }

  // ----- Guardado -----
  // OJO: "especiales" no se guarda a propósito (ver arriba).

  Map<String, dynamic> aMapaGuardado() => {
    's': stats.toMap(),
    'u': Map<String, int>.from(desbloqueados),
    'c': Map<String, int>.from(cobrados),
    't': titulo,
  };

  void cargarDeMapa(dynamic mapa, {List<String>? especialesNube}) {
    stats.cargar(null);
    desbloqueados.clear();
    cobrados.clear();
    titulo = null;
    if (mapa is Map) {
      stats.cargar(mapa['s']);
      final u = mapa['u'];
      if (u is Map) {
        u.forEach((k, v) => desbloqueados[k.toString()] = (v as num).toInt());
      }
      final c = mapa['c'];
      if (c is Map) {
        c.forEach((k, v) => cobrados[k.toString()] = (v as num).toInt());
      }
      titulo = mapa['t'] as String?;
    }
    if (especialesNube != null) especiales = especialesNube;
  }

  // Lo que ven los demás jugadores
  PerfilLogrosDatos comoPerfil(EstadoJuego j) => PerfilLogrosDatos(
    nombre: j.nombre,
    nivel: j.nivel,
    raza: j.raza.nombre,
    titulo: titulo,
    stats: stats.toMap(),
    logros: Map<String, int>.from(desbloqueados),
  );
}

// ---------- Perfil que se publica / se lee de otros jugadores ----------

class PerfilLogrosDatos {
  final String nombre;
  final int nivel;
  final String raza;
  final String? titulo;
  final Map<String, int> stats;
  final Map<String, int> logros;
  const PerfilLogrosDatos({
    required this.nombre,
    required this.nivel,
    required this.raza,
    required this.titulo,
    required this.stats,
    required this.logros,
  });

  Map<String, dynamic> toMap() => {
    'nombre': nombre,
    'nivel': nivel,
    'raza': raza,
    'titulo': titulo,
    's': stats,
    'u': logros,
  };

  static Map<String, int> _mapaInt(dynamic m) {
    final r = <String, int>{};
    if (m is Map) {
      m.forEach((k, v) => r[k.toString()] = (v as num?)?.toInt() ?? 0);
    }
    return r;
  }

  factory PerfilLogrosDatos.fromMap(Map<String, dynamic> m) =>
      PerfilLogrosDatos(
        nombre: (m['nombre'] ?? 'Aventurero') as String,
        nivel: (m['nivel'] as num?)?.toInt() ?? 1,
        raza: (m['raza'] ?? '') as String,
        titulo: m['titulo'] as String?,
        stats: _mapaInt(m['s']),
        logros: _mapaInt(m['u']),
      );
}

// Abre el perfil de otro jugador a partir de su documento de "perfiles".
// Úsalo en la Arena y en el Ranking.
void abrirPerfilPublico(
    BuildContext context, String uid, Map<String, dynamic> docPerfil) {
  final pub = docPerfil['perfilLogros'];
  final base = <String, dynamic>{
    if (pub is Map) ...Map<String, dynamic>.from(pub),
  };
  base['nombre'] = docPerfil['nombre'] ?? base['nombre'] ?? 'Aventurero';
  base['nivel'] = docPerfil['nivel'] ?? base['nivel'] ?? 1;
  if (base['raza'] == null || base['raza'] == '') {
    final r = (docPerfil['raza'] as num?)?.toInt() ?? 0;
    base['raza'] = Raza.values[max(0, min(r, Raza.values.length - 1))].nombre;
  }
  Navigator.push(
    context,
    MaterialPageRoute(
        builder: (_) =>
            PantallaPerfilPublico(PerfilLogrosDatos.fromMap(base), uid: uid)),
  );
}

Future<List<String>> cargarEspecialesDe(String uid) async {
  try {
    final snap = await FirebaseFirestore.instance
        .collection('medallas')
        .doc(uid)
        .get()
        .timeout(const Duration(seconds: 15));
    final l = snap.data()?['lista'];
    if (l is List) return l.map((e) => e.toString()).toList();
  } catch (e) {
    debugPrint('Logros: no se pudieron leer las condecoraciones: $e');
  }
  return [];
}

// ---------- Avisos en pantalla ----------

void mostrarAvisosLogros(BuildContext context) {
  final a = juego.logros.avisos;
  if (a.isEmpty) return;
  final copia = List<String>.from(a);
  a.clear();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final m = ScaffoldMessenger.maybeOf(context);
    if (m == null) return;
    final texto = copia.length == 1
        ? copia.first
        : '${copia.first}  (y ${copia.length - 1} más)';
    m.showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.emoji_events, color: Colors.amber),
        const SizedBox(width: 10),
        Expanded(child: Text(texto)),
      ]),
      duration: const Duration(seconds: 4),
    ));
  });
}

// ====================== PANTALLAS Y WIDGETS ======================

// Imagen de una medalla. Busca assets/medallas/<id>_<nivel>.png y, si no
// existe, dibuja un ícono. Así puedes ir añadiendo imágenes poco a poco.
Widget _medalla(String ruta, IconData icono, Color color, double tam,
    {bool bloqueada = false}) {
  final fallback = Container(
    width: tam,
    height: tam,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xFF2A1218),
      border: Border.all(color: color, width: 2),
    ),
    child: Icon(icono, color: color, size: tam * 0.55),
  );
  final w = Image.asset(ruta,
      width: tam,
      height: tam,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => fallback);
  return Opacity(opacity: bloqueada ? 0.3 : 1.0, child: w);
}

class _Fila {
  final String etiqueta;
  final String Function(Map<String, int>) valor;
  const _Fila(this.etiqueta, this.valor);
}

class _Categoria {
  final String titulo;
  final IconData icono;
  final List<_Fila> filas;
  const _Categoria(this.titulo, this.icono, this.filas);
}

String _n(Map<String, int> s, String k) => fmt(s[k] ?? 0);

String _porcentaje(int parte, int total) =>
    total == 0 ? '0%' : '${(parte * 100 / total).round()}%';

final List<_Categoria> _categorias = [
  _Categoria('Combate', Icons.gavel, [
    _Fila('Peleas', (s) => _n(s, 'peleas')),
    _Fila('Victorias', (s) => _n(s, 'victorias')),
    _Fila('Derrotas', (s) => _n(s, 'derrotas')),
    _Fila('Empates', (s) => _n(s, 'empates')),
    _Fila('Porcentaje de victorias',
            (s) => _porcentaje(s['victorias'] ?? 0, s['peleas'] ?? 0)),
    _Fila('Racha actual', (s) => _n(s, 'racha')),
    _Fila('Mejor racha', (s) => _n(s, 'mejorRacha')),
    _Fila('Daño hecho', (s) => _n(s, 'danoHecho')),
    _Fila('Daño recibido', (s) => _n(s, 'danoRecibido')),
    _Fila('Golpe más fuerte', (s) => _n(s, 'golpeMax')),
    _Fila('Golpes críticos', (s) => _n(s, 'criticos')),
    _Fila('Pelea más larga', (s) => '${_n(s, 'rondasMax')} rondas'),
    _Fila(
        'Victoria más rápida',
            (s) => (s['victoriaRapida'] ?? 0) == 0
            ? '-'
            : '${s['victoriaRapida']} rondas'),
    _Fila('Mayor diferencia de nivel vencida',
            (s) => '+${_n(s, 'mayorDif')}'),
    _Fila('Enemigo de mayor nivel vencido',
            (s) => 'Nivel ${_n(s, 'nivelEnemigoMax')}'),
    _Fila('Vencidos en la Cripta', (s) => _n(s, 'vencidosCripta')),
    _Fila('Vencidos en la Ciudadela', (s) => _n(s, 'vencidosCiudadela')),
  ]),
  _Categoria('Arena (PvP)', Icons.shield, [
    _Fila('Peleas', (s) => _n(s, 'pvpPeleas')),
    _Fila('Victorias', (s) => _n(s, 'pvpVic')),
    _Fila('Derrotas', (s) => _n(s, 'pvpDer')),
    _Fila('Oro robado en total', (s) => _n(s, 'oroRobado')),
    _Fila('Mejor botín en una pelea', (s) => _n(s, 'mejorRobo')),
    _Fila('Oro que te robaron', (s) => _n(s, 'oroPerdido')),
    _Fila('Veces que te atacaron', (s) => _n(s, 'atacado')),
    _Fila('Ataques que resististe', (s) => _n(s, 'defensas')),
  ]),
  _Categoria('Misiones y taberna', Icons.map, [
    _Fila('Misiones completadas', (s) => _n(s, 'misiones')),
    _Fila('Por el bien', (s) => _n(s, 'misionesBien')),
    _Fila('Por el mal', (s) => _n(s, 'misionesMal')),
    _Fila('Veces con mala suerte', (s) => _n(s, 'malaSuerte')),
    _Fila('Mejor recompensa de oro', (s) => _n(s, 'mejorOroMision')),
    _Fila('Turnos de taberna', (s) => _n(s, 'turnosTaberna')),
    _Fila('Horas trabajadas', (s) => _n(s, 'horas')),
    _Fila('Esquirlas encontradas', (s) => _n(s, 'gemasHalladas')),
  ]),
  _Categoria('Economía', Icons.monetization_on, [
    _Fila('Oro ganado en total', (s) => _n(s, 'oroGanado')),
    _Fila('Objetos comprados', (s) => _n(s, 'comprados')),
    _Fila('Objetos vendidos', (s) => _n(s, 'vendidos')),
    _Fila('Puntos de atributo comprados', (s) => _n(s, 'entrenados')),
    _Fila('Objetos distintos poseídos', (s) => _n(s, 'distintos')),
  ]),
  _Categoria('Constancia', Icons.event_available, [
    _Fila('Días jugados', (s) => _n(s, 'diasJugados')),
    _Fila('Mejor racha diaria', (s) => _n(s, 'rachaMax')),
    _Fila('Anuncios vistos', (s) => _n(s, 'anunciosVistos')),
    _Fila('Inclinación máxima al bien', (s) => _n(s, 'inclinBienMax')),
    _Fila('Inclinación máxima al mal', (s) => _n(s, 'inclinMalMax')),
  ]),
];

// Estadísticas (plegables por categoría) + logros + condecoraciones.
class SeccionLogrosPerfil extends StatelessWidget {
  final PerfilLogrosDatos datos;
  final List<String> especiales;
  // true solo en tu propio perfil: muestra los botones para cobrar el oro
  final bool puedeCobrar;
  const SeccionLogrosPerfil(
      {super.key,
        required this.datos,
        this.especiales = const [],
        this.puedeCobrar = false});

  void _aviso(BuildContext context, String t) {
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(content: Text(t)));
  }

  void _detalle(BuildContext context, Logro l) {
    final nivel = datos.logros[l.id] ?? 0;
    final valor = datos.stats[l.stat] ?? 0;
    final oculto = l.secreto && nivel == 0;
    final completo = nivel >= l.metas.length;
    final meta = completo ? l.metas.last : l.metas[nivel];
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(oculto ? 'Logro secreto' : l.nombre),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _medalla('assets/medallas/${l.id}_${max(1, nivel)}.png', l.icono,
                nivel == 0 ? Colors.grey : coloresNivel[nivel - 1], 72,
                bloqueada: nivel == 0),
            const SizedBox(height: 10),
            Text(oculto
                ? 'Sigue jugando para descubrir cómo desbloquearlo.'
                : l.textoMeta(completo ? nivel - 1 : nivel)),
            if (!oculto && !l.unico) ...[
              const SizedBox(height: 8),
              Text(
                  nivel == 0
                      ? 'Sin ganar todavía'
                      : 'Nivel: ${nombresNivel[nivel - 1]}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
            if (!oculto && !completo && !l.unico)
              Text('Progreso: ${fmt(min(valor, meta))} / ${fmt(meta)}'),
            if (!oculto && l.unico && nivel == 0)
              Text('Progreso: ${fmt(min(valor, meta))} / ${fmt(meta)}'),
            if (!oculto && !completo)
              Text('Premio: ${fmt(l.oroDeNivel(nivel + 1))} de oro',
                  style: const TextStyle(color: Colors.amber)),
            if (completo) const Text('¡Completado!'),
          ],
        ),
        actions: [
          if (puedeCobrar && juego.logros.oroPendiente(l) > 0)
            ElevatedButton(
              onPressed: () {
                final oro = juego.logros.cobrar(l, juego);
                Navigator.pop(ctx);
                _aviso(context, 'Cobraste ${fmt(oro)} de oro.');
              },
              child: Text('Cobrar ${fmt(juego.logros.oroPendiente(l))} de oro'),
            ),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))
        ],
      ),
    );
  }

  Widget _tarjetaLogro(BuildContext context, Logro l) {
    final nivel = datos.logros[l.id] ?? 0;
    final oculto = l.secreto && nivel == 0;
    final color = nivel == 0 ? Colors.grey : coloresNivel[nivel - 1];
    final porCobrar = puedeCobrar && juego.logros.oroPendiente(l) > 0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _detalle(context, l),
      child: SizedBox(
        width: 82,
        child: Column(
          children: [
            Badge(
              isLabelVisible: porCobrar,
              backgroundColor: Colors.amber,
              smallSize: 12,
              child: _medalla('assets/medallas/${l.id}_${max(1, nivel)}.png',
                  oculto ? Icons.help_outline : l.icono, color, 52,
                  bloqueada: nivel == 0),
            ),
            const SizedBox(height: 4),
            Text(oculto ? '???' : l.nombre,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11)),
            if (nivel > 0 && !l.unico)
              Text(nombresNivel[nivel - 1],
                  style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ganados = datos.logros.values.where((v) => v > 0).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---------- ESTADÍSTICAS ----------
        const Text('Estadísticas',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        // Resumen siempre visible
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _dato('Victorias', _n(datos.stats, 'victorias')),
                _dato('Derrotas', _n(datos.stats, 'derrotas')),
                _dato('Empates', _n(datos.stats, 'empates')),
                _dato(
                    'Victorias %',
                    _porcentaje(datos.stats['victorias'] ?? 0,
                        datos.stats['peleas'] ?? 0)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        for (final c in _categorias)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                leading: Icon(c.icono, size: 20),
                title: Text(c.titulo, style: const TextStyle(fontSize: 14)),
                childrenPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                children: [
                  for (final f in c.filas)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                              child: Text(f.etiqueta,
                                  style: const TextStyle(fontSize: 12))),
                          Text(f.valor(datos.stats),
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF1E3C0))),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        const SizedBox(height: 14),

        // ---------- CONDECORACIONES ----------
        if (especiales.isNotEmpty) ...[
          const Text('Condecoraciones',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final e in todasLasEspeciales)
                if (especiales.contains(e.id))
                  GestureDetector(
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(e.nombre),
                        content: Text(e.descripcion),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cerrar'))
                        ],
                      ),
                    ),
                    child: SizedBox(
                      width: 82,
                      child: Column(children: [
                        _medalla('assets/medallas/${e.id}.png', e.icono,
                            Colors.amber, 52),
                        const SizedBox(height: 4),
                        Text(e.nombre,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11)),
                      ]),
                    ),
                  ),
            ],
          ),
          const SizedBox(height: 14),
        ],

        // ---------- LOGROS ----------
        Row(children: [
          Expanded(
            child: Text('Logros ($ganados/${todosLosLogros.length})',
                style:
                const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ),
          if (puedeCobrar && juego.logros.oroPendienteTotal > 0)
            ElevatedButton.icon(
              onPressed: () {
                final oro = juego.logros.cobrarTodo(juego);
                _aviso(context, 'Cobraste ${fmt(oro)} de oro por tus logros.');
              },
              icon: const IconoMoneda(tam: 18),
              label: Text('Cobrar ${fmt(juego.logros.oroPendienteTotal)}'),
            ),
        ]),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 12,
          children: [
            for (final l in todosLosLogros) _tarjetaLogro(context, l),
          ],
        ),
      ],
    );
  }

  Widget _dato(String etiqueta, String valor) {
    return Column(
      children: [
        Text(valor,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFF1E3C0))),
        Text(etiqueta, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

// Perfil de otro jugador (solo lectura)
class PantallaPerfilPublico extends StatelessWidget {
  final PerfilLogrosDatos datos;
  final String? uid;
  const PantallaPerfilPublico(this.datos, {super.key, this.uid});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(datos.nombre)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
              child: Text(datos.nombre,
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold))),
          if (datos.titulo != null)
            Center(
                child: Text('«${datos.titulo}»',
                    style: const TextStyle(
                        fontStyle: FontStyle.italic, color: Colors.amber))),
          Center(
              child: Text(
                  'Nivel ${datos.nivel}${datos.raza.isEmpty ? '' : '  |  Raza: ${datos.raza}'}')),
          const SizedBox(height: 16),
          FutureBuilder<List<String>>(
            future: uid == null ? Future.value(<String>[]) : cargarEspecialesDe(uid!),
            builder: (context, snap) => SeccionLogrosPerfil(
              datos: datos,
              especiales: snap.data ?? const [],
            ),
          ),
        ],
      ),
    );
  }
}