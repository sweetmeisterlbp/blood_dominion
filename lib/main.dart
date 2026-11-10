import 'dart:async';
import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'altar.dart';
import 'anuncios.dart';
import 'arena.dart';
import 'batalla.dart';
import 'armado.dart';
import 'bienvenida.dart';
import 'boton_oscuro.dart';
import 'catalogo.dart';
import 'dados.dart';
import 'compras.dart';
import 'firebase_options.dart';
import 'fondos.dart';
import 'idioma.dart';
import 'imagenes.dart';
import 'inmortal.dart';
import 'notificaciones.dart';
import 'nube.dart';
import 'pantalla_login.dart';
import 'ranking.dart';
import 'social.dart';
import 'bestiario.dart';
import 'diarias.dart';
import 'legal.dart';
import 'subida_nivel.dart';
import 'tutorial.dart';
import 'logros.dart';
import 'musica.dart';

// Otros archivos que importan main.dart siguen viendo Objeto, catalogo, etc.
export 'catalogo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Bloquea la rotación: el juego solo se ve en vertical.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Prepara los anuncios (no espera: se cargan en segundo plano).
  Anuncios.instancia.iniciar();
  // Prepara las notificaciones de fin de misión y de trabajo.
  Notificaciones.instancia.iniciar();
  // Carga el idioma guardado (o el del teléfono) antes de dibujar la primera pantalla.
  await Idioma.instancia.cargar();
  // Música de fondo: carga volumen/silencio guardados y empieza a sonar.
  await Musica.instancia.cargar();
  Musica.instancia.reproducir('oscura');
  runApp(const BloodDominionApp());
}

// ====================== CONFIGURACIÓN ======================

// Minutos que dura UN bloque de misión. Todo lo demás se calcula a partir de aquí.
const int minutosPorBloque = 5;

// Duración real de un bloque. Para probar rápido, usa Duration(seconds: 10)
// y vuelve a esta línea antes de publicar.
const Duration duracionBloque = Duration(minutes: minutosPorBloque);

// Opciones que ve el jugador, en bloques: 5, 10, 15 y 30 minutos
const List<int> opcionesBloques = [1, 2, 3, 6];

// Probabilidad de mala suerte (0.08 = 8%)
const double probMalaSuerte = 0.08;

// Tope de puntos de inclinación hacia cada lado. Es exageradamente alto a
// propósito: en la práctica no hay límite (antes era 100 y se perdían puntos).
const int limiteInclinacion = 1000000;

// Cuánto más suben los puntos de inclinación por cada bloque extra de misión.
// 0.1 = +10% por bloque extra: 5 min x1, 10 min x1.1, 15 min x1.2, 30 min x1.5
const double extraInclinacionPorBloque = 0.1;

// Probabilidad de encontrar gemas por cada bloque de misión
// (0.04 = 4%). En una misión larga se acumula: 30 min ≈ 22%.
const double probGemasPorBloque = 0.04;

// Oro que cuesta salir a una misión (se paga una vez, al partir)
const int costoMision = 10;

// Tiempo de misiones por día, medido en bloques de 5 minutos.
// 12 bloques = 60 minutos al día (24 bloques = 120 min con premium).
// Una misión de 30 minutos gasta 6 bloques. Se reinicia a las 00:00 (hora del servidor).
const int bloquesPorDia = 12;
const int bloquesPorDiaPremium = 24;

// Hora del servidor: zona horaria del reloj del juego. A las 00:00 de esta hora
// se reinicia el tiempo de misiones del día. -3 = Uruguay/Argentina/Brasil.
// (Si algún día lo cambias, el reloj y el reinicio cambian juntos.)
const int desfaseHoraServidorHoras = -3;

// Equipo con el que empieza el jugador (nombres exactos del catálogo).
// Se agregan al inventario y quedan equipados desde el principio.
const List<String> equipoInicial = [
  'Espada de entrenamiento de madera',
  'Túnica de aprendiz',
];

// ---------- COMBATE (Cripta y Ciudadela de la Luz) ----------
// Tiempo que tarda la vida en recuperarse de 0 a la vida máxima
const Duration regeneracionCompleta = Duration(minutes: 30);
// Vida mínima (en proporción a la máxima) para poder pelear: 0.10 = 10%
const double vidaMinimaParaPelear = 0.10;
// Si pasan estas rondas sin vencedor, el combate termina en empate
const int maxRondasCombate = 40;

// ---------- CANSANCIO (atributo Aguante) ----------
// Cada luchador pelea sin cansarse durante 5 + Aguante/2 rondas.
// Después, cada ronda pierde un 5% de daño y de esquive, hasta un mínimo del 50%.
const int rondasFrescasBase = 5;
const double fatigaPorRonda = 0.05;
const double fatigaMinima = 0.5;

// ---------- FÓRMULAS DE COMBATE ----------
// Daño = ataque * C / (C + defensa), con C = base + porNivel * nivel del atacante.
// Así la defensa nunca deja el daño en 0, ni siquiera con valores enormes.
const double defensaConstanteBase = 6.0;
const double defensaConstantePorNivel = 2.5;
// Límites para que ningún build sea imposible de golpear o de esquivar
const double topeEsquive = 0.65;
const double topeCritico = 0.60;
const double multCriticoBase = 2.0;
// Cada punto de habilidad por encima del mínimo de un objeto mejora su valor
const double bonusPorPuntoHabilidad = 0.03;

// ---------- PASIVAS DE RAZA ----------
// Sed de sangre: parte del daño que haces se te devuelve en vida.
// Cura menos cuando el golpe cae sobre otro jugador, para no romper el PvP.
const double sedSangreContraMonstruos = 0.17;
const double sedSangreContraJugadores = 0.12;
// Ferocidad: el primer golpe siempre es crítico y los críticos pegan más
const double multCriticoFerocidad = 2.3;
// Precisión: el rival esquiva un 40% menos
const double precisionReduceEsquive = 0.42;
// Penetración: tus golpes ignoran un 30% de la defensa del rival
const double penetracionDefensa = 0.30;
// Dificultad de los enemigos de Cripta y Ciudadela (no afecta a la Arena).
// 1.0 = parejos con un jugador normal de su nivel; sube para hacerlos más fuertes.
const double factorDificultadPve = 1.0;
// Ambición (Humano): más oro y fama al ganar en Arena, Cripta y Ciudadela
const double bonoAmbicion = 0.10;
// Más allá de la muerte (Muerto viviente): una vez por combate, si un golpe te
// dejaría en 0, quedas con este porcentaje de tu vida máxima
const double masAllaMuerteVida = 0.20;

// Oro que cuesta actualizar la búsqueda de rivales para ver otros.
// La primera búsqueda es gratis, y también la primera después de cada pelea.
const int costoActualizarBusqueda = 20;
// Cuántos rivales aparecen en la búsqueda "cercanos a tu poder"
const int enemigosPorBusqueda = 4;
// Nivel de esos rivales respecto al tuyo: desde -3 (más débil)
// hasta +3 (más fuerte).
const int difNivelMin = -3;
const int difNivelMax = 3;

// ---------- COMBATE contra jugadores (PvP) ----------
// Todavía no está implementado (Arena): estas reglas quedan fijadas para después.
const Duration esperaEntreAtaques = Duration(minutes: 15);
const Duration esperaEntreAtaquesPremium = Duration(minutes: 5);
const Duration esperaMismoRival = Duration(hours: 12); // al mismo jugador
const Duration proteccionTrasSerAtacado = Duration(hours: 1);
const double porcentajeRoboOro = 0.10; // 10% del oro de la víctima

// ---------- ANUNCIOS RECOMPENSADOS ----------
// Máximo de anuncios (recompensas) que se pueden usar por día
const int maxAnunciosPorDia = 8;
// Bloques de misión (5 min cada uno) que da el anuncio de "tiempo extra"
const int bloquesPorAnuncio = 2;

// ---------- TIENDA E INVENTARIO ----------
// En la tienda se ven los objetos hasta este número de niveles por encima del tuyo
// (nivel 5 -> hasta nivel 7).
const int nivelesExtraTienda = 2;

// Mercado negro: cada día trae entre [bazarMinPorDia] y [bazarMaxPorDia]
// objetos distintos (1 unidad de cada uno). La cantidad y los objetos se
// sortean al azar, sin patrón. Se renueva a medianoche del servidor.
const int bazarMinPorDia = 2;
const int bazarMaxPorDia = 5;
// Cada hueco del día puede ser un objeto cualquiera de la Tienda con descuento.
const double bazarProbRebaja = 0.20; // 20 % de probabilidad por hueco
const double bazarDescuento = 0.10; // 10 % más barata que en la Tienda

// Afilador ambulante: cada afilado suma +1 al daño del arma (mínimo y máximo).
const int afiladosMax = 3; // veces que se puede afilar una misma arma
const int costoAfilado = 50; // gemas por cada afilado
// Ponerle (o cambiarle) el nombre a un arma: brilla en turquesa con aura.
const int costoRenombrar = 100; // gemas
const int largoMaxApodo = 20; // letras
// Qué parte del precio te pagan al vender un objeto (0.5 = la mitad).
const double porcentajeVenta = 0.5;

// ---------- RECOMPENSA DIARIA ----------
// Premio por entrar cada día. La racha sube un día por cada día seguido; si
// faltas un día, vuelve a empezar. El ciclo es de 7 días y se repite.
// El oro es el de un personaje nivel 1 y crece con tu nivel (igual que las
// misiones). "bloques" son bloques de misión extra de 5 min para hoy.
class RecompensaDiaria {
  final int oro;
  final int gemas;
  final int bloques;
  const RecompensaDiaria(this.oro, {this.gemas = 0, this.bloques = 0});
}

const List<RecompensaDiaria> recompensasDiarias = [
  RecompensaDiaria(60),
  RecompensaDiaria(80),
  RecompensaDiaria(100, bloques: 1),
  RecompensaDiaria(120, gemas: 10),
  RecompensaDiaria(150, gemas: 1),
  RecompensaDiaria(200, bloques: 1),
  RecompensaDiaria(300, gemas: 15),
];

// Nivel máximo del juego
const int nivelMaximo = 200;

final Random azar = Random();

// Fama necesaria para pasar del nivel [n] al [n+1].
// Del nivel 1 al 10 piden 100 y cada nivel pide 20% más que el anterior.
// Del nivel 10 en adelante el costo crece de forma cuadrática (mucho más
// suave), así los niveles altos siguen siendo alcanzables.
int famaParaSubir(int n) {
  if (n <= 10) {
    double costo = 100;
    for (int i = 1; i < n; i++) {
      costo *= 1.2;
    }
    return costo.round();
  }
  final double costoNivel10 = (100 * pow(1.2, 9)).toDouble();
  return (costoNivel10 * pow(n / 10, 2)).round();
}

// ====================== ORO DE MISIONES POR NIVEL ======================
// El oro de cada destino es el de un personaje nivel 1.
// Al subir de nivel se multiplica por un factor:
//   factor = 1 + lineal * (nivel - 1) + cuadratico * (nivel - 1)^2
// Nivel 10 = x2.9 de oro | nivel 20 = x6.9 | nivel 50 = x30.9
// La FAMA de las misiones NO usa este factor: es fija por destino (ver Destino.fama).
const double oroMisionLineal = 0.12;
const double oroMisionCuadratico = 0.01;

double factorOroMision(int nivel) {
  final n = nivel - 1;
  return 1 + oroMisionLineal * n + oroMisionCuadratico * n * n;
}

// ====================== FAMA E INCLINACIÓN EN COMBATE ======================

// ---------- Cuántas peleas pide cada nivel ----------
// Contra un rival de TU mismo nivel, subir de nivel pide siempre el mismo
// número de victorias, que crece despacio con el nivel:
//   peleasPorNivel = base + porNivel * nivel   (30 en el nivel 1, 60 en el 100, 90 en el 200)
// La fama de una victoria sale de ahí: famaParaSubir(nivel) / peleasPorNivel(nivel).
// Así la fama de las peleas ya no crece más rápido que el costo de subir, y
// el oro y el equipo (que valen por nivel) pueden seguirle el paso.
// Para hacer más lento o más rápido subir peleando, toca solo estos dos números.
const int peleasPorNivelBase = 30;
const double peleasPorNivelPorNivel = 0.3;

int peleasPorNivel(int nivel) =>
    (peleasPorNivelBase + peleasPorNivelPorNivel * nivel).round();

// Fama base de una pelea (rival de tu nivel, antes de aplicar la diferencia).
int famaBasePelea(int nivel) =>
    max(1, (famaParaSubir(nivel) / peleasPorNivel(nivel)).round());

// [dif] = nivel del rival - tu nivel.
// Multiplicador de la fama al GANAR. Entre más fuerte el rival, más fama.
// Vencer a alguien mucho más débil te quita fama (número negativo).
double factorFamaVictoria(int dif) {
  if (dif >= 5) return 2.0;
  if (dif >= 3) return 1.5;
  if (dif >= 1) return 1.2;
  if (dif == 0) return 1.0;
  if (dif >= -2) return 0.7;
  if (dif >= -4) return 0.4;
  if (dif >= -6) return 0.0;
  return -0.25;
}

// Multiplicador de la fama al PERDER (siempre 0 o negativo).
// Perder contra alguien mucho más fuerte no cuesta nada; perder contra
// alguien más débil duele.
double factorFamaDerrota(int dif) {
  if (dif >= 3) return 0.0;
  if (dif >= 0) return -0.15;
  if (dif >= -3) return -0.3;
  return -0.5;
}

// Cambio de fama (positivo o negativo) tras un combate.
// Las ganancias se calculan con el nivel del rival y las pérdidas con el tuyo.
int cambioFamaCombate(int nivelJugador, int nivelEnemigo, bool gano) {
  final dif = nivelEnemigo - nivelJugador;
  final factor = gano ? factorFamaVictoria(dif) : factorFamaDerrota(dif);
  // La base depende de TU nivel (no del rival): la diferencia de nivel solo
  // la multiplica con los factores de arriba.
  final base = famaBasePelea(nivelJugador);
  return (base * factor).round();
}

// ---------- FAMA EN PvE (Cripta y Ciudadela) ----------
// En PvE la fama es FIJA según cuántos niveles más fuerte es el rival que tú
// (dif = nivel del rival - tu nivel). No depende de tu nivel.
// La Arena (contra jugadores) sigue usando cambioFamaCombate.
// Rivales más débiles que tú (dif negativo) te QUITAN fama al ganar: es la
// misma escala de los más fuertes pero en negativo (-1: -2, -2: -5, -3: -10).
const Map<int, int> famaPveVictoria = {
  3: 10,
  2: 5,
  1: 2,
  0: 1,
  -1: -2,
  -2: -5,
  -3: -10,
};

// Cambio de fama tras un combate PvE (Cripta y Ciudadela).
// Victoria: valor fijo según la diferencia de nivel (de -3 a +3).
// Derrota: se usa la misma regla de pérdida que en la Arena.
int cambioFamaPve(int nivelJugador, int nivelEnemigo, bool gano) {
  final dif = nivelEnemigo - nivelJugador;
  if (gano) {
    return famaPveVictoria[max(-3, min(3, dif))] ?? 0;
  }
  return cambioFamaCombate(nivelJugador, nivelEnemigo, false);
}

// Oro al ganar contra rivales de tu nivel o más débiles (dif <= 0): se paga
// solo este porcentaje del oro normal de ese enemigo. Los rivales más fuertes
// (dif > 0) siguen dando el 100 %. Fuera de -3 se usa el valor de -3.
const Map<int, double> porcentajeOroPve = {
  0: 0.40,
  -1: 0.20,
  -2: 0.10,
  -3: 0.04,
};

double porcentajeOroPveDe(int nivelJugador, int nivelEnemigo) {
  final dif = nivelEnemigo - nivelJugador;
  if (dif > 0) return 1.0;
  return porcentajeOroPve[max(-3, dif)] ?? 0.04;
}

// Puntos de inclinación al ganar un combate, de 1 a 5 según el nivel del rival.
int puntosInclinacionCombate(int nivelEnemigo) =>
    min(5, 1 + nivelEnemigo ~/ 5);

// ====================== ENTRENAMIENTO ======================

// Qué hace cada atributo. Se muestra al tocar su nombre.
const Map<String, String> descripcionAtributo = {
  'Poder':
  'Aumenta tu ataque: cada 2 puntos de Poder suman 1 de ataque. Es la base del daño de cada golpe.',
  'Vigor':
  'Aumenta tu vida máxima: cada punto suma 5 de vida (la vida base es 50).',
  'Agilidad':
  'Aumenta tu probabilidad de esquivar los golpes del rival (el máximo es 65%: cuando alcances ese porcentaje no podrás seguir entrenándola). Además, quien tiene más Agilidad ataca primero en cada ronda.',
  'Maestría de combate':
  'Aumenta tu probabilidad de golpe crítico (el máximo es 60%: cuando alcances ese porcentaje no podrás seguir entrenándola). Un crítico hace el doble de daño.',
  'Guardia':
  'Aumenta tu defensa: cada 2 puntos de Guardia suman 1 de defensa, lo que reduce el daño que recibes.',
  'Aguante':
  'Determina cuánto peleas sin cansarte: 5 rondas más 1 por cada 2 puntos de Aguante. Después de eso pierdes daño y esquive en cada ronda, hasta un mínimo del 50%.',
};

void mostrarDescripcionAtributo(BuildContext context, String clave) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(clave),
      content: Text((descripcionAtributo[clave] ?? '') +
          (topeEntrenamiento(clave) == null
              ? ''
              : clave == 'Agilidad'
              ? '\n\nTope: $topeAgilidad de Agilidad (cuenta el equipo), '
              'medido contra un rival con $agilidadRivalReferencia de Agilidad.'
              : '\n\nTope: $topeMaestria de Maestría (cuenta el equipo).')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}

// ---------- Topes de entrenamiento ----------
// Maestría: la probabilidad de crítico es maestría / (maestría + 190) y tiene
// tope [topeCritico]. Con este valor ya estás en el tope.
final int topeMaestria = (topeCritico * 190 / (1 - topeCritico)).ceil(); // 285

// Agilidad: el esquive depende del rival (agil / (agil + agilRival + 90)),
// así que no hay un valor exacto. Se usa un rival de referencia: con esta
// Agilidad llegas al tope [topeEsquive] contra un rival con ese valor.
const int agilidadRivalReferencia = 500;
final int topeAgilidad = (topeEsquive * (agilidadRivalReferencia + 90) /
    (1 - topeEsquive)).ceil(); // 1096

// Valor máximo hasta el que se puede entrenar un atributo (null = sin tope).
// Cuenta el valor total, con el equipo puesto.
int? topeEntrenamiento(String clave) {
  if (clave == 'Maestría de combate') return topeMaestria;
  if (clave == 'Agilidad') return topeAgilidad;
  return null;
}

// Texto con el porcentaje actual y el máximo (solo Agilidad y Maestría).
String? textoPorcentajeTope(String clave, int total) {
  if (clave == 'Maestría de combate') {
    final p = min(topeCritico, total / (total + 190)) * 100;
    return 'Crítico ${p.round()}% (máx ${(topeCritico * 100).round()}%)';
  }
  if (clave == 'Agilidad') {
    final p = min(topeEsquive, total / (total + agilidadRivalReferencia + 90)) * 100;
    return 'Esquive ${p.round()}% (máx ${(topeEsquive * 100).round()}%)';
  }
  return null;
}

// Valor con el que empieza cada atributo de un personaje nuevo.
const int atributoInicial = 5;

// Precio del primer punto de cada atributo.
const Map<String, int> precioBaseAtributo = {
  'Poder': 10,
  'Vigor': 5,
  'Agilidad': 5,
  'Maestría de combate': 5,
  'Guardia': 10,
  'Aguante': 5,
};

// Cuánto sube el precio con cada punto comprado, en porcentaje.
// Poder y Guardia: 15%. Los demás: 10%.
int porcentajeAumento(String clave) {
  return (clave == 'Poder' || clave == 'Guardia') ? 15 : 10;
}

// Precio del siguiente punto, sabiendo cuántos puntos ya compraste.
// Cada paso se redondea SIEMPRE hacia arriba (cualquier decimal sube un punto).
// Se calcula con enteros para evitar errores de decimales.
int precioEntrenamiento(String clave, int puntosComprados) {
  int precio = precioBaseAtributo[clave]!;
  final int porcentaje = porcentajeAumento(clave);
  for (int i = 0; i < puntosComprados; i++) {
    precio = (precio * (100 + porcentaje) + 99) ~/ 100;
  }
  return precio;
}

// ====================== DATOS ======================

// El catálogo de equipo (Objeto, TipoObjeto, Ranura, catalogo...) está en catalogo.dart

// Un destino posible de misión. El oro es por bloque de misión; la fama es
// FIJA por misión (da igual si dura 5 min o 30 min).
class Destino {
  final String articulo; // "un" o "una"
  final String lugar;
  final int probabilidad; // peso relativo (suman 100)
  final int puntosAlineamiento; // 1 a 5 según el tamaño del lugar
  final int genteMin;
  final int genteMax;
  final int oroMin;
  final int oroMax;
  final int fama; // fama fija por misión, sin importar su duración
  final List<String> historiasBien;
  final List<String> historiasMal;

  const Destino(
      this.articulo,
      this.lugar,
      this.probabilidad,
      this.puntosAlineamiento,
      this.genteMin,
      this.genteMax,
      this.oroMin,
      this.oroMax,
      this.fama,
      this.historiasBien,
      this.historiasMal);

  // Máximo de gemas que puede dar este destino en una misión.
  // Va de 2 (caserío) a 10 (metrópoli), según su tamaño.
  int get gemasMax => puntosAlineamiento * 2;
}

const List<Destino> destinos = [
  // ---------------- CASERÍO ----------------
  Destino(
    'un',
    'caserío',
    30,
    1,
    5,
    14,
    5,
    25,
    3,
    [
      'Viste a una muchacha siendo golpeada por su marido furioso, que la acusaba de serle infiel. Te interpusiste y lo echaste a empujones.',
      'Encontraste a un granjero con la carreta atascada en el barro bajo la lluvia. Lo ayudaste a sacarla y quedaste cubierto de lodo hasta las cejas.',
      'Unos niños lloraban porque un lobo flaco rondaba el corral. Lo espantaste a gritos y a pedradas.',
    ],
    [
      'Entraste a una casa vacía mientras la familia estaba en el campo y te llevaste lo poco que tenían guardado.',
      'Un viejo granjero dormía junto al camino. Le vaciaste los bolsillos sin que se diera cuenta.',
      'Les dijiste a los vecinos que cobrabas un impuesto del señor feudal. Era mentira, pero pagaron igual.',
    ],
  ),
  // ---------------- ALDEA ----------------
  Destino(
    'una',
    'aldea',
    30,
    2,
    15,
    30,
    20,
    60,
    7,
    [
      'Había un alboroto en la plaza: dos hermanos se peleaban a golpes por una herencia. Los separaste y los obligaste a repartirla en partes iguales.',
      'Un incendio había prendido en el granero del molinero. Hiciste una cadena de cubos con los vecinos y lo apagaron antes de que se extendiera.',
      'Un forastero vendía una medicina milagrosa que enfermaba a la gente. Lo denunciaste y le quitaste el negocio.',
    ],
    [
      'Se celebraba una boda y todos estaban distraídos. Te llevaste los regalos de los novios sin que nadie lo notara.',
      'Amenazaste al molinero con quemarle el granero si no te entregaba su bolsa de monedas. Pagó temblando.',
      'Asustaste a los aldeanos con una historia de bandidos y te ofreciste a protegerlos, a cambio de una generosa contribución.',
    ],
  ),
  // ---------------- PUEBLO ----------------
  Destino(
    'un',
    'pueblo',
    20,
    3,
    50,
    90,
    80,
    170,
    12,
    [
      'Una banda de bandidos acechaba el camino al mercado. Los emboscaste de noche y los entregaste al alguacil.',
      'La taberna estaba a punto de estallar en una pelea masiva entre mineros y leñadores. Te subiste a una mesa y los calmaste con un brindis.',
      'Un ladrón huía con la bolsa de una anciana. Lo perseguiste por los tejados y se la devolviste.',
    ],
    [
      'Cobraste una cuota de protección a los comerciantes del mercado. Los que se negaron sufrieron un misterioso accidente con sus puestos.',
      'Te hiciste pasar por inspector del reino y multaste a media docena de tenderos con tarifas inventadas.',
      'Aprovechaste la noche de feria para vaciar la caja del recaudador del pueblo.',
    ],
  ),
  // ---------------- CIUDAD ----------------
  Destino(
    'una',
    'ciudad',
    12,
    4,
    120,
    180,
    150,
    340,
    16,
    [
      'Escoltaste una caravana de mercaderes por callejones peligrosos. Los asaltantes se lo pensaron mejor al verte.',
      'Descubriste a un noble corrupto mezclando arena en el grano de los pobres. Lo denunciaste ante el consejo de la ciudad.',
      'Un incendio amenazaba el barrio de los tejedores. Organizaste a los guardias y salvaste decenas de casas.',
    ],
    [
      'Interceptaste una caravana de mercaderes en un callejón oscuro y te quedaste con la mejor parte de la carga.',
      'Te infiltraste en la casa de un prestamista y copiaste su libro de deudas para chantajear a sus clientes.',
      'Organizaste una pelea falsa en una plaza concurrida mientras tus cómplices vaciaban los bolsillos de los curiosos.',
    ],
  ),
  // ---------------- METRÓPOLI ----------------
  Destino(
    'una',
    'metrópoli',
    8,
    5,
    200,
    300,
    280,
    550,
    20,
    [
      'Una turba furiosa saqueaba el gran mercado. Te abriste paso entre la multitud, detuviste a los cabecillas y devolviste el orden.',
      'Un asesino acechaba a un joven heredero en plena fiesta del gremio. Lo desarmaste a tiempo, ante cientos de testigos.',
      'Los canales de la ciudad se desbordaron. Guiaste a cientos de familias hacia terreno seguro durante toda la noche.',
    ],
    [
      'Saqueaste el barrio rico mientras la guardia estaba ocupada con un desfile. Los nobles tardaron horas en notar sus pérdidas.',
      'Te infiltraste en la bóveda de un gremio mercantil y te llevaste una fortuna antes del amanecer.',
      'Provocaste un motín en el mercado y, entre el caos, te llevaste lo mejor de los puestos de los joyeros.',
    ],
  ),
];

// Elige un destino al azar según su probabilidad.
Destino elegirDestino() {
  final total = destinos.fold<int>(0, (suma, d) => suma + d.probabilidad);
  int tirada = azar.nextInt(total);
  for (final d in destinos) {
    if (tirada < d.probabilidad) return d;
    tirada -= d.probabilidad;
  }
  return destinos.first;
}

const List<String> textosMalaSuerte = [
  'Tropezaste con una piedra, te golpeaste la cabeza y despertaste horas después sin ganar nada.',
  'Viste una taberna en el camino y decidiste tomar unas cervezas en lugar de trabajar.',
  'Te perdiste en el camino y volviste cuando ya era de noche, con las manos vacías.',
  'Un cuervo te robó la bolsa de monedas y te pasaste el día persiguiéndolo.',
  'Te quedaste dormido bajo un árbol y la misión terminó sin ti.',
];

// ====================== TABERNA (TRABAJOS AFK) ======================

// Duración de UNA hora de trabajo (un turno de 1 a 12 horas reales).
// Para probar rápido, cámbialo a Duration(seconds: 10) y devuélvelo antes de publicar.
const Duration duracionHora = Duration(hours: 1);

// Un turno dura de 1 a 12 horas
const int horasMinTaberna = 1;
const int horasMaxTaberna = 12;

// Sueldo por hora de un personaje nivel 1. Crece con el nivel igual que el
// oro de las misiones (factorOroMision). Premium cobra un 20% más.
const int oroPorHoraBase = 60;
const double bonusPremiumTaberna = 0.20;

// Cuántos trabajos aparecen a la vez (entre 5 y 6)
const int ofertasTabernaMin = 5;
const int ofertasTabernaMax = 6;

// Puntos de inclinación al terminar un turno: 1 por cada 3 horas (redondeado hacia arriba)
const int horasPorPuntoTaberna = 3;

// Gemas en la taberna: probabilidad por cada hora trabajada (0.01 = 1%).
// Es mucho más baja que en las misiones. Un turno de 12 horas ≈ 11%.
// Si sale, la cantidad va de 1 a gemasMaxTaberna (lo más común es 1).
const double probGemasPorHoraTaberna = 0.01;
// Con premium la probabilidad por hora sube a 5% (12 horas ≈ 46%).
const double probGemasPorHoraTabernaPremium = 0.05;
const int gemasMaxTaberna = 3;

// Sueldo de UNA hora. Para cambiar el sueldo, toca oroPorHoraBase o los factores.
int pagoPorHoraTaberna(int nivel, bool premium) =>
    (oroPorHoraBase *
        factorOroMision(nivel) *
        (premium ? 1 + bonusPremiumTaberna : 1.0))
        .round();

// Sueldo total de un turno
int pagoTaberna(int nivel, int horas, bool premium) =>
    pagoPorHoraTaberna(nivel, premium) * horas;

// Puntos de inclinación de un turno de [horas] horas
int puntosTaberna(int horas) =>
    (horas + horasPorPuntoTaberna - 1) ~/ horasPorPuntoTaberna;

class Trabajo {
  final String nombre;
  final String descripcion;
  const Trabajo(this.nombre, this.descripcion);
}

