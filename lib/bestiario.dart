import 'package:flutter/material.dart';
import 'main.dart';

// ====================== BESTIARIO (EL GRIMORIO) ======================
// Un libro con todas las bestias del juego. Cada una se anota cuando la vences
// por primera vez, y cada entrada da esquirlas (más si la bestia es más dura).
// Hay 3 páginas: Cripta, Ciudadela y Jefes. Completar una página da un bono.
//
// Para cambiar los premios, edita los números de aquí abajo.

// ---------- Números para ajustar ----------
// Esquirlas por una bestia normal, según el nivel desde el que aparece
int esquirlasBestia(int nivelMin) {
  if (nivelMin <= 10) return 2;
  if (nivelMin <= 40) return 3;
  if (nivelMin <= 90) return 4;
  return 5;
}

// Esquirlas por un jefe, según el nivel con el que se desbloquea
int esquirlasJefe(int nivelMin) {
  if (nivelMin <= 40) return 3;
  if (nivelMin <= 90) return 4;
  if (nivelMin <= 140) return 5;
  return 6;
}

// Página 4 (Rarezas): esquirlas por completar las 4 rarezas de una bestia
int esquirlasRarezas(int nivelMin) {
  if (nivelMin <= 10) return 3;
  if (nivelMin <= 40) return 4;
  if (nivelMin <= 90) return 5;
  return 6;
}

// Bono por completar una página entera (Cripta, Ciudadela, Jefes, Rarezas).
// 0 = esa página no tiene bono.
const List<int> bonoPagina = [10, 10, 25, 0];
const List<String> nombresPagina = ['Cripta', 'Ciudadela', 'Jefes', 'Rarezas'];

// ---------- Rarezas de los perfiles de combate ----------
const List<String> nombresRareza = ['Común', 'Poco común', 'Raro', 'Muy raro'];
// Son los colores de las auras: común azul, poco común púrpura, raro dorado,
// muy raro rojo. Cuando haya imágenes de los enemigos se usarán para su aura.
const List<Color> coloresRareza = [
  Color(0xFF3D8BFF), // común: azul
  Color(0xFFB266FF), // poco común: púrpura
  Color(0xFFFFC83D), // raro: dorado
  Color(0xFFFF3B3B), // muy raro: rojo
];

// 0 común, 1 poco común, 2 raro, 3 muy raro (según la rareza del perfil)
int rarezaDePerfil(String perfil) {
  for (final a in arquetipos) {
    if (a.nombre == perfil) {
      if (a.rareza >= 10) return 0;
      if (a.rareza >= 5) return 1;
      if (a.rareza >= 2) return 2;
      return 3;
    }
  }
  return 0;
}

