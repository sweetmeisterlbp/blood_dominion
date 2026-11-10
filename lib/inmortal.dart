import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'batalla.dart';
import 'boton_oscuro.dart';
import 'main.dart';
import 'musica.dart';

// ====================== EVENTO: EL INMORTAL (DOMINGOS) ======================
// Pantalla del evento: video de fondo en bucle (sin su propio audio), música
// épica propia (assets/musica/musica_evento.ogg) y un solo botón rojo.
// La pelea, el oro y el guardado viven en main.dart (pelearInmortal).
// El resultado se ve en la pantalla de batalla con la imagen de Mario.

const int inmortalRankingTamano = 10;

// Video corto (con su propio sonido) que se ve al atacar a Mariolo: él se agacha,
// carga energía y se lanza. Va en assets/animaciones/mario_carga.mp4
const String rutaVideoCargaInmortal = 'assets/animaciones/mario_carga.mp4';

// ---------- Aviso al abrir el juego un domingo ----------

bool _avisoMostrado = false;

// Se llama una vez al abrir el menú. Solo avisa en domingo y si aún no peleaste.
void avisoInmortalDomingo(BuildContext context) {
  if (_avisoMostrado) return;
  _avisoMostrado = true;
  Future.delayed(const Duration(seconds: 3), () async {
    if (!context.mounted) return;
    if (!juego.esDomingoServidor || juego.inmortalIntentadoHoy) return;
    final ir = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0xCC000000),
      builder: (ctx) => const _CartelInmortal(),
    );
    if (ir == true && context.mounted) {
      Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const PantallaInmortal()));
    }
  });
}

// Cartel rojo brillante que avisa que Mariolo llegó. Late como brasa encendida.
// Devuelve true si el jugador toca el botón para ir a la batalla.
class _CartelInmortal extends StatefulWidget {
  const _CartelInmortal();

  @override
  State<_CartelInmortal> createState() => _CartelInmortalState();
}