// 30 trabajos del camino del BIEN
const List<Trabajo> trabajosBien = [
  Trabajo('Cargar barriles en el muelle',
      'Bajas y apilas barriles de cerveza y pescado salado para los comerciantes del puerto.'),
  Trabajo('Servir mesas en la taberna',
      'Llevas jarras y platos entre los clientes sin derramar una sola gota.'),
  Trabajo('Guardia de la puerta',
      'Vigilas la entrada de la taberna y echas con buenos modales a los borrachos pasados de copas.'),
  Trabajo('Escolta de carretas',
      'Acompañas una caravana de mercaderes por caminos poco seguros.'),
  Trabajo('Patrulla del mercado',
      'Recorres los puestos para evitar robos y mediar en las discusiones.'),
  Trabajo('Reparar el tejado del molino',
      'Subes con tejas y clavos antes de que lleguen las lluvias.'),
  Trabajo('Pastor por un día',
      'Cuidas un rebaño de ovejas y lo mantienes lejos de los lobos.'),
  Trabajo('Cazador de lobos',
      'Rastreas a los lobos que acechan los establos de las granjas vecinas.'),
  Trabajo('Ayudar con la cosecha',
      'Siegas, atas y cargas trigo desde el amanecer hasta el anochecer.'),
  Trabajo('Ayudante del herrero',
      'Manejas el fuelle y levantas el martillo pesado en la fragua del pueblo.'),
  Trabajo('Limpiar el pozo del pueblo',
      'Bajas con cuerdas y cubos para sacar el lodo que enturbia el agua.'),
  Trabajo('Mensajero entre aldeas',
      'Llevas cartas y paquetes por senderos largos y enlodados.'),
  Trabajo('Cuidador de la casa de curación',
      'Cambias vendas, llevas agua y acompañas a los enfermos.'),
  Trabajo('Recolector de hierbas',
      'Buscas hierbas medicinales en el bosque para el curandero.'),
  Trabajo('Maestro de lectura',
      'Enseñas letras y números a los niños de la aldea.'),
  Trabajo('Guía de viajeros',
      'Conduces a forasteros perdidos a través del bosque hasta el camino real.'),
  Trabajo('Vigía de la muralla',
      'Montas guardia sobre la muralla de noche y das la alarma si algo se mueve.'),
  Trabajo('Instructor de reclutas',
      'Enseñas a los nuevos guardias a sostener la espada y el escudo.'),
  Trabajo('Reconstruir un puente',
      'Colocas troncos y cuerdas para reparar el puente que se llevó la tormenta.'),
  Trabajo('Guardián del granero',
      'Proteges las reservas de grano de las ratas y de los ladrones de cosechas.'),
  Trabajo('Pescador del río',
      'Lanzas las redes al amanecer para que el pueblo tenga pescado fresco.'),
  Trabajo('Leñador solidario',
      'Cortas leña y la repartes entre las familias más pobres antes del invierno.'),
  Trabajo('Escolta de peregrinos',
      'Acompañas a un grupo de peregrinos hasta la capilla de la montaña.'),
  Trabajo('Montar la feria',
      'Levantas tablados, toldos y puestos para la fiesta del pueblo.'),
  Trabajo('Mozo de cuadra',
      'Cepillas y alimentas a los caballos de los viajeros.'),
  Trabajo('Buscar a un niño perdido',
      'Rastreas el bosque y los campos hasta encontrar a un niño extraviado.'),
  Trabajo('Reparar las redes',
      'Remiendas redes y botes a la orilla del río para los pescadores.'),
  Trabajo('Repartir pan',
      'Llevas pan caliente a las casas del barrio más pobre.'),
  Trabajo('Cuidador del hospicio',
      'Atiendes a los ancianos del hospicio y escuchas sus historias.'),
  Trabajo('Bombero voluntario',
      'Vigilas los tejados de paja y apagas cualquier chispa antes de que prenda.'),
];

// 30 trabajos del camino del MAL
const List<Trabajo> trabajosMal = [
  Trabajo('Cobrar protección',
      'Visitas a los tenderos y les explicas lo caro que puede salir un accidente.'),
  Trabajo('Contrabandista de aduana',
      'Escondes mercancía prohibida en carretas para pasar sin pagar impuestos.'),
  Trabajo('Carterista de feria',
      'Te mezclas entre la multitud y alivias bolsillos descuidados.'),
  Trabajo('Saqueador de tumbas',
      'Excavas en el cementerio viejo en busca de joyas y reliquias.'),
  Trabajo('Falsificador de documentos',
      'Imitas sellos y firmas del gremio para quien pague bien.'),
  Trabajo('Tahúr de dados cargados',
      'Desplumas a los viajeros con dados que siempre caen a tu favor.'),
  Trabajo('Vendedor de pociones falsas',
      'Embotellas agua teñida y la vendes como elixir milagroso.'),
  Trabajo('Espía a sueldo',
      'Escuchas tras las puertas de un noble y vendes lo que oyes a su rival.'),
  Trabajo('Salteador de caminos',
      'Esperas tras las rocas a los mercaderes con la bolsa más pesada.'),
  Trabajo('Incendiario por encargo',
      'Prendes fuego a un almacén vacío para arruinar a un competidor.'),
  Trabajo('Cazador furtivo',
      'Cazas ciervos en el coto del señor sin que lo sepan los guardabosques.'),
  Trabajo('Susto a un deudor',
      'Haces una visita nocturna a un moroso para que recuerde que debe pagar.'),
  Trabajo('Vendedor de secretos',
      'Compras rumores en la taberna y se los vendes a los bandidos.'),
  Trabajo('Encubridor',
      'Compras mercancía robada por poco y la revendes lejos, a buen precio.'),
  Trabajo('Amañar apuestas',
      'Pagas a un luchador para que pierda y apuestas por su rival.'),
  Trabajo('Saboteador de molinos',
      'Atascas las ruedas del molino de un competidor para que no pueda moler.'),
  Trabajo('Matón de taberna',
      'Pones orden a golpes, pero solo a favor de quien paga la ronda.'),
  Trabajo('Ladrón de cosechas',
      'Llenas sacos en campos ajenos durante la noche.'),
  Trabajo('Testigo falso',
      'Juras en un juicio lo que te pidan, con cara de santo.'),
  Trabajo('Peaje ilegal',
      'Cobras a los viajeros por cruzar un puente que no es tuyo.'),
  Trabajo('Saqueador de ermitas',
      'Vacías las ofrendas de una ermita abandonada.'),
  Trabajo('Contrabando por el río',
      'Remas de noche con barriles de licor sin sello.'),
  Trabajo('Ladrón de mansiones',
      'Trepas por una ventana y te llevas las joyas de la señora de la casa.'),
  Trabajo('Chantajista',
      'Reúnes los secretos de un recaudador y le haces pagar por tu silencio.'),
  Trabajo('Vigilante de escondite',
      'Haces guardia en la guarida de unos bandidos y silbas si llega la ley.'),
  Trabajo('Quemalibros',
      'Destruyes el libro de cuentas de un prestamista a cambio de una buena bolsa.'),
  Trabajo('Fuga de prisioneros',
      'Sobornas al carcelero para que un preso desaparezca de su celda.'),
  Trabajo('Vendedor de reliquias falsas',
      'Envejeces huesos y metales y los vendes como tesoros de santos.'),
  Trabajo('Ladrón de caballos',
      'Sueltas los caballos del señor y los llevas hasta un comprador discreto.'),
  Trabajo('Sobornador de guardias',
      'Repartes monedas entre los guardias para que miren hacia otro lado.'),
];

// ---------- ENCARGOS DE NOBLES ----------
// Cada vez que aparecen en la taberna, se les asigna un noble y un lugar al azar.
// En los textos: {Noble} = "El duque de Valdoria" (con mayúscula inicial),
// {noble} = "el duque de Valdoria", {lugar} = "Valdoria".
// Evita adjetivos o pronombres con género: el noble puede ser hombre o mujer.

const List<String> titulosNobles = [
  'El duque',
  'La duquesa',
  'El lord',
  'La lady',
  'El conde',
  'La condesa',
  'El barón',
  'La baronesa',
  'El marqués',
  'El vizconde',
];

const List<String> lugaresNobles = [
  'Valdoria',
  'Rocaférrea',
  'Montenegro',
  'Altamar',
  'Piedralta',
  'Torrefría',
  'Sombraluz',
  'Puertoespuma',
  'Robleda',
  'Cuervonegro',
  'Aguasclaras',
  'Hierroalto',
  'Brumaverde',
  'Costablanca',
];

class EncargoNoble {
  final String nombre; // puede llevar {lugar}
  final String descripcion; // puede llevar {Noble}, {noble} y {lugar}
  const EncargoNoble(this.nombre, this.descripcion);

  // Crea un Trabajo de verdad con un noble y un lugar al azar
  Trabajo crear() {
    final titulo = titulosNobles[azar.nextInt(titulosNobles.length)];
    final lugar = lugaresNobles[azar.nextInt(lugaresNobles.length)];
    final noble = '$titulo de $lugar';
    String rellenar(String t) => t
        .replaceAll('{Noble}', noble)
        .replaceAll('{noble}', noble[0].toLowerCase() + noble.substring(1))
        .replaceAll('{lugar}', lugar);
    return Trabajo(rellenar(nombre), rellenar(descripcion));
  }
}

// Encargos del camino del BIEN
const List<EncargoNoble> encargosNoblesBien = [
  EncargoNoble('Guardia de la mansión de {lugar}',
      '{Noble} teme por su casa tras oír rumores de ladrones y quiere que la vigiles día y noche.'),
  EncargoNoble('Escolta hasta la corte de {lugar}',
      '{Noble} debe cruzar bosques peligrosos hasta la corte y busca una escolta de confianza. Serás tú.'),
  EncargoNoble('Guardaespaldas en {lugar}',
      '{Noble} tiene miedo: recibió amenazas anónimas y quiere que no te separes de su lado hasta que pase el peligro.'),
  EncargoNoble('Custodiar el tesoro de {lugar}',
      '{Noble} guarda el tesoro familiar en el sótano y quiere que lo custodies mientras se prepara una boda.'),
  EncargoNoble('Vigilar los establos de {lugar}',
      '{Noble} perdió dos caballos en una semana y quiere que vigiles los establos de noche hasta atrapar al culpable.'),
  EncargoNoble('Cazar al lobo de {lugar}',
      '{Noble} ofrece una bolsa a quien acabe con el lobo gigante que ronda sus tierras. Te toca rastrearlo.'),
  EncargoNoble('Proteger la cosecha de {lugar}',
      '{Noble} quiere que protejas los campos de una banda de saqueadores hasta terminar la siega.'),
  EncargoNoble('Mensajero de {lugar}',
      '{Noble} necesita llevar una carta urgente a un aliado y quiere que la entregues sin que nadie la lea.'),
  EncargoNoble('Guardia del banquete de {lugar}',
      '{Noble} da un gran banquete con invitados importantes y quiere que vigiles la sala y evites cualquier problema.'),
  EncargoNoble('Instructor de la guardia de {lugar}',
      '{Noble} quiere que enseñes a sus soldados novatos a sostener la espada y el escudo.'),
  EncargoNoble('Reparto de grano en {lugar}',
      '{Noble} abre sus graneros a los campesinos durante la escasez y quiere que mantengas el orden en la fila.'),
  EncargoNoble('Buscar al heredero de {lugar}',
      '{Noble} ofrece una recompensa a quien encuentre a su heredero, desaparecido en el bosque.'),
  EncargoNoble('Vigía de la torre de {lugar}',
      '{Noble} teme un ataque nocturno y quiere que vigiles desde su torre y des la alarma si ves algo.'),
  EncargoNoble('Reconstruir la capilla de {lugar}',
      '{Noble} promete oro a quien ayude a levantar la capilla del pueblo tras la tormenta.'),
  EncargoNoble('Escoltar víveres desde {lugar}',
      '{Noble} envía ayuda a una aldea vecina y quiere que protejas la carreta con víveres y medicinas.'),
];

// Encargos del camino del MAL
const List<EncargoNoble> encargosNoblesMal = [
  EncargoNoble('Saquear la bodega rival de {lugar}',
      '{Noble} quiere que vacíes la bodega de un rival sin dejar rastro, y paga bien por ello.'),
  EncargoNoble('Incendiar los graneros de un rival de {lugar}',
      '{Noble} paga para que quemes de noche los graneros de un vecino, sin testigos.'),
  EncargoNoble('Chantaje para {lugar}',
      '{Noble} quiere que consigas los secretos de un consejero para obligarlo a votar a su favor.'),
  EncargoNoble('Silenciar a un testigo de {lugar}',
      '{Noble} necesita que cierto testigo olvide lo que vio. Tú sabrás cómo convencerlo.'),
  EncargoNoble('Cobrador de deudas de {lugar}',
      '{Noble} quiere que visites a unos campesinos morosos y les hagas entender la urgencia de pagar.'),
  EncargoNoble('Contrabando para {lugar}',
      '{Noble} quiere que cruces la frontera con barriles de licor y sedas sin pagar el peaje del rey.'),
  EncargoNoble('Robar las joyas de una familia rival de {lugar}',
      '{Noble} te entrega el plano de una mansión rival y te encarga sus joyas.'),
  EncargoNoble('Espiar al consejo de {lugar}',
      '{Noble} te paga por escuchar tras las puertas del consejo y contarle lo que oigas.'),
  EncargoNoble('Guardaespaldas sin preguntas en {lugar}',
      '{Noble} tiene miedo, pero no de bandidos: de acreedores peligrosos. Quiere un guardia que no haga preguntas.'),
  EncargoNoble('Arruinar la siega rival de {lugar}',
      '{Noble} quiere que pises los campos de un rival de noche y espantes a sus jornaleros antes de la cosecha.'),
  EncargoNoble('Sabotear la boda de {lugar}',
      '{Noble} no soporta que un rival se case con una buena dote y quiere que arruines el banquete.'),
  EncargoNoble('Vigilar el sótano de {lugar}',
      '{Noble} guarda a un prisionero en sus sótanos. Tu trabajo es vigilar la puerta y no preguntar.'),
  EncargoNoble('Asaltar la caravana rival de {lugar}',
      '{Noble} quiere que intercepten la caravana de un mercader rival y le lleven la carga.'),
  EncargoNoble('Falsificar un decreto de {lugar}',
      '{Noble} te pide falsificar un decreto con un sello ajeno para quedarse con unas tierras.'),
  EncargoNoble('Sobornar a los jueces de {lugar}',
      '{Noble} quiere que repartas bolsas entre los jueces para ganar un pleito.'),
];

// Colores de los trabajos: azul para el bien, rojo para el mal
Color colorInclinacion(bool esBien) =>
    esBien ? Colors.lightBlueAccent : Colors.redAccent;
Color fondoInclinacion(bool esBien) =>
    esBien ? const Color(0xFF14283A) : const Color(0xFF3A1416);

// ====================== LUGARES DE COMBATE ======================

// Lugares donde se pelea contra enemigos generados por el juego.
// (La Arena, para PvP, todavía no existe como lugar: es "próximamente".)
enum LugarCombate { cripta, ciudadela }

// Un tipo de enemigo que empieza a aparecer desde cierto nivel.
class PlantillaEnemigo {
  final int nivelMin;
  final String nombre;
  const PlantillaEnemigo(this.nivelMin, this.nombre);
}

// Hordas oscuras. Vencerlas da puntos de BIEN.
const List<PlantillaEnemigo> plantillasCripta = [
  PlantillaEnemigo(1, 'Rata de cripta'),
  PlantillaEnemigo(1, 'Esqueleto raquítico'),
  PlantillaEnemigo(3, 'Zombi putrefacto'),
  PlantillaEnemigo(5, 'Necrófago'),
  PlantillaEnemigo(7, 'Espectro aullante'),
  PlantillaEnemigo(10, 'Cultista de sangre'),
  PlantillaEnemigo(13, 'Caballero no muerto'),
  PlantillaEnemigo(16, 'Vampiro nocturno'),
  PlantillaEnemigo(20, 'Liche menor'),
  PlantillaEnemigo(30, 'Demonio de ceniza'),
  PlantillaEnemigo(40, 'Segador de almas'),
  PlantillaEnemigo(60, 'Señor de la cripta'),
  PlantillaEnemigo(90, 'Heraldo del abismo'),
  PlantillaEnemigo(130, 'Lord vampiro'),
  PlantillaEnemigo(170, 'Rey de las hordas oscuras'),
];

// Caballeros y seres de luz (benevolentes). Atacarlos da puntos de MAL.
const List<PlantillaEnemigo> plantillasCiudadela = [
  PlantillaEnemigo(1, 'Novicio de la luz'),
  PlantillaEnemigo(1, 'Aprendiz de monje'),
  PlantillaEnemigo(3, 'Monje guerrero'),
  PlantillaEnemigo(5, 'Acólito de armas'),
  PlantillaEnemigo(7, 'Paladín novato'),
  PlantillaEnemigo(10, 'Caballero de la Luz'),
  PlantillaEnemigo(13, 'Inquisidor sagrado'),
  PlantillaEnemigo(16, 'Guardián alado'),
  PlantillaEnemigo(20, 'Capitán de la Orden'),
  PlantillaEnemigo(30, 'Serafín menor'),
  PlantillaEnemigo(40, 'Campeón celestial'),
  PlantillaEnemigo(60, 'Arcángel guerrero'),
  PlantillaEnemigo(90, 'Custodio del Alba'),
  PlantillaEnemigo(130, 'Gran Maestre de la Luz'),
  PlantillaEnemigo(170, 'Avatar de la Luz'),
];

extension InfoLugarCombate on LugarCombate {
  String get nombre {
    switch (this) {
      case LugarCombate.cripta:
        return 'Cripta';
      case LugarCombate.ciudadela:
        return 'Ciudadela de la Luz';
    }
  }

  String get descripcion {
    switch (this) {
      case LugarCombate.cripta:
        return 'Las hordas oscuras se arrastran bajo la tierra. '
            'Vencerlas te da puntos de bien.';
      case LugarCombate.ciudadela:
        return 'Caballeros y seres de luz custodian este lugar. Son benévolos, '
            'así que atacarlos te da puntos de mal.';
    }
  }

  // true: vencer aquí da puntos de bien. false: da puntos de mal.
  bool get daInclinacionBien => this == LugarCombate.cripta;

  IconData get icono {
    switch (this) {
      case LugarCombate.cripta:
        return Icons.nights_stay;
      case LugarCombate.ciudadela:
        return Icons.wb_sunny;
    }
  }

  List<PlantillaEnemigo> get plantillas {
    switch (this) {
      case LugarCombate.cripta:
        return plantillasCripta;
      case LugarCombate.ciudadela:
        return plantillasCiudadela;
    }
  }
}

// ====================== RAZAS Y PASIVAS ======================

// Habilidad pasiva fija. Cada raza tiene una; algunos enemigos raros tienen una o dos.
enum Pasiva {
  sedSangre,
  ferocidad,
  precision,
  penetracion,
  ambicion,
  masAllaMuerte
}

extension InfoPasiva on Pasiva {
  String get nombre {
    switch (this) {
      case Pasiva.sedSangre:
        return 'Sed de sangre';
      case Pasiva.ferocidad:
        return 'Ferocidad';
      case Pasiva.precision:
        return 'Precisión';
      case Pasiva.penetracion:
        return 'Penetración';
      case Pasiva.ambicion:
        return 'Ambición';
      case Pasiva.masAllaMuerte:
        return 'Más allá de la muerte';
    }
  }

  String get descripcion {
    switch (this) {
      case Pasiva.sedSangre:
        return 'Recuperas ${(sedSangreContraMonstruos * 100).round()}% del daño que haces '
            '(${(sedSangreContraJugadores * 100).round()}% si el golpe cae sobre otro jugador).';
      case Pasiva.ferocidad:
        return 'Tu primer golpe siempre es crítico y tus críticos hacen x$multCriticoFerocidad '
            'en vez de x$multCriticoBase.';
      case Pasiva.precision:
        return 'Tus rivales esquivan un ${(precisionReduceEsquive * 100).round()}% menos.';
      case Pasiva.penetracion:
        return 'Tus golpes ignoran el ${(penetracionDefensa * 100).round()}% de la defensa del rival.';
      case Pasiva.ambicion:
        return 'Ganas un ${(bonoAmbicion * 100).round()}% más de oro y de fama '
            'cuando ganas en la Arena, la Cripta o la Ciudadela.';
      case Pasiva.masAllaMuerte:
        return 'Una vez por combate, si un golpe te dejaría en 0 de vida, '
            'quedas con el ${(masAllaMuerteVida * 100).round()}% de tu vida máxima.';
    }
  }
}

enum Raza { vampiro, orco, elfo, enano, humano, muertoViviente }

extension InfoRaza on Raza {
  String get nombre {
    switch (this) {
      case Raza.vampiro:
        return 'Vampiro';
      case Raza.orco:
        return 'Orco';
      case Raza.elfo:
        return 'Elfo';
      case Raza.enano:
        return 'Enano';
      case Raza.humano:
        return 'Humano';
      case Raza.muertoViviente:
        return 'Muerto viviente';
    }
  }

  Pasiva get pasiva {
    switch (this) {
      case Raza.vampiro:
        return Pasiva.sedSangre;
      case Raza.orco:
        return Pasiva.ferocidad;
      case Raza.elfo:
        return Pasiva.precision;
      case Raza.enano:
        return Pasiva.penetracion;
      case Raza.humano:
        return Pasiva.ambicion;
      case Raza.muertoViviente:
        return Pasiva.masAllaMuerte;
    }
  }
}

// ====================== COMBATIENTES ======================

// Todo lo que cuenta en una pelea. Lo usan por igual el jugador y los enemigos
// (y más adelante los rivales del PvP).
class Combatiente {
  final String nombre;
  final int nivel;
  final bool esJugador;
  final int poder;
  final int vigor;
  final int agilidad;
  final int maestria;
  final int guardia;
  final int aguante;
  final int habArmadura;
  final int habUnaMano;
  final int habDosManos;
  final Objeto? arma;
  final Objeto? escudo;
  final Objeto? armadura;
  final Set<Pasiva> pasivas;

  const Combatiente({
    required this.nombre,
    required this.nivel,
    required this.esJugador,
    required this.poder,
    required this.vigor,
    required this.agilidad,
    required this.maestria,
    required this.guardia,
    required this.aguante,
    this.habArmadura = 0,
    this.habUnaMano = 0,
    this.habDosManos = 0,
    this.arma,
    this.escudo,
    this.armadura,
    this.pasivas = const {},
  });

  int get vidaMaxima => 50 + vigor * 5;

  // Valor de un objeto, mejorado por los puntos de habilidad sobre su mínimo
  static double _valor(Objeto? o, int habilidad) {
    if (o == null) return 0;
    final extra = max(0, habilidad - o.habilidadMin);
    return o.valorMedio * (1 + bonusPorPuntoHabilidad * extra);
  }

  // Igual que _valor, pero sortea un número entre el mínimo y el máximo del objeto
  static double _tirada(Objeto? o, int habilidad) {
    if (o == null) return 0;
    final extra = max(0, habilidad - o.habilidadMin);
    final base = o.danoMin + azar.nextInt(o.danoMax - o.danoMin + 1);
    return base * (1 + bonusPorPuntoHabilidad * extra);
  }

  int get _habilidadArma =>
      arma?.tipo == TipoObjeto.armaDosManos ? habDosManos : habUnaMano;

  // Sin arma se pelea a puños (valor 1)
  double get ataque =>
      (arma == null ? 1.0 : _valor(arma, _habilidadArma)) + poder / 2;

  double get defensa =>
      _valor(armadura, habArmadura) +
          _valor(escudo, habArmadura) +
          guardia / 2;

  // Ataque y defensa de UN golpe: el arma y la armadura sortean su rango
  double get ataqueTirada =>
      (arma == null ? 1.0 : _tirada(arma, _habilidadArma)) + poder / 2;

  double get defensaTirada =>
      _tirada(armadura, habArmadura) +
          _tirada(escudo, habArmadura) +
          guardia / 2;
}

// Un lado de la pelea mientras se simula
class _Lado {
  final Combatiente c;
  int hp;
  int danoHecho = 0;
  int criticos = 0;
  int golpeMax = 0;
  bool primerGolpe = true;
  bool segundoAlientoUsado = false;
  _Lado(this.c, this.hp);
}

class ResultadoCombate {
  final int vidaA; // vida que le queda al luchador A (el jugador)
  final int vidaB;
  final int rondas;
  final int danoA; // daño que hizo A
  final int danoB;
  final List<String> log;
  final int criticosA; // críticos que hizo A
  final int golpeMaxA; // su golpe más fuerte
  const ResultadoCombate(
      this.vidaA, this.vidaB, this.rondas, this.danoA, this.danoB, this.log,
      {this.criticosA = 0, this.golpeMaxA = 0});
}

// Rondas que un luchador aguanta sin cansarse
int rondasFrescas(Combatiente c) => rondasFrescasBase + c.aguante ~/ 2;

// 1.0 = descansado. Baja con cada ronda de cansancio, hasta [fatigaMinima].
double factorFatiga(Combatiente c, int ronda) {
  final frescas = rondasFrescas(c);
  if (ronda <= frescas) return 1.0;
  return max(fatigaMinima, 1 - fatigaPorRonda * (ronda - frescas));
}

// Un golpe de [at] contra [df]. Puede esquivarse, ser crítico y curar al atacante.
void _golpear(_Lado at, _Lado df, int ronda, List<String>? partes) {
  final a = at.c;
  final d = df.c;

  // ---- Esquive ----
  double probEsquive = d.agilidad / (d.agilidad + a.agilidad + 90);
  if (a.pasivas.contains(Pasiva.precision)) {
    probEsquive *= 1 - precisionReduceEsquive;
  }
  probEsquive = min(probEsquive * factorFatiga(d, ronda), topeEsquive);
  if (azar.nextDouble() < probEsquive) {
    if (partes != null) {
      if (d.esJugador && !a.esJugador) {
        partes.add('Esquivas el golpe de ${a.nombre}.');
      } else if (a.esJugador && !d.esJugador) {
        partes.add('${d.nombre} esquiva tu golpe.');
      } else {
        partes.add('${d.nombre} esquiva el golpe de ${a.nombre}.');
      }
    }
    return;
  }

  // ---- Crítico ----
  final ferocidad = a.pasivas.contains(Pasiva.ferocidad);
  final probCritico = min(topeCritico, a.maestria / (a.maestria + 190));
  final critico =
      (ferocidad && at.primerGolpe) || azar.nextDouble() < probCritico;
  at.primerGolpe = false;

  // ---- Daño ----
  final penetra = a.pasivas.contains(Pasiva.penetracion);
  final defensa = d.defensaTirada * (penetra ? 1 - penetracionDefensa : 1.0);
  final k = defensaConstanteBase + defensaConstantePorNivel * a.nivel;
  double dano = a.ataqueTirada * k / (k + defensa);
  dano *= 0.85 + azar.nextDouble() * 0.3;
  dano *= factorFatiga(a, ronda);
  if (critico) dano *= ferocidad ? multCriticoFerocidad : multCriticoBase;
  final golpe = max(1, dano.round());
  df.hp -= golpe;
  at.danoHecho += golpe;
  if (critico) at.criticos++;
  if (golpe > at.golpeMax) at.golpeMax = golpe;

  // ---- Más allá de la muerte ----
  bool revive = false;
  if (df.hp <= 0 &&
      !df.segundoAlientoUsado &&
      d.pasivas.contains(Pasiva.masAllaMuerte)) {
    df.segundoAlientoUsado = true;
    df.hp = max(1, (d.vidaMaxima * masAllaMuerteVida).round());
    revive = true;
  }

  // ---- Sed de sangre ----
  int cura = 0;
  if (a.pasivas.contains(Pasiva.sedSangre)) {
    final pct =
    d.esJugador ? sedSangreContraJugadores : sedSangreContraMonstruos;
    cura = min((golpe * pct).round(), a.vidaMaxima - at.hp);
    if (cura > 0) at.hp += cura;
  }

  if (partes != null) {
    final marca = critico ? ' (¡crítico!)' : '';
    // Si el arma tiene nombre propio, aparece en el relato (entre marcadores
    // para pintarlo en turquesa; ver textoRonda).
    final apodo = a.arma?.apodo;
    final con = apodo == null ? '' : ' con $marcaApodoIni$apodo$marcaApodoFin';
    String texto;
    if (a.esJugador && !d.esJugador) {
      texto = 'Golpeas a ${d.nombre}$con por $golpe$marca.';
    } else if (d.esJugador && !a.esJugador) {
      texto = '${a.nombre} te golpea por $golpe$marca.';
    } else {
      texto = '${a.nombre} golpea a ${d.nombre}$con por $golpe$marca.';
    }
    if (cura > 0) {
      texto += a.esJugador
          ? ' Recuperas $cura de vida.'
          : ' ${a.nombre} recupera $cura de vida.';
    }
    if (revive) {
      texto += (d.esJugador && !a.esJugador)
          ? ' ¡Vuelves de entre los muertos con ${df.hp} de vida!'
          : ' ¡${d.nombre} vuelve de entre los muertos con ${df.hp} de vida!';
    }
    partes.add(texto);
  }
}

// Simula una pelea completa entre A (el jugador) y B. [vidaA] permite empezar
// con la vida actual del jugador; B siempre empieza con la vida máxima.
ResultadoCombate simularCombate(Combatiente a, Combatiente b,
    {int? vidaA, int? vidaB, int? maxRondas, bool conLog = true}) {
  final ladoA = _Lado(a, vidaA ?? a.vidaMaxima);
  final ladoB = _Lado(b, vidaB ?? b.vidaMaxima);
  final tope = maxRondas ?? maxRondasCombate;
  final log = <String>[];
  final aPrimero = a.agilidad >= b.agilidad;
  int ronda = 0;

  while (ladoA.hp > 0 && ladoB.hp > 0 && ronda < tope) {
    ronda++;
    final partes = conLog ? <String>[] : null;
    if (partes != null) {
      for (final l in [ladoA, ladoB]) {
        if (ronda == rondasFrescas(l.c) + 1) {
          partes.add(l.c.esJugador
              ? 'Empiezas a cansarte.'
              : '${l.c.nombre} empieza a cansarse.');
        }
      }
    }
    final primero = aPrimero ? ladoA : ladoB;
    final segundo = aPrimero ? ladoB : ladoA;
    _golpear(primero, segundo, ronda, partes);
    if (segundo.hp > 0) _golpear(segundo, primero, ronda, partes);
    if (partes != null) log.add('Ronda $ronda: ${partes.join(' ')}');
  }

  return ResultadoCombate(max(0, ladoA.hp), max(0, ladoB.hp), ronda,
      ladoA.danoHecho, ladoB.danoHecho, log,
      criticosA: ladoA.criticos, golpeMaxA: ladoA.golpeMax);
}

