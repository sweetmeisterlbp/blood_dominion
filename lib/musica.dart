import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Música de fondo del juego: volumen, modo silencio y cambio de pista.
///
/// Las pistas van en  assets/musica/musica_<nombre>.ogg
/// (por ejemplo "oscura" -> assets/musica/musica_oscura.ogg).
class Musica extends ChangeNotifier with WidgetsBindingObserver {
  Musica._();
  static final Musica instancia = Musica._();

  final AudioPlayer _player = AudioPlayer();
  double _volumen = 0.6; // 0.0 a 1.0
  bool _silencio = false;
  String? _pista;
  bool _enSegundoPlano = false;

  double get volumen => _volumen;
  bool get silencio => _silencio;

  /// Carga lo guardado. Llamar una vez antes de dibujar la primera pantalla.
  Future<void> cargar() async {
    try {
      final p = await SharedPreferences.getInstance();
      _volumen = (p.getDouble('musica_volumen') ?? 0.6).clamp(0.0, 1.0);
      _silencio = p.getBool('musica_silencio') ?? false;
    } catch (_) {}
    WidgetsBinding.instance.addObserver(this);
    await _player.setReleaseMode(ReleaseMode.loop);
    await _aplicarVolumen();
  }

  /// Empieza a sonar una pista (en bucle). Si ya suena esa, no hace nada.
  Future<void> reproducir(String nombre) async {
    if (_pista == nombre) return;
    _pista = nombre;
    try {
      await _player.stop();
      await _aplicarVolumen();
      if (!_silencio && !_enSegundoPlano) {
        await _player.play(AssetSource('musica/musica_$nombre.ogg'));
      }
    } catch (_) {}
  }

  /// Corta la música (por ejemplo mientras suena el audio de un video).
  /// La siguiente llamada a [reproducir] vuelve a arrancar una pista.
  Future<void> detener() async {
    _pista = null;
    try {
      await _player.stop();
    } catch (_) {}
  }

  /// Mueve la barra (se llama mientras el dedo se desliza).
  void cambiarVolumen(double v) {
    _volumen = v.clamp(0.0, 1.0);
    _aplicarVolumen();
    notifyListeners();
  }

  /// Guarda el volumen (se llama al soltar la barra).
  Future<void> guardarVolumen() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble('musica_volumen', _volumen);
    } catch (_) {}
  }

  /// Activa o quita el modo silencio.
  Future<void> ponerSilencio(bool valor) async {
    _silencio = valor;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('musica_silencio', valor);
    } catch (_) {}
    await _aplicarVolumen();
    await _sincronizar();
  }

  Future<void> _aplicarVolumen() async {
    try {
      await _player.setVolume(_silencio ? 0.0 : _volumen);
    } catch (_) {}
  }

  // Pausa o reanuda según haya silencio o la app esté en segundo plano.
  Future<void> _sincronizar() async {
    try {
      if (_silencio || _enSegundoPlano) {
        await _player.pause();
      } else if (_pista != null) {
        if (_player.state == PlayerState.paused) {
          await _player.resume();
        } else if (_player.state != PlayerState.playing) {
          await _player.play(AssetSource('musica/musica_$_pista.ogg'));
        }
      }
    } catch (_) {}
  }

  // La música se calla al salir del juego y vuelve al regresar.
  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    _enSegundoPlano = estado != AppLifecycleState.resumed;
    _sincronizar();
  }
}