// ---------- Textos de cada bestia ----------
const Map<String, String> _descripciones = {
  // Cripta
  'Rata de cripta':
  'Roe huesos y fe por igual. Pequeña, hambrienta y siempre en grupo.',
  'Esqueleto raquítico':
  'Un muerto tan flaco que sus huesos suenan como campanillas rotas.',
  'Zombi putrefacto':
  'Camina sin prisa y sin miedo al dolor. Su olor llega antes que él.',
  'Necrófago': 'Desentierra tumbas recién cerradas. Le gusta lo fresco.',
  'Espectro aullante':
  'Un lamento con forma. Su grito hiela la sangre de quien lo escucha.',
  'Cultista de sangre':
  'Se hiere a sí mismo para ofrecer su sangre al Dominio.',
  'Caballero no muerto':
  'Juró lealtad en vida y sigue cumpliéndola, aunque su señor ya sea polvo.',
  'Vampiro nocturno':
  'Elegante, paciente y sediento. Solo caza cuando la luna sangra.',
  'Liche menor':
  'Cambió su alma por años. Guarda su corazón donde nadie lo encuentra.',
  'Demonio de ceniza':
  'Nace de las hogueras apagadas. Cada paso suyo deja brasas.',
  'Segador de almas': 'No mata por odio: cosecha. Su guadaña no hace ruido.',
  'Señor de la cripta':
  'Dueño de las galerías profundas. Todo esqueleto de allí le debe obediencia.',
  'Heraldo del abismo':
  'Anuncia la llegada de algo peor. Nadie vivió para oír el resto.',
  'Lord vampiro':
  'Un noble antiguo que olvidó el sabor del vino y solo recuerda el de la sangre.',
  'Rey de las hordas oscuras':
  'Reina sobre todos los muertos de la Cripta. Su corona pesa más que mil almas.',
  // Ciudadela
  'Novicio de la luz':
  'Recién llegado a la Orden. Reza más de lo que pelea, pero pelea.',
  'Aprendiz de monje':
  'Golpea con vara y con paciencia. Todavía le tiemblan las manos.',
  'Monje guerrero':
  'Sus puños rezan. Siempre encuentra el hueco entre tus defensas.',
  'Acólito de armas':
  'Cuida el arsenal sagrado y sabe usar cada pieza.',
  'Paladín novato':
  'Brilla más que su armadura. Está seguro de que la luz lo protege.',
  'Caballero de la Luz':
  'Sirve a la Ciudadela sin dudas. Su escudo ha visto mil batallas.',
  'Inquisidor sagrado':
  'Busca el mal incluso donde no lo hay. Nunca llega tarde a un juicio.',
  'Guardián alado':
  'Vigila las torres desde el aire y cae como una lanza de luz.',
  'Capitán de la Orden':
  'Manda a cien y no pide a nadie lo que él no haría.',
  'Serafín menor':
  'Seis alas, tres ojos y ninguna paciencia con los pecadores.',
  'Campeón celestial':
  'Ganó el torneo de los cielos. Todavía no ha perdido un combate.',
  'Arcángel guerrero':
  'Su espada es un amanecer. Nadie le ha visto el rostro.',
  'Custodio del Alba':
  'Guarda el primer rayo del día. Si cae, el mundo se queda a oscuras.',
  'Gran Maestre de la Luz':
  'Dirige la Orden entera. Cada paso suyo es una oración.',
  'Avatar de la Luz':
  'La Luz misma hecha cuerpo. Atacarla es la mayor herejía.',
};

// ---------- Una entrada del libro ----------
class EntradaBestiario {
  final String clave; // para saber si ya cobraste su premio
  final String nombre;
  final String descripcion;
  final int nivelMin;
  final int premio;
  final int pagina; // 0 cripta, 1 ciudadela, 2 jefes
  final Jefe? jefe;
  const EntradaBestiario(this.clave, this.nombre, this.descripcion,
      this.nivelMin, this.premio, this.pagina,
      {this.jefe});

  bool get esJefe => jefe != null;
  bool get esDeCripta => plantillasCripta.any((p) => p.nombre == nombre);
}

List<EntradaBestiario>? _cache;

List<EntradaBestiario> get todasLasEntradas {
  return _cache ??= [
    for (final p in plantillasCripta)
      EntradaBestiario('b:${p.nombre}', p.nombre, _descripciones[p.nombre] ?? '',
          p.nivelMin, esquirlasBestia(p.nivelMin), 0),
    for (final p in plantillasCiudadela)
      EntradaBestiario('b:${p.nombre}', p.nombre, _descripciones[p.nombre] ?? '',
          p.nivelMin, esquirlasBestia(p.nivelMin), 1),
    for (final j in jefes)
      EntradaBestiario('j:${j.nombre}', j.nombre, j.descripcion, j.nivelMin,
          esquirlasJefe(j.nivelMin), 2,
          jefe: j),
    // Página 4: cada bestia normal otra vez, para sus 4 rarezas
    for (final p in [...plantillasCripta, ...plantillasCiudadela])
      EntradaBestiario('r:${p.nombre}', p.nombre, _descripciones[p.nombre] ?? '',
          p.nivelMin, esquirlasRarezas(p.nivelMin), 3),
  ];
}