// ====================== ENEMIGOS GENERADOS ======================

enum EstiloArma { unaMano, dosManos, ninguna }

// Un "perfil" de enemigo: cómo reparte sus puntos y qué equipo usa.
// Hay perfiles comunes y otros muy raros (con un atributo en 0 y otro exagerado).
class Arquetipo {
  final String nombre;
  final double rareza; // peso para salir: más alto = más común
  // Reparto de los puntos: poder, vigor, agilidad, maestría, guardia, aguante.
  // Un 0 significa 0 puntos en ese atributo.
  final List<double> pesos;
  final EstiloArma arma;
  // 0 = no usa, 1 = lo mejor que permite su nivel
  final double calidadArma;
  final double calidadEscudo;
  final double calidadArmadura;
  // Multiplicador de sus puntos totales en cada nivel de [nivelesAnclaje]
  // (entre un nivel y otro se interpola). Salen de simular miles de peleas
  // para que cada perfil sea parejo con un jugador normal de su nivel.
  final List<double> fuerzas;
  final Set<Pasiva> pasivas;

  const Arquetipo(this.nombre, this.rareza, this.pesos, this.arma,
      this.calidadArma, this.calidadEscudo, this.calidadArmadura, this.fuerzas,
      {this.pasivas = const {}});

  Arquetipo conFuerzas(List<double> f) => Arquetipo(nombre, rareza, pesos, arma,
      calidadArma, calidadEscudo, calidadArmadura, f,
      pasivas: pasivas);

  // Fuerza que le toca a un enemigo de nivel [n]
  double fuerzaEn(int n) {
    if (n <= nivelesAnclaje.first) return fuerzas.first;
    for (int i = 1; i < nivelesAnclaje.length; i++) {
      if (n <= nivelesAnclaje[i]) {
        final t = (n - nivelesAnclaje[i - 1]) /
            (nivelesAnclaje[i] - nivelesAnclaje[i - 1]);
        return fuerzas[i - 1] + (fuerzas[i] - fuerzas[i - 1]) * t;
      }
    }
    return fuerzas.last;
  }
}

// Niveles en los que se calibró la fuerza de cada perfil
const List<int> nivelesAnclaje = [1, 3, 5, 10, 20, 40, 80, 200];

const List<Arquetipo> arquetipos = [
  // ---------------- COMUNES ----------------
  Arquetipo('Equilibrado', 12, [1, 1, 1, 1, 1, 1], EstiloArma.unaMano, 1.0, 0.7,
      0.7, [1.06, 1.05, 1.06, 1.11, 1.13, 1.09, 1.08, 1.06]),
  Arquetipo('Soldado', 10, [1, 1.5, 0.5, 0.5, 1.5, 1.2], EstiloArma.unaMano,
      1.0, 1.0, 1.0, [0.86, 0.92, 0.94, 0.99, 1.06, 1.08, 1.11, 1.11]),
  Arquetipo('Bruto', 10, [2, 1.5, 0.5, 0.5, 0.5, 1], EstiloArma.dosManos, 1.0,
      0, 0.4, [0.80, 0.89, 0.78, 0.92, 0.95, 0.95, 0.96, 0.97]),
  // ---------------- POCO COMUNES ----------------
  Arquetipo('Duelista', 6, [1.2, 0.6, 2, 1.5, 0.4, 1], EstiloArma.unaMano, 1.0,
      0, 0.3, [1.33, 1.41, 1.43, 1.43, 1.42, 1.29, 1.23, 1.19]),
  Arquetipo('Cañón de cristal', 5, [3, 0.2, 1, 1.5, 0, 0.8],
      EstiloArma.dosManos, 1.0, 0, 0,
      [1.26, 1.53, 1.40, 1.76, 1.77, 1.59, 1.52, 1.48]),
  Arquetipo('Muro', 5, [0.8, 2.5, 0.2, 0, 3, 2], EstiloArma.unaMano, 1.0, 1.0,
      1.0, [0.69, 0.90, 0.92, 1.04, 1.21, 1.35, 1.45, 1.44]),
  // ---------------- RAROS ----------------
  Arquetipo('Fantasma', 3, [1, 0.8, 4, 1, 0, 1], EstiloArma.unaMano, 1.0, 0, 0,
      [1.75, 1.71, 1.67, 1.65, 1.55, 1.40, 1.31, 1.27]),
  Arquetipo('Velocista', 3, [2.5, 0.5, 2, 2, 0.3, 0], EstiloArma.unaMano, 1.0,
      0, 0, [1.23, 1.30, 1.29, 1.39, 1.34, 1.18, 1.13, 1.10]),
  Arquetipo('Maratonista', 3, [0.8, 2, 0.5, 0.2, 1.5, 4], EstiloArma.unaMano,
      1.0, 0, 0.6, [1.05, 1.20, 1.24, 1.53, 1.64, 1.64, 1.67, 1.67]),
  Arquetipo('Puños desnudos', 2, [4, 1.5, 1.2, 1, 0.3, 1], EstiloArma.ninguna,
      0, 0, 0.6, [0.89, 1.06, 0.98, 1.20, 1.18, 1.08, 1.02, 0.96]),
  Arquetipo('Embestida', 2, [2.5, 1, 0.5, 0.5, 2.5, 1], EstiloArma.ninguna, 0,
      1.0, 1.0, [0.87, 1.01, 1.02, 1.20, 1.23, 1.19, 1.20, 1.17]),
  // ---------------- MUY RAROS (con pasiva) ----------------
  Arquetipo('Sanguijuela', 1.2, [1.5, 1.5, 1, 1, 0.8, 1.5], EstiloArma.unaMano,
      1.0, 0.5, 0.6, [0.96, 0.93, 0.94, 1.04, 1.06, 1.04, 1.03, 1.01],
      pasivas: {Pasiva.sedSangre}),
  Arquetipo('Salvaje', 1.2, [2, 0.8, 1.5, 2, 0.3, 0.8], EstiloArma.dosManos,
      1.0, 0, 0, [1.12, 1.17, 0.96, 1.12, 1.03, 1.00, 0.97, 0.99],
      pasivas: {Pasiva.ferocidad}),
  Arquetipo('Cazador', 1.2, [1.5, 1, 1.5, 1.5, 0.8, 1], EstiloArma.unaMano,
      1.0, 0, 0.5, [1.08, 1.10, 1.07, 1.13, 1.12, 1.03, 0.98, 0.95],
      pasivas: {Pasiva.precision}),
  Arquetipo('Rompeescudos', 1.2, [2, 1.2, 0.8, 0.8, 1, 1], EstiloArma.dosManos,
      1.0, 0, 0.6, [0.82, 0.90, 0.72, 0.91, 0.89, 0.93, 0.94, 0.94],
      pasivas: {Pasiva.penetracion}),
  Arquetipo('Señor de la guerra', 0.5, [2, 2, 1, 1, 1, 1.5],
      EstiloArma.dosManos, 1.0, 0, 1.0,
      [0.79, 0.86, 0.65, 0.78, 0.76, 0.83, 0.89, 0.90],
      pasivas: {Pasiva.sedSangre, Pasiva.penetracion}),
];

Arquetipo _elegirArquetipo() {
  final total = arquetipos.fold<double>(0, (s, a) => s + a.rareza);
  double t = azar.nextDouble() * total;
  for (final a in arquetipos) {
    if (t < a.rareza) return a;
    t -= a.rareza;
  }
  return arquetipos.first;
}

class Enemigo {
  final Combatiente c;
  final String perfil; // nombre del arquetipo
  final int oroMin;
  final int oroMax;
  final int fama; // fama base (el cambio real depende de la diferencia de nivel)

  const Enemigo(this.c, this.perfil, this.oroMin, this.oroMax, this.fama);

  String get nombre => c.nombre;
  int get nivel => c.nivel;
}

// Elige el nombre entre los 3 tipos de enemigo más avanzados que ya
// pueden aparecer a ese nivel.
String _nombreEnemigo(LugarCombate lugar, int nivel) {
  final aptas = lugar.plantillas.where((p) => p.nivelMin <= nivel).toList();
  final desde = max(0, aptas.length - 3);
  return aptas[desde + azar.nextInt(aptas.length - desde)].nombre;
}

// El mejor objeto de ese tipo que permite el nivel (calidad 1) o uno más modesto.
Objeto? _elegirObjeto(TipoObjeto tipo, int nivel, double calidad) {
  if (calidad <= 0) return null;
  final opciones = catalogo
      .where((o) =>
  o.tipo == tipo &&
      o.nivelRequerido <= nivel &&
      !o.bazar &&
      !o.conGemas)
      .toList()
    ..sort((a, b) => a.valorMedio.compareTo(b.valorMedio));
  if (opciones.isEmpty) return null;
  return opciones[((opciones.length - 1) * calidad).round()];
}

Objeto? _elegirArma(Arquetipo arq, int nivel) {
  switch (arq.arma) {
    case EstiloArma.unaMano:
      return _elegirObjeto(TipoObjeto.armaUnaMano, nivel, arq.calidadArma);
    case EstiloArma.dosManos:
    // Si todavía no hay armas de dos manos a ese nivel, usa una de una mano
      return _elegirObjeto(TipoObjeto.armaDosManos, nivel, arq.calidadArma) ??
          _elegirObjeto(TipoObjeto.armaUnaMano, nivel, arq.calidadArma);
    case EstiloArma.ninguna:
      return null;
  }
}

// Crea un enemigo del nivel pedido con un perfil al azar (o el indicado).
// Sus puntos totales crecen con el nivel y se reparten según el perfil.
Enemigo generarEnemigo(LugarCombate lugar, int nivelDeseado,
    {Arquetipo? arquetipo}) {
  final n = min(max(nivelDeseado, 1), nivelMaximo);
  final arq = arquetipo ?? _elegirArquetipo();

  // Puntos de atributo: un jugador de nivel n "normal" tiene unos
  // atributoInicial + 2.5 por nivel en cada uno de los 6 atributos. Las
  // "fuerzas" de cada perfil se calibraron cuando el jugador empezaba en 10;
  // el factor de abajo mantiene esa misma proporción ahora que empieza en 5
  // (jugador normal de nivel n: 30 + 15n puntos; antes: 60 + 15n).
  final presupuesto =
      (45 + 15 * n) *
          ((30 + 15 * n) / (60 + 15 * n)) *
          arq.fuerzaEn(n) *
          factorDificultadPve;
  final suma = arq.pesos.fold<double>(0, (s, p) => s + p);
  int puntos(int i) {
    final w = arq.pesos[i];
    if (w <= 0) return 0;
    return max(
        0, (presupuesto * w / suma * (0.92 + azar.nextDouble() * 0.16)).round());
  }

  // Equipo. El arma de dos manos no se combina con escudo.
  final arma = _elegirArma(arq, n);
  var escudo = _elegirObjeto(TipoObjeto.escudo, n, arq.calidadEscudo);
  if (arma?.tipo == TipoObjeto.armaDosManos) escudo = null;
  final armadura = _elegirObjeto(TipoObjeto.armadura, n, arq.calidadArmadura);

  // Habilidades: lo mínimo que piden sus objetos, más algunos puntos extra
  final extraMax = 1 + n ~/ 10;
  int extra() => azar.nextInt(extraMax + 1);
  int habArmadura = 0;
  if (armadura != null || escudo != null) {
    habArmadura =
        max(armadura?.habilidadMin ?? 0, escudo?.habilidadMin ?? 0) + extra();
  }
  int habUnaMano = 0;
  int habDosManos = 0;
  if (arma != null) {
    if (arma.tipo == TipoObjeto.armaDosManos) {
      habDosManos = arma.habilidadMin + extra();
    } else {
      habUnaMano = arma.habilidadMin + extra();
    }
  }

  final oroMedio = 1 + 2 * n + 0.5 * n * n;
  return Enemigo(
    Combatiente(
      nombre: _nombreEnemigo(lugar, n),
      nivel: n,
      esJugador: false,
      poder: puntos(0),
      vigor: puntos(1),
      agilidad: puntos(2),
      maestria: puntos(3),
      guardia: puntos(4),
      aguante: puntos(5),
      habArmadura: habArmadura,
      habUnaMano: habUnaMano,
      habDosManos: habDosManos,
      arma: arma,
      escudo: escudo,
      armadura: armadura,
      pasivas: arq.pasivas,
    ),
    arq.nombre,
    (oroMedio * 0.7).round(),
    (oroMedio * 1.3).round(),
    famaBasePelea(n),
  );
}

// ====================== JEFES ======================
// Un jefe es un combate especial: más fuerte que un enemigo normal de su
// nivel y con pasivas propias. Solo se puede intentar 1 vez por día cada uno.
// Dan SOLO oro: no mueven la fama ni los puntos de bien/mal.

// Qué tan fuerte es un jefe respecto a un enemigo normal de su perfil base
const double fuerzaJefe = 1.15;
// Oro medio de un jefe = oro medio de un enemigo normal de su nivel x esto
const double multOroJefe = 10.0;
// La primera vez que vences a un jefe cobras este multiplicador extra de oro
// (se suma: 1.0 = otro tanto igual).
const double bonoPrimeraVictoriaJefe = 2.0;
const int intentosJefePorDia = 1;

class Jefe {
  final String nombre;
  final int nivelMin; // nivel del jugador para poder desafiarlo
  final String perfilBase; // arquetipo del que toma el reparto de puntos
  final Set<Pasiva> pasivas;
  final String descripcion;
  const Jefe(this.nombre, this.nivelMin, this.perfilBase, this.pasivas,
      this.descripcion);

  // El jefe es un poco más fuerte que tú al desbloquearlo.
  int get nivel => min(nivelMin + 2, nivelMaximo);

  Arquetipo get arquetipo {
    final base = arquetipos.firstWhere((a) => a.nombre == perfilBase);
    return Arquetipo(nombre, 1, base.pesos, base.arma, base.calidadArma,
        base.calidadEscudo, base.calidadArmadura,
        [for (final f in base.fuerzas) f * fuerzaJefe],
        pasivas: pasivas);
  }

  int get oroMedio {
    final n = nivel;
    return ((1 + 2 * n + 0.5 * n * n) * multOroJefe).round();
  }

  int get oroMin => (oroMedio * 0.9).round();
  int get oroMax => (oroMedio * 1.1).round();
}

const List<Jefe> jefes = [
  Jefe('Gorlak el Devorador', 5, 'Bruto', {Pasiva.sedSangre},
      'Un ogro hambriento que se cura con cada mordisco.'),
  Jefe('Sor Mirela la Pálida', 10, 'Duelista', {Pasiva.precision},
      'Una duelista que casi nunca falla un golpe.'),
  Jefe('El Carcelero Hueco', 15, 'Muro', {Pasiva.masAllaMuerte},
      'Una armadura vacía que se niega a caer a la primera.'),
  Jefe('Varkhul Rompehuesos', 20, 'Rompeescudos', {Pasiva.penetracion},
      'Su martillo atraviesa cualquier defensa.'),
  Jefe('Reina Morwenna', 25, 'Sanguijuela', {Pasiva.sedSangre},
      'Bebe la vida de quien se atreve a mirarla.'),
  Jefe('El Heraldo sin Rostro', 30, 'Fantasma', {Pasiva.precision},
      'Se mueve entre las sombras y golpea donde duele.'),
  Jefe('Ghorrath Cuernoférreo', 35, 'Salvaje', {Pasiva.ferocidad},
      'Su primer golpe siempre es un crítico.'),
  Jefe('Lord Ashkaran', 40, 'Señor de la guerra',
      {Pasiva.sedSangre, Pasiva.penetracion},
      'Un general inmortal que ignora tu armadura y se cura con tu sangre.'),
  Jefe('La Abadesa de Ceniza', 45, 'Maratonista', {Pasiva.masAllaMuerte},
      'Aguanta más que nadie y vuelve de entre los muertos.'),
  Jefe('Malrik, Rey Cadáver', 50, 'Soldado',
      {Pasiva.masAllaMuerte, Pasiva.penetracion, Pasiva.ferocidad},
      'Un rey muerto que no se deja derrotar sin sufrir.'),
  Jefe('Brakka la Quebrantahuesos', 55, 'Bruto',
      {Pasiva.ferocidad},
      'Rompe huesos con cada golpe y siempre empieza con un crítico.'),
  Jefe('El Cardenal Escarlata', 60, 'Sanguijuela',
      {Pasiva.sedSangre, Pasiva.masAllaMuerte},
      'Un sacerdote que bebe sangre y se levanta cuando lo creías muerto.'),
  Jefe('Nythra, Voz del Abismo', 65, 'Fantasma',
      {Pasiva.precision, Pasiva.masAllaMuerte},
      'Su susurro te desorienta; sus golpes nunca fallan.'),
  Jefe('Colmillo Negro', 70, 'Velocista',
      {Pasiva.ferocidad, Pasiva.sedSangre},
      'Una bestia veloz que te desgarra y se cura con tu sangre.'),
  Jefe('El Gólem de Hueso', 75, 'Muro',
      {Pasiva.penetracion, Pasiva.masAllaMuerte},
      'Una pila de huesos que atraviesa tu defensa y se rearma al caer.'),
  Jefe('Sir Aldric el Caído', 80, 'Soldado',
      {Pasiva.penetracion, Pasiva.sedSangre},
      'Un antiguo paladín que ya no responde a ninguna luz.'),
  Jefe('Vesper, la Dama sin Piel', 85, 'Duelista',
      {Pasiva.precision, Pasiva.ferocidad},
      'Una esgrimista implacable: no falla y golpea fuerte primero.'),
  Jefe('Thorgar Puño de Trueno', 90, 'Puños desnudos',
      {Pasiva.ferocidad, Pasiva.penetracion},
      'No necesita armas: sus puños atraviesan cualquier armadura.'),
  Jefe('El Coloso Encadenado', 95, 'Embestida',
      {Pasiva.masAllaMuerte, Pasiva.sedSangre},
      'Rompió sus cadenas y no piensa volver a caer.'),
  Jefe('Azrael, Primer Verdugo', 100, 'Señor de la guerra',
      {Pasiva.sedSangre, Pasiva.penetracion, Pasiva.ferocidad},
      'El verdugo original. Mucho oro para quien lo derrote.'),
  Jefe('La Bruja de las Mil Agujas', 105, 'Cazador',
      {Pasiva.precision, Pasiva.penetracion},
      'Sus agujas encuentran el hueco de cualquier armadura.'),
  Jefe('Dragón de Ceniza', 110, 'Cañón de cristal',
      {Pasiva.ferocidad, Pasiva.penetracion},
      'Pega como un derrumbe, pero se rompe rápido.'),
  Jefe('Karn el Interminable', 115, 'Maratonista',
      {Pasiva.sedSangre, Pasiva.masAllaMuerte},
      'Nunca se cansa y siempre vuelve a levantarse.'),
  Jefe('El Segador Mudo', 120, 'Fantasma',
      {Pasiva.ferocidad, Pasiva.precision},
      'Un golpe crítico de apertura y ninguno que falle.'),
  Jefe('Hidra de Sangre', 125, 'Sanguijuela',
      {Pasiva.sedSangre, Pasiva.masAllaMuerte, Pasiva.penetracion},
      'Cada cabeza cortada deja una más sedienta.'),
  Jefe('Orlok, Príncipe Vampiro', 130, 'Equilibrado',
      {Pasiva.sedSangre, Pasiva.precision},
      'Elegante, preciso y hambriento.'),
  Jefe('El Titán Podrido', 135, 'Bruto',
      {Pasiva.masAllaMuerte, Pasiva.penetracion},
      'Un gigante en descomposición que no cae ni con tu mejor ataque.'),
  Jefe('Isolde, Tejedora de Pesadillas', 140, 'Duelista',
      {Pasiva.precision, Pasiva.masAllaMuerte},
      'Sus pesadillas la mantienen en pie cuando debería caer.'),
  Jefe('Balrog Menor', 145, 'Salvaje',
      {Pasiva.ferocidad, Pasiva.sedSangre},
      'Fuego, furia y un apetito por tu vida.'),
  Jefe('Kaelthas el Sin Nombre', 150, 'Señor de la guerra',
      {Pasiva.sedSangre, Pasiva.penetracion, Pasiva.masAllaMuerte},
      'Un general al que ni la muerte quiso quedarse.'),
  Jefe('El Juez Eterno', 155, 'Soldado',
      {Pasiva.penetracion, Pasiva.masAllaMuerte},
      'Dicta sentencia y no acepta apelaciones.'),
  Jefe('Nidhogg, Devorador de Raíces', 160, 'Rompeescudos',
      {Pasiva.penetracion, Pasiva.sedSangre},
      'Muerde la base del mundo y todo lo que lo protege.'),
  Jefe('Serafiel Caído', 165, 'Velocista',
      {Pasiva.ferocidad, Pasiva.precision},
      'Alas rotas, golpes certeros y una velocidad cruel.'),
  Jefe('El Leviatán Seco', 170, 'Muro',
      {Pasiva.masAllaMuerte, Pasiva.sedSangre},
      'Una muralla viva que se cura a costa tuya.'),
  Jefe('Madre de las Plagas', 175, 'Maratonista',
      {Pasiva.sedSangre, Pasiva.precision, Pasiva.masAllaMuerte},
      'Resiste todo, enferma todo y nunca termina.'),
  Jefe('Gorthak Rompemundos', 180, 'Embestida',
      {Pasiva.ferocidad, Pasiva.penetracion},
      'Embiste sin armas y atraviesa todo a su paso.'),
  Jefe('El Archilich Vaskar', 185, 'Cañón de cristal',
      {Pasiva.precision, Pasiva.penetracion, Pasiva.ferocidad},
      'Magia vieja convertida en golpes devastadores.'),
  Jefe('Sombra del Último Rey', 190, 'Fantasma',
      {Pasiva.sedSangre, Pasiva.masAllaMuerte, Pasiva.precision},
      'Lo que queda de un rey que se negó a morir.'),
  Jefe('Behemot Eterno', 195, 'Bruto',
      {Pasiva.ferocidad, Pasiva.masAllaMuerte, Pasiva.penetracion},
      'Una montaña de furia que ignora tu defensa.'),
  Jefe('Drakhul, Señor del Dominio de Sangre', 200, 'Señor de la guerra',
      {Pasiva.sedSangre, Pasiva.penetracion, Pasiva.ferocidad, Pasiva.masAllaMuerte},
      'El último jefe. Quien lo venza es leyenda en todo el Dominio.'),
];

// Crea al jefe listo para pelear (mismos puntos y equipo que el perfil base).
Enemigo generarJefe(Jefe j) {
  final base = generarEnemigo(LugarCombate.cripta, j.nivel,
      arquetipo: j.arquetipo);
  final b = base.c;
  return Enemigo(
    Combatiente(
      nombre: j.nombre,
      nivel: b.nivel,
      esJugador: false,
      poder: b.poder,
      vigor: b.vigor,
      agilidad: b.agilidad,
      maestria: b.maestria,
      guardia: b.guardia,
      aguante: b.aguante,
      habArmadura: b.habArmadura,
      habUnaMano: b.habUnaMano,
      habDosManos: b.habDosManos,
      arma: b.arma,
      escudo: b.escudo,
      armadura: b.armadura,
      pasivas: j.pasivas,
    ),
    'Jefe',
    j.oroMin,
    j.oroMax,
    0,
  );
}

// ====================== EVENTO: EL INMORTAL (DOMINGOS) ======================
// Los domingos aparece LaBestiaPapuuu el Inmortal. No se le puede matar: el
// combate dura [rondasInmortal] rondas o hasta que caigas. Tu oro es el daño
// que le hagas x [multOroInmortal]. SIN tope de oro. 1 intento por domingo.

// Qué tan fuerte es respecto a un enemigo normal de tu mismo nivel (1.25 = +25%)
const double fuerzaInmortal = 1.25;
const int multOroInmortal = 10;
const int rondasInmortal = 40;
const String nombreInmortal = 'LaBestiaPapuuu el Inmortal';
const int vidaInfinitaInmortal = 1000000000;

// Día del servidor del domingo más reciente (hoy, si es domingo).
String ultimoDomingo() {
  final n = RelojServidor.ahora();
  final d = n.subtract(Duration(days: n.weekday % 7));
  return '${d.year}-${d.month}-${d.day}';
}

// Nombre del campo del perfil donde se guarda tu daño de ese domingo.
// Cada domingo usa un campo distinto, así el ranking no pide índices nuevos.
String campoInmortal(String dia) => 'ind_${dia.replaceAll('-', '_')}';

// Mario escalado a TU nivel (sus stats y equipo salen del perfil "Soldado").
Enemigo generarInmortal(int nivel) {
  final base = arquetipos.firstWhere((a) => a.nombre == 'Soldado');
  final arq = Arquetipo(nombreInmortal, 1, base.pesos, base.arma,
      base.calidadArma, base.calidadEscudo, base.calidadArmadura,
      [for (final f in base.fuerzas) f * fuerzaInmortal],
      pasivas: {Pasiva.ferocidad, Pasiva.penetracion});
  final b = generarEnemigo(LugarCombate.cripta, nivel, arquetipo: arq).c;
  return Enemigo(
    Combatiente(
      nombre: nombreInmortal,
      nivel: b.nivel,
      esJugador: false,
      poder: b.poder,
      vigor: b.vigor,
      agilidad: b.agilidad,
      maestria: b.maestria,
      guardia: b.guardia,
      aguante: b.aguante,
      habArmadura: b.habArmadura,
      habUnaMano: b.habUnaMano,
      habDosManos: b.habDosManos,
      arma: b.arma,
      escudo: b.escudo,
      armadura: b.armadura,
      pasivas: arq.pasivas,
    ),
    'Inmortal',
    0,
    0,
    0,
  );
}

// ====================== HISTORIAL DE COMBATES ======================

// Cuántos combates se guardan por pestaña (PvE y, más adelante, Arena).
const int maxHistorialCombates = 30;

// Una tarjeta de personaje congelada en el momento del combate.
// Marcadores invisibles que encierran el nombre propio de un arma en el relato
// de las rondas. textoRonda los convierte en letras turquesa brillantes.
const String marcaApodoIni = '\uE000';
const String marcaApodoFin = '\uE001';

// Una línea del relato de una ronda, con el nombre de las armas con apodo en
// turquesa brillante. Sin marcadores se ve como un texto normal.
Widget textoRonda(String linea, TextStyle estilo) {
  if (!linea.contains(marcaApodoIni) && !linea.contains(marcaApodoFin)) {
    return Text(linea, style: estilo);
  }
  const brillo = TextStyle(
    fontWeight: FontWeight.bold,
    color: Color(0xFFB8FFF8),
    shadows: [
      Shadow(color: Color(0xFF00F5E0), blurRadius: 6),
      Shadow(color: Color(0xAA00F5E0), blurRadius: 14),
    ],
  );
  final partes = <InlineSpan>[];
  var dentro = false;
  var buffer = StringBuffer();
  void cerrar() {
    if (buffer.isEmpty) return;
    partes.add(TextSpan(text: buffer.toString(), style: dentro ? brillo : null));
    buffer = StringBuffer();
  }

  for (final r in linea.runes) {
    final c = String.fromCharCode(r);
    if (c == marcaApodoIni) {
      cerrar();
      dentro = true;
    } else if (c == marcaApodoFin) {
      cerrar();
      dentro = false;
    } else {
      buffer.write(c);
    }
  }
  cerrar();
  return Text.rich(TextSpan(children: partes), style: estilo);
}

class FichaCombate {
  final String nombre;
  final int nivel;
  final String perfil; // raza/arquetipo o ''
  final int vidaMaxima;
  final int ataque;
  final int defensa;
  final Map<String, int> atributos; // Poder, Vigor, Agilidad, ...
  final String arma;
  final String escudo;
  final String armadura;
  // Afilados y apodo del arma (solo para mostrarlos en la pantalla de batalla).
  final int armaAfilado;
  final String? armaApodo;
  const FichaCombate(this.nombre, this.nivel, this.perfil, this.vidaMaxima,
      this.ataque, this.defensa, this.atributos, this.arma, this.escudo,
      this.armadura,
      {this.armaAfilado = 0, this.armaApodo});

  factory FichaCombate.de(Combatiente c, {String perfil = ''}) => FichaCombate(
    c.nombre,
    c.nivel,
    perfil,
    c.vidaMaxima,
    c.ataque.round(),
    c.defensa.round(),
    {
      'Poder': c.poder,
      'Vigor': c.vigor,
      'Agilidad': c.agilidad,
      'Maestría': c.maestria,
      'Guardia': c.guardia,
      'Aguante': c.aguante,
    },
    c.arma?.nombre ?? 'Sin arma',
    c.escudo?.nombre ?? 'Sin escudo',
    c.armadura?.nombre ?? 'Sin armadura',
    armaAfilado: c.arma?.afilado ?? 0,
    armaApodo: c.arma?.apodo,
  );

  Map<String, dynamic> toMap() => {
    'n': nombre,
    'v': nivel,
    'p': perfil,
    'vm': vidaMaxima,
    'at': ataque,
    'df': defensa,
    'a': atributos,
    'ar': arma,
    'es': escudo,
    'am': armadura,
    if (armaAfilado > 0) 'af': armaAfilado,
    if (armaApodo != null) 'ap': armaApodo,
  };

  factory FichaCombate.fromMap(Map<String, dynamic> m) => FichaCombate(
    (m['n'] ?? '?') as String,
    _aEntero(m['v']),
    (m['p'] ?? '') as String,
    _aEntero(m['vm']),
    _aEntero(m['at']),
    _aEntero(m['df']),
    {
      if (m['a'] is Map)
        for (final e in (m['a'] as Map).entries)
          e.key.toString(): _aEntero(e.value),
    },
    (m['ar'] ?? 'Sin arma') as String,
    (m['es'] ?? 'Sin escudo') as String,
    (m['am'] ?? 'Sin armadura') as String,
    armaAfilado: _aEntero(m['af']),
    armaApodo: m['ap'] as String?,
  );
}

