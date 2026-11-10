import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'boton_oscuro.dart';
import 'imagenes.dart';
import 'main.dart';
import 'musica.dart';

// ====================== PANTALLAS DE BATALLA ======================
// Al pelear se abre UNA sola ruta con dos fases seguidas:
//   Fase 1: el video "toarena.mp4" (entrando a la arena, cripta o ciudadela).
//           Es opcional: con conVideo: false se salta directo a la fase 2.
//   Fase 2: aparece al instante el fondo del resultado y los bloques van
//           apareciendo de a poco: tarjetas de los personajes, equipamiento,
//           comparación de stats, resultado con botín y, al final, las
//           rondas desplegables.
//
// Para usarlas desde cualquier lado:
//   Arena (con video):        mostrarBatalla(context, registro);
//   Cripta/Ciudadela (sin):   mostrarBatalla(context, registro, conVideo: false);
//   Historial (ya cargada):   mostrarBatalla(context, registro, conVideo: false, animar: false);
// donde "registro" es el RegistroCombate del combate que acaba de terminar.

// Dónde están los archivos. Deben estar declarados en pubspec.yaml.
const String rutaVideoEntrada = 'assets/animaciones/toarena.mp4';
const String rutaFondoResultado = 'assets/fondos/resultadobatalla.jpg';
// Evento del Inmortal: video de espera (en bucle) e imagen sin fondo.
const String rutaVideoInmortal = 'assets/animaciones/mario_espera.mp4';
const String rutaImagenInmortal = 'assets/animaciones/mario_inmortal.png';

// Pausa entre un bloque del resultado y el siguiente.
const Duration pausaEntreBloques = Duration(milliseconds: 900);

// Si el video no arranca o se traba, se pasa al resultado después de esto.
const Duration esperaMaximaVideo = Duration(seconds: 15);

const Color _dorado = Color(0xFFC9A24B);
const Color _panelOscuro = Color(0xD9100808);

Future<void> mostrarBatalla(BuildContext context, RegistroCombate registro,
    {bool conVideo = true, bool animar = true}) async {
  // La música de combate solo suena en peleas nuevas, no al revisar el historial.
  // Con video (Arena), la música se corta mientras suena el audio del video y
  // la de combate empieza cuando el video termina (ver _mostrarResultado).
  if (animar) {
    if (conVideo) {
      Musica.instancia.detener();
    } else {
      Musica.instancia.reproducir('combate');
    }
  }
  try {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, __, ___) =>
            PantallaBatalla(registro, conVideo: conVideo, animar: animar),
        transitionsBuilder: (_, animacion, __, hijo) =>
            FadeTransition(opacity: animacion, child: hijo),
      ),
    );
  } finally {
    // Al cerrar la pantalla de batalla vuelve la música de fondo.
    if (animar) Musica.instancia.reproducir('oscura');
  }
}

// "Entrando en la arena...", "Entrando en la cripta...", etc.
String _textoEntrada(String lugar) {
  switch (lugar) {
    case 'Arena':
      return 'Entrando en la arena...';
    case 'Cripta':
      return 'Entrando en la cripta...';
    case 'Ciudadela':
      return 'Entrando en la ciudadela...';
    case 'Inmortal':
      return 'Entrando en combate...';
    case 'Jefe':
      return 'Entrando en la guarida...';
    default:
      return 'Entrando en combate...';
  }
}

Color _colorResultado(String resultado) {
  switch (resultado) {
    case 'victoria':
      return Colors.greenAccent;
    case 'derrota':
      return Colors.redAccent;
    default:
      return Colors.amber;
  }
}

// ---------- Contenedor: primero el video (opcional), luego el resultado ----------

class PantallaBatalla extends StatefulWidget {
  final RegistroCombate r;
  final bool conVideo;
  // false = el resultado aparece completo de una vez (para el historial)
  final bool animar;
  const PantallaBatalla(this.r,
      {super.key, this.conVideo = true, this.animar = true});

  @override
  State<PantallaBatalla> createState() => _PantallaBatallaState();
}