List<EntradaBestiario> entradasDe(int pagina) =>
    todasLasEntradas.where((e) => e.pagina == pagina).toList();

// ---------- Lo que guarda cada jugador ----------
class DatosBestiario {
  final Map<String, int> victorias = {}; // nombre de la bestia -> veces vencida
  final Set<String> cobrados = {}; // claves ya cobradas (entradas y bonos)
  // Rarezas vencidas de cada bestia: bits 1, 2, 4, 8 = común ... muy raro
  final Map<String, int> rarezas = {};

  // Se llama al vencer a una bestia normal en la Cripta o la Ciudadela.
  void registrarVictoria(String nombre, String perfil) {
    final nueva = !victorias.containsKey(nombre);
    victorias[nombre] = (victorias[nombre] ?? 0) + 1;
    if (nueva) {
      juego.logros.avisos.add('Nueva entrada en el Bestiario: $nombre');
    }
    final antes = rarezas[nombre] ?? 0;
    final r = rarezaDePerfil(perfil);
    final ahora = antes | (1 << r);
    if (ahora != antes) {
      rarezas[nombre] = ahora;
      if (ahora == 15) {
        juego.logros.avisos
            .add('¡Rarezas completas de $nombre! Cobra tu premio en el Bestiario.');
      } else if (r >= 2 && !nueva) {
        juego.logros.avisos
            .add('Nueva rareza anotada: $nombre (${nombresRareza[r]})');
      }
    }
  }

  // true: ya no hay que reconocer nada por el nivel. Las cuentas de antes del
  // bestiario no tienen este dato guardado, así que se les hace una sola vez.
  bool migrado = false;

  // Para jugadores que ya tenían nivel cuando llegó el bestiario: las bestias
  // que aparecen desde su nivel o menos se anotan como vencidas, y las que ya no
  // pueden salirle en la búsqueda normal (porque quedaron muy atrás) cuentan
  // con sus 4 rarezas. Las cuentas nuevas empiezan desde cero.
  void migrarSiHaceFalta() {
    if (migrado) return;
    if (!juego.personajeCreado) return;
    migrado = true;
    final n = juego.nivel;
    int nuevas = 0;
    for (final lugar in LugarCombate.values) {
      final aptas = lugar.plantillas.where((p) => p.nivelMin <= n).toList();
      final fuera = aptas.length - 3; // las 3 últimas son las que aún salen
      for (int i = 0; i < aptas.length; i++) {
        final nombre = aptas[i].nombre;
        if (!victorias.containsKey(nombre)) {
          victorias[nombre] = 1;
          nuevas++;
        }
        if (i < fuera) rarezas[nombre] = 15;
      }
    }
    if (nuevas > 0) {
      juego.logros.avisos.add(
          'Bestiario: se anotaron $nuevas bestias que ya habías superado por tu nivel.');
    }
  }

  // Bits de las rarezas ya vencidas de esa bestia
  int mascaraRarezas(String nombre) => rarezas[nombre] ?? 0;

  int rarezasVencidas(String nombre) {
    final m = mascaraRarezas(nombre);
    return [0, 1, 2, 3].where((i) => (m & (1 << i)) != 0).length;
  }

  bool descubierta(EntradaBestiario e) {
    if (e.pagina == 3) return mascaraRarezas(e.nombre) == 15;
    return e.esJefe
        ? juego.jefesVencidos.contains(e.nombre)
        : victorias.containsKey(e.nombre);
  }

  int vecesVencida(EntradaBestiario e) => victorias[e.nombre] ?? 0;

  bool cobrada(String clave) => cobrados.contains(clave);

  int descubiertasEn(int pagina) =>
      entradasDe(pagina).where(descubierta).length;

  bool paginaCompleta(int pagina) {
    final l = entradasDe(pagina);
    return l.every(descubierta);
  }

  String _claveBono(int pagina) => 'bono:$pagina';

  bool bonoCobrado(int pagina) => cobrados.contains(_claveBono(pagina));