int _aEntero(dynamic v) => (v as num?)?.toInt() ?? 0;

// Recorta las rondas para que el historial guardado en la nube no pese demasiado.
List<String> _recortarLog(List<String> log) => [
  for (final l in log.take(40)) l.length > 160 ? l.substring(0, 160) : l,
];

// Un combate ya terminado, con todo lo que hace falta para mostrarlo.
class RegistroCombate {
  final DateTime fecha;
  final String lugar; // 'Cripta', 'Ciudadela' o 'Arena'
  final String resultado; // 'victoria', 'derrota' o 'empate'
  final FichaCombate yo;
  final FichaCombate rival;
  final int rondas;
  final int danoHecho;
  final int danoRecibido;
  final int oro;
  final int fama; // positivo, negativo o 0
  final int puntosInclinacion;
  final bool inclinacionBien;
  final bool subioNivel;
  final List<String> log; // una línea por ronda
  const RegistroCombate({
    required this.fecha,
    required this.lugar,
    required this.resultado,
    required this.yo,
    required this.rival,
    required this.rondas,
    required this.danoHecho,
    required this.danoRecibido,
    required this.oro,
    required this.fama,
    required this.puntosInclinacion,
    required this.inclinacionBien,
    required this.subioNivel,
    required this.log,
  });

  Map<String, dynamic> toMap() => {
    'f': fecha.millisecondsSinceEpoch,
    'l': lugar,
    'r': resultado,
    'yo': yo.toMap(),
    'rv': rival.toMap(),
    'ro': rondas,
    'dh': danoHecho,
    'dr': danoRecibido,
    'o': oro,
    'fa': fama,
    'pi': puntosInclinacion,
    'ib': inclinacionBien,
    'sn': subioNivel,
    'lg': _recortarLog(log),
  };

  // Copia con otro monto de oro (se usa al registrar defensas: el oro que
  // realmente perdiste se conoce recién al procesar el ataque).
  RegistroCombate conOro(int nuevoOro) => RegistroCombate(
    fecha: fecha,
    lugar: lugar,
    resultado: resultado,
    yo: yo,
    rival: rival,
    rondas: rondas,
    danoHecho: danoHecho,
    danoRecibido: danoRecibido,
    oro: nuevoOro,
    fama: fama,
    puntosInclinacion: puntosInclinacion,
    inclinacionBien: inclinacionBien,
    subioNivel: subioNivel,
    log: log,
  );

  factory RegistroCombate.fromMap(Map<String, dynamic> m) => RegistroCombate(
    fecha: DateTime.fromMillisecondsSinceEpoch(_aEntero(m['f'])),
    lugar: (m['l'] ?? '') as String,
    resultado: (m['r'] ?? 'empate') as String,
    yo: FichaCombate.fromMap(Map<String, dynamic>.from(m['yo'] as Map)),
    rival: FichaCombate.fromMap(Map<String, dynamic>.from(m['rv'] as Map)),
    rondas: _aEntero(m['ro']),
    danoHecho: _aEntero(m['dh']),
    danoRecibido: _aEntero(m['dr']),
    oro: _aEntero(m['o']),
    fama: _aEntero(m['fa']),
    puntosInclinacion: _aEntero(m['pi']),
    inclinacionBien: m['ib'] == true,
    subioNivel: m['sn'] == true,
    log: List<String>.from((m['lg'] as List?) ?? const []),
  );
}

// ====================== ESTADO DEL JUEGO ======================

enum Genero { hombre, mujer }

class EstadoJuego extends ChangeNotifier {
  EstadoJuego() {
    // Equipo inicial: se agrega al inventario y queda equipado.
    for (final nombreObjeto in equipoInicial) {
      final o = catalogo.firstWhere((x) => x.nombre == nombreObjeto);
      inventario.add(o);
      equipado[o.tipo.ranura] = o;
    }
    // Trabajos que se ven al abrir la taberna por primera vez
    _generarOfertas(true);
    _generarOfertas(false);
  }

  String nombre = 'Aventurero';
  int nivel = 1;
  int oro = 500;
  int gemas = 0; // moneda premium (todavía sin valor real ni compra)
  int xp = 0; // en pantalla se llama "Fama"
  int puntosLibres = puntosHabilidadIniciales; // sin repartir (3 por nivel)
  // Negativo = mal, positivo = bien. Casi sin límite (ver limiteInclinacion).
  int alineamiento = 0;
  Genero genero = Genero.hombre;
  Raza raza = Raza.vampiro; // su pasiva es la habilidad fija de la raza

  // Es false hasta que el jugador crea su personaje (pantalla inicial).
  bool personajeCreado = false;

  // Premium por tiempo: se compra por días (7 o 30) y los días se suman.
  // premiumHasta es el instante (en UTC) en que termina. Debe guardarse en la nube.
  DateTime? premiumHasta;

  bool get premium =>
      premiumHasta != null && RelojServidor.instante().isBefore(premiumHasta!);

  // Solo para código viejo que haga "premium = false". Un "true" se ignora a
  // propósito: el premium se obtiene únicamente con agregarPremium().
  set premium(bool v) {
    if (!v) premiumHasta = null;
  }

  // Suma [dias] días de premium (desde hoy, o desde que termina el actual).
  void agregarPremium(int dias) {
    final ahora = RelojServidor.instante();
    final base = (premiumHasta != null && premiumHasta!.isAfter(ahora))
        ? premiumHasta!
        : ahora;
    premiumHasta = base.add(Duration(days: dias));
    notifyListeners();
  }

  // Bloques de misión gastados en el día guardado en diaMisiones.
  // Para saber cuántos llevas HOY usa bloquesUsadosHoy.
  int bloquesHoy = 0;
  String diaMisiones = '';

  // ---- Mercado negro (bazar) ----
  // Día (del servidor) de la última renovación y nombres de los objetos que
  // quedan a la venta hoy. Cada uno tiene 1 sola unidad: al comprarlo sale de
  // la lista hasta la próxima renovación.
  String bazarDia = '';
  List<String> bazarOfertas = [];
  // De las ofertas de hoy, las que son armas de la Tienda con descuento.
  List<String> bazarRebaja = [];

  // Jefes: cuáles intentaste hoy (se renueva cada día) y cuáles ya venciste
  // alguna vez (para la bonificación de primera victoria). Se guardan en la nube.
  String jefesDia = '';
  List<String> jefesHoy = [];
  List<String> jefesVencidos = [];
  final Map<String, Enemigo> _jefesGenerados = {};

  // Evento del Inmortal: día (del servidor) de tu último intento, el daño que
  // hiciste y el oro que ganaste. Se guarda en la nube.
  String inmortalDia = '';
  int inmortalDano = 0;
  int inmortalOro = 0;

  // Dados de la taberna: partidas jugadas hoy (se renueva cada día). Se guarda
  // en la nube para que no se pueda reiniciar el límite cerrando el juego.
  String dadosDia = '';
  int dadosPartidas = 0;
  int get dadosPartidasHoy =>
      dadosDia == RelojServidor.dia ? dadosPartidas : 0;

  // Empieza una partida: descuenta la apuesta y cuenta la partida del día.
  // Devuelve un mensaje solo si no se puede jugar.
  String? empezarPartidaDados(int apuesta) {
    if (dadosPartidasHoy >= partidasDadosPorDia) {
      return 'Ya jugaste $partidasDadosPorDia partidas hoy. Vuelve mañana.';
    }
    if (apuesta <= 0) return 'Elige una apuesta.';
    if (oro < apuesta) return 'No tienes tanto oro para apostar.';
    oro -= apuesta;
    dadosPartidas = dadosPartidasHoy + 1;
    dadosDia = RelojServidor.dia;
    notifyListeners();
    return null;
  }

  // Paga una partida ganada (la apuesta ya se descontó al empezar).
  int cobrarDados(int apuesta) {
    final premio = (apuesta * pagoDados).round();
    oro += premio;
    notifyListeners();
    return premio;
  }

  bool get esDomingoServidor => RelojServidor.ahora().weekday == DateTime.sunday;
  bool get inmortalIntentadoHoy => inmortalDia == RelojServidor.dia;

  Enemigo enemigoJefe(Jefe j) =>
      _jefesGenerados.putIfAbsent(j.nombre, () => generarJefe(j));

  bool jefeDesbloqueado(Jefe j) => nivel >= j.nivelMin;
  bool jefeIntentadoHoy(Jefe j) =>
      jefesDia == RelojServidor.dia && jefesHoy.contains(j.nombre);
  bool jefeVencido(Jefe j) => jefesVencidos.contains(j.nombre);

  // Lo que cuesta hoy un objeto en el Mercado negro.
  int precioBazar(Objeto o) => bazarRebaja.contains(o.nombre)
      ? max(1, (o.precio * (1 - bazarDescuento)).round())
      : o.precio;

  // Objetos del Bazar que quedan a la venta ahora.
  List<Objeto> get bazarDisponibles => [
    for (final n in bazarOfertas)
      for (final o in catalogo)
        if (o.nombre == n) o
  ];

  // Si cambió el día, sortea ofertas nuevas (pueden repetirse las de ayer).
  // Solo entran objetos hasta [nivelesExtraTienda] niveles sobre el tuyo.
  void actualizarBazar({bool avisar = true}) {
    if (bazarDia == RelojServidor.dia) return;
    final azar = Random();
    final nivelMax = nivel + nivelesExtraTienda;
    final delBazar = catalogo
        .where((o) => o.bazar && o.nivelRequerido <= nivelMax)
        .toList()
      ..shuffle(azar);
    // Objetos de la Tienda (de cualquier tipo: armas, escudos, armaduras,
    // anillos, colgantes) que pueden salir con descuento.
    final delaTienda = catalogoTienda
        .where((o) => o.nivelRequerido <= nivelMax && o.precio >= 20)
        .toList()
      ..shuffle(azar);
    // Cantidad del día: 2, 3 o 4, todas igual de probables.
    final cantidad =
        bazarMinPorDia + azar.nextInt(bazarMaxPorDia - bazarMinPorDia + 1);
    final ofertas = <String>[];
    final rebajas = <String>[];
    for (var i = 0; i < cantidad; i++) {
      var deTienda = azar.nextDouble() < bazarProbRebaja;
      var lista = deTienda ? delaTienda : delBazar;
      if (lista.isEmpty) {
        // Si en esa lista no queda nada, se usa la otra.
        deTienda = !deTienda;
        lista = deTienda ? delaTienda : delBazar;
      }
      if (lista.isEmpty) break;
      final o = lista.removeLast();
      ofertas.add(o.nombre);
      if (deTienda) rebajas.add(o.nombre);
    }
    bazarDia = RelojServidor.dia;
    bazarOfertas = ofertas;
    bazarRebaja = rebajas;
    if (avisar) notifyListeners();
  }

  // Compra una unidad del Bazar. Se agota hasta la próxima renovación.
  String comprarBazar(Objeto o) {
    if (!bazarOfertas.contains(o.nombre)) return 'Ese objeto ya se agotó';
    final msg = comprar(o, precio: precioBazar(o));
    if (msg.startsWith('Compraste')) {
      bazarOfertas = bazarOfertas.where((n) => n != o.nombre).toList();
      bazarRebaja = bazarRebaja.where((n) => n != o.nombre).toList();
      notifyListeners();
    }
    return msg;
  }

  // Vida: baja al pelear y se recupera sola con el tiempo.
  // La vida máxima depende del Vigor: 50 + 5 por cada punto.
  int vidaActual = 100;
  DateTime _vidaActualizada = DateTime.now();
  // Incluye lo que suma o resta tu equipo al Vigor (nunca baja de 0 puntos).
  int get vidaMaxima => 50 + atributoTotal('Vigor') * 5;

  // Vida actual, contando la recuperación del tiempo transcurrido.
  // Solo calcula: no modifica nada al leerla.
  int get vida {
    if (vidaActual >= vidaMaxima) return vidaMaxima;
    final ms = DateTime.now().difference(_vidaActualizada).inMilliseconds;
    final recuperada =
    (ms * vidaMaxima / regeneracionCompleta.inMilliseconds).floor();
    return min(vidaMaxima, max(vidaActual, 0) + max(recuperada, 0));
  }

  // Guarda en vidaActual la recuperación acumulada hasta ahora.
  // Se llama justo ANTES de cambiar la vida o la vida máxima.
  void _asentarVida() {
    final actual = vida;
    if (actual >= vidaMaxima) {
      _vidaActualizada = DateTime.now();
    } else {
      // Avanza el reloj solo lo que "pagaron" los puntos recuperados,
      // para no perder los decimales entre una consulta y otra.
      final ganados = actual - max(vidaActual, 0);
      _vidaActualizada = _vidaActualizada.add(Duration(
          milliseconds: (ganados *
              regeneracionCompleta.inMilliseconds /
              vidaMaxima)
              .round()));
    }
    vidaActual = actual;
  }

  // Último combate
  String? textoCombate;
  List<String> logCombate = [];
  LugarCombate? lugarUltimoCombate;

  // Historial de combates contra la cripta y la ciudadela (PvE). El más
  // nuevo va primero. Guarda hasta [maxHistorialCombates].
  // OJO: por ahora vive solo en memoria; para que sobreviva al cerrar el
  // juego hay que guardarlo junto con el resto de la partida en la nube.
  final List<RegistroCombate> historialPvE = [];

  // Sube con cada combate nuevo: Nube lo usa para saber cuándo guardar.
  int versionHistorial = 0;

  void _guardarRegistroPvE(RegistroCombate r) {
    versionHistorial++;
    historialPvE.insert(0, r);
    if (historialPvE.length > maxHistorialCombates) {
      historialPvE.removeRange(maxHistorialCombates, historialPvE.length);
    }
  }

  // Rivales a la vista en cada lugar de combate.
  // "cercanos": los 4 rivales de poder similar o mayor. "aleatorio": uno
  // de cualquier nivel. Al pelear en un lugar, sus rivales desaparecen.
  final Map<LugarCombate, List<Enemigo>> cercanos = {
    for (final l in LugarCombate.values) l: <Enemigo>[],
  };
  final Map<LugarCombate, Enemigo?> aleatorio = {
    for (final l in LugarCombate.values) l: null,
  };

  // Las 3 habilidades
  int habArmadura = 0; // armadura y escudo
  int habUnaMano = 0; // armas de una mano
  int habDosManos = 0; // armas de dos manos

  // Objeto equipado en cada ranura (null = vacía)
  final Map<Ranura, Objeto?> equipado = {
    for (final r in Ranura.values) r: null,
  };

  final List<Objeto> inventario = [];

  // Atributos: se suben pagando oro en la pestaña Entrenar. Todos empiezan en
  // [atributoInicial]. El precio de cada punto NO depende de este valor
  // (depende de cuántos puntos compraste), y no hay tope: con oro se puede
  // subir tanto como se quiera.
  final Map<String, int> atributos = {
    'Poder': atributoInicial,
    'Vigor': atributoInicial,
    'Agilidad': atributoInicial,
    'Maestría de combate': atributoInicial,
    'Guardia': atributoInicial,
    'Aguante': atributoInicial,
  };

  // Cuántos puntos has comprado de cada atributo (para calcular el precio)
  final Map<String, int> puntosEntrenados = {
    'Poder': 0,
    'Vigor': 0,
    'Agilidad': 0,
    'Maestría de combate': 0,
    'Guardia': 0,
    'Aguante': 0,
  };

  // --- Misión en curso ---
  bool misionEsBien = true;
  int misionBloques = 0;
  Destino? misionDestino; // se decide al empezar, pero no se muestra
  DateTime? misionTermina;
  String? ultimoResultado;

  // Fama que falta para el siguiente nivel (0 si ya estás en el máximo)
  int famaParaSiguienteNivel() =>
      nivel >= nivelMaximo ? 0 : famaParaSubir(nivel);

  // Gasta 1 punto libre en una habilidad.
  // tipo: 'armadura', 'unaMano' o 'dosManos'
  void subirHabilidad(String tipo) {
    if (puntosLibres <= 0) return;
    switch (tipo) {
      case 'armadura':
        habArmadura++;
        break;
      case 'unaMano':
        habUnaMano++;
        break;
      case 'dosManos':
        habDosManos++;
        break;
      default:
        return;
    }
    puntosLibres--;
    notifyListeners();
  }

  // Precio actual del siguiente punto de un atributo
  int precioDe(String clave) =>
      precioEntrenamiento(clave, puntosEntrenados[clave]!);

  // Compra 1 punto de atributo con oro. Devuelve un mensaje.
  String entrenar(String clave) {
    final tope = topeEntrenamiento(clave);
    if (tope != null && atributoTotal(clave) >= tope) {
      return '$clave ya está en su tope ($tope). No se puede entrenar más';
    }
    final precio = precioDe(clave);
    if (oro < precio) return 'No te alcanza el oro ($precio necesarios)';
    // Antes de subir la vida máxima, se guarda la recuperación acumulada.
    if (clave == 'Vigor') _asentarVida();
    oro -= precio;
    atributos[clave] = atributos[clave]! + 1;
    puntosEntrenados[clave] = puntosEntrenados[clave]! + 1;
    if (clave == 'Vigor') vidaActual += 5; // sube la vida máxima y la actual
    logros.stats.sumar('entrenados');
    diarias.sumar('entrenar');
    revisarLogros();
    notifyListeners();
    final topeAhora = topeEntrenamiento(clave);
    if (topeAhora != null && atributoTotal(clave) >= topeAhora) {
      return '$clave sube a ${atributos[clave]}. ¡Llegaste al tope! '
          'Ya no se puede seguir entrenando';
    }
    return '$clave sube a ${atributos[clave]}';
  }

  // Cuántos puntos tienes en la habilidad que pide este objeto.
  // Anillos y colgantes no usan habilidad.
  int habilidadPara(Objeto o) {
    switch (o.tipo) {
      case TipoObjeto.armadura:
      case TipoObjeto.escudo:
        return habArmadura;
      case TipoObjeto.armaUnaMano:
        return habUnaMano;
      case TipoObjeto.armaDosManos:
        return habDosManos;
      case TipoObjeto.anillo:
      case TipoObjeto.colgante:
        return 0;
    }
  }

  // Si el objeto pide inclinación y no la tienes, devuelve el motivo (si no, null).
  // Positivo = puntos de bien mínimos; negativo = puntos de mal mínimos.
  String? motivoInclinacion(Objeto o) {
    final req = o.inclinacion;
    if (req > 0 && alineamiento < req) {
      return 'Necesitas $req puntos de bien (tienes ${max(0, alineamiento)})';
    }
    if (req < 0 && alineamiento > req) {
      return 'Necesitas ${-req} puntos de mal (tienes ${max(0, -alineamiento)})';
    }
    return null;
  }

  // Devuelve null si puedes equiparlo, o el motivo si no puedes.
  String? motivoNoEquipable(Objeto o) {
    if (nivel < o.nivelRequerido) {
      return 'Necesitas nivel ${o.nivelRequerido}';
    }
    final motivoInc = motivoInclinacion(o);
    if (motivoInc != null) return motivoInc;
    if (habilidadPara(o) < o.habilidadMin) {
      return 'Necesitas ${o.habilidadMin} puntos de habilidad';
    }
    // Un arma de dos manos y un escudo no se pueden usar a la vez.
    if (o.tipo == TipoObjeto.armaDosManos && equipado[Ranura.escudo] != null) {
      return 'Quita el escudo: el arma de dos manos usa ambas manos';
    }
    if (o.tipo == TipoObjeto.escudo &&
        equipado[Ranura.arma]?.tipo == TipoObjeto.armaDosManos) {
      return 'Tienes un arma de dos manos equipada';
    }
    return null;
  }

  // Comprar solo pide oro. Para equiparlo hacen falta nivel y habilidad.
  // Se puede comprar el mismo objeto las veces que quieras: en el inventario
  // se ven apilados (x2, x3...).
  String comprar(Objeto o, {int? precio}) {
    final costo = precio ?? o.precio;
    if (o.conGemas) {
      if (gemas < costo) return 'No te alcanzan las gemas';
      gemas -= costo;
    } else {
      if (oro < costo) return 'No te alcanza el oro';
      oro -= costo;
    }
    inventario.add(o);
    logros.stats.sumar('comprados');
    revisarLogros();
    notifyListeners();
    return 'Compraste ${o.nombre}';
  }

  // Equipa [o]. Si das [en], lo pone en esa ranura (sirve para elegir el anillo
  // I o el II). Sin [en], un anillo va al primer hueco libre y, si los dos
  // están ocupados, reemplaza al anillo I.
  String equipar(Objeto o, {Ranura? en}) {
    final motivo = motivoNoEquipable(o);
    if (motivo != null) return motivo;
    Ranura destino = en ?? o.tipo.ranura;
    if (en == null && o.tipo == TipoObjeto.anillo) {
      if (equipado[Ranura.anillo] == null) {
        destino = Ranura.anillo;
      } else if (equipado[Ranura.anillo2] == null) {
        destino = Ranura.anillo2;
      } else {
        destino = Ranura.anillo;
      }
    }
    // No puedes llevar más copias puestas que las que tienes.
    final enOtras = equipado.entries
        .where((e) => e.key != destino && e.value == o)
        .length;
    if (enOtras >= cantidadDe(o)) return 'Ya lo llevas puesto en otra casilla';
    _asentarVida(); // el equipo puede cambiar la vida máxima
    equipado[destino] = o;
    notifyListeners();
    return 'Equipaste ${o.nombreMostrado}';
  }

  // Equipa un objeto en una ranura concreta (lo usa la pantalla de armado).
  String equiparEn(Ranura ranura, Objeto o) {
    final esAnilloEnRanuraAnillo = o.tipo == TipoObjeto.anillo &&
        (ranura == Ranura.anillo || ranura == Ranura.anillo2);
    if (o.tipo.ranura != ranura && !esAnilloEnRanuraAnillo) {
      return 'Ese objeto no va en esa ranura';
    }
    return equipar(o, en: ranura);
  }

  void desequipar(Ranura ranura) {
    _asentarVida(); // el equipo puede cambiar la vida máxima
    equipado[ranura] = null;
    notifyListeners();
  }

  // Cuántas copias de [o] lleva puestas (un anillo puede estar en las 2 ranuras).
  int copiasEquipadas(Objeto o) =>
      equipado.values.where((x) => x == o).length;

  bool estaEquipado(Objeto o) => copiasEquipadas(o) > 0;

  // Quita [o] de la ranura donde esté puesto (en un anillo, de la última).
  void desequiparObjeto(Objeto o) {
    final ranura = equipado.entries.lastWhere(
          (e) => e.value == o,
      orElse: () => MapEntry(o.tipo.ranura, null),
    );
    if (ranura.value == null) return;
    desequipar(ranura.key);
  }

  // ---------- AFILADOR AMBULANTE ----------

  // Cambia UNA copia de [o] por [nueva]. Si todas tus copias están puestas,
  // cambia la que llevas puesta; si no, una de las que guardas.
  void _cambiarCopia(Objeto o, Objeto nueva) {
    final i = inventario.indexWhere((x) => x == o);
    if (i < 0) return;
    final puestas = copiasEquipadas(o);
    final todasPuestas = puestas >= cantidadDe(o);
    _asentarVida();
    inventario[i] = nueva;
    if (todasPuestas && puestas > 0) {
      final ranura = equipado.entries.firstWhere((e) => e.value == o).key;
      equipado[ranura] = nueva;
    }
  }

  bool _esArma(Objeto o) =>
      o.tipo == TipoObjeto.armaUnaMano || o.tipo == TipoObjeto.armaDosManos;

  // Afila UNA copia de [o] (+1 de daño).
  String afilar(Objeto o) {
    if (!_esArma(o)) return 'El afilador solo trabaja con armas';
    if (o.afilado >= afiladosMax) return 'Esta arma ya está afilada al máximo';
    if (gemas < costoAfilado) return 'No te alcanzan las gemas';
    if (!inventario.contains(o)) return 'No tienes esa arma';
    final nueva = o.conAfilado(o.afilado + 1);
    gemas -= costoAfilado;
    _cambiarCopia(o, nueva);
    notifyListeners();
    return '${o.nombreMostrado} afilada: +${nueva.afilado} de daño';
  }

  // Le pone un nombre a UNA copia del arma (cuesta [costoRenombrar] gemas).
  String renombrar(Objeto o, String texto) {
    if (!_esArma(o)) return 'Solo se puede nombrar a las armas';
    final limpio = texto.replaceAll('|', '').trim();
    if (limpio.isEmpty) return 'Escribe un nombre';
    if (limpio.length > largoMaxApodo) {
      return 'El nombre puede tener hasta $largoMaxApodo letras';
    }
    if (o.apodo == limpio) return 'Ya tiene ese nombre';
    if (gemas < costoRenombrar) return 'No te alcanzan las gemas';
    if (!inventario.contains(o)) return 'No tienes esa arma';
    gemas -= costoRenombrar;
    _cambiarCopia(o, o.conApodo(limpio));
    notifyListeners();
    return 'Ahora se llama "$limpio"';
  }

  // ---------- APILADO Y VENTA ----------

  // Cuántas copias de este objeto tienes (incluida la equipada).
  // Las copias afiladas cuentan aparte: "Espada +1" no es lo mismo que "Espada".
  int cantidadDe(Objeto o) => inventario.where((x) => x == o).length;

  // Copias del objeto sin importar su afilado (para la Tienda y el Mercado negro).
  int cantidadPorNombre(Objeto o) =>
      inventario.where((x) => x.nombre == o.nombre).length;

  // Copias que puedes vender: la equipada no se vende (hay que quitarla antes).
  int disponiblesParaVender(Objeto o) =>
      max(0, cantidadDe(o) - copiasEquipadas(o));

  // Cuánto te pagan por UNA copia (en la misma moneda con la que se compra).
  int valorVenta(Objeto o) => max(1, (o.precio * porcentajeVenta).floor());

  // Vende [cantidad] copias (las que se puedan). Devuelve un mensaje.
  String vender(Objeto o, {int cantidad = 1}) {
    final n = min(cantidad, disponiblesParaVender(o));
    if (n <= 0) {
      return cantidadDe(o) == 0
          ? 'No tienes ${o.nombreMostrado}'
          : 'Quita ${o.nombreMostrado} antes de venderlo';
    }
    int quitados = 0;
    inventario.removeWhere((x) {
      if (quitados < n && x == o) {
        quitados++;
        return true;
      }
      return false;
    });
    final total = valorVenta(o) * n;
    if (o.conGemas) {
      gemas += total;
    } else {
      oro += total;
    }
    logros.stats.sumar('vendidos', n);
    if (valorVenta(o) == 1) logros.stats.fijar('tacano');
    revisarLogros();
    notifyListeners();
    return 'Vendiste ${n > 1 ? '$n x ' : ''}${o.nombreMostrado} por $total '
        '${o.conGemas ? 'esquirlas' : 'de oro'}';
  }

  // ---------- BONOS DEL EQUIPO ----------

  // Cuánto suma (o resta) tu equipo a un atributo. Lo dan todos los
  // objetos (armas, escudos, armaduras, anillos y colgantes). Se usa en la pelea y se publica en el perfil de la Arena.
  int bonoEquipo(String clave) {
    int total = 0;
    for (final o in equipado.values) {
      if (o != null) total += o.bonos[clave] ?? 0;
    }
    return total;
  }

  // Atributo entrenado + bono del equipo (nunca menos de 0)
  int atributoTotal(String clave) =>
      max(0, atributos[clave]! + bonoEquipo(clave));

  // ---------- MÉTODOS QUE USAN LA ARENA Y NUBE (desde otros archivos) ----------

  // notifyListeners solo se puede llamar desde esta clase; esto lo abre.
  void avisarCambio() => notifyListeners();

  // Estadísticas y logros (ver logros.dart)
  final DatosLogros logros = DatosLogros();
  // Desafíos diarios y premios (ver diarias.dart)
  final DatosDiarias diarias = DatosDiarias();
  // Bestiario: bestias descubiertas y premios (ver bestiario.dart)
  final DatosBestiario bestiario = DatosBestiario();
  void revisarLogros() => logros.actualizar(this);

  // Deja la vida en [nueva] y reinicia el reloj de recuperación.
  void fijarVida(int nueva) {
    vidaActual = max(0, min(nueva, vidaMaxima));
    _vidaActualizada = DateTime.now();
  }

  // Sube de nivel si ya juntaste la fama necesaria.
  // Si subes de nivel, la vida se te recupera por completo.
  void _revisarSubidaDeNivel() {
    final nivelAntes = nivel;
    revisarSubidaDeNivel(this);
    if (nivel > nivelAntes) fijarVida(vidaMaxima);
  }

  // Lo usa la Arena (otro archivo), por eso es público.
  void revisarNivel() => _revisarSubidaDeNivel();

  // ---------- COMBATE ----------

  // Tu personaje tal como entra a una pelea (atributos + equipo + pasiva de raza)
  Combatiente get comoCombatiente => Combatiente(
    nombre: nombre,
    nivel: nivel,
    esJugador: true,
    poder: atributoTotal('Poder'),
    vigor: atributoTotal('Vigor'),
    agilidad: atributoTotal('Agilidad'),
    maestria: atributoTotal('Maestría de combate'),
    guardia: atributoTotal('Guardia'),
    aguante: atributoTotal('Aguante'),
    habArmadura: habArmadura,
    habUnaMano: habUnaMano,
    habDosManos: habDosManos,
    arma: equipado[Ranura.arma],
    escudo: equipado[Ranura.escudo],
    armadura: equipado[Ranura.armadura],
    pasivas: {raza.pasiva},
  );

  // Ataque y defensa totales del personaje (atributos + equipo + habilidades).
  // La inclinación de los objetos no da bonos: solo es un requisito para equiparlos.
  int get ataqueTotal => comoCombatiente.ataque.round();