class _PantallaBatallaState extends State<PantallaBatalla> {
  late bool _animando;
  bool _precargado = false;

  @override
  void initState() {
    super.initState();
    // Sin video se muestra el resultado directamente.
    _animando = widget.conVideo;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Mientras corre el video se carga el fondo, para que aparezca al instante.
    if (!_precargado) {
      _precargado = true;
      precacheImage(const AssetImage(rutaFondoResultado), context,
          onError: (_, __) {});
    }
  }

  void _mostrarResultado() {
    if (mounted && _animando) {
      setState(() => _animando = false);
      // El video terminó (o se saltó): ahora entra la música de combate.
      if (widget.animar) Musica.instancia.reproducir('combate');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _animando
            ? _EntradaVideo(
          key: const ValueKey('entrada'),
          lugar: widget.r.lugar,
          alTerminar: _mostrarResultado,
        )
            : _Resultado(
            key: const ValueKey('resultado'),
            r: widget.r,
            animar: widget.animar),
      ),
    );
  }
}

// ---------- Fase 1: video de entrada ----------

class _EntradaVideo extends StatefulWidget {
  final String lugar;
  final VoidCallback alTerminar;
  const _EntradaVideo({super.key, required this.lugar, required this.alTerminar});

  @override
  State<_EntradaVideo> createState() => _EntradaVideoState();
}

class _EntradaVideoState extends State<_EntradaVideo> {
  VideoPlayerController? _video;
  Timer? _seguro;
  bool _listo = false;
  bool _terminado = false;

  @override
  void initState() {
    super.initState();
    _seguro = Timer(esperaMaximaVideo, _terminar);
    final video = VideoPlayerController.asset(rutaVideoEntrada);
    _video = video;
    video.addListener(_vigilar);
    video.initialize().then((_) {
      if (!mounted) return;
      setState(() => _listo = true);
      video.play();
    }).catchError((e) {
      debugPrint('Batalla: error al cargar el video: $e');
      _terminar();
    });
  }

  // Detecta el final del video y los errores
  void _vigilar() {
    final v = _video?.value;
    if (v == null) return;
    if (v.hasError) {
      debugPrint('Batalla: error del video: ${v.errorDescription}');
      _terminar();
      return;
    }
    if (v.isInitialized &&
        v.duration > Duration.zero &&
        v.position >= v.duration - const Duration(milliseconds: 100)) {
      _terminar();
    }
  }

  void _terminar() {
    if (_terminado) return;
    _terminado = true;
    _seguro?.cancel();
    widget.alTerminar();
  }

  @override
  void dispose() {
    _seguro?.cancel();
    _video?.removeListener(_vigilar);
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _terminar, // tocar la pantalla salta el video
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          if (_listo && video != null)
            FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: video.value.size.width,
                height: video.value.size.height,
                child: VideoPlayer(video),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _textoEntrada(widget.lugar),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Toca para saltar',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.white70,
                        shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Fase 2: resultado, que se arma de a poco ----------

class _FilaStat {
  final String nombre;
  final int yo;
  final int rival;
  const _FilaStat(this.nombre, this.yo, this.rival);
}

class _Resultado extends StatefulWidget {
  final RegistroCombate r;
  final bool animar;
  const _Resultado({super.key, required this.r, this.animar = true});

  @override
  State<_Resultado> createState() => _ResultadoState();
}

class _ResultadoState extends State<_Resultado> {
  // Bloques, en orden: 0 tarjetas, 1 equipamiento, 2 comparación,
  // 3 resultado y botín, 4 rondas, 5 botón Continuar.
  static const int _totalBloques = 6;
  static const _chico = TextStyle(fontSize: 12);

  final List<GlobalKey> _claves =
  List.generate(_totalBloques, (_) => GlobalKey());
  Timer? _temporizador;
  int _visibles = 0;

  RegistroCombate get r => widget.r;

  @override
  void initState() {
    super.initState();
    if (widget.animar) {
      _temporizador = Timer(const Duration(milliseconds: 250), _avanzar);
    } else {
      // Sin animación: todos los bloques ya están a la vista
      _visibles = _totalBloques;
    }
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }

  // Muestra el siguiente bloque y baja la pantalla si hace falta
  void _avanzar() {
    if (!mounted || _visibles >= _totalBloques) return;
    setState(() => _visibles++);
    final indice = _visibles - 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final contexto = _claves[indice].currentContext;
      if (!mounted || contexto == null) return;
      Scrollable.ensureVisible(
        contexto,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
    if (_visibles < _totalBloques) {
      _temporizador = Timer(pausaEntreBloques, _avanzar);
    }
  }

  // Tocar la pantalla muestra todo de una vez
  void _mostrarTodo() {
    _temporizador?.cancel();
    if (_visibles < _totalBloques) setState(() => _visibles = _totalBloques);
  }

  // Aparición suave de un bloque
  Widget _bloque(int i, Widget hijo) {
    final visible = _visibles > i;
    return KeyedSubtree(
      key: _claves[i],
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 500),
          child: AnimatedSlide(
            offset: visible ? Offset.zero : const Offset(0, 0.06),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            child: hijo,
          ),
        ),
      ),
    );
  }