  // Esquirlas que tienes pendientes de cobrar en una página (con el bono)
  int pendientesEn(int pagina) {
    int n = 0;
    for (final e in entradasDe(pagina)) {
      if (descubierta(e) && !cobrada(e.clave)) n += e.premio;
    }
    if (bonoPagina[pagina] > 0 && paginaCompleta(pagina) && !bonoCobrado(pagina)) {
      n += bonoPagina[pagina];
    }
    return n;
  }

  int get pendientesTotal =>
      [0, 1, 2, 3].fold<int>(0, (s, p) => s + pendientesEn(p));

  String? cobrar(EntradaBestiario e) {
    if (!descubierta(e)) return 'Primero tienes que vencerla.';
    if (cobrada(e.clave)) return 'Ya cobraste esa entrada.';
    cobrados.add(e.clave);
    juego.gemas += e.premio;
    juego.avisarCambio();
    return '${e.nombre}: +${e.premio} esquirlas.';
  }

  String? cobrarBono(int pagina) {
    if (bonoPagina[pagina] <= 0) return 'Esa página no tiene bono.';
    if (!paginaCompleta(pagina)) return 'Todavía faltan bestias en esta página.';
    if (bonoCobrado(pagina)) return 'Ya cobraste ese bono.';
    cobrados.add(_claveBono(pagina));
    juego.gemas += bonoPagina[pagina];
    juego.avisarCambio();
    return '¡Página de ${nombresPagina[pagina]} completa! +${bonoPagina[pagina]} esquirlas.';
  }

  // Cobra todo lo pendiente de una página
  String? cobrarTodo(int pagina) {
    final n = pendientesEn(pagina);
    if (n == 0) return 'No tienes nada para cobrar aquí.';
    for (final e in entradasDe(pagina)) {
      if (descubierta(e) && !cobrada(e.clave)) cobrados.add(e.clave);
    }
    if (bonoPagina[pagina] > 0 && paginaCompleta(pagina)) {
      cobrados.add(_claveBono(pagina));
    }
    juego.gemas += n;
    juego.avisarCambio();
    return 'Cobraste $n esquirlas.';
  }

  Map<String, dynamic> aMapa() => {
    'v': Map<String, int>.from(victorias),
    'c': cobrados.toList(),
    'r': Map<String, int>.from(rarezas),
  };

  void cargar(dynamic m) {
    victorias.clear();
    cobrados.clear();
    rarezas.clear();
    // Si ya hay datos guardados por esta versión, no hay nada que migrar.
    migrado = m is Map;
    if (m is! Map) return;
    try {
      final v = m['v'];
      if (v is Map) {
        v.forEach((k, x) => victorias[k.toString()] = (x as num).toInt());
      }
      final c = m['c'];
      if (c is List) cobrados.addAll(c.map((e) => e.toString()));
      final r = m['r'];
      if (r is Map) {
        r.forEach((k, x) => rarezas[k.toString()] = (x as num).toInt());
      }
    } catch (_) {}
  }
}

// ====================== PANTALLA ======================

class PantallaBestiario extends StatefulWidget {
  const PantallaBestiario({super.key});

  @override
  State<PantallaBestiario> createState() => _PantallaBestiarioState();
}

class _PantallaBestiarioState extends State<PantallaBestiario> {
  int _pagina = 0;