  int get defensaTotal => comoCombatiente.defensa.round();

  // ---------- BÚSQUEDA DE RIVALES ----------

  // Busca 4 rivales de poder similar o mayor.
  // Es gratis si no hay búsqueda a la vista; si ya hay una, actualizarla cuesta oro.
  String? buscarCercanos(LugarCombate lugar) {
    if (cercanos[lugar]!.isNotEmpty) {
      if (oro < costoActualizarBusqueda) {
        return 'Necesitas $costoActualizarBusqueda de oro para actualizar la búsqueda';
      }
      oro -= costoActualizarBusqueda;
    }
    final nuevos = List<Enemigo>.generate(enemigosPorBusqueda, (_) {
      final dif = difNivelMin + azar.nextInt(difNivelMax - difNivelMin + 1);
      return generarEnemigo(lugar, max(1, min(nivelMaximo, nivel + dif)));
    });
    nuevos.sort((a, b) => a.nivel.compareTo(b.nivel));
    cercanos[lugar] = nuevos;
    notifyListeners();
    return null;
  }

  // Busca 1 rival de cualquier nivel (de 1 al máximo).
  // Gratis la primera vez; buscar otro cuesta oro.
  String? buscarAleatorio(LugarCombate lugar) {
    if (aleatorio[lugar] != null) {
      if (oro < costoActualizarBusqueda) {
        return 'Necesitas $costoActualizarBusqueda de oro para buscar otro rival';
      }
      oro -= costoActualizarBusqueda;
    }
    aleatorio[lugar] = generarEnemigo(lugar, 1 + azar.nextInt(nivelMaximo));
    notifyListeners();
    return null;
  }

  // ---------- PELEA ----------

  // Ambición: suma el bono a una ganancia (oro o fama). Solo si es positiva.
  int conBonoAmbicion(int base) {
    if (raza.pasiva != Pasiva.ambicion || base <= 0) return base;
    return (base * (1 + bonoAmbicion)).round();
  }

  // Pelea contra un enemigo en un lugar. Devuelve un mensaje solo si no se puede pelear.
  String? pelearEn(LugarCombate lugar, Enemigo e) {
    if (trabajando) {
      return 'Estás trabajando en la taberna. Termina o abandona el trabajo para pelear.';
    }
    if (vida < vidaMaxima * vidaMinimaParaPelear) {
      return 'Estás demasiado herido para pelear. Descansa un poco.';
    }

    final miFicha = FichaCombate.de(comoCombatiente);
    final r = simularCombate(comoCombatiente, e.c, vidaA: vida);
    final ronda = r.rondas;
    final danoHecho = r.danoA;
    final danoRecibido = r.danoB;
    datosPvp.pveDano += danoHecho; // para el ranking

    // La vida que te queda, y el reloj de recuperación vuelve a empezar
    vidaActual = max(0, r.vidaA);
    _vidaActualizada = DateTime.now();

    final nivelAntes = nivel;
    int regOro = 0;
    int regFama = 0;
    int regPuntos = 0;

    if (r.vidaB <= 0) {
      // ---- Victoria ----
      // El oro normal del enemigo, reducido si es de tu nivel o menor.
      final oroBruto = e.oroMin + azar.nextInt(e.oroMax - e.oroMin + 1);
      final oroGanado = conBonoAmbicion(
          max(1, (oroBruto * porcentajeOroPveDe(nivel, e.nivel)).round()));
      final cambioFama = conBonoAmbicion(cambioFamaPve(nivel, e.nivel, true));
      final puntos = puntosInclinacionCombate(e.nivel);
      regOro = oroGanado;
      regFama = cambioFama;
      regPuntos = puntos;
      oro += oroGanado;
      logros.sumarOro(oroGanado);
      datosPvp.pveVictorias++; // para el ranking
      diarias.sumar('pve');
      bestiario.registrarVictoria(e.nombre, e.perfil);
      datosPvp.pveOroGanado += oroGanado;
      xp = max(0, xp + cambioFama);
      alineamiento =
          (alineamiento + (lugar.daInclinacionBien ? puntos : -puntos))
              .clamp(-limiteInclinacion, limiteInclinacion);
      _revisarSubidaDeNivel();

      final famaTxt = cambioFama > 0
          ? 'Ganaste $cambioFama de fama.'
          : cambioFama < 0
          ? 'Perdiste ${-cambioFama} de fama por vencer a un rival mucho más débil.'
          : 'No ganaste fama.';
      textoCombate = 'Venciste a ${e.nombre} en $ronda rondas. '
          'Hiciste $danoHecho de daño y recibiste $danoRecibido. '
          'Ganaste $oroGanado de oro y $puntos '
          '${puntos == 1 ? 'punto' : 'puntos'} '
          '${lugar.daInclinacionBien ? 'de bien' : 'de mal'}. '
          '$famaTxt'
          '${nivel > nivelAntes ? ' ¡Subiste al nivel $nivel!' : ''}';
    } else if (r.vidaA <= 0) {
      // ---- Derrota ----
      final cambioFama = cambioFamaPve(nivel, e.nivel, false);
      datosPvp.pveDerrotas++; // para el ranking
      regFama = cambioFama;
      xp = max(0, xp + cambioFama);
      final famaTxt = cambioFama < 0
          ? 'Perdiste ${-cambioFama} de fama.'
          : 'No perdiste fama: el rival era mucho más fuerte que tú.';
      textoCombate = '${e.nombre} te derrotó en $ronda rondas. '
          'Hiciste $danoHecho de daño y recibiste $danoRecibido. '
          'No ganaste oro ni puntos de inclinación. $famaTxt '
          'Necesitas descansar para recuperar la vida.';
    } else {
      // ---- Empate ----
      datosPvp.pveEmpates++; // para el ranking
      textoCombate = 'El combate contra ${e.nombre} se alargó demasiado y '
          'terminó en empate. No ganaste ni perdiste nada.';
    }

    logros.registrarCombate(
      victoria: r.vidaB <= 0,
      derrota: r.vidaB > 0 && r.vidaA <= 0,
      rondas: r.rondas,
      danoHecho: r.danoA,
      danoRecibido: r.danoB,
      criticos: r.criticosA,
      golpeMax: r.golpeMaxA,
      difNivel: e.nivel - nivelAntes,
      nivelEnemigo: e.nivel,
      perfil: e.perfil,
      nombreEnemigo: e.nombre,
      enCripta: lugar == LugarCombate.cripta,
      superviviente:
      r.vidaB <= 0 && r.vidaA > 0 && r.vidaA < vidaMaxima * 0.10,
      agotador: r.vidaB <= 0 &&
          r.rondas > max(rondasFrescas(comoCombatiente), rondasFrescas(e.c)),
    );
    revisarLogros();
    lugarUltimoCombate = lugar;
    logCombate = r.log;
    _guardarRegistroPvE(RegistroCombate(
      fecha: DateTime.now(),
      lugar: lugar.nombre,
      resultado: r.vidaB <= 0 ? 'victoria' : (r.vidaA <= 0 ? 'derrota' : 'empate'),
      yo: miFicha,
      rival: FichaCombate.de(e.c, perfil: e.perfil),
      rondas: r.rondas,
      danoHecho: r.danoA,
      danoRecibido: r.danoB,
      oro: regOro,
      fama: regFama,
      puntosInclinacion: regPuntos,
      inclinacionBien: lugar.daInclinacionBien,
      subioNivel: nivel > nivelAntes,
      log: List<String>.from(r.log),
    ));
    // Los rivales de este lugar ya no están: la próxima búsqueda es gratis.
    cercanos[lugar] = <Enemigo>[];
    aleatorio[lugar] = null;
    notifyListeners();
    return null;
  }

  // Desafía a un jefe. Cada jefe se puede intentar 1 vez por día (ganes o no).
  // Da solo oro: no cambia la fama ni la inclinación. Devuelve un mensaje solo
  // si no se puede pelear.
  String? pelearJefe(Jefe j) {
    if (trabajando) {
      return 'Estás trabajando en la taberna. Termina o abandona el trabajo para pelear.';
    }
    if (!jefeDesbloqueado(j)) {
      return '${j.nombre} te espera desde el nivel ${j.nivelMin}.';
    }
    if (jefeIntentadoHoy(j)) {
      return 'Ya desafiaste a ${j.nombre} hoy. Vuelve mañana.';
    }
    if (vida < vidaMaxima * vidaMinimaParaPelear) {
      return 'Estás demasiado herido para pelear. Descansa un poco.';
    }

    // El intento se gasta al empezar, ganes o pierdas.
    if (jefesDia != RelojServidor.dia) {
      jefesDia = RelojServidor.dia;
      jefesHoy = [];
    }
    jefesHoy = [...jefesHoy, j.nombre];

    final e = enemigoJefe(j);
    final miFicha = FichaCombate.de(comoCombatiente);
    final r = simularCombate(comoCombatiente, e.c, vidaA: vida);
    datosPvp.pveDano += r.danoA; // para el ranking

    vidaActual = max(0, r.vidaA);
    _vidaActualizada = DateTime.now();

    final nivelAntes = nivel;
    int regOro = 0;
    final primeraVez = !jefesVencidos.contains(j.nombre);
    if (r.vidaB <= 0) {
      final base = e.oroMin + azar.nextInt(e.oroMax - e.oroMin + 1);
      final bono = primeraVez ? (base * bonoPrimeraVictoriaJefe).round() : 0;
      regOro = conBonoAmbicion(base + bono);
      oro += regOro;
      logros.sumarOro(regOro);
      datosPvp.pveVictorias++;
      datosPvp.pveOroGanado += regOro;
      diarias.sumar('jefe');
      if (primeraVez) {
        jefesVencidos = [...jefesVencidos, j.nombre];
        logros.avisos.add('Nueva entrada en el Bestiario: ${j.nombre}');
      }
      textoCombate = 'Venciste a ${j.nombre} en ${r.rondas} rondas. '
          'Ganaste $regOro de oro'
          '${primeraVez ? ' (incluye el bono por la primera victoria)' : ''}. '
          'Los jefes no dan fama.';
    } else if (r.vidaA <= 0) {
      datosPvp.pveDerrotas++;
      textoCombate = '${j.nombre} te derrotó en ${r.rondas} rondas. '
          'No ganaste oro. Necesitas descansar para recuperar la vida.';
    } else {
      datosPvp.pveEmpates++;
      textoCombate = 'El combate contra ${j.nombre} se alargó demasiado y '
          'terminó en empate. Perdiste el intento de hoy.';
    }

    revisarLogros();
    logCombate = r.log;
    _guardarRegistroPvE(RegistroCombate(
      fecha: DateTime.now(),
      lugar: 'Jefe',
      resultado:
      r.vidaB <= 0 ? 'victoria' : (r.vidaA <= 0 ? 'derrota' : 'empate'),
      yo: miFicha,
      rival: FichaCombate.de(e.c, perfil: 'Jefe'),
      rondas: r.rondas,
      danoHecho: r.danoA,
      danoRecibido: r.danoB,
      oro: regOro,
      fama: 0,
      puntosInclinacion: 0,
      inclinacionBien: true,
      subioNivel: nivel > nivelAntes,
      log: List<String>.from(r.log),
    ));
    notifyListeners();
    return null;
  }

  // Pelea contra el Inmortal (solo domingos, 1 intento). Gana oro igual al daño
  // que le hagas x [multOroInmortal], sin tope. No da fama ni inclinación.
  // Devuelve un mensaje solo si no se puede pelear.
  String? pelearInmortal() {
    if (trabajando) {
      return 'Estás trabajando en la taberna. Termina o abandona el trabajo para pelear.';
    }
    if (!esDomingoServidor) {
      return 'El Inmortal solo aparece los domingos.';
    }
    if (inmortalIntentadoHoy) {
      return 'Ya enfrentaste al Inmortal hoy. Vuelve el próximo domingo.';
    }
    if (vida < vidaMaxima * vidaMinimaParaPelear) {
      return 'Estás demasiado herido para pelear. Descansa un poco.';
    }

    final e = generarInmortal(nivel);
    final miFicha = FichaCombate.de(comoCombatiente);
    final r = simularCombate(comoCombatiente, e.c,
        vidaA: vida, vidaB: vidaInfinitaInmortal, maxRondas: rondasInmortal);

    vidaActual = max(0, r.vidaA);
    _vidaActualizada = DateTime.now();

    final dano = r.danoA;
    final oroGanado = conBonoAmbicion(dano * multOroInmortal);
    oro += oroGanado;
    logros.sumarOro(oroGanado);
    inmortalDia = RelojServidor.dia;
    inmortalDano = dano;
    inmortalOro = oroGanado;

    final cayo = r.vidaA <= 0;
    textoCombate = cayo
        ? '${e.nombre} te derribó en ${r.rondas} rondas. Le hiciste $dano de daño y ganaste $oroGanado de oro.'
        : 'Aguantaste las ${r.rondas} rondas contra ${e.nombre}. Le hiciste $dano de daño y ganaste $oroGanado de oro.';

    revisarLogros();
    logCombate = r.log;
    _guardarRegistroPvE(RegistroCombate(
      fecha: DateTime.now(),
      lugar: 'Inmortal',
      resultado: cayo ? 'derrota' : 'victoria',
      yo: miFicha,
      rival: FichaCombate.de(e.c, perfil: 'Inmortal'),
      rondas: r.rondas,
      danoHecho: dano,
      danoRecibido: r.danoB,
      oro: oroGanado,
      fama: 0,
      puntosInclinacion: 0,
      inclinacionBien: true,
      subioNivel: false,
      log: List<String>.from(r.log),
    ));
    notifyListeners();
    return null;
  }

  // Cambios de raza ya hechos después de crear el personaje.
  // El primero es gratis; los siguientes cuestan [costoCambioRaza] gemas.
  // Debe guardarse en la nube.
  int cambiosRaza = 0;
  static const int costoCambioRaza = 50;

  // Gemas que costaría cambiar de raza ahora (0 = gratis)
  int get costoProximoCambioRaza => cambiosRaza == 0 ? 0 : costoCambioRaza;

  // Personalización del personaje (nombre, género y raza).
  // Devuelve un mensaje solo si no se pudo (por ejemplo, faltan gemas).
  String? personalizar(String nuevoNombre, Genero nuevoGenero, Raza nuevaRaza) {
    if (nuevaRaza != raza) {
      final costo = costoProximoCambioRaza;
      if (gemas < costo) {
        return 'Cambiar de raza cuesta $costo esquirlas y tienes $gemas.';
      }
      gemas -= costo;
      cambiosRaza++;
      raza = nuevaRaza;
    }
    final n = nuevoNombre.trim();
    if (n.isNotEmpty) nombre = n;
    genero = nuevoGenero;
    notifyListeners();
    return null;
  }

  // Creación inicial del personaje: la raza elegida aquí no cuesta nada ni
  // cuenta como cambio.
  void crearPersonaje(String nuevoNombre, Genero nuevoGenero, Raza nuevaRaza) {
    final n = nuevoNombre.trim();
    if (n.isNotEmpty) nombre = n;
    genero = nuevoGenero;
    raza = nuevaRaza;
    personajeCreado = true;
    notifyListeners();
  }

  // ---------- TABERNA (trabajos AFK) ----------

  // Trabajos que se ven ahora en la taberna, según la inclinación (true = bien)
  final Map<bool, List<Trabajo>> ofertasTaberna = {true: [], false: []};

  // Trabajo en curso
  Trabajo? trabajoActual;
  bool trabajoEsBien = true;
  int trabajoHoras = 0;
  int trabajoPago = 0;
  DateTime? trabajoTermina;
  String? ultimoResultadoTaberna;

  bool get trabajando => trabajoTermina != null;

  bool get trabajoListo =>
      trabajoTermina != null && DateTime.now().isAfter(trabajoTermina!);

  // Elige 5 o 6 trabajos de la inclinación indicada.
  // La mitad (o un poco más) son encargos de nobles; el resto, trabajos comunes.
  void _generarOfertas(bool esBien) {
    final cuantos = ofertasTabernaMin +
        azar.nextInt(ofertasTabernaMax - ofertasTabernaMin + 1);
    final nobles =
    List<EncargoNoble>.of(esBien ? encargosNoblesBien : encargosNoblesMal)
      ..shuffle(azar);
    final comunes = List<Trabajo>.of(esBien ? trabajosBien : trabajosMal)
      ..shuffle(azar);
    final cantNobles = (cuantos + 1) ~/ 2;
    final lista = <Trabajo>[
      ...nobles.take(cantNobles).map((p) => p.crear()),
      ...comunes.take(cuantos - cantNobles),
    ]..shuffle(azar);
    ofertasTaberna[esBien] = lista;
  }

  void actualizarOfertas(bool esBien) {
    _generarOfertas(esBien);
    notifyListeners();
  }

  // Empieza un turno de [horas] horas. Devuelve un mensaje solo si no se puede.
  String? iniciarTrabajo(Trabajo t, int horas, {required bool esBien}) {
    if (trabajando) return 'Ya estás trabajando.';
    if (hayMisionEnCurso) {
      return 'Estás en una misión. Termínala antes de ponerte a trabajar.';
    }
    final h = min(max(horas, horasMinTaberna), horasMaxTaberna);
    trabajoActual = t;
    trabajoEsBien = esBien;
    trabajoHoras = h;
    trabajoPago = pagoTaberna(nivel, h, premium);
    trabajoTermina = DateTime.now().add(duracionHora * h);
    ultimoResultadoTaberna = null;
    Notificaciones.instancia.pedirPermiso();
    _avisarTrabajo();
    notifyListeners();
    return null;
  }

  // Abandonar antes de terminar: se pierde el tiempo y no se cobra nada
  void cancelarTrabajo() {
    if (!trabajando || trabajoListo) return;
    ultimoResultadoTaberna =
    'Abandonaste el trabajo "${trabajoActual!.nombre}" antes de terminar. '
        'Perdiste el tiempo y no cobraste nada.';
    _limpiarTrabajo();
    notifyListeners();
  }

  void cobrarTrabajo() {
    if (!trabajoListo) return;
    final t = trabajoActual!;
    final puntos = puntosTaberna(trabajoHoras);
    oro += trabajoPago;
    alineamiento = (alineamiento + (trabajoEsBien ? puntos : -puntos))
        .clamp(-limiteInclinacion, limiteInclinacion);

    // Gemas: una sola tirada por turno; la probabilidad sube con las horas.
    int gemasGanadas = 0;
    final probPorHora =
    premium ? probGemasPorHoraTabernaPremium : probGemasPorHoraTaberna;
    final probGemas = 1 - pow(1 - probPorHora, trabajoHoras);
    if (azar.nextDouble() < probGemas) {
      gemasGanadas =
          (azar.nextDouble() * azar.nextDouble() * gemasMaxTaberna).floor() + 1;
      gemas += gemasGanadas;
    }

    ultimoResultadoTaberna =
    'Terminaste el trabajo "${t.nombre}". Trabajaste $trabajoHoras '
        '${trabajoHoras == 1 ? 'hora' : 'horas'} y cobraste $trabajoPago de oro. '
        'Ganaste $puntos ${puntos == 1 ? 'punto' : 'puntos'} '
        '${trabajoEsBien ? 'de bien' : 'de mal'}.'
        '${gemasGanadas > 0 ? ' ¡Además encontraste $gemasGanadas ${gemasGanadas == 1 ? 'esquirla' : 'esquirlas'}!' : ''}';
    logros.registrarTaberna(
        horas: trabajoHoras, oro: trabajoPago, gemas: gemasGanadas);
    diarias.sumar('taberna');
    revisarLogros();
    _limpiarTrabajo();
    notifyListeners();
  }

  void _limpiarTrabajo() {
    Notificaciones.instancia.cancelar(Notificaciones.idTrabajo);
    trabajoActual = null;
    trabajoHoras = 0;
    trabajoPago = 0;
    trabajoTermina = null;
  }

  // ---------- MISIONES ----------

  int get limiteBloquesDia =>
      (premium ? bloquesPorDiaPremium : bloquesPorDia) + _bonusVigente;

  // ---------- ANUNCIOS RECOMPENSADOS ----------

  // Compra única "Sin anuncios": las recompensas se dan al instante, sin ver
  // el anuncio. Se activa desde compras.dart y debe guardarse en la nube.
  bool sinAnuncios = false;

  // Bloques extra de misión ganados con anuncios hoy y anuncios usados hoy.
  // Se reinician solos cuando cambia el día del servidor.
  int bloquesBonusHoy = 0;
  int anunciosVistosHoy = 0;
  String diaBonus = '';

  int get _bonusVigente => diaBonus == _hoy ? bloquesBonusHoy : 0;
  int get anunciosUsadosHoy => diaBonus == _hoy ? anunciosVistosHoy : 0;
  int get anunciosRestantesHoy => maxAnunciosPorDia - anunciosUsadosHoy;
  bool get puedeVerAnuncio => anunciosRestantesHoy > 0;

  // Si cambió el día, reinicia los contadores de anuncios y de tiempo extra.
  void _prepararDiaBonus() {
    if (diaBonus != _hoy) {
      diaBonus = _hoy;
      bloquesBonusHoy = 0;
      anunciosVistosHoy = 0;
    }
  }

  void _registrarAnuncio() {
    _prepararDiaBonus();
    anunciosVistosHoy++;
    logros.stats.sumar('anunciosVistos');
  }

  // Pide una recompensa. Con "Sin anuncios" se da al instante; si no, se
  // muestra el anuncio. Devuelve un mensaje solo si no se pudo.
  String? pedirAnuncio(VoidCallback recompensa) {
    if (!puedeVerAnuncio) return 'Ya usaste todos tus anuncios de hoy. Vuelve mañana.';
    if (sinAnuncios) {
      recompensa();
      return null;
    }
    final ok = Anuncios.instancia.mostrar(recompensa);
    if (!ok) return 'El anuncio aún no está listo, intenta en unos segundos.';
    return null;
  }

  // Recompensa: vida completa
  void recompensaCurar() {
    _registrarAnuncio();
    _asentarVida();
    fijarVida(vidaMaxima);
    notifyListeners();
  }

  // Recompensa: tiempo extra de misión hoy
  void recompensaTiempoExtra() {
    _registrarAnuncio();
    bloquesBonusHoy += bloquesPorAnuncio;
    notifyListeners();
  }

  // Recompensa: cobrar la misión con el oro y la fama duplicados
  void recompensaDobleMision() {
    _registrarAnuncio();
    cobrarMision(doble: true);
  }

  // ---------- RECOMPENSA DIARIA ----------

  // Último día (del servidor) en que se reclamó, y días seguidos reclamados.
  String diaRecompensa = '';
  int rachaDiaria = 0;

  bool get puedeReclamarDiaria => personajeCreado && diaRecompensa != _hoy;

  // Racha que tendrías al reclamar hoy: continúa si reclamaste ayer.
  int get rachaParaReclamar =>
      diaRecompensa == RelojServidor.diaAnterior ? rachaDiaria + 1 : 1;

  RecompensaDiaria get recompensaDeHoy =>
      recompensasDiarias[(rachaParaReclamar - 1) % recompensasDiarias.length];

  int oroDiario(RecompensaDiaria r) => (r.oro * factorOroMision(nivel)).round();

  // Reclama la recompensa de hoy. Con [doble] el oro se duplica.
  // Devuelve el mensaje para mostrar al jugador.
  String reclamarRecompensaDiaria({bool doble = false}) {
    if (!puedeReclamarDiaria) return 'Ya reclamaste la recompensa de hoy.';
    final racha = rachaParaReclamar;
    final r = recompensasDiarias[(racha - 1) % recompensasDiarias.length];
    final oroGanado = oroDiario(r) * (doble ? 2 : 1);
    oro += oroGanado;
    gemas += r.gemas;
    if (r.bloques > 0) {
      _prepararDiaBonus();
      bloquesBonusHoy += r.bloques;
    }
    rachaDiaria = racha;
    diaRecompensa = _hoy;
    logros.sumarOro(oroGanado);
    revisarLogros();
    notifyListeners();
    final extra = [
      if (r.gemas > 0) '${r.gemas} ${r.gemas == 1 ? 'esquirla' : 'esquirlas'}',
      if (r.bloques > 0) '${r.bloques * minutosPorBloque} min de misión',
    ].join(' y ');
    return 'Recompensa diaria (racha de $racha): $oroGanado de oro'
        '${extra.isEmpty ? '' : ' y $extra'}.';
  }

  // Reclamar viendo un anuncio: el oro se duplica.
  String recompensaDiariaDoble() {
    _registrarAnuncio();
    return reclamarRecompensaDiaria(doble: true);
  }

  // ---------- TUTORIAL ----------

  bool tutorialVisto = false;

  void marcarTutorialVisto() {
    if (tutorialVisto) return;
    tutorialVisto = true;
    notifyListeners();
  }

  // ---------- AVISOS (notificaciones) ----------

  void _avisarMision() {
    final fin = misionTermina;
    if (fin == null) return;
    Notificaciones.instancia.programar(
        Notificaciones.idMision,
        tr('¡Misión terminada!'),
        tr('Tu aventurero ya volvió. Cobra tu recompensa.'),
        fin);
  }

  void _avisarTrabajo() {
    final fin = trabajoTermina;
    if (fin == null) return;
    Notificaciones.instancia.programar(
        Notificaciones.idTrabajo,
        tr('¡Turno terminado!'),
        tr('Terminaste de trabajar en la taberna. Cobra tu sueldo.'),
        fin);
  }

  // Se llama al cargar la partida: si hay una misión o un trabajo en curso,
  // se vuelve a programar su aviso (por si se reinstaló la app).
  void reprogramarAvisos() {
    _avisarMision();
    _avisarTrabajo();
  }

  // Día según la hora del servidor: cambia justo cuando el reloj marca 00:00.
  String get _hoy => RelojServidor.dia;

  // Bloques de misión (minutosPorBloque minutos cada uno) gastados hoy.
  // Solo calcula: si cambió el día, devuelve 0 sin modificar nada.
  int get bloquesUsadosHoy => diaMisiones == _hoy ? bloquesHoy : 0;

  // Bloques de misión que aún te quedan hoy
  int get bloquesRestantesHoy => limiteBloquesDia - bloquesUsadosHoy;

  // ¿Puedes partir a una misión de [bloques] bloques?
  bool puedeIniciarMision(int bloques) =>
      !trabajando && oro >= costoMision && bloques <= bloquesRestantesHoy;

  bool get hayMisionEnCurso => misionTermina != null;

  bool get misionLista =>
      misionTermina != null && DateTime.now().isAfter(misionTermina!);

  void iniciarMision({required bool esBien, required int bloques}) {
    if (hayMisionEnCurso) return;
    if (!puedeIniciarMision(bloques)) return; // el botón ya está desactivado
    // Si es un día nuevo, el contador de bloques vuelve a empezar.
    if (diaMisiones != _hoy) {
      diaMisiones = _hoy;
      bloquesHoy = 0;
    }
    oro -= costoMision;
    bloquesHoy += bloques;
    misionEsBien = esBien;
    misionBloques = bloques;
    misionDestino = elegirDestino(); // aleatorio según probabilidad
    misionTermina = DateTime.now().add(duracionBloque * bloques);
    ultimoResultado = null;
    Notificaciones.instancia.pedirPermiso();
    _avisarMision();
    notifyListeners();
  }

  void cobrarMision({bool doble = false}) {
    final d = misionDestino;
    if (d == null || !misionLista) return;

    final gente = d.genteMin + azar.nextInt(d.genteMax - d.genteMin + 1);

    if (azar.nextDouble() < probMalaSuerte) {
      // Mala suerte: no hay oro, ni fama, ni puntos de inclinación.
      logros.registrarMision(
          bien: misionEsBien, oro: 0, gemas: 0, malaSuerte: true);
      ultimoResultado =
      'Llegaste a ${d.articulo} ${d.lugar} con $gente personas. '
          '${textosMalaSuerte[azar.nextInt(textosMalaSuerte.length)]} '
          'No ganaste oro, ni fama, ni puntos de inclinación.';
    } else {
      final proporcion = (gente - d.genteMin) / (d.genteMax - d.genteMin);
      final base = d.oroMin + (d.oroMax - d.oroMin) * proporcion;
      final variacion = 0.9 + azar.nextDouble() * 0.2;
      // El oro y la fama del destino crecen con tu nivel
      final fOro = factorOroMision(nivel);
      final porBloque = (base * variacion * fOro)
          .round()
          .clamp((d.oroMin * fOro).round(), (d.oroMax * fOro).round());

      final mult = doble ? 2 : 1;
      final ganancia = porBloque * misionBloques * mult;
      // Fama fija: no depende del nivel ni de la duración de la misión.
      final famaGanada = d.fama * mult;
      final puntos = (d.puntosAlineamiento *
          (1 + extraInclinacionPorBloque * (misionBloques - 1)))
          .round();

      // Gemas: una sola tirada por misión; la probabilidad sube con la
      // duración. La cantidad va de 1 hasta el máximo del destino, pero el
      // máximo es muy raro (la mayoría de las veces salen pocas).
      int gemasGanadas = 0;
      final probGemas = 1 - pow(1 - probGemasPorBloque, misionBloques);
      if (azar.nextDouble() < probGemas) {
        gemasGanadas =
            (azar.nextDouble() * azar.nextDouble() * d.gemasMax).floor() + 1;
      }
      gemas += gemasGanadas;

      oro += ganancia;
      xp += famaGanada;
      alineamiento += misionEsBien ? puntos : -puntos;
      alineamiento = alineamiento.clamp(-limiteInclinacion, limiteInclinacion);

      final historias = misionEsBien ? d.historiasBien : d.historiasMal;
      final historia = historias[azar.nextInt(historias.length)];
      final tipoPuntos = misionEsBien ? 'de bien' : 'de mal';

      ultimoResultado =
      'Llegaste a ${d.articulo} ${d.lugar} con $gente personas. '
          '$historia '
          'Ganaste $ganancia de oro, $famaGanada de fama y $puntos '
          '${puntos == 1 ? 'punto' : 'puntos'} $tipoPuntos.'
          '${doble ? ' ¡Duplicado por el anuncio!' : ''}'
          '${gemasGanadas > 0 ? ' ¡Además encontraste $gemasGanadas ${gemasGanadas == 1 ? 'esquirla' : 'esquirlas'}!' : ''}';

      logros.registrarMision(
          bien: misionEsBien,
          oro: ganancia,
          gemas: gemasGanadas,
          malaSuerte: false);
      _revisarSubidaDeNivel();
    }

    misionDestino = null;
    misionTermina = null;
    misionBloques = 0;
    Notificaciones.instancia.cancelar(Notificaciones.idMision);
    diarias.sumar('mision');
    revisarLogros();
    notifyListeners();

    if (nivel >= nivelMaximo) xp = 0;
  }
}