class _CartelInmortalState extends State<_CartelInmortal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulso = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: AnimatedBuilder(
        animation: _pulso,
        builder: (context, _) {
          final p = Curves.easeInOut.transform(_pulso.value); // 0..1
          final brillo = 10 + 22 * p;
          return Container(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 16),
            decoration: BoxDecoration(
              color: const Color(0xF2120505),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: Color.lerp(
                      const Color(0xFF8B0000), const Color(0xFFFF3B3B), p)!,
                  width: 3),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFFFF1A1A).withOpacity(0.25 + 0.35 * p),
                    blurRadius: 26 + 18 * p,
                    spreadRadius: 2),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('MARIOLO',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        color: const Color(0xFFFF2B2B),
                        shadows: [
                          Shadow(color: const Color(0xFFFF0000), blurRadius: brillo),
                          Shadow(color: const Color(0xFFFF4A4A), blurRadius: brillo * 2),
                          const Shadow(color: Colors.black, blurRadius: 2),
                        ])),
                Text('EL INMORTAL',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        color: const Color(0xFFFF4D4D),
                        shadows: [
                          Shadow(color: const Color(0xFFFF0000), blurRadius: brillo),
                          Shadow(color: const Color(0xFFFF4A4A), blurRadius: brillo * 1.6),
                        ])),
                const SizedBox(height: 10),
                Text('¡YA ESTÁ AQUÍ!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFFF3030),
                        shadows: [
                          Shadow(color: const Color(0xFFFF0000), blurRadius: brillo * 1.2),
                          Shadow(color: const Color(0xFFFF5A5A), blurRadius: brillo * 2.2),
                        ])),
                const SizedBox(height: 12),
                const Text('¿Estarás a la altura?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black, blurRadius: 6)])),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: BotonOscuro(
                    texto: '¡A LA BATALLA!',
                    alto: 56,
                    color: ColorBoton.rojo,
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Más tarde',
                      style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------- Pantalla del evento ----------

class PantallaInmortal extends StatefulWidget {
  const PantallaInmortal({super.key});

  @override
  State<PantallaInmortal> createState() => _PantallaInmortalState();
}

class _PantallaInmortalState extends State<PantallaInmortal> {
  VideoPlayerController? _video;
  bool _peleando = false;

  @override
  void initState() {
    super.initState();
    Musica.instancia.reproducir('evento');
    _iniciarVideo();
  }

  Future<void> _iniciarVideo() async {
    try {
      final v = VideoPlayerController.asset(rutaVideoInmortal);
      _video = v;
      await v.initialize();
      await v.setLooping(true);
      await v.setVolume(0); // el sonido lo pone la música del evento
      await v.play();
      if (mounted) setState(() {});
    } catch (_) {
      // Sin video se ve la imagen de Mario sobre fondo oscuro.
      _video = null;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    Musica.instancia.reproducir('oscura');
    super.dispose();
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _batalla() async {
    if (_peleando) return;
    _peleando = true;
    final aviso = juego.pelearInmortal();
    if (aviso != null) {
      _peleando = false;
      _aviso(aviso);
      return;
    }
    // La pelea ya está resuelta y guardada: esto es solo la animación de ataque.
    // Se corta la música para que no se pise con el sonido del video.
    await Musica.instancia.detener();
    if (!mounted) {
      _peleando = false;
      return;
    }
    await Navigator.of(context).push<void>(PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => const _PantallaCargaInmortal(),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
    if (!mounted) {
      _peleando = false;
      return;
    }
    if (juego.historialPvE.isNotEmpty) {
      await mostrarBatalla(context, juego.historialPvE.first, conVideo: false);
    }
    _peleando = false;
    if (!mounted) return;
    Musica.instancia.reproducir('evento');
    setState(() {});
  }

  void _verRanking() {
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const PantallaRankingInmortal()));
  }

  Widget _fondo() {
    final v = _video;
    if (v != null && v.value.isInitialized) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: v.value.size.width,
            height: v.value.size.height,
            child: VideoPlayer(v),
          ),
        ),
      );
    }
    return Container(
      color: const Color(0xFF0B0707),
      alignment: Alignment.center,
      child: Image.asset(
        rutaImagenInmortal,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }

  static const _sombra = [
    Shadow(color: Colors.black, blurRadius: 8),
    Shadow(color: Colors.black, blurRadius: 18),
  ];

  Widget _texto(String titulo, String? sub) {
    return Column(
      children: [
        Text(titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE6C16A),
                shadows: _sombra)),
        if (sub != null) ...[
          const SizedBox(height: 8),
          Text(sub,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16, color: Colors.white, shadows: _sombra)),
        ],
      ],
    );
  }

  Widget _contenido() {
    if (!juego.esDomingoServidor) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _texto('El Inmortal descansa',
              'Mariolo vuelve todos los domingos. Prepárate.'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: BotonOscuro(
              texto: 'Ver ranking del último domingo',
              alto: 52,
              color: ColorBoton.morado,
              onPressed: _verRanking,
            ),
          ),
        ],
      );
    }
    if (juego.inmortalIntentadoHoy) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _texto('Ya lo enfrentaste hoy',
              'Le hiciste ${juego.inmortalDano} de daño y ganaste ${juego.inmortalOro} de oro.\nVuelve el próximo domingo.'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: BotonOscuro(
              texto: 'Ver ranking',
              alto: 52,
              color: ColorBoton.morado,
              onPressed: _verRanking,
            ),
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _texto('Mariolo el Inmortal ya está aquí',
            '¿Te animas a atacar a LaBestiaPapuuu el Inmortal?'),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: BotonOscuro(
            texto: '¡A LA BATALLA!',
            alto: 60,
            color: ColorBoton.rojo,
            onPressed: _batalla,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _fondo(),
          // Degradado para que el texto se lea sobre el video
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x66000000), Color(0x00000000), Color(0xCC000000)],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.leaderboard, color: Colors.white),
                      tooltip: 'Ranking del Inmortal',
                      onPressed: _verRanking,
                    ),
                  ],
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                  child: _contenido(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Animación de ataque (se ve al tocar "¡A LA BATALLA!") ----------
// Pantalla completa, sin botones. Se cierra sola al terminar el video o al
// tocar la pantalla (para saltarla). Si el video no carga, se cierra enseguida.

class _PantallaCargaInmortal extends StatefulWidget {
  const _PantallaCargaInmortal();

  @override
  State<_PantallaCargaInmortal> createState() => _PantallaCargaInmortalState();
}

class _PantallaCargaInmortalState extends State<_PantallaCargaInmortal> {
  VideoPlayerController? _v;
  bool _cerrado = false;
  Timer? _seguro;

  @override
  void initState() {
    super.initState();
    // Por si algo falla, nunca se queda trabada aquí.
    _seguro = Timer(const Duration(seconds: 9), _cerrar);
    _iniciar();
  }

  Future<void> _iniciar() async {
    try {
      final v = VideoPlayerController.asset(rutaVideoCargaInmortal);
      _v = v;
      await v.initialize();
      await v.setLooping(false);
      // Respeta el volumen y el modo silencio de Ajustes.
      await v.setVolume(
          Musica.instancia.silencio ? 0.0 : Musica.instancia.volumen);
      v.addListener(_vigilar);
      await v.play();
      if (mounted) setState(() {});
    } catch (_) {
      _cerrar();
    }
  }

  void _vigilar() {
    final v = _v;
    if (v == null) return;
    final val = v.value;
    if (val.isInitialized &&
        val.duration > Duration.zero &&
        val.position >= val.duration - const Duration(milliseconds: 80)) {
      _cerrar();
    }
  }

  void _cerrar() {
    if (_cerrado || !mounted) return;
    _cerrado = true;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _seguro?.cancel();
    _v?.removeListener(_vigilar);
    _v?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _v;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _cerrar,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.expand(
          child: (v != null && v.value.isInitialized)
              ? FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: v.value.size.width,
              height: v.value.size.height,
              child: VideoPlayer(v),
            ),
          )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

// ---------- Ranking del domingo ----------
// Lee los perfiles que tienen el campo de ese domingo (ind_AAAA_M_D), ordenados
// por daño. Un solo campo, así Firestore no pide índices nuevos.

class PantallaRankingInmortal extends StatefulWidget {
  const PantallaRankingInmortal({super.key});

  @override
  State<PantallaRankingInmortal> createState() =>
      _PantallaRankingInmortalState();
}

class _PantallaRankingInmortalState extends State<PantallaRankingInmortal> {
  late final String _domingo = ultimoDomingo();
  late Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _futuro =
  _cargar();

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _cargar() async {
    final campo = campoInmortal(_domingo);
    final snap = await FirebaseFirestore.instance
        .collection('perfiles')
        .orderBy(campo, descending: true)
        .limit(inmortalRankingTamano)
        .get()
        .timeout(const Duration(seconds: 15));
    return snap.docs;
  }

  @override
  Widget build(BuildContext context) {
    final miUid = FirebaseAuth.instance.currentUser?.uid;
    final campo = campoInmortal(_domingo);
    return Scaffold(
      backgroundColor: const Color(0xFF0B0707),
      appBar: AppBar(
        title: const Text('Ranking del Inmortal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _futuro = _cargar()),
          ),
        ],
      ),
      body: FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        future: _futuro,
        builder: (ctx, s) {
          if (s.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.hasError) {
            return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                      'No se pudo cargar el ranking. Revisa tu conexión e inténtalo de nuevo.',
                      textAlign: TextAlign.center),
                ));
          }
          final docs = s.data ?? const [];
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                    'Domingo $_domingo  -  los $inmortalRankingTamano que más daño le hicieron a LaBestiaPapuuu el Inmortal.',
                    style: const TextStyle(
                        fontStyle: FontStyle.italic, fontSize: 12)),
              ),
              if (docs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Todavía nadie lo desafió ese domingo.',
                      textAlign: TextAlign.center),
                ),
              for (int i = 0; i < docs.length; i++)
                _fila(i + 1, docs[i], campo, docs[i].id == miUid),
            ],
          );
        },
      ),
    );
  }

  Widget _fila(int puesto, QueryDocumentSnapshot<Map<String, dynamic>> d,
      String campo, bool esMio) {
    final m = d.data();
    final nombre = (m['nombre'] ?? '?').toString();
    final nivel = (m['nivel'] as num?)?.toInt() ?? 0;
    final dano = (m[campo] as num?)?.toInt() ?? 0;
    final medalla = puesto == 1
        ? const Color(0xFFFFD54F)
        : puesto == 2
        ? const Color(0xFFCFD8DC)
        : puesto == 3
        ? const Color(0xFFBF8A5A)
        : Colors.white54;
    return Card(
      color: esMio ? const Color(0xFF3A1A1A) : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.black54,
          child: Text('$puesto',
              style: TextStyle(fontWeight: FontWeight.bold, color: medalla)),
        ),
        title: Text(esMio ? '$nombre (tú)' : nombre,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Nivel $nivel'),
        trailing: Text('$dano de daño',
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.amber)),
      ),
    );
  }
}