  // Caja oscura con borde dorado, para leer bien sobre el fondo
  Widget _panel({required Widget hijo, Color borde = const Color(0x88C9A24B)}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panelOscuro,
        border: Border.all(color: borde, width: 1.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: hijo,
    );
  }

  Widget _tituloPanel(String texto) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(texto,
        style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.bold, color: _dorado)),
  );

  // ----- Bloque 0: tarjetas de los personajes -----

  Widget _ficha(FichaCombate f, Color color) {
    const chico = TextStyle(fontSize: 11);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _panelOscuro,
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(f.nombre,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text(
                'Nivel ${f.nivel}${f.perfil.isEmpty ? '' : '  -  ${f.perfil}'}',
                style: chico),
            const SizedBox(height: 8),
            Text('Vida ${f.vidaMaxima}', style: chico),
            Text('Ataque ${f.ataque}', style: chico),
            Text('Defensa ${f.defensa}', style: chico),
          ],
        ),
      ),
    );
  }

  // El Inmortal sale con su imagen sin fondo en lugar de la tarjeta de datos.
  Widget _fichaInmortal(FichaCombate f) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _panelOscuro,
          border: Border.all(color: _dorado, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Image.asset(
              rutaImagenInmortal,
              height: 190,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
              const Icon(Icons.shield, size: 90, color: _dorado),
            ),
            const SizedBox(height: 6),
            Text(f.nombre,
                textAlign: TextAlign.center,
                style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text('Nivel ${f.nivel}  -  ${f.perfil}',
                style: const TextStyle(fontSize: 11)),
            Text('Ataque ${f.ataque}  |  Defensa ${f.defensa}',
                style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _tarjetas(Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ficha(r.yo, color),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 26),
            child: Text('VS', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          r.lugar == 'Inmortal'
              ? _fichaInmortal(r.rival)
              : _ficha(r.rival, Colors.white54),
        ],
      ),
    );
  }

  // ----- Bloque 1: equipamiento -----

  Widget _equipo(FichaCombate f) {
    Widget linea(String etiqueta, String nombre, IconData icono,
        {String? apodo, int afilado = 0}) {
      final vacio = nombre.startsWith('Sin ');
      final respaldo = Container(
        color: Colors.black38,
        child: Icon(icono, size: 28, color: Colors.white38),
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Casilla vacía: solo icono. Con objeto: su imagen.
            vacio
                ? SizedBox(
                width: 64,
                height: 64,
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: respaldo))
                : ImagenObjeto(nombre: nombre, tamano: 64, respaldo: respaldo),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(etiqueta,
                      style:
                      const TextStyle(fontSize: 10, color: Colors.white54)),
                  if (apodo != null) ApodoBrillante(apodo, tamano: 14),
                  Text(nombre,
                      style: apodo != null
                          ? const TextStyle(fontSize: 10, color: Colors.white54)
                          : _chico),
                  if (afilado > 0)
                    Text('Filo +$afilado',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.orangeAccent)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(f.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: _dorado)),
          const SizedBox(height: 6),
          linea('Arma', f.arma, Icons.gavel,
              apodo: f.armaApodo, afilado: f.armaAfilado),
          linea('Escudo', f.escudo, Icons.shield),
          linea('Armadura', f.armadura, Icons.checkroom),
        ],
      ),
    );
  }

  Widget _equipamiento() {
    return _panel(
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tituloPanel('Equipamiento'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _equipo(r.yo),
              const SizedBox(width: 12),
              _equipo(r.rival),
            ],
          ),
        ],
      ),
    );
  }

  // ----- Bloque 2: comparación de stats -----

  Widget _filaComparacion(_FilaStat f) {
    final total = f.yo + f.rival;
    final parteYo =
    total <= 0 ? 500 : (f.yo * 1000 / total).round().clamp(1, 999);
    final gana = f.yo > f.rival;
    final pierde = f.yo < f.rival;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Text(f.nombre, style: _chico),
          const SizedBox(height: 2),
          Row(
            children: [
              SizedBox(
                width: 46,
                child: Text('${f.yo}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: gana ? FontWeight.bold : FontWeight.normal,
                        color: gana ? Colors.greenAccent : Colors.white)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 8,
                    child: Row(
                      children: [
                        Expanded(
                            flex: parteYo,
                            child: Container(color: Colors.amber)),
                        Expanded(
                            flex: 1000 - parteYo,
                            child: Container(color: Colors.blueGrey)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 46,
                child: Text('${f.rival}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                        pierde ? FontWeight.bold : FontWeight.normal,
                        color: pierde ? Colors.redAccent : Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _comparacion() {
    int atr(FichaCombate f, String clave) => f.atributos[clave] ?? 0;
    final filas = <_FilaStat>[
      _FilaStat('Vida', r.yo.vidaMaxima, r.rival.vidaMaxima),
      _FilaStat('Ataque', r.yo.ataque, r.rival.ataque),
      _FilaStat('Defensa', r.yo.defensa, r.rival.defensa),
      for (final clave in const [
        'Poder',
        'Vigor',
        'Agilidad',
        'Maestría',
        'Guardia',
        'Aguante'
      ])
        _FilaStat(clave, atr(r.yo, clave), atr(r.rival, clave)),
    ];
    return _panel(
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tituloPanel('Comparación de stats'),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(r.yo.nombre,
                  style: const TextStyle(fontSize: 11, color: Colors.amber)),
              Text(r.rival.nombre,
                  style:
                  const TextStyle(fontSize: 11, color: Colors.blueGrey)),
            ],
          ),
          for (final f in filas) _filaComparacion(f),
        ],
      ),
    );
  }

  // ----- Bloque 3: resultado y botín -----

  Widget _lineaBotin(IconData icono, String texto, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icono, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
              child: Text(texto, style: TextStyle(fontSize: 14, color: color))),
        ],
      ),
    );
  }

  // Lo que dice el Inmortal según cuánto daño le hiciste (comparado con su vida).
  String _fraseInmortal() {
    final vida = r.rival.vidaMaxima <= 0 ? 1 : r.rival.vidaMaxima;
    final x = r.danoHecho / vida;
    if (x < 0.5) return '«¿Eso fue todo? Casi ni lo sentí.»';
    if (x < 1.0) return '«Una caricia... pero con ganas.»';
    if (x < 2.0) return '«¡Ouch! Eso sí dolió, retador.»';
    return '«¡Imposible! Eres una bestia... casi como yo.»';
  }

  Widget _resultadoInmortal(Color color) {
    final sobreviviste = r.resultado == 'victoria';
    return _panel(
      borde: color,
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(sobreviviste ? 'SOBREVIVISTE' : 'CAÍSTE',
                style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          ),
          const Center(
              child: Text('Evento del Inmortal', style: TextStyle(fontSize: 12))),
          const SizedBox(height: 10),
          _tituloPanel('Botín'),
          _lineaBotin(Icons.flash_on, 'Daño al Inmortal: ${r.danoHecho}',
              Colors.deepOrangeAccent),
          _lineaBotin(Icons.monetization_on,
              '+${r.oro} de oro  (daño x$multOroInmortal)', Colors.amber),
          const SizedBox(height: 8),
          Center(
            child: Text(_fraseInmortal(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontStyle: FontStyle.italic, color: _dorado)),
          ),
        ],
      ),
    );
  }

  Widget _resultado(Color color) {
    if (r.lugar == 'Inmortal') return _resultadoInmortal(color);
    final titulo = r.resultado == 'victoria'
        ? 'VICTORIA'
        : r.resultado == 'derrota'
        ? 'DERROTA'
        : 'EMPATE';

    final lineas = <Widget>[];
    if (r.oro > 0) {
      lineas.add(_lineaBotin(
          Icons.monetization_on, '+${r.oro} de oro', Colors.amber));
    } else if (r.oro < 0) {
      lineas.add(_lineaBotin(
          Icons.monetization_on, '${r.oro} de oro', Colors.redAccent));
    } else {
      lineas.add(
          _lineaBotin(Icons.monetization_on, 'Sin oro', Colors.white70));
    }
    if (r.fama > 0) {
      lineas.add(
          _lineaBotin(Icons.star, '+${r.fama} de fama', Colors.greenAccent));
    } else if (r.fama < 0) {
      lineas.add(
          _lineaBotin(Icons.star, '${r.fama} de fama', Colors.redAccent));
    } else {
      lineas.add(
          _lineaBotin(Icons.star, 'Sin cambio de fama', Colors.white70));
    }
    if (r.puntosInclinacion > 0) {
      lineas.add(_lineaBotin(
          Icons.balance,
          '+${r.puntosInclinacion} '
              '${r.puntosInclinacion == 1 ? 'punto' : 'puntos'} '
              '${r.inclinacionBien ? 'de bien' : 'de mal'}',
          Colors.lightBlueAccent));
    }
    if (r.subioNivel) {
      lineas.add(_lineaBotin(
          Icons.arrow_upward, '¡Subiste de nivel!', Colors.greenAccent));
    }

    return _panel(
      borde: color,
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(titulo,
                style: TextStyle(
                    fontSize: 30, fontWeight: FontWeight.bold, color: color)),
          ),
          Center(child: Text(r.lugar, style: const TextStyle(fontSize: 12))),
          const SizedBox(height: 10),
          _tituloPanel('Botín'),
          ...lineas,
        ],
      ),
    );
  }

  // ----- Bloque 4: rondas desplegables -----

  Widget _rondas() {
    return _panel(
      hijo: Theme(
        // Quita las líneas que ExpansionTile dibuja por defecto
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text('Rondas (${r.rondas})',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold, color: _dorado)),
          subtitle: Text(
              'Hiciste ${r.danoHecho} de daño  |  Recibiste ${r.danoRecibido}',
              style: _chico),
          childrenPadding: const EdgeInsets.only(top: 4, bottom: 4),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (r.log.isEmpty)
              const Text('No hay detalle de rondas de este combate.',
                  style: _chico)
            else
              for (final linea in r.log)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: textoRonda(linea, _chico),
                ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorResultado(r.resultado);
    return Stack(
      fit: StackFit.expand,
      children: [
        // El fondo se ve desde el primer instante
        Image.asset(
          rutaFondoResultado,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
          const ColoredBox(color: Color(0xFF0B0707)),
        ),
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _mostrarTodo,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _bloque(0, _tarjetas(color)),
                  _bloque(1, _equipamiento()),
                  _bloque(2, _comparacion()),
                  _bloque(3, _resultado(color)),
                  _bloque(4, _rondas()),
                  _bloque(
                    5,
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: BotonOscuro(
                        texto: widget.animar ? 'Continuar' : 'Cerrar',
                        alto: 48,
                        color: ColorBoton.rojo,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}