EstadoJuego juego = EstadoJuego();

// ====================== APP ======================

class BloodDominionApp extends StatelessWidget {
  const BloodDominionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blood Dominion',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1A1014),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF5A0F1B),
          elevation: 4,
          shadowColor: Colors.black87,
        ),
        // Las tarjetas son un poco transparentes (0xE6 = 90%) para que se
        // vea el fondo de cada pantalla sin perder legibilidad.
        cardTheme: CardThemeData(
          color: const Color(0xA6241419
          ),
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFF3F2A31)),
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xFF2A1218),
          indicatorColor: Color(0xFF5A0F1B),
        ),
      ),
      // Primero se crea el personaje; después se abre el menú del juego
      home: const PuertaDeEntrada(),
    );
  }
}

// ====================== CREACIÓN DEL PERSONAJE ======================
// Se muestra al abrir el juego, antes del menú principal.

class PantallaCreacionPersonaje extends StatefulWidget {
  const PantallaCreacionPersonaje({super.key});

  @override
  State<PantallaCreacionPersonaje> createState() =>
      _PantallaCreacionPersonajeState();
}

class _PantallaCreacionPersonajeState extends State<PantallaCreacionPersonaje> {
  bool _procesando = false; // evita pulsar "Comenzar" dos veces
  final TextEditingController _nombre = TextEditingController();
  Genero _genero = Genero.hombre;
  Raza _raza = Raza.vampiro;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  bool get _nombreValido => _nombre.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FondoPantalla(
        imagen: Fondos.crearPersonaje,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                const Text(
                  'BLOOD DOMINION',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: Color(0xFFF1E3C0),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Crea tu personaje',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _nombre,
                  maxLength: 16,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Género'),
                const SizedBox(height: 8),
                SegmentedButton<Genero>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                        value: Genero.hombre,
                        label: Text('Hombre'),
                        icon: Icon(Icons.man)),
                    ButtonSegment(
                        value: Genero.mujer,
                        label: Text('Mujer'),
                        icon: Icon(Icons.woman)),
                  ],
                  selected: {_genero},
                  onSelectionChanged: (s) => setState(() => _genero = s.first),
                ),
                const SizedBox(height: 20),
                const Text('Raza'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: Raza.values
                      .map((r) => ChoiceChip(
                    label: Text(r.nombre),
                    selected: _raza == r,
                    onSelected: (_) => setState(() => _raza = r),
                  ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      '${_raza.pasiva.nombre}: ${_raza.pasiva.descripcion}',
                      style: const TextStyle(
                          fontStyle: FontStyle.italic, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  color: const Color(0xFF3A2A10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Colors.amber),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Elige bien tu raza: después solo podrás cambiarla '
                                'una vez gratis. Los demás cambios cuestan '
                                '${EstadoJuego.costoCambioRaza} esquirlas.',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                BotonOscuro(
                  texto: 'Comenzar',
                  alto: 52,
                  color: ColorBoton.rojo,
                  onPressed: _nombreValido
                      ? () async {
                    if (_procesando) return;
                    _procesando = true;
                    FocusScope.of(context).unfocus();
                    // Cuenta reiniciada: mensaje de recompensa (solo una vez)
                    if (await Nube.recompensaReinicioPendiente()) {
                      if (!mounted) return;
                      await showDialog<void>(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => AlertDialog(
                          title: const Text('¡Recompensa!'),
                          content: Text(
                              'Como recompensa por tu personaje anterior recibes:\n\n'
                                  '• $recompensaReinicioGemas esquirlas\n'
                                  '• $recompensaReinicioOro de oro'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Recibir'),
                            ),
                          ],
                        ),
                      );
                    }
                    juego.crearPersonaje(_nombre.text, _genero, _raza);
                    await Nube.entregarRecompensaReinicio();
                  }
                      : null,
                ),
                if (!_nombreValido)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Escribe un nombre para continuar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// La navegación tiene 4 pestañas (Inicio, Combate, Misiones, Comercio) y cada
// una tiene sus sub-pestañas en una fila debajo de la barra superior.
// Para agregar una pantalla nueva solo hay que añadirla a la lista de [subs]
// del grupo que corresponda.
class SubSeccion {
  final String etiqueta; // texto de la sub-pestaña
  final Widget Function() pantalla;
  // Imagen de fondo (ver fondo_pantalla.dart). Si es null, la propia pantalla
  // se encarga de su fondo (como Combate) o no lleva.
  final String? fondo;
  final double oscuridad; // 0 a 1: qué tan oscura es la capa sobre el fondo
  const SubSeccion(this.etiqueta, this.pantalla,
      {this.fondo, this.oscuridad = 0.4});
}

class Grupo {
  final String titulo; // título de la barra superior
  final String etiqueta; // texto de la barra inferior
  final IconData icono;
  final List<SubSeccion> subs;
  const Grupo(this.titulo, this.etiqueta, this.icono, this.subs);
}

// Se crean sin "const" a propósito: así Flutter reconstruye la pantalla
// cada vez que el juego cambia (compras, equipo, puntos, etc.).
final List<Grupo> grupos = [
  Grupo('Inicio', 'Inicio', Icons.home, [
    SubSeccion('Perfil', () => PantallaPersonaje(), fondo: Fondos.personaje),
    SubSeccion('Equipo', () => const PantallaEquipo()),
    SubSeccion('Entrenar', () => PantallaEntrenamiento(),
        fondo: Fondos.entrenamiento),
    SubSeccion('Altar', () => PantallaAltar(), fondo: Fondos.altar),
    SubSeccion('Logros', () => const PantallaPersonaje(soloLogros: true),
        fondo: Fondos.personaje),
    SubSeccion('Bestiario', () => const PantallaBestiario(),
        fondo: Fondos.personaje, oscuridad: 0.6),
  ]),
  Grupo('Combate', 'Combate', Icons.gavel, [
    // Combate pone su propio fondo según el lugar.
    SubSeccion('Arena', () => const PantallaCombate(fija: VistaCombate.arena)),
    SubSeccion('Cripta', () => const PantallaCombate(fija: VistaCombate.cripta)),
    SubSeccion('Ciudadela',
            () => const PantallaCombate(fija: VistaCombate.ciudadela)),
    SubSeccion('Jefes', () => const PantallaCombate(fija: VistaCombate.jefes)),
    SubSeccion('Ranking', () => PantallaRanking(), fondo: Fondos.ranking),
    SubSeccion('Torneo', () => const PantallaTorneo(), fondo: Fondos.ranking),
    SubSeccion('Eventos', () => const PantallaEventos(), fondo: Fondos.combate),
    SubSeccion('Historial',
            () => const PantallaCombate(fija: VistaCombate.historial)),
  ]),
  Grupo('Misiones', 'Misiones', Icons.map, [
    SubSeccion('Misiones', () => PantallaMisiones(), fondo: Fondos.misiones),
    SubSeccion('Diarias', () => const PantallaDiarias(), fondo: Fondos.misiones),
    SubSeccion('Taberna', () => PantallaTaberna(), fondo: Fondos.taberna),
    SubSeccion('Dados', () => const PantallaDados(), fondo: Fondos.taberna),
  ]),
  Grupo('Comercio', 'Comercio', Icons.store, [
    SubSeccion('Tienda', () => PantallaTienda(), fondo: Fondos.tienda),
    SubSeccion('Mercado negro', () => PantallaBazar(), fondo: Fondos.tienda),
    SubSeccion('Afilador', () => PantallaAfilador(), fondo: Fondos.tienda),
    SubSeccion('Premium', () => PantallaCompras()),
  ]),
  Grupo('Social', 'Social', Icons.forum, [
    SubSeccion('Global', () => const PantallaChatGlobal(), fondo: Fondos.taberna),
    SubSeccion('Amigos', () => const PantallaAmigos(), fondo: Fondos.taberna),
    SubSeccion('Bloqueados', () => const PantallaBloqueados(),
        fondo: Fondos.taberna),
  ]),
];

// Equipo: Armado e Inventario en una sola pantalla, con un selector arriba.
class PantallaEquipo extends StatefulWidget {
  const PantallaEquipo({super.key});

  @override
  State<PantallaEquipo> createState() => _PantallaEquipoState();
}

class _PantallaEquipoState extends State<PantallaEquipo> {
  bool armado = true;

  @override
  Widget build(BuildContext context) {
    return FondoPantalla(
      imagen: armado ? Fondos.armadoPj : Fondos.inventario,
      oscuridad: armado ? 0.2 : 0.4,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                      value: true, label: Text('Armado'), icon: Icon(Icons.shield)),
                  ButtonSegment(
                      value: false,
                      label: Text('Inventario'),
                      icon: Icon(Icons.backpack)),
                ],
                selected: {armado},
                onSelectionChanged: (v) => setState(() => armado = v.first),
              ),
            ),
          ),
          Expanded(child: armado ? PantallaArmado() : PantallaInventario()),
        ],
      ),
    );
  }
}

// Eventos: hoy el Inmortal (solo los domingos). Aquí irán los que vengan.
class PantallaEventos extends StatelessWidget {
  const PantallaEventos({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (juego.esDomingoServidor)
          Card(
            child: ListTile(
              leading: const Icon(Icons.local_fire_department,
                  color: Colors.orangeAccent, size: 32),
              title: const Text('Evento: el Inmortal',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                  '¡Mariolo está aquí! Tu daño x$multOroInmortal es tu oro.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const PantallaInmortal())),
            ),
          )
        else
          const Card(
            child: ListTile(
              leading: Icon(Icons.event, size: 32),
              title: Text('Sin eventos activos',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                  'El Inmortal aparece los domingos. Vuelve ese día.'),
            ),
          ),
      ],
    );
  }
}

// ====================== RELOJ DEL SERVIDOR ======================

class RelojServidor {
  // Diferencia entre el reloj real del servidor y el del dispositivo.
  // Queda en cero hasta que se sincronice con un servidor (ver nota abajo).
  static Duration ajuste = Duration.zero;

  // Instante real actual (UTC), con el ajuste del servidor. Sirve para medir
  // duraciones, como los días de premium.
  static DateTime instante() => DateTime.now().toUtc().add(ajuste);

  // Hora actual del servidor (usa .hour, .minute, .second, .day...).
  static DateTime ahora() => DateTime.now()
      .toUtc()
      .add(ajuste)
      .add(const Duration(hours: desfaseHoraServidorHoras));

  // Identificador del día del servidor. Las misiones se reinician cuando cambia.
  static String get dia {
    final n = ahora();
    return '${n.year}-${n.month}-${n.day}';
  }

  // El día de ayer según el servidor (para contar la racha diaria).
  static String get diaAnterior {
    final n = ahora().subtract(const Duration(days: 1));
    return '${n.year}-${n.month}-${n.day}';
  }
}

// Reloj pequeño con la hora del servidor. Cuando llega a las 00:00 avisa al
// juego para que el tiempo de misiones se reinicie en pantalla al instante.
class RelojJuego extends StatefulWidget {
  const RelojJuego({super.key});

  @override
  State<RelojJuego> createState() => _RelojJuegoState();
}

class _RelojJuegoState extends State<RelojJuego> {
  Timer? _timer;
  String _diaVisto = RelojServidor.dia;
  bool _premiumVisto = juego.premium;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final d = RelojServidor.dia;
      if (d != _diaVisto) {
        _diaVisto = d;
        juego.avisarCambio();
      }
      // Si el premium se acaba, se refresca el juego al instante.
      if (juego.premium != _premiumVisto) {
        _premiumVisto = juego.premium;
        juego.avisarCambio();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _dos(int v) => v.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final n = RelojServidor.ahora();
    return Tooltip(
      message: tr('Hora del servidor. Las misiones se reinician a las 00:00.'),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Medalla de premium, junto al reloj.
          if (juego.premium) ...[
            const MedallaPremium(tamano: 16),
            const SizedBox(width: 8),
          ],
          const Icon(Icons.schedule, size: 14),
          const SizedBox(width: 4),
          SizedBox(
            width: 62,
            child: Text(
              '${_dos(n.hour)}:${_dos(n.minute)}:${_dos(n.second)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class MenuPrincipal extends StatefulWidget {
  const MenuPrincipal({super.key});

  @override
  State<MenuPrincipal> createState() => _MenuPrincipalState();
}

class _MenuPrincipalState extends State<MenuPrincipal> {
  int grupo = 0; // pestaña de abajo: posición dentro de [grupos]
  final List<int> subSel = List<int>.filled(5, 0); // sub-pestaña de cada grupo
  final ScrollController _scrollSubs = ScrollController();

  // Poner en true si quieres el deslizar al revés (izquierda a derecha = siguiente).
  static const bool deslizarAlReves = false;

  // Cambia de sub-pestaña. Si te pasas del final, sigue a la pestaña de abajo
  // siguiente (y al revés al principio).
  void _irASub(int i) {
    setState(() => subSel[grupo] = i);
    _centrarSub();
  }

  void _centrarSub() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollSubs.hasClients) return;
      final destino = (subSel[grupo] * 92.0 - 90)
          .clamp(0.0, _scrollSubs.position.maxScrollExtent);
      _scrollSubs.animateTo(destino,
          duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    });
  }

  // dir = 1: siguiente, dir = -1: anterior
  void _deslizar(int dir) {
    final n = grupos[grupo].subs.length;
    final nueva = subSel[grupo] + dir;
    if (nueva >= 0 && nueva < n) {
      _irASub(nueva);
      return;
    }
    final g = grupo + dir;
    if (g < 0 || g >= grupos.length) return;
    setState(() {
      grupo = g;
      subSel[g] = dir > 0 ? 0 : grupos[g].subs.length - 1;
    });
    if (_scrollSubs.hasClients) _scrollSubs.jumpTo(0);
    _centrarSub();
  }

  void _alSoltarDedo(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v.abs() < 350) return; // un roce suave no cambia de pestaña
    // Deslizar hacia la izquierda (v < 0) = pestaña siguiente
    final siguiente = deslizarAlReves ? v > 0 : v < 0;
    _deslizar(siguiente ? 1 : -1);
  }

  @override
  void initState() {
    super.initState();
    // Empieza a escuchar las compras desde que se abre el juego.
    ServicioCompras.instancia.iniciar();
    // Escucha solicitudes de amistad y mensajes nuevos (punto rojo en Social).
    Social.instancia.iniciar();
    // Permite que la guía de primeros pasos lleve a otras pestañas.
    irAPestana = (g, s) {
      if (!mounted || g < 0 || g >= grupos.length) return;
      setState(() {
        grupo = g;
        subSel[g] = s.clamp(0, grupos[g].subs.length - 1);
      });
      if (_scrollSubs.hasClients) _scrollSubs.jumpTo(0);
      _centrarSub();
    };
    // Tutorial (si es nuevo) y recompensa diaria, ya con el menú dibujado.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      juego.revisarLogros();
      juego.avisarCambio();
      if (mounted) avisosDeInicio(context);
      if (mounted) avisoInmortalDomingo(context);
    });
  }

  @override
  void dispose() {
    Social.instancia.detener();
    irAPestana = null;
    _scrollSubs.dispose();
    super.dispose();
  }

  // Pide confirmación y cierra la sesión.
  Future<void> _cerrarSesion() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('¿Cerrar sesión?')),
        content: Text(tr('Tu progreso queda guardado en tu cuenta.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('Cancelar'))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('Salir'))),
        ],
      ),
    );
    if (ok == true) await Nube.cerrarSesion();
  }

  // Menú de ajustes: idioma y cerrar sesión.
  void _abrirAjustes() {
    showDialog<void>(
      context: context,
      builder: (ctx) => ListenableBuilder(
        listenable: Idioma.instancia,
        builder: (ctx, _) => AlertDialog(
          title: Text(tr('Ajustes')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('Idioma'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              for (final e in Idioma.nombres.entries)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(e.value),
                  trailing: Idioma.instancia.codigo == e.key
                      ? const Icon(Icons.check, color: Colors.amber)
                      : null,
                  onTap: () => Idioma.instancia.cambiar(e.key),
                ),
              const Divider(),
              // ---- Música: volumen y modo silencio ----
              ListenableBuilder(
                listenable: Musica.instancia,
                builder: (ctx, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Música'),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        Icon(
                            Musica.instancia.silencio
                                ? Icons.volume_off
                                : Icons.volume_up,
                            size: 20),
                        Expanded(
                          child: Slider(
                            value: Musica.instancia.volumen,
                            onChanged: Musica.instancia.silencio
                                ? null
                                : Musica.instancia.cambiarVolumen,
                            onChangeEnd: (_) => Musica.instancia.guardarVolumen(),
                          ),
                        ),
                      ],
                    ),
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(tr('Modo silencio')),
                      value: Musica.instancia.silencio,
                      onChanged: (v) => Musica.instancia.ponerSilencio(v ?? false),
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.help_outline),
                title: Text(tr('Ver tutorial')),
                onTap: () {
                  Navigator.pop(ctx);
                  mostrarTutorialNuevo(context);
                },
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout),
                title: Text(tr('Cerrar sesión')),
                onTap: () {
                  Navigator.pop(ctx);
                  _cerrarSesion();
                },
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.feedback_outlined),
                title: Text(tr('Enviar comentario')),
                onTap: () {
                  Navigator.pop(ctx);
                  mostrarEnviarComentario(context);
                },
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.privacy_tip_outlined),
                title: Text(tr('Política de privacidad')),
                onTap: () => abrirUrl(context, urlPoliticaPrivacidad),
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.rule),
                title: Text(tr('Reglas de la comunidad')),
                onTap: () => abrirUrl(context, urlReglas),
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.delete_forever, color: Colors.red.shade300),
                title: Text(tr('Eliminar mi cuenta'),
                    style: TextStyle(color: Colors.red.shade300)),
                onTap: () {
                  Navigator.pop(ctx);
                  mostrarEliminarCuenta(context);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: Text(tr('Cerrar'))),
          ],
        ),
      ),
    );
  }

  // Oro o gemas en la barra superior: cápsula pequeña con ícono.
  Widget _monedaBarra(Widget icono, Color color, int valor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(70),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(170)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icono,
          const SizedBox(width: 4),
          Text('$valor',
              style:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // Fila de sub-pestañas, debajo de la barra superior. Se desliza si no caben.
  Widget _filaSubpestanas() {
    final subs = grupos[grupo].subs;
    return Container(
      height: 42,
      color: const Color(0xFF2A0F18),
      child: ListView.builder(
        controller: _scrollSubs,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        itemCount: subs.length,
        itemBuilder: (_, i) {
          final activa = subSel[grupo] == i;
          return InkWell(
            onTap: () => _irASub(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                      width: 3,
                      color: activa ? const Color(0xFFE03A3A) : Colors.transparent),
                ),
              ),
              child: Text(tr(subs[i].etiqueta),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: activa ? FontWeight.bold : FontWeight.normal,
                      color: activa ? const Color(0xFFFFD54A) : Colors.white70)),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      // También se reconstruye al cambiar el idioma.
      listenable: Listenable.merge([juego, Idioma.instancia, Social.instancia]),
      builder: (context, _) {
        mostrarMensajeSubidaNivel(context);
        mostrarAvisosLogros(context);
        final g = grupos[grupo];
        final actual = g.subs[subSel[grupo]];
        // La clave hace que cada sub-pestaña empiece limpia al cambiar.
        final pantalla = KeyedSubtree(
            key: ValueKey('$grupo-${subSel[grupo]}'), child: actual.pantalla());
        return Scaffold(
          appBar: AppBar(
            // El título se encoge si es largo, para no tocar el reloj del centro.
            title: SizedBox(
              width: MediaQuery.of(context).size.width / 2 - 70,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(tr(g.titulo)),
              ),
            ),
            // Reloj del servidor, al centro de la barra.
            flexibleSpace: const SafeArea(
              child: Center(child: RelojJuego()),
            ),
            actions: [
              IconButton(
                tooltip: tr('Ajustes'),
                icon: const Icon(Icons.settings),
                onPressed: _abrirAjustes,
              ),
              // Oro y gemas, en la esquina superior derecha.
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width / 2 - 110),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _monedaBarra(
                            const IconoMoneda(tam: 18),
                            Colors.amber,
                            juego.oro),
                        const SizedBox(height: 2),
                        _monedaBarra(const IconoEsquirla(tam: 18),
                            const Color(0xFFE53935), juego.gemas),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(42),
              child: _filaSubpestanas(),
            ),
          ),
          // Deslizar el dedo hacia los lados cambia de sub-pestaña.
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: _alSoltarDedo,
            child: actual.fondo == null
                ? pantalla
                : FondoPantalla(
              imagen: actual.fondo!,
              oscuridad: actual.oscuridad,
              child: pantalla,
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: grupo,
            onDestinationSelected: (i) {
              setState(() => grupo = i);
              if (_scrollSubs.hasClients) _scrollSubs.jumpTo(0);
              _centrarSub();
            },
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              for (final gr in grupos)
                NavigationDestination(
                    icon: gr.etiqueta == 'Social'
                        ? Badge(
                        isLabelVisible: Social.instancia.pendientes > 0,
                        label: Text('${Social.instancia.pendientes}'),
                        child: Icon(gr.icono))
                        : gr.etiqueta == 'Misiones'
                        ? Badge(
                        isLabelVisible: juego.diarias.hayParaCobrar,
                        child: Icon(gr.icono))
                        : gr.etiqueta == 'Inicio'
                    // Punto rojo: logros u oro del bestiario por cobrar
                        ? Badge(
                        isLabelVisible:
                        juego.logros.oroPendienteTotal > 0 ||
                            juego.bestiario.pendientesTotal > 0,
                        child: Icon(gr.icono))
                        : Icon(gr.icono),
                    label: tr(gr.etiqueta)),
            ],
          ),
        );
      },
    );
  }
}

// ====================== PANTALLAS ======================

// Barra de inclinación que crece desde el CENTRO: hacia la izquierda en rojo
// (mal) y hacia la derecha en azul (bien). Debajo se ven los puntos de cada lado.
class _BarraInclinacion extends StatelessWidget {
  final int valor; // de -100 (mal) a +100 (bien)
  const _BarraInclinacion(this.valor);

  @override
  Widget build(BuildContext context) {
    final mal = valor < 0 ? -valor : 0;
    final bien = valor > 0 ? valor : 0;
    // Como no hay tope, la barra se mide contra el siguiente múltiplo de 100
    // (hasta 100 puntos: llena al 100; de 101 a 200: contra 200; etc.).
    final escala = max(100, ((max(mal, bien) + 99) ~/ 100) * 100);
    final titulo = valor > 0
        ? 'Bien'
        : valor < 0
        ? 'Mal'
        : 'Neutral';
    const colorMal = Colors.redAccent;
    const colorBien = Colors.lightBlueAccent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Inclinación: $titulo', style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 14,
            color: const Color(0xFF3A2A30),
            child: Stack(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: FractionallySizedBox(
                          widthFactor: mal / escala,
                          heightFactor: 1,
                          child: Container(color: colorMal),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: bien / escala,
                          heightFactor: 1,
                          child: Container(color: colorBien),
                        ),
                      ),
                    ),
                  ],
                ),
                // Marca del centro (neutral)
                Center(
                  child: Container(width: 2, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Mal: $mal',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: mal > 0 ? FontWeight.bold : FontWeight.normal,
                    color: mal > 0 ? colorMal : Colors.white60)),
            Text('Bien: $bien',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: bien > 0 ? FontWeight.bold : FontWeight.normal,
                    color: bien > 0 ? colorBien : Colors.white60)),
          ],
        ),
      ],
    );
  }
}

class PantallaPersonaje extends StatelessWidget {
  // soloLogros: muestra solo estadísticas y logros (sub-pestaña Logros).
  final bool soloLogros;
  const PantallaPersonaje({super.key, this.soloLogros = false});

  // Una línea del equipo. Si el arma tiene nombre propio, brilla en turquesa.
  Widget _lineaRanura(Ranura r) {
    const estilo = TextStyle(fontSize: 13);
    final o = juego.equipado[r];
    if (o == null) return Text('${r.nombre}: ninguno', style: estilo);
    if (o.apodo == null) {
      return Text('${r.nombre}: ${o.nombre} (${o.resumen.toLowerCase()})',
          style: estilo);
    }
    return textoRonda(
        '${r.nombre}: $marcaApodoIni${o.apodo}$marcaApodoFin '
            '(${o.nombre}, ${o.resumen.toLowerCase()}'
            '${o.afilado > 0 ? ', Filo +${o.afilado}' : ''})',
        estilo);
  }

  Widget _titulo(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(texto,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final necesario = juego.famaParaSiguienteNivel();
    final bool enMaximo = juego.nivel >= nivelMaximo;
    final anchoColumna = (MediaQuery.of(context).size.width - 40) / 2;

    if (soloLogros) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SeccionLogrosPerfil(
            datos: juego.logros.comoPerfil(juego),
            especiales: juego.logros.especiales,
            puedeCobrar: true,
          ),
          const SizedBox(height: 16),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ---------- PRIMEROS PASOS (jugadores nuevos) ----------
        const GuiaInicial(),
        // ---------- RECOMPENSA DIARIA (solo si hay una por reclamar) ----------
        if (juego.puedeReclamarDiaria) ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.card_giftcard,
                  color: Colors.amber, size: 32),
              title: Text(tr('Recompensa diaria disponible'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                  '${tr('Racha')}: ${juego.rachaParaReclamar} ${juego.rachaParaReclamar == 1 ? tr('día') : tr('días')}',
                  style: const TextStyle(fontSize: 12)),
              trailing: BotonOscuro(
                texto: tr('Reclamar'),
                ancho: 110,
                alto: 40,
                color: ColorBoton.verde,
                onPressed: () => mostrarRecompensaDiaria(context),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ---------- NOMBRE Y NIVEL ----------
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Premium: medalla dorada y nombre en dorado.
            if (juego.premium) ...[
              const MedallaPremium(tamano: 26),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: NombreConTitulo(juego.nombre, juego.alineamiento,
                  tamano: 26,
                  dosLineas: true,
                  alinear: TextAlign.center,
                  colorNeutro: juego.premium ? Colors.amber : null),
            ),
            IconButton(
              tooltip: 'Personalizar',
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const DialogoPersonalizar(),
              ),
            ),
          ],
        ),
        Center(
            child: Text('Nivel ${juego.nivel}${enMaximo ? ' (máximo)' : ''}')),
        if (juego.logros.titulo != null)
          Center(
              child: Text('«${juego.logros.titulo}»',
                  style: const TextStyle(
                      fontStyle: FontStyle.italic, color: Colors.amber))),
        const SizedBox(height: 4),
        Center(
            child: Text(
                'Raza: ${juego.raza.nombre}  |  Pasiva: ${juego.raza.pasiva.nombre}',
                style: const TextStyle(fontSize: 12))),
        const SizedBox(height: 12),