  void _msg(String? t) {
    if (t == null) return;
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(content: Text(t)));
  }

  Widget _imagen(EntradaBestiario e, bool visible) {
    const tam = 52.0;
    if (e.esJefe) {
      final n = (jefes.indexOf(e.jefe!) + 1).toString().padLeft(2, '0');
      Widget img = Image.asset(
        'assets/jefes/jefe_$n.png',
        width: tam,
        height: tam,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
        const Icon(Icons.shield, size: tam * 0.6),
      );
      if (!visible) {
        img = ColorFiltered(
          colorFilter:
          const ColorFilter.mode(Colors.black87, BlendMode.srcATop),
          child: img,
        );
      }
      return ClipRRect(borderRadius: BorderRadius.circular(8), child: img);
    }
    return Container(
      width: tam,
      height: tam,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withAlpha(90),
        border: Border.all(
            color: visible
                ? (e.esDeCripta
                ? const Color(0xFFB266FF)
                : const Color(0xFF00F5E0))
                : Colors.white24),
      ),
      child: Icon(
          visible
              ? (e.esDeCripta ? Icons.nights_stay : Icons.wb_sunny)
              : Icons.lock,
          color: visible ? Colors.white : Colors.white38),
    );
  }

  // Página 4: qué perfiles cuentan para cada rareza y cuáles ya vencidas
  void _detalleRarezas(EntradaBestiario e) {
    final d = juego.bestiario;
    final m = d.mascaraRarezas(e.nombre);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(d.victorias.containsKey(e.nombre) ? e.nombre : '???'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Vence a esta bestia con un perfil de cada rareza para '
                      'completar la entrada.',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
              const SizedBox(height: 10),
              for (int i = 0; i < 4; i++) ...[
                Row(children: [
                  Icon((m & (1 << i)) != 0
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                      size: 16, color: coloresRareza[i]),
                  const SizedBox(width: 6),
                  Text(nombresRareza[i],
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: coloresRareza[i])),
                ]),
                Padding(
                  padding: const EdgeInsets.only(left: 22, bottom: 8),
                  child: Text(
                      arquetipos
                          .where((a) => rarezaDePerfil(a.nombre) == i)
                          .map((a) => a.nombre)
                          .join(', '),
                      style: const TextStyle(fontSize: 12)),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'))
        ],
      ),
    );
  }

  void _detalle(EntradaBestiario e) {
    final d = juego.bestiario;
    if (e.pagina == 3) {
      _detalleRarezas(e);
      return;
    }
    if (!d.descubierta(e)) {
      _msg(e.esJefe
          ? 'Véncelo para anotarlo. Se desbloquea en el nivel ${e.nivelMin}.'
          : 'Aparece desde el nivel ${e.nivelMin}. Véncela para anotarla.');
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(e.nombre),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (e.esJefe) Center(child: _imagen(e, true)),
              if (e.esJefe) const SizedBox(height: 10),
              Text(e.descripcion,
                  style: const TextStyle(fontStyle: FontStyle.italic)),
              const SizedBox(height: 10),
              Text(e.esJefe
                  ? 'Se desbloquea en el nivel ${e.nivelMin}.'
                  : 'Aparece desde el nivel ${e.nivelMin}.'),
              if (!e.esJefe) Text('Vencida ${d.vecesVencida(e)} veces.'),
              if (e.esJefe) ...[
                Text('Estilo de combate: ${e.jefe!.perfilBase}.'),
                if (e.jefe!.pasivas.isNotEmpty)
                  Text(
                      'Pasivas: ${e.jefe!.pasivas.map((p) => p.nombre).join(', ')}.'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'))
        ],
      ),
    );
  }

  Widget _premio(EntradaBestiario e) {
    final d = juego.bestiario;
    if (d.cobrada(e.clave)) {
      return const Icon(Icons.check_circle, color: Colors.greenAccent);
    }
    if (d.descubierta(e)) {
      return ElevatedButton.icon(
        onPressed: () => _msg(d.cobrar(e)),
        icon: const IconoEsquirla(tam: 18),
        label: Text('+${e.premio}'),
      );
    }
    return Opacity(
      opacity: 0.45,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const IconoEsquirla(tam: 16),
        const SizedBox(width: 4),
        Text('${e.premio}'),
      ]),
    );
  }

  // Página 4: la bestia con sus 4 rarezas
  Widget _tarjetaRarezas(EntradaBestiario e) {
    final d = juego.bestiario;
    final vista = d.victorias.containsKey(e.nombre);
    final m = d.mascaraRarezas(e.nombre);
    return Card(
      child: InkWell(
        onTap: () => _detalle(e),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            _imagen(e, vista),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vista ? e.nombre : '???',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                      vista
                          ? '${d.rarezasVencidas(e.nombre)}/4 rarezas'
                          : 'Aparece desde el nivel ${e.nivelMin}',
                      style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    for (int i = 0; i < 4; i++)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: (m & (1 << i)) != 0
                              ? coloresRareza[i].withAlpha(60)
                              : Colors.black26,
                          border: Border.all(
                              color: (m & (1 << i)) != 0
                                  ? coloresRareza[i]
                                  : Colors.white24),
                        ),
                        child: Text(nombresRareza[i],
                            style: TextStyle(
                                fontSize: 10,
                                color: (m & (1 << i)) != 0
                                    ? coloresRareza[i]
                                    : Colors.white38)),
                      ),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 6),
            _premio(e),
          ]),
        ),
      ),
    );
  }

  Widget _tarjeta(EntradaBestiario e) {
    if (e.pagina == 3) return _tarjetaRarezas(e);
    final d = juego.bestiario;
    final visible = d.descubierta(e);
    return Card(
      child: ListTile(
        onTap: () => _detalle(e),
        leading: _imagen(e, visible),
        title: Text(visible ? e.nombre : '???',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(visible
            ? (e.esJefe
            ? 'Jefe · nivel ${e.nivelMin}+'
            : 'Nivel ${e.nivelMin}+ · vencida ${d.vecesVencida(e)} ${d.vecesVencida(e) == 1 ? 'vez' : 'veces'}')
            : (e.esJefe
            ? 'Se desbloquea en el nivel ${e.nivelMin}'
            : 'Aparece desde el nivel ${e.nivelMin}')),
        trailing: _premio(e),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: juego,
      builder: (context, _) {
        final d = juego.bestiario;
        final lista = entradasDe(_pagina);
        final hechas = d.descubiertasEn(_pagina);
        final pend = d.pendientesEn(_pagina);
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            SegmentedButton<int>(
              showSelectedIcon: false,
              style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  padding: WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 4))),
              segments: [
                for (int i = 0; i < 4; i++)
                  ButtonSegment(
                    value: i,
                    label: Text(nombresPagina[i],
                        style: const TextStyle(fontSize: 12)),
                  ),
              ],
              selected: {_pagina},
              onSelectionChanged: (s) => setState(() => _pagina = s.first),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.menu_book, size: 20),
                      const SizedBox(width: 8),
                      Text('${nombresPagina[_pagina]}: $hechas/${lista.length}',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      if (pend > 0)
                        ElevatedButton.icon(
                          onPressed: () => _msg(d.cobrarTodo(_pagina)),
                          icon: const IconoEsquirla(tam: 18),
                          label: Text('Cobrar $pend'),
                        ),
                    ]),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                        value: lista.isEmpty ? 0 : hechas / lista.length,
                        minHeight: 6),
                    const SizedBox(height: 8),
                    if (bonoPagina[_pagina] > 0)
                      Row(children: [
                        const IconoEsquirla(tam: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                              d.bonoCobrado(_pagina)
                                  ? 'Bono de página cobrado.'
                                  : 'Completa la página y gana +${bonoPagina[_pagina]} de bono.',
                              style: const TextStyle(fontSize: 12)),
                        ),
                        if (d.bonoCobrado(_pagina))
                          const Icon(Icons.check_circle,
                              color: Colors.greenAccent, size: 18),
                      ])
                    else
                      const Text(
                          'Cada bestia da su premio al vencerla con las 4 rarezas.',
                          style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
            for (final e in lista) _tarjeta(e),
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                  'Cada bestia se anota la primera vez que la vences y da esquirlas. '
                      'Las más duras dan más. En Rarezas, toca una bestia para ver '
                      'qué perfiles cuentan.',
                  style: TextStyle(fontSize: 12, color: Colors.white70)),
            ),
          ],
        );
      },
    );
  }
}