        // ---------- IMAGEN DEL PERSONAJE ----------
        Center(
          child: Container(
            width: 180,
            height: 220,
            decoration: BoxDecoration(
              color: const Color(0xFF2A1218),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC0392B), width: 2),
            ),
            // Cuando tengas imágenes, cambia este Icon por:
            // Image.asset('assets/personaje.png', fit: BoxFit.cover)
            child: Icon(
              juego.genero == Genero.hombre ? Icons.man : Icons.woman,
              size: 140,
              color: Colors.white54,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ---------- VIDA Y FAMA (lado a lado) ----------
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Vida', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  BarraMarco(
                    valor: juego.vida / juego.vidaMaxima,
                    texto: '${juego.vida} / ${juego.vidaMaxima}',
                    color: ColorBarra.verde,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Fama', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  BarraMarco(
                    valor: enMaximo ? 1 : juego.xp / necesario,
                    texto: enMaximo ? 'MAX' : '${juego.xp} / $necesario',
                    color: ColorBarra.roja,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ---------- INCLINACIÓN (bien / mal) ----------
        _BarraInclinacion(juego.alineamiento),
        const SizedBox(height: 20),

        // ---------- EQUIPO ----------
        _titulo('Equipo'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final r in Ranura.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: _lineaRanura(r),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ---------- ATRIBUTOS (2 columnas) ----------
        _titulo('Atributos'),
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Se entrenan con oro en la pestaña Entrenar. Toca uno para ver qué hace.',
            style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: juego.atributos.entries.map((e) {
            return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => mostrarDescripcionAtributo(context, e.key),
                child: SizedBox(
                  width: anchoColumna,
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(e.key,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13)),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${e.value}',
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFF1E3C0))),
                              if (juego.bonoEquipo(e.key) != 0)
                                Text(
                                    ' ${juego.bonoEquipo(e.key) > 0 ? '+' : ''}${juego.bonoEquipo(e.key)}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: juego.bonoEquipo(e.key) > 0
                                            ? Colors.lightGreenAccent
                                            : Colors.redAccent)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ));
          }).toList(),
        ),
        const SizedBox(height: 12),
        Text(
          'Habilidades: armadura/escudo ${juego.habArmadura}, '
              'una mano ${juego.habUnaMano}, dos manos ${juego.habDosManos}',
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// Ventana para cambiar nombre y género del personaje
class DialogoPersonalizar extends StatefulWidget {
  const DialogoPersonalizar({super.key});

  @override
  State<DialogoPersonalizar> createState() => _DialogoPersonalizarState();
}

class _DialogoPersonalizarState extends State<DialogoPersonalizar> {
  late final TextEditingController _nombre =
  TextEditingController(text: juego.nombre);
  late Genero _genero = juego.genero;
  late Raza _raza = juego.raza;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Personalizar personaje'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nombre,
              maxLength: 16,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 12),
            const Text('Género'),
            const SizedBox(height: 8),
            SegmentedButton<Genero>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                    value: Genero.hombre,
                    label: Text('Hombre'),
                    icon: Icon(Icons.man)),
                ButtonSegment(
                    value: Genero.mujer,
                    label: Text('Mujer'),
                    icon: Icon(Icons.woman)),
              ],
              selected: {_genero},
              onSelectionChanged: (s) => setState(() => _genero = s.first),
            ),
            const SizedBox(height: 16),
            const Text('Raza'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: Raza.values
                  .map((r) => ChoiceChip(
                label: Text(r.nombre),
                selected: _raza == r,
                onSelected: (_) => setState(() => _raza = r),
              ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            Text(
              '${_raza.pasiva.nombre}: ${_raza.pasiva.descripcion}',
              style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.amber, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    juego.costoProximoCambioRaza == 0
                        ? 'Cambiar de raza es gratis solo esta vez. Después '
                        'costará ${EstadoJuego.costoCambioRaza} esquirlas cada cambio.'
                        : 'Cambiar de raza cuesta ${EstadoJuego.costoCambioRaza} '
                        'esquirlas (tienes ${juego.gemas}).',
                    style: const TextStyle(fontSize: 12, color: Colors.amber),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            final error = juego.personalizar(_nombre.text, _genero, _raza);
            if (error != null) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(error)));
              return;
            }
            Navigator.pop(context);
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class PantallaEntrenamiento extends StatelessWidget {
  const PantallaEntrenamiento({super.key});

  void _aviso(BuildContext context, String texto) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Widget _filaHabilidad(String titulo, int valor, VoidCallback onMas) {
    return Card(
      child: ListTile(
        title: Text(titulo),
        subtitle: Text('Puntos: $valor'),
        trailing: IconButton(
          icon: const Icon(Icons.add_circle, color: Color(0xFFC0392B)),
          onPressed: juego.puntosLibres > 0 ? onMas : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ---------- HABILIDADES (se suben con puntos libres) ----------
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Text('Puntos de habilidad libres: ${juego.puntosLibres}',
              style:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Text(
            'Ganas 3 puntos por nivel. Se gastan en las habilidades.',
            style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
          ),
        ),
        _filaHabilidad('Armadura y escudo', juego.habArmadura,
                () => juego.subirHabilidad('armadura')),
        _filaHabilidad('Armas de una mano', juego.habUnaMano,
                () => juego.subirHabilidad('unaMano')),
        _filaHabilidad('Armas de dos manos', juego.habDosManos,
                () => juego.subirHabilidad('dosManos')),
        const SizedBox(height: 16),

        // ---------- ATRIBUTOS (se compran con oro) ----------
        const Padding(
          padding: EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Text('Atributos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Text(
            'Entrena tus atributos pagando oro. Cada punto cuesta más que el anterior. Toca el nombre de un atributo para ver qué hace.',
            style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
          ),
        ),
        ...juego.atributos.entries.map((e) {
          final precio = juego.precioDe(e.key);
          final tope = topeEntrenamiento(e.key);
          final enTope = tope != null && juego.atributoTotal(e.key) >= tope;
          return Card(
            child: ListTile(
              onTap: () => mostrarDescripcionAtributo(context, e.key),
              title: Text(e.key),
              subtitle: Text('Valor: ${e.value}'
                  '${tope == null ? '' : '  |  Tope: $tope\n${textoPorcentajeTope(e.key, juego.atributoTotal(e.key))}'}'),
              trailing: BotonOscuro(
                texto: enTope ? 'En el tope' : '$precio oro',
                ancho: 110,
                alto: 40,
                color: ColorBoton.verde,
                onPressed:
                enTope ? null : () => _aviso(context, juego.entrenar(e.key)),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ---------- TÍTULO DE INCLINACIÓN (Luz / Sombra) ----------
// Se calcula solo con los puntos de bien (+) o de mal (-) del jugador.
const List<int> umbralesTituloInc = [25, 100, 300, 800, 2000, 5000, 12000, 30000, 60000];
const List<String> titulosLuz = [
  'Devoto', 'Heraldo de la Luz', 'Paladín', 'Cruzado Sagrado',
  'Guardián del Alba', 'Campeón Radiante', 'Serafín Terrenal',
  'Santo Viviente', 'Avatar de la Luz',
];
const List<String> titulosSombra = [
  'Rufián', 'Heraldo de la Sombra', 'Verdugo', 'Señor del Terror',
  'Azote de la Noche', 'Príncipe de la Ruina', 'Demonio Encarnado',
  'Archidemonio', 'Avatar de la Oscuridad',
];

String tituloInclinacion(int alineamiento) {
  final p = alineamiento.abs();
  var idx = -1;
  for (var i = 0; i < umbralesTituloInc.length; i++) {
    if (p >= umbralesTituloInc[i]) idx = i;
  }
  if (idx < 0) return 'Errante';
  return alineamiento > 0 ? titulosLuz[idx] : titulosSombra[idx];
}

// Nombre del jugador con su título delante.
// Luz: letras turquesa con halo dorado. Sombra: letras púrpura con halo negro.
// Errante: texto normal (con [colorNeutro] si se pide).
// [dosLineas]: el título va pequeño arriba y el nombre grande abajo (perfil).
// Icono de la moneda premium (esquirla roja). Si falta el PNG, dibuja un rombo rojo.
class IconoEsquirla extends StatelessWidget {
  final double tam;
  const IconoEsquirla({super.key, this.tam = 16});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/ui/esquirla.png',
      width: tam,
      height: tam,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          Icon(Icons.diamond, size: tam * 0.85, color: const Color(0xFFE53935)),
    );
  }
}

// Icono del oro (moneda con calavera coronada). Si falta el PNG, usa el ícono normal.
class IconoMoneda extends StatelessWidget {
  final double tam;
  const IconoMoneda({super.key, this.tam = 16});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/ui/moneda.png',
      width: tam,
      height: tam,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          Icon(Icons.monetization_on, size: tam * 0.85, color: Colors.amber),
    );
  }
}

class NombreConTitulo extends StatelessWidget {
  final String nombre;
  final int alineamiento;
  final double tamano;
  final Color? colorNeutro;
  final TextAlign alinear;
  final bool dosLineas;
  const NombreConTitulo(this.nombre, this.alineamiento,
      {super.key,
        this.tamano = 15,
        this.colorNeutro,
        this.alinear = TextAlign.start,
        this.dosLineas = false});

  // Texto con el efecto de Luz (letra negra + halo plateado) o Sombra (letra negra + halo púrpura).
  Widget _conEfecto(String texto, double tam, bool luz) {
    const Color relleno = Colors.black;
    final Color halo = luz ? const Color(0xFFDCE6EE) : const Color(0xFFA24DFF);
    final trazo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = tam * (luz ? 0.30 : 0.28)
      ..color = halo;
    final sombras = luz
        ? const [
      Shadow(color: Color(0xFFDCE6EE), blurRadius: 8),
      Shadow(color: Color(0xFFDCE6EE), blurRadius: 16),
      Shadow(color: Color(0xFFB0BEC5), blurRadius: 26),
    ]
        : const [
      Shadow(color: Color(0xFFB266FF), blurRadius: 8),
      Shadow(color: Color(0xFFA24DFF), blurRadius: 16),
      Shadow(color: Color(0xFF7B2CD9), blurRadius: 26),
    ];
    Text capa(TextStyle st) => Text(texto,
        maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: alinear, style: st);
    return Stack(
      children: [
        capa(TextStyle(
            fontSize: tam,
            fontWeight: FontWeight.bold,
            foreground: trazo,
            shadows: sombras)),
        capa(TextStyle(fontSize: tam, fontWeight: FontWeight.bold, color: relleno)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final titulo = tituloInclinacion(alineamiento);
    final bool conTitulo = alineamiento.abs() >= umbralesTituloInc.first;
    final Text nombreSolo = Text(nombre,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: alinear,
        style: TextStyle(
            fontSize: tamano, fontWeight: FontWeight.bold, color: colorNeutro));
    if (!conTitulo) {
      return dosLineas
          ? nombreSolo
          : Text('$titulo $nombre',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alinear,
          style: TextStyle(
              fontSize: tamano, fontWeight: FontWeight.bold, color: colorNeutro));
    }
    final luz = alineamiento > 0;
    if (dosLineas) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _conEfecto(titulo, tamano * 0.62, luz),
          nombreSolo,
        ],
      );
    }
    return _conEfecto('$titulo $nombre', tamano, luz);
  }
}

// ---------- NOMBRE BRILLANTE (armas con apodo) ----------
// Letras turquesa con un aura que pulsa suavemente.

class ApodoBrillante extends StatefulWidget {
  final String texto;
  final double tamano;
  const ApodoBrillante(this.texto, {super.key, this.tamano = 17});

  @override
  State<ApodoBrillante> createState() => _ApodoBrillanteState();
}

class _ApodoBrillanteState extends State<ApodoBrillante>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const turquesa = Color(0xFF00F5E0);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final k = 0.6 + 0.4 * _c.value; // intensidad del aura (0.6 a 1.0)
        return Text(
          widget.texto,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: widget.tamano,
            color: const Color(0xFFB8FFF8),
            shadows: [
              Shadow(color: turquesa, blurRadius: 6 * k),
              Shadow(color: const Color(0xCC00F5E0), blurRadius: 14 * k),
              Shadow(color: const Color(0x8000F5E0), blurRadius: 26 * k),
            ],
          ),
        );
      },
    );
  }
}

// ---------- FILA DE OBJETO (tienda e inventario) ----------

Widget _etiquetaObjeto(String texto, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: color.withAlpha(40),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withAlpha(160)),
    ),
    child: Text(texto,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold, color: color)),
  );
}

class _FilaObjeto extends StatelessWidget {
  final Objeto objeto;
  final String detalle;
  final List<Widget> botones;
  final int cantidad; // se muestra "xN" si es mayor que 1
  final bool equipado;
  final String? aviso; // texto rojo pequeño (ej: nivel que falta)
  // Si se da, se muestra justo debajo del detalle (lo usa la tienda para
  // pintar cada requisito de su propio color).
  final Widget? requisitos;
  // Etiqueta destacada junto al nombre (ej: OFERTA en el Mercado negro).
  final String? etiqueta;

  const _FilaObjeto({
    required this.objeto,
    required this.detalle,
    required this.botones,
    this.cantidad = 0,
    this.equipado = false,
    this.aviso,
    this.requisitos,
    this.etiqueta,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Imagen grande arriba
            ImagenObjeto(
              nombre: objeto.nombre,
              tamano: 150,
              respaldo: Container(
                color: Colors.black26,
                child: Icon(objeto.tipo.icono, size: 64, color: Colors.white38),
              ),
            ),
            const SizedBox(height: 10),
            // Nombre y etiquetas
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (objeto.apodo == null)
                  Text(objeto.nombre,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16))
                else
                  ApodoBrillante(objeto.apodo!),
                if (etiqueta != null)
                  _etiquetaObjeto(etiqueta!, Colors.orangeAccent),
                if (cantidad > 1) _etiquetaObjeto('x$cantidad', Colors.amber),
                if (equipado)
                  _etiquetaObjeto('Equipado', Colors.lightGreenAccent),
              ],
            ),
            const SizedBox(height: 4),
            // Con apodo, se ve debajo qué arma es en realidad
            if (objeto.apodo != null)
              Text('(${objeto.nombre})',
                  style: const TextStyle(fontSize: 11, color: Colors.white54)),
            // Estadísticas
            if (detalle.isNotEmpty)
              Text(detalle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13)),
            if (requisitos != null) requisitos!,
            if (aviso != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(aviso!,
                    textAlign: TextAlign.center,
                    style:
                    const TextStyle(fontSize: 12, color: Colors.redAccent)),
              ),
            const SizedBox(height: 10),
            // Botones debajo
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: botones,
            ),
          ],
        ),
      ),
    );
  }
}

// Requisitos de un objeto para la tienda: cada uno en rojo si todavía no lo
// cumples (nivel, puntos de habilidad e inclinación por separado).
Widget _requisitosTienda(Objeto o, int tiene, {int? precioOferta}) {
  const rojo = TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold);
  final partes = <InlineSpan>[];
  void agregar(String texto, bool falta) {
    if (partes.isNotEmpty) partes.add(const TextSpan(text: ', '));
    partes.add(TextSpan(text: texto, style: falta ? rojo : null));
  }

  agregar('nivel ${o.nivelRequerido}', juego.nivel < o.nivelRequerido);
  if (o.habilidadMin > 0) {
    // Se aclara de qué habilidad se trata (una mano, dos manos o armadura).
    final cual = switch (o.tipo) {
      TipoObjeto.armaUnaMano => 'de una mano',
      TipoObjeto.armaDosManos => 'de dos manos',
      TipoObjeto.escudo => 'de armadura y escudo',
      TipoObjeto.armadura => 'de armadura y escudo',
      _ => '',
    };
    agregar('habilidad ${cual.isEmpty ? '' : '$cual '}${o.habilidadMin}',
        juego.habilidadPara(o) < o.habilidadMin);
  }
  final falloInclinacion = juego.motivoInclinacion(o) != null;
  if (o.inclinacion > 0) {
    agregar('${o.inclinacion} puntos de bien', falloInclinacion);
  }
  if (o.inclinacion < 0) {
    agregar('${-o.inclinacion} puntos de mal', falloInclinacion);
  }
  return Column(
    children: [
      Text.rich(
        TextSpan(children: [
          const TextSpan(text: 'Pide '),
          ...partes,
          if (precioOferta == null)
            TextSpan(text: '  |  ${o.textoPrecio}')
          else
            TextSpan(
                text: '  |  Oferta: $precioOferta '
                    '${o.conGemas ? 'esquirlas' : 'oro'}',
                style: const TextStyle(
                    color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
        ]),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13),
      ),
      if (precioOferta != null)
        Text('¡Más barato que en la Tienda! Allí cuesta ${o.textoPrecio}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.orangeAccent)),
      if (tiene > 0)
        Text('Tienes: $tiene',
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
    ],
  );
}

// Orden: nivel requerido, luego precio, luego nombre.
int _compararObjetos(Objeto a, Objeto b) {
  final porNivel = a.nivelRequerido.compareTo(b.nivelRequerido);
  if (porNivel != 0) return porNivel;
  final porPrecio = a.precio.compareTo(b.precio);
  if (porPrecio != 0) return porPrecio;
  final porNombre = a.nombre.compareTo(b.nombre);
  if (porNombre != 0) return porNombre;
  return a.afilado.compareTo(b.afilado);
}

// Arma la lista con un encabezado "Nivel N" cada vez que cambia el nivel.
List<Widget> _conEncabezadosDeNivel(
    List<Objeto> objetos, Widget Function(Objeto) fila) {
  final salida = <Widget>[];
  int? ultimo;
  for (final o in objetos) {
    if (o.nivelRequerido != ultimo) {
      ultimo = o.nivelRequerido;
      salida.add(Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
        child: Text('Nivel $ultimo',
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.amber)),
      ));
    }
    salida.add(fila(o));
  }
  return salida;
}

// ---------- TIENDA ----------

class PantallaTienda extends StatelessWidget {
  const PantallaTienda({super.key});

  void _aviso(BuildContext context, String texto) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    // Solo las categorías que tienen algo a la venta
    final tipos = TipoObjeto.values
        .where((t) => catalogoTienda.any((o) => o.tipo == t))
        .toList();
    // Solo se ven objetos hasta [nivelesExtraTienda] niveles sobre el tuyo.
    final nivelMaxVisible = juego.nivel + nivelesExtraTienda;
    return DefaultTabController(
      length: tipos.length,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: const Color(0xFFC0392B),
            tabs: tipos.map((t) => Tab(text: t.pestana)).toList(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(
              'Ves objetos hasta el nivel $nivelMaxVisible. '
                  'Los de más nivel aparecen al subir.',
              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: TabBarView(
              children: tipos.map((tipo) {
                // De más nivel a menos: lo de tu nivel queda arriba.
                final items = catalogoTienda
                    .where((o) =>
                o.tipo == tipo && o.nivelRequerido <= nivelMaxVisible)
                    .toList()
                  ..sort((a, b) => _compararObjetos(b, a));
                if (items.isEmpty) {
                  return const Center(
                    child: Text('No hay objetos de este tipo para tu nivel.',
                        textAlign: TextAlign.center),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: _conEncabezadosDeNivel(items, (o) {
                    final tiene = juego.cantidadPorNombre(o);
                    // Daño/defensa y bonos; los requisitos van aparte, con color.
                    final lineas = <String>[
                      if (o.esArmaOProteccion)
                        '${o.tipo.etiquetaValor} ${o.danoMin}-${o.danoMax}',
                      if (o.textoBonos.isNotEmpty) o.textoBonos,
                    ];
                    return _FilaObjeto(
                      objeto: o,
                      detalle: lineas.join('\n'),
                      requisitos: _requisitosTienda(o, tiene),
                      botones: [
                        BotonOscuro(
                          texto: 'Comprar',
                          ancho: 110,
                          alto: 40,
                          color: o.conGemas
                              ? ColorBoton.azul
                              : ColorBoton.verde,
                          onPressed: () => _aviso(context, juego.comprar(o)),
                        ),
                      ],
                    );
                  }),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- MERCADO NEGRO (en el código se llama "bazar") ----------
// Pocos objetos por día, 1 unidad de cada uno. Se renueva a medianoche.

class PantallaBazar extends StatefulWidget {
  const PantallaBazar({super.key});

  @override
  State<PantallaBazar> createState() => _PantallaBazarState();
}

class _PantallaBazarState extends State<PantallaBazar> {
  Timer? _vigia;

  @override
  void initState() {
    super.initState();
    // Sin avisar: initState corre mientras se dibuja y no se puede notificar.
    juego.actualizarBazar(avisar: false);
    // Si el juego queda abierto pasada la medianoche, se renueva solo.
    _vigia = Timer.periodic(
        const Duration(seconds: 30), (_) {
      juego.actualizarBazar();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _vigia?.cancel();
    super.dispose();
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    final items = juego.bazarDisponibles..sort((a, b) => _compararObjetos(b, a));
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Text(
            'El Mercado negro trae de 2 a 5 objetos al azar cada día (armas, escudos, armaduras, anillos...) y solo 1 unidad de cada uno. '
                'Se renueva a medianoche.',
            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Compraste todo lo que había hoy.\n'
                    'Vuelve mañana: llegarán nuevos objetos.',
                textAlign: TextAlign.center,
              ),
            ),
          )
              : ListView(
            padding: const EdgeInsets.all(12),
            children: _conEncabezadosDeNivel(items, (o) {
              final tiene = juego.cantidadPorNombre(o);
              final lineas = <String>[
                if (o.esArmaOProteccion)
                  '${o.tipo.etiquetaValor} ${o.danoMin}-${o.danoMax}',
                if (o.textoBonos.isNotEmpty) o.textoBonos,
              ];
              final rebaja = juego.bazarRebaja.contains(o.nombre);
              return _FilaObjeto(
                objeto: o,
                detalle: lineas.join('\n'),
                etiqueta: rebaja ? 'OFERTA -10%' : null,
                requisitos: _requisitosTienda(o, tiene,
                    precioOferta: rebaja ? juego.precioBazar(o) : null),
                botones: [
                  BotonOscuro(
                    texto: 'Comprar',
                    ancho: 110,
                    alto: 40,
                    color: o.conGemas
                        ? ColorBoton.azul
                        : ColorBoton.verde,
                    onPressed: () {
                      _aviso(juego.comprarBazar(o));
                      setState(() {});
                    },
                  ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

// ---------- AFILADOR AMBULANTE ----------
// Afila tus armas con gemas: +1 de daño por afilado, hasta 3 veces por arma.

class PantallaAfilador extends StatelessWidget {
  const PantallaAfilador({super.key});

  void _aviso(BuildContext context, String texto) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  // Pide el nombre y se lo pone al arma.
  Future<void> _pedirNombre(BuildContext context, Objeto o) async {
    final c = TextEditingController(text: o.apodo ?? '');
    final nombre = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nombre del arma'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: c,
              autofocus: true,
              maxLength: largoMaxApodo,
              inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[|]'))],
              decoration: const InputDecoration(hintText: 'Escribe el nombre'),
            ),
            const SizedBox(height: 4),
            Text('Cuesta $costoRenombrar esquirlas. Solo lo ves tú.',
                style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, c.text),
              child: const Text('Grabar')),
        ],
      ),
    );
    c.dispose();
    if (nombre != null && context.mounted) {
      _aviso(context, juego.renombrar(o, nombre));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Una fila por tipo de arma y afilado (las copias iguales se apilan).
    final grupos = <String, List<Objeto>>{};
    for (final o in juego.inventario.where((o) =>
    o.tipo == TipoObjeto.armaUnaMano || o.tipo == TipoObjeto.armaDosManos)) {
      grupos.putIfAbsent(o.claveApilado, () => []).add(o);
    }
    final armas = grupos.values.map((l) => l.first).toList()
      ..sort((a, b) => _compararObjetos(b, a));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Text(
            'El afilador afila tus armas hasta $afiladosMax veces. '
                'Cada afilado suma +1 de daño y cuesta $costoAfilado esquirlas.\n'
                'También puede grabarles un nombre que brilla: '
                '$costoRenombrar esquirlas.\n'
                'Tienes ${juego.gemas} esquirlas.',
            style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: armas.isEmpty
              ? const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No tienes armas para afilar.\nVisita la tienda.',
                  textAlign: TextAlign.center),
            ),
          )
              : ListView(
            padding: const EdgeInsets.all(12),
            children: _conEncabezadosDeNivel(armas, (o) {
              final cantidad = grupos[o.claveApilado]!.length;
              final alMaximo = o.afilado >= afiladosMax;
              return _FilaObjeto(
                objeto: o,
                cantidad: cantidad,
                equipado: juego.estaEquipado(o),
                etiqueta: o.afilado > 0 ? 'Filo +${o.afilado}' : null,
                detalle: '${o.tipo.etiquetaValor} ${o.danoMin}-${o.danoMax}'
                    '${alMaximo ? '' : '  ->  ${o.danoMin + 1}-${o.danoMax + 1}'}',
                botones: [
                  BotonOscuro(
                    texto: alMaximo
                        ? 'Al máximo'
                        : 'Afilar ($costoAfilado esquirlas)',
                    ancho: 190,
                    alto: 40,
                    color: ColorBoton.azul,
                    onPressed: alMaximo
                        ? null
                        : () => _aviso(context, juego.afilar(o)),
                  ),
                  BotonOscuro(
                    texto: o.apodo == null
                        ? 'Poner nombre ($costoRenombrar esquirlas)'
                        : 'Cambiar nombre ($costoRenombrar esquirlas)',
                    ancho: 190,
                    alto: 40,
                    color: ColorBoton.verde,
                    onPressed: () => _pedirNombre(context, o),
                  ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

// ---------- INVENTARIO ----------
// Pestañas por tipo; dentro de cada una, ordenado por nivel y con los objetos
// repetidos apilados (x2, x3...).

class PantallaInventario extends StatelessWidget {
  const PantallaInventario({super.key});

  void _aviso(BuildContext context, String texto) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _venderTodo(BuildContext context, Objeto o) async {
    final n = juego.disponiblesParaVender(o);
    final total = juego.valorVenta(o) * n;
    final moneda = o.conGemas ? 'esquirlas' : 'de oro';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Vender todo?'),
        content: Text('Vas a vender $n x ${o.nombreMostrado} por $total $moneda.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Vender')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      _aviso(context, juego.vender(o, cantidad: n));
    }
  }

  Widget _lista(BuildContext context, TipoObjeto tipo) {
    // Apila por nombre: un solo renglón por objeto, con su cantidad.
    final grupos = <String, List<Objeto>>{};
    for (final o in juego.inventario.where((o) => o.tipo == tipo)) {
      grupos.putIfAbsent(o.claveApilado, () => []).add(o);
    }
    final objetos = grupos.values.map((l) => l.first).toList()
      ..sort(_compararObjetos);
    if (objetos.isEmpty) {
      return const Center(
        child: Text('No tienes objetos de este tipo.\nVisita la tienda.',
            textAlign: TextAlign.center),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: _conEncabezadosDeNivel(objetos, (o) {
        final equipado = juego.estaEquipado(o);
        final cantidad = grupos[o.claveApilado]!.length;
        final vendibles = juego.disponiblesParaVender(o);
        final moneda = o.conGemas ? 'esquirlas' : 'de oro';
        return _FilaObjeto(
          objeto: o,
          cantidad: cantidad,
          equipado: equipado,
          etiqueta: o.afilado > 0 ? 'Filo +${o.afilado}' : null,
          aviso: equipado ? null : juego.motivoInclinacion(o),
          detalle:
          '${o.detalle(conPrecio: false)}\nVenta: ${juego.valorVenta(o)} $moneda',
          botones: [
            BotonOscuro(
              texto: equipado ? 'Quitar' : 'Equipar',
              ancho: 110,
              alto: 36,
              color: equipado ? ColorBoton.rojo : ColorBoton.azul,
              onPressed: () {
                if (equipado) {
                  juego.desequiparObjeto(o);
                } else {
                  _aviso(context, juego.equipar(o));
                }
              },
            ),
            BotonOscuro(
              texto: 'Vender',
              ancho: 110,
              alto: 36,
              color: ColorBoton.verde,
              onPressed:
              vendibles > 0 ? () => _aviso(context, juego.vender(o)) : null,
            ),
            if (vendibles > 1)
              BotonOscuro(
                texto: 'Vender x$vendibles',
                ancho: 110,
                alto: 36,
                color: ColorBoton.rojo,
                onPressed: () => _venderTodo(context, o),
              ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (juego.inventario.isEmpty) {
      return const Center(
        child: Text('Tu inventario está vacío.\nVisita la tienda.',
            textAlign: TextAlign.center),
      );
    }
    final tipos = TipoObjeto.values.toList();
    // Abre en la primera pestaña que tenga algo.
    final primera = tipos.indexWhere(
            (t) => juego.inventario.any((o) => o.tipo == t));
    return DefaultTabController(
      length: tipos.length,
      initialIndex: primera < 0 ? 0 : primera,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: const Color(0xFFC0392B),
            tabs: tipos.map((t) {
              final n = juego.inventario.where((o) => o.tipo == t).length;
              return Tab(text: n > 0 ? '${t.pestana} ($n)' : t.pestana);
            }).toList(),
          ),
          Expanded(
            child: TabBarView(
              children: tipos.map((t) => _lista(context, t)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- MISIONES ----------

class PantallaMisiones extends StatefulWidget {
  const PantallaMisiones({super.key});

  @override
  State<PantallaMisiones> createState() => _PantallaMisionesState();
}

class _PantallaMisionesState extends State<PantallaMisiones> {
  Timer? _reloj;
  bool eligeBien = true;
  int bloquesElegidos = opcionesBloques.first;

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
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

  String _tiempoRestante() {
    final falta = juego.misionTermina!.difference(DateTime.now());
    final s = falta.inSeconds.clamp(0, 99999);
    final min = (s ~/ 60).toString().padLeft(2, '0');
    final seg = (s % 60).toString().padLeft(2, '0');
    return '$min:$seg';
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    // Tiempo de misión que te queda hoy y duración que se puede elegir
    final restantes = juego.bloquesRestantesHoy;
    final cabenEnElDia = opcionesBloques.where((b) => b <= restantes).toList();
    final elegido = bloquesElegidos <= restantes || cabenEnElDia.isEmpty
        ? bloquesElegidos
        : cabenEnElDia.last;

    // Resultado de la última misión
    if (juego.ultimoResultado != null) {
      children.add(Card(
        color: const Color(0xFF3A1A22),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(juego.ultimoResultado!),
        ),
      ));
      children.add(const SizedBox(height: 8));
    }

    if (juego.hayMisionEnCurso) {
      // ---- Misión en curso (el destino no se muestra) ----
      children.add(Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  juego.misionEsBien
                      ? 'Misión en curso (camino del bien)'
                      : 'Misión en curso (camino del mal)',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (juego.misionLista) ...[
                BotonOscuro(
                  texto: 'Cobrar recompensa',
                  color: juego.misionEsBien ? ColorBoton.azul : ColorBoton.rojo,
                  onPressed: () => juego.cobrarMision(),
                ),
                const SizedBox(height: 8),
                BotonOscuro(
                  texto: juego.sinAnuncios
                      ? 'Cobrar x2 (oro y fama)'
                      : 'Cobrar x2 viendo un anuncio',
                  color: ColorBoton.verde,
                  onPressed: juego.puedeVerAnuncio
                      ? () {
                    final r =
                    juego.pedirAnuncio(juego.recompensaDobleMision);
                    if (r != null) _aviso(r);
                  }
                      : null,
                ),
              ] else
                Text('Tiempo restante: ${_tiempoRestante()}',
                    style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ));
    } else {
      // ---- Elegir misión: solo inclinación y duración ----
      children.add(Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nueva misión',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('Inclinación'),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                      value: true,
                      label: Text('Bien'),
                      icon: Icon(Icons.shield)),
                  ButtonSegment(
                      value: false,
                      label: Text('Mal'),
                      icon: Icon(Icons.dangerous)),
                ],
                selected: {eligeBien},
                onSelectionChanged: (s) => setState(() => eligeBien = s.first),
              ),
              const SizedBox(height: 20),
              const Text('Duración'),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: opcionesBloques
                    .map((b) => ButtonSegment(
                    value: b,
                    label: Text('${b * minutosPorBloque} min'),
                    enabled: b <= restantes))
                    .toList(),
                selected: {elegido},
                onSelectionChanged: (s) =>
                    setState(() => bloquesElegidos = s.first),
              ),
              const SizedBox(height: 20),
              BotonOscuro(
                texto: 'Partir a la aventura ($costoMision oro)',
                alto: 52,
                color: eligeBien ? ColorBoton.azul : ColorBoton.rojo,
                onPressed: juego.puedeIniciarMision(elegido)
                    ? () => juego.iniciarMision(
                    esBien: eligeBien, bloques: elegido)
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                'Tiempo de misión hoy: ${juego.bloquesUsadosHoy * minutosPorBloque} / ${juego.limiteBloquesDia * minutosPorBloque} min',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              BotonOscuro(
                texto: juego.sinAnuncios
                    ? '+${bloquesPorAnuncio * minutosPorBloque} min de misión hoy'
                    : '+${bloquesPorAnuncio * minutosPorBloque} min de misión (ver anuncio)',
                alto: 44,
                color: ColorBoton.verde,
                onPressed: juego.puedeVerAnuncio
                    ? () {
                  final r =
                  juego.pedirAnuncio(juego.recompensaTiempoExtra);
                  if (r != null) _aviso(r);
                }
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Recompensas por anuncio disponibles hoy: ${juego.anunciosRestantesHoy} / $maxAnunciosPorDia',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                juego.trabajando
                    ? 'Estás trabajando en la taberna. Termina o abandona el trabajo para partir.'
                    : restantes <= 0
                    ? 'Ya usaste todo tu tiempo de misión de hoy. Vuelve mañana.'
                    : juego.oro < costoMision
                    ? 'Necesitas $costoMision de oro para partir.'
                    : 'No sabrás adónde te lleva el camino hasta volver.',
                style:
                const TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
              ),
            ],
          ),
        ),
      ));
    }

    return ListView(padding: const EdgeInsets.all(12), children: children);
  }
}

// ---------- TABERNA ----------

class PantallaTaberna extends StatefulWidget {
  const PantallaTaberna({super.key});

  @override
  State<PantallaTaberna> createState() => _PantallaTabernaState();
}

class _PantallaTabernaState extends State<PantallaTaberna> {
  Timer? _reloj;
  bool eligeBien = true;
  int horas = 4;

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
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

  String _tiempoRestante() {
    final falta = juego.trabajoTermina!.difference(DateTime.now());
    final s = falta.inSeconds.clamp(0, 999999);
    final hh = (s ~/ 3600).toString().padLeft(2, '0');
    final mm = ((s % 3600) ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  Future<void> _confirmarAbandono() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Abandonar el trabajo?'),
        content: const Text(
            'Si te vas ahora perderás el tiempo trabajado y no cobrarás nada.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Seguir trabajando'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abandonar'),
          ),
        ],
      ),
    );
    if (ok == true) juego.cancelarTrabajo();
  }

  @override
  Widget build(BuildContext context) {
    final hijos = <Widget>[];

    // Resultado del último trabajo
    if (juego.ultimoResultadoTaberna != null) {
      hijos.add(Card(
        color: const Color(0xFF3A1A22),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(juego.ultimoResultadoTaberna!),
        ),
      ));
      hijos.add(const SizedBox(height: 8));
    }

    if (juego.trabajando) {
      // ---- Trabajo en curso ----
      final t = juego.trabajoActual!;
      hijos.add(Card(
        color: fondoInclinacion(juego.trabajoEsBien),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Trabajando: ${t.nombre}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(t.descripcion,
                  style: const TextStyle(
                      fontStyle: FontStyle.italic, fontSize: 12)),
              const SizedBox(height: 12),
              Text(
                  'Turno de ${juego.trabajoHoras} ${juego.trabajoHoras == 1 ? 'hora' : 'horas'}  |  Sueldo: ${juego.trabajoPago} de oro'),
              const SizedBox(height: 12),
              if (juego.trabajoListo)
                BotonOscuro(
                  texto: 'Cobrar sueldo',
                  alto: 52,
                  color:
                  juego.trabajoEsBien ? ColorBoton.azul : ColorBoton.rojo,
                  onPressed: juego.cobrarTrabajo,
                )
              else ...[
                Text('Tiempo restante: ${_tiempoRestante()}',
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _confirmarAbandono,
                    child: const Text('Abandonar trabajo'),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              const Text(
                'Mientras trabajas no puedes salir de misión ni pelear.',
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
              ),
            ],
          ),
        ),
      ));
    } else {
      // ---- Elegir inclinación, duración y trabajo ----
      final ofertas = juego.ofertasTaberna[eligeBien]!;
      final porHora = pagoPorHoraTaberna(juego.nivel, juego.premium);
      final puntos = puntosTaberna(horas);
      hijos.add(Card(
        color: fondoInclinacion(eligeBien),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Trabajos de la taberna',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                'Cada hora paga $porHora de oro (sube con tu nivel'
                    '${juego.premium ? ', +${(bonusPremiumTaberna * 100).round()}% premium' : ''}). '
                    'Si abandonas antes de terminar, no cobras nada.',
                style:
                const TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
              ),
              const SizedBox(height: 16),
              const Text('Inclinación'),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                      value: true,
                      label: Text('Bien'),
                      icon: Icon(Icons.shield)),
                  ButtonSegment(
                      value: false,
                      label: Text('Mal'),
                      icon: Icon(Icons.dangerous)),
                ],
                selected: {eligeBien},
                onSelectionChanged: (s) => setState(() => eligeBien = s.first),
              ),
              const SizedBox(height: 16),
              Text('Duración: $horas ${horas == 1 ? 'hora' : 'horas'}'),
              Slider(
                value: horas.toDouble(),
                min: horasMinTaberna.toDouble(),
                max: horasMaxTaberna.toDouble(),
                divisions: horasMaxTaberna - horasMinTaberna,
                label: '$horas h',
                onChanged: (v) => setState(() => horas = v.round()),
              ),
              Text(
                'Sueldo: ${pagoTaberna(juego.nivel, horas, juego.premium)} de oro  |  '
                    '+$puntos ${puntos == 1 ? 'punto' : 'puntos'} de ${eligeBien ? 'bien' : 'mal'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ));

      hijos.add(const Padding(
        padding: EdgeInsets.fromLTRB(8, 16, 8, 6),
        child: Text('Trabajos disponibles',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ));
      for (final t in ofertas) {
        final color = colorInclinacion(eligeBien);
        hijos.add(FilaConBoton(
          icono: Icon(eligeBien ? Icons.shield : Icons.dangerous, color: color),
          titulo: t.nombre,
          detalle: t.descripcion,
          colorTitulo: color,
          colorFondo: fondoInclinacion(eligeBien),
          colorBorde: color.withAlpha(160),
          boton: BotonOscuro(
            texto: 'Trabajar',
            ancho: 110,
            alto: 40,
            color: eligeBien ? ColorBoton.azul : ColorBoton.rojo,
            onPressed: () {
              final r = juego.iniciarTrabajo(t, horas, esBien: eligeBien);
              if (r != null) _aviso(r);
            },
          ),
        ));
      }
      hijos.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: OutlinedButton(
          onPressed: () => juego.actualizarOfertas(eligeBien),
          child: const Text('Ver otros trabajos'),
        ),
      ));
    }

    return ListView(padding: const EdgeInsets.all(12), children: hijos);
  }
}

// ---------- COMBATE ----------

// Qué se está viendo dentro de la pestaña Combate
enum VistaCombate { menu, arena, cripta, ciudadela, jefes, historial }

class PantallaCombate extends StatefulWidget {
  // Si [fija] no es null, la pantalla muestra solo esa vista y sin botón
  // "Volver" (la navegación la hacen las sub-pestañas).
  final VistaCombate? fija;
  const PantallaCombate({super.key, this.fija});

  @override
  State<PantallaCombate> createState() => _PantallaCombateState();
}

class _PantallaCombateState extends State<PantallaCombate> {
  Timer? _reloj;
  late VistaCombate vista = widget.fija ?? VistaCombate.menu;

  @override
  void initState() {
    super.initState();
    // Refresca la pantalla para ver cómo se recupera la vida
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
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

  void _ir(VistaCombate nueva) {
    setState(() {
      vista = nueva;
    });
  }

  // Fondo que le toca a cada vista de Combate
  String get _fondoActual {
    switch (vista) {
      case VistaCombate.menu:
        return Fondos.combate;
      case VistaCombate.arena:
        return Fondos.arena;
      case VistaCombate.cripta:
        return Fondos.cripta;
      case VistaCombate.ciudadela:
        return Fondos.ciudadela;
      case VistaCombate.jefes:
        return Fondos.cripta;
      case VistaCombate.historial:
        return Fondos.combate;
    }
  }

  // ---------- Piezas compartidas ----------

  Widget _botonVolver() {
    if (widget.fija != null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => _ir(VistaCombate.menu),
        icon: const Icon(Icons.arrow_back),
        label: const Text('Volver'),
      ),
    );
  }

  // Tu vida, ataque y defensa
  Widget _tarjetaEstado() {
    final vida = juego.vida;
    final maxima = juego.vidaMaxima;
    final puedePelear = vida >= maxima * vidaMinimaParaPelear;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vida: $vida / $maxima',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: vida / maxima,
                minHeight: 12,
                color: Colors.green,
                backgroundColor: const Color(0xFF3A2A30),
              ),
            ),
            const SizedBox(height: 8),
            Text('Ataque ${juego.ataqueTotal}  |  Defensa ${juego.defensaTotal}',
                style: const TextStyle(fontSize: 12)),
            if (!puedePelear)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Estás demasiado herido para pelear. Tu vida se recupera sola con el tiempo.',
                  style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                ),
              ),
            if (vida < maxima)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: BotonOscuro(
                    texto: juego.sinAnuncios
                        ? 'Curarte al instante'
                        : 'Curarte viendo un anuncio',
                    alto: 44,
                    color: ColorBoton.verde,
                    onPressed: juego.puedeVerAnuncio
                        ? () {
                      final r =
                      juego.pedirAnuncio(juego.recompensaCurar);
                      if (r != null) _aviso(r);
                      setState(() {});
                    }
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tituloSeccion(String titulo, String explicacion) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(explicacion,
              style:
              const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
        ],
      ),
    );
  }

  // Botón que ocupa todo el ancho
  Widget _botonAncho(String texto, VoidCallback? onPressed,
      {bool contorno = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        width: double.infinity,
        child: BotonOscuro(
          texto: texto,
          alto: 48,
          color: contorno ? ColorBoton.morado : ColorBoton.rojo,
          onPressed: onPressed,
        ),
      ),
    );
  }

  // Un rival con todos sus datos. El botín y la fama se ven recién después de pelear.
  // El botón "Pelear" va abajo, a todo el ancho, para que el texto respire.
  Widget _tarjetaEnemigo(LugarCombate lugar, Enemigo e, bool puedePelear) {
    final c = e.c;
    const chico = TextStyle(fontSize: 12);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${e.nombre}  -  ${e.perfil}',
                style:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
                'Nivel ${e.nivel}  |  Vida ${c.vidaMaxima}  |  Ataque ${c.ataque.round()}  |  Defensa ${c.defensa.round()}',
                style: chico),
            Text(
                'Poder ${c.poder}  |  Vigor ${c.vigor}  |  Agilidad ${c.agilidad}  |  Maestría ${c.maestria}  |  Guardia ${c.guardia}  |  Aguante ${c.aguante}',
                style: chico),
            Text(
                'Arma: ${c.arma?.nombre ?? 'ninguna'}  |  Escudo: ${c.escudo?.nombre ?? 'ninguno'}  |  Armadura: ${c.armadura?.nombre ?? 'ninguna'}',
                style: chico),
            Text(
                'Habilidades: armadura ${c.habArmadura}, una mano ${c.habUnaMano}, dos manos ${c.habDosManos}',
                style: chico),
            if (c.pasivas.isNotEmpty)
              Text('Pasiva: ${c.pasivas.map((p) => p.nombre).join(' + ')}',
                  style: chico),
            const SizedBox(height: 10),
            BotonOscuro(
              texto: 'Pelear',
              alto: 44,
              color: ColorBoton.rojo,
              onPressed: puedePelear
                  ? () async {
                final aviso = juego.pelearEn(lugar, e);
                if (aviso != null) {
                  _aviso(aviso);
                  return;
                }
                // El combate recién terminado queda primero en el historial:
                // se muestra el resultado animado, sin el video de entrada.
                if (juego.historialPvE.isNotEmpty) {
                  await mostrarBatalla(context, juego.historialPvE.first,
                      conVideo: false);
                }
              }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // Una opción del menú de combate (Arena, Cripta, Ciudadela)
  Widget _opcionMenu(
      IconData icono, String titulo, String texto, VoidCallback onTap) {
    return Card(
      child: ListTile(
        leading: Icon(icono, size: 32),
        title:
        Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(texto),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  // ---------- Vistas ----------

  Widget _vistaMenu() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _tarjetaEstado(),
        const Padding(
          padding: EdgeInsets.fromLTRB(8, 12, 8, 6),
          child: Text('¿Adónde vas a pelear?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        _opcionMenu(Icons.emoji_events, 'Arena',
            'Pelea contra otros jugadores y róbales oro.',
                () => _ir(VistaCombate.arena)),
        _opcionMenu(LugarCombate.cripta.icono, LugarCombate.cripta.nombre,
            'Hordas oscuras. Vencerlas te da puntos de bien.',
                () => _ir(VistaCombate.cripta)),
        _opcionMenu(
            LugarCombate.ciudadela.icono,
            LugarCombate.ciudadela.nombre,
            'Seres de luz. Atacarlos te da puntos de mal.',
                () => _ir(VistaCombate.ciudadela)),
        _opcionMenu(Icons.whatshot, 'Guaridas de jefes',
            'Enemigos temibles. 1 intento por jefe al día. Solo dan oro.',
                () => _ir(VistaCombate.jefes)),
        // El evento solo existe los domingos: el resto de la semana no se ve.
        if (juego.esDomingoServidor)
          _opcionMenu(Icons.local_fire_department, 'Evento: el Inmortal',
              '¡Mariolo está aquí! Tu daño x$multOroInmortal es tu oro.',
                  () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const PantallaInmortal()))),
        _opcionMenu(Icons.history, 'Historial de combates',
            'Tus últimos $maxHistorialCombates combates, con rondas y recompensas.',
                () => _ir(VistaCombate.historial)),
      ],
    );
  }

  Widget _vistaArena() {
    return Column(
      children: [
        _botonVolver(),
        const Expanded(child: PantallaArena()),
      ],
    );
  }

  // Un jefe con sus datos, su recompensa y el botón de desafío.
  Widget _imagenJefe(Jefe j, double tam, {bool bloqueado = false}) {
    final n = (jefes.indexOf(j) + 1).toString().padLeft(2, '0');
    Widget img = Image.asset(
      'assets/jefes/jefe_$n.png',
      width: tam,
      height: tam,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          Icon(bloqueado ? Icons.lock : Icons.shield, size: tam * 0.6),
    );
    if (bloqueado) {
      img = ColorFiltered(
        colorFilter: const ColorFilter.mode(Colors.black87, BlendMode.srcATop),
        child: img,
      );
    }
    return ClipRRect(borderRadius: BorderRadius.circular(8), child: img);
  }

  Widget _tarjetaJefe(Jefe j, bool puedePelear) {
    final desbloqueado = juego.jefeDesbloqueado(j);
    final intentado = juego.jefeIntentadoHoy(j);
    final vencido = juego.jefeVencido(j);
    const chico = TextStyle(fontSize: 12);
    if (!desbloqueado) {
      return Card(
        child: ListTile(
          leading: _imagenJefe(j, 56, bloqueado: true),
          title: Text(j.nombre,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('Se desbloquea en el nivel ${j.nivelMin}.'),
        ),
      );
    }
    final e = juego.enemigoJefe(j);
    final c = e.c;
    final bono = vencido
        ? ''
        : '  (+${(j.oroMedio * bonoPrimeraVictoriaJefe).round()} de bono la primera vez)';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: _imagenJefe(j, 190)),
            const SizedBox(height: 8),
            Text(j.nombre,
                style:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(j.descripcion,
                style: const TextStyle(
                    fontStyle: FontStyle.italic, fontSize: 12)),
            const SizedBox(height: 4),
            Text(
                'Nivel ${e.nivel}  |  Vida ${c.vidaMaxima}  |  Ataque ${c.ataque.round()}  |  Defensa ${c.defensa.round()}',
                style: chico),
            Text(
                'Poder ${c.poder}  |  Vigor ${c.vigor}  |  Agilidad ${c.agilidad}  |  Maestría ${c.maestria}  |  Guardia ${c.guardia}  |  Aguante ${c.aguante}',
                style: chico),
            Text(
                'Arma: ${c.arma?.nombre ?? 'ninguna'}  |  Escudo: ${c.escudo?.nombre ?? 'ninguno'}  |  Armadura: ${c.armadura?.nombre ?? 'ninguna'}',
                style: chico),
            Text('Pasiva: ${c.pasivas.map((p) => p.nombre).join(' + ')}',
                style: chico),
            const SizedBox(height: 4),
            Text('Recompensa: ${j.oroMin} a ${j.oroMax} de oro$bono',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber)),
            if (vencido)
              const Text('Ya lo venciste alguna vez.', style: chico),
            const SizedBox(height: 10),
            BotonOscuro(
              texto: intentado ? 'Vuelve mañana' : 'Desafiar',
              alto: 44,
              color: ColorBoton.rojo,
              onPressed: (puedePelear && !intentado)
                  ? () async {
                final aviso = juego.pelearJefe(j);
                if (aviso != null) {
                  _aviso(aviso);
                  return;
                }
                if (juego.historialPvE.isNotEmpty) {
                  await mostrarBatalla(context, juego.historialPvE.first,
                      conVideo: false);
                }
              }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _vistaJefes() {
    final puedePelear = juego.vida >= juego.vidaMaxima * vidaMinimaParaPelear;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _botonVolver(),
        const Padding(
          padding: EdgeInsets.fromLTRB(8, 0, 8, 4),
          child: Text('Guaridas de jefes',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Text(
              'Cada jefe se puede desafiar 1 vez al día, ganes o pierdas. Dan mucho oro, pero no fama ni puntos de bien o mal.',
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
        ),
        _tarjetaEstado(),
        const SizedBox(height: 8),
        for (final j in jefes.where((j) => juego.jefeDesbloqueado(j)))
          _tarjetaJefe(j, puedePelear),
        if (jefes.any((j) => !juego.jefeDesbloqueado(j))) ...[
          _tarjetaJefe(
              jefes.firstWhere((j) => !juego.jefeDesbloqueado(j)), puedePelear),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
                'Quedan ${jefes.where((j) => !juego.jefeDesbloqueado(j)).length - 1} jefes más por descubrir.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontStyle: FontStyle.italic, fontSize: 12)),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _vistaLugar(LugarCombate lugar) {
    final puedePelear = juego.vida >= juego.vidaMaxima * vidaMinimaParaPelear;
    final cercanos = juego.cercanos[lugar]!;
    final aleatorio = juego.aleatorio[lugar];
    final puedePagar = juego.oro >= costoActualizarBusqueda;

    final hijos = <Widget>[
      _botonVolver(),
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
        child: Text(lugar.nombre,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Text(lugar.descripcion,
            style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
      ),
      _tarjetaEstado(),
    ];

    // ---- Rivales cercanos a tu poder ----
    hijos.add(_tituloSeccion('Rivales cercanos a tu poder',
        'Aparecen $enemigosPorBusqueda rivales de nivel parecido o superior. Solo puedes pelear con uno.'));
    if (cercanos.isEmpty) {
      hijos.add(_botonAncho('Buscar rivales', () {
        final r = juego.buscarCercanos(lugar);
        if (r != null) _aviso(r);
      }));
    } else {
      for (final e in cercanos) {
        hijos.add(_tarjetaEnemigo(lugar, e, puedePelear));
      }
      hijos.add(_botonAncho(
          'Actualizar búsqueda ($costoActualizarBusqueda oro)',
          puedePagar
              ? () {
            final r = juego.buscarCercanos(lugar);
            if (r != null) _aviso(r);
          }
              : null,
          contorno: true));
    }

    // ---- Rival aleatorio ----
    hijos.add(_tituloSeccion('Rival aleatorio',
        'Un rival de cualquier nivel, del 1 al $nivelMaximo. Puede ser muy fácil o mortal.'));
    if (aleatorio == null) {
      hijos.add(_botonAncho('Buscar rival', () {
        final r = juego.buscarAleatorio(lugar);
        if (r != null) _aviso(r);
      }));
    } else {
      hijos.add(_tarjetaEnemigo(lugar, aleatorio, puedePelear));
      hijos.add(_botonAncho(
          'Buscar otro ($costoActualizarBusqueda oro)',
          puedePagar
              ? () {
            final r = juego.buscarAleatorio(lugar);
            if (r != null) _aviso(r);
          }
              : null,
          contorno: true));
    }

    hijos.add(const SizedBox(height: 16));
    return ListView(padding: const EdgeInsets.all(12), children: hijos);
  }

  @override
  Widget build(BuildContext context) {
    final Widget contenido;
    switch (vista) {
      case VistaCombate.menu:
        contenido = _vistaMenu();
        break;
      case VistaCombate.arena:
        contenido = _vistaArena();
        break;
      case VistaCombate.cripta:
        contenido = _vistaLugar(LugarCombate.cripta);
        break;
      case VistaCombate.ciudadela:
        contenido = _vistaLugar(LugarCombate.ciudadela);
        break;
      case VistaCombate.jefes:
        contenido = _vistaJefes();
        break;
      case VistaCombate.historial:
        contenido = Column(
          children: [
            _botonVolver(),
            const Expanded(child: PantallaHistorialCombates()),
          ],
        );
        break;
    }
    // La Ciudadela es muy clara, así que lleva una capa más oscura
    return FondoPantalla(
      imagen: _fondoActual,
      oscuridad: vista == VistaCombate.ciudadela ? 0.55 : 0.4,
      child: contenido,
    );
  }
}

// ====================== PANTALLA: HISTORIAL DE COMBATES ======================
// Dos pestañas: PvE (cripta y ciudadela) y Arena. Cada combate muestra tu
// tarjeta frente a la del rival, el resumen y, desplegable, las rondas.
class PantallaHistorialCombates extends StatelessWidget {
  const PantallaHistorialCombates({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'PvE'),
              Tab(text: 'Arena'),
              Tab(text: 'Defensas'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ListaHistorial(registros: juego.historialPvE),
                _ListaHistorial(
                    registros: datosPvp.historial,
                    vacio: 'Todavía no peleaste en la Arena. '
                        'Tus combates aparecerán aquí.'),
                _ListaHistorial(
                    registros: datosPvp.defensas,
                    esDefensa: true,
                    vacio: 'Nadie te ha atacado todavía. Cuando un jugador '
                        'te ataque en la Arena, verás aquí el resultado.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ListaHistorial extends StatelessWidget {
  final List<RegistroCombate> registros;
  final String vacio;
  final bool esDefensa; // true: ataques que recibiste (victoria = te defendiste)
  const _ListaHistorial(
      {required this.registros,
        this.esDefensa = false,
        this.vacio = 'Todavía no peleaste. Tus combates aparecerán aquí.'});

  @override
  Widget build(BuildContext context) {
    if (registros.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(vacio, textAlign: TextAlign.center),
        ),
      );
    }
    final victorias = registros.where((r) => r.resultado == 'victoria').length;
    final derrotas = registros.where((r) => r.resultado == 'derrota').length;
    final empates = registros.length - victorias - derrotas;
    final porcentaje = (victorias * 100 / registros.length).round();
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      // El primer elemento es el resumen; los demás son los combates.
      itemCount: registros.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                esDefensa
                    ? 'Últimos ${registros.length} ataques recibidos: '
                    'te defendiste $victorias ${victorias == 1 ? 'vez' : 'veces'}, '
                    'te vencieron $derrotas'
                    '${empates > 0 ? ', $empates empates' : ''}  |  '
                    '$porcentaje% de defensas exitosas'
                    : 'Últimos ${registros.length} combates: $victorias victorias, '
                    '$derrotas derrotas'
                    '${empates > 0 ? ', $empates empates' : ''}  |  '
                    '$porcentaje% de victorias',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          );
        }
        return _TarjetaRegistro(registros[i - 1]);
      },
    );
  }
}

class _TarjetaRegistro extends StatefulWidget {
  final RegistroCombate r;
  const _TarjetaRegistro(this.r);

  @override
  State<_TarjetaRegistro> createState() => _TarjetaRegistroState();
}

class _TarjetaRegistroState extends State<_TarjetaRegistro> {
  bool rondasAbiertas = false;

  String _hace(DateTime f) {
    final d = DateTime.now().difference(f);
    if (d.inMinutes < 1) return 'hace un momento';
    if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
    if (d.inHours < 24) return 'hace ${d.inHours} h';
    return 'hace ${d.inDays} d';
  }

  // Una columna de la tarjeta de personaje
  Widget _ficha(FichaCombate f, Color color) {
    const chico = TextStyle(fontSize: 11);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0x33000000),
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(f.nombre,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(
                'Nivel ${f.nivel}${f.perfil.isEmpty ? '' : '  -  ${f.perfil}'}',
                style: chico),
            const SizedBox(height: 4),
            Text('Vida ${f.vidaMaxima}', style: chico),
            Text('Ataque ${f.ataque}  |  Defensa ${f.defensa}', style: chico),
            const SizedBox(height: 4),
            for (final e in f.atributos.entries)
              Text('${e.key}: ${e.value}', style: chico),
            const SizedBox(height: 4),
            Text(f.arma, style: chico),
            Text(f.escudo, style: chico),
            Text(f.armadura, style: chico),
          ],
        ),
      ),
    );
  }

  String _resumen(RegistroCombate r) {
    final nombre = r.yo.nombre;
    if (r.lugar == 'Defensa') {
      switch (r.resultado) {
        case 'victoria':
          return '${r.rival.nombre} te atacó y $nombre lo derrotó en '
              '${r.rondas} rondas. Infligiste ${r.danoHecho} de daño y '
              'recibiste ${r.danoRecibido}. '
              '${r.oro > 0 ? 'Ganaste ${r.oro} de oro por defenderte.' : 'No perdiste oro.'}';
        case 'derrota':
          return '${r.rival.nombre} te atacó y venció a $nombre en '
              '${r.rondas} rondas. Infligiste ${r.danoHecho} de daño y '
              'recibiste ${r.danoRecibido}. '
              '${r.oro < 0 ? 'Te robó ${-r.oro} de oro.' : 'No te robó oro.'}';
        default:
          return '${r.rival.nombre} te atacó y el combate se alargó '
              '${r.rondas} rondas: empate. No perdiste nada.';
      }
    }
    switch (r.resultado) {
      case 'victoria':
        final fama = r.fama > 0
            ? 'ganó ${r.fama} de fama'
            : r.fama < 0
            ? 'perdió ${-r.fama} de fama'
            : 'no ganó fama';
        final inc = r.puntosInclinacion <= 0
            ? ''
            : ' y ${r.puntosInclinacion} '
            '${r.puntosInclinacion == 1 ? 'punto' : 'puntos'} '
            '${r.inclinacionBien ? 'de bien' : 'de mal'}';
        return '$nombre venció a ${r.rival.nombre} en ${r.rondas} rondas e '
            'infligió ${r.danoHecho} de daño (recibió ${r.danoRecibido}). '
            'Ganó ${r.oro} de oro, $fama$inc.'
            '${r.subioNivel ? ' ¡Subió de nivel!' : ''}';
      case 'derrota':
        final fama = r.fama < 0 ? 'perdió ${-r.fama} de fama' : 'no perdió fama';
        return '${r.rival.nombre} venció a $nombre en ${r.rondas} rondas. '
            'Infligió ${r.danoHecho} de daño y recibió ${r.danoRecibido}. '
            '${r.oro < 0 ? 'Perdió ${-r.oro} de oro' : 'No ganó oro'}'
            '${r.lugar == 'Arena' ? '' : ' ni inclinación'} y $fama.';
      default:
        return 'Empate contra ${r.rival.nombre}: el combate se alargó '
            '${r.rondas} rondas. Infligió ${r.danoHecho} de daño y recibió '
            '${r.danoRecibido}.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    final Color colorRes = r.resultado == 'victoria'
        ? Colors.greenAccent
        : r.resultado == 'derrota'
        ? Colors.redAccent
        : Colors.amber;
    final bool defensa = r.lugar == 'Defensa';
    final String titulo = r.resultado == 'victoria'
        ? (defensa ? 'TE DEFENDISTE' : 'VICTORIA')
        : r.resultado == 'derrota'
        ? (defensa ? 'TE VENCIERON' : 'DERROTA')
        : 'EMPATE';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(titulo,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: colorRes)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${r.lugar}  -  ${_hace(r.fecha)}',
                      style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ficha(r.yo, colorRes),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 30),
                  child: Text('VS',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                _ficha(r.rival, Colors.white38),
              ],
            ),
            const SizedBox(height: 8),
            Text(_resumen(r), style: const TextStyle(fontSize: 12)),
            TextButton.icon(
              onPressed: () =>
                  mostrarBatalla(context, r, conVideo: false, animar: false),
              icon: const Icon(Icons.visibility, size: 18),
              label: const Text('Ver resultado de la batalla'),
            ),
            if (r.log.isNotEmpty) ...[
              TextButton(
                onPressed: () =>
                    setState(() => rondasAbiertas = !rondasAbiertas),
                child:
                Text(rondasAbiertas ? 'Ocultar rondas' : 'Ver las rondas'),
              ),
              if (rondasAbiertas)
                for (final linea in r.log)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: textoRonda(linea, const TextStyle(fontSize: 12)),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class PantallaProximamente extends StatelessWidget {
  final String titulo;
  final String descripcion;
  const PantallaProximamente(this.titulo, this.descripcion, {super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.construction, size: 56),
            const SizedBox(height: 12),
            Text(titulo,
                style:
                const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(descripcion, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('(Próximamente)'),
          ],
        ),
      ),
    );
  }
}