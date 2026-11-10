import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'arena.dart';
import 'idioma.dart';
import 'main.dart';

// ====================== SOCIAL: CHAT, AMIGOS Y MENSAJES ======================
// - Chat global (colección "chat_global"): 200 caracteres por mensaje.
// - Amigos: se agregan con un código (BD-XXXXXX) o desde un mensaje del chat.
//   Hay que aceptar la solicitud.
// - Chat privado solo entre amigos (colección "chats").
// - Traducir: botón en cada mensaje. Traduce dentro del celular (ML Kit),
//   sin servidor. La primera vez de cada idioma descarga su paquete.
// - Reportar y bloquear (lo exige Google Play cuando hay chat entre jugadores).
// Las reglas de Firestore que necesita están en reglas_firestore_social.txt.

const int maxCaracteresChat = 200;
const int maxMensajesChat = 30; // últimos mensajes que se muestran
const int maxAmigos = 50;
const Duration esperaEntreMensajes = Duration(seconds: 4);

// Código corto que ve el jugador para que lo agreguen. Sale de su identificador.
String codigoJugador(String uid) =>
    'BD-${(uid.length < 6 ? uid : uid.substring(0, 6)).toUpperCase()}';

String parDeChat(String a, String b) =>
    a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';

// Filtro básico: tapa insultos comunes y rechaza enlaces.
// (No reemplaza el botón de reportar.)
const List<String> _palabrasFeas = [
  'puta', 'puto', 'mierda', 'pendejo', 'cabron', 'cabrón', 'hdp', 'malparido',
  'fuck', 'shit', 'bitch', 'nigger', 'faggot', 'cunt',
];

String limpiarTexto(String t) {
  var r = t.trim();
  for (final p in _palabrasFeas) {
    r = r.replaceAllMapped(RegExp(RegExp.escape(p), caseSensitive: false),
            (m) => '*' * m.group(0)!.length);
  }
  return r;
}

bool tieneEnlace(String t) {
  final x = t.toLowerCase();
  return x.contains('http') || x.contains('www.') || x.contains('.com');
}

int _entero(dynamic v) => (v as num?)?.toInt() ?? 0;

// ---------- Datos ----------

class AmigoSocial {
  final String uid;
  final String nombre;
  final int nivel;
  const AmigoSocial(this.uid, this.nombre, this.nivel);
}

class SolicitudSocial {
  final String uid;
  final String nombre;
  final int nivel;
  const SolicitudSocial(this.uid, this.nombre, this.nivel);
}

// ====================== TRADUCTOR ======================

class Traductor {
  static TranslateLanguage? _idioma(String codigo) {
    final base = codigo.toLowerCase().split(RegExp('[-_]')).first;
    for (final l in TranslateLanguage.values) {
      if (l.bcpCode == base) return l;
    }
    return null;
  }

  // Devuelve el texto traducido al idioma que elegiste en Ajustes.
  // Si el mensaje ya está en tu idioma, lo devuelve igual.
  // Lanza un error si no hay internet la primera vez (descarga el idioma).
  static Future<String> traducir(String texto) async {
    final identificador = LanguageIdentifier(confidenceThreshold: 0.4);
    String codigo;
    try {
      codigo = await identificador.identifyLanguage(texto);
    } finally {
      await identificador.close();
    }
    if (codigo == 'und') {
      throw StateError('No se pudo reconocer el idioma del mensaje.');
    }
    final origen = _idioma(codigo);
    if (origen == null) {
      throw StateError('Ese idioma todavía no se puede traducir.');
    }
    final destino = _idioma(Idioma.instancia.codigo) ?? TranslateLanguage.spanish;
    if (origen == destino) return texto;
    final t = OnDeviceTranslator(sourceLanguage: origen, targetLanguage: destino);
    try {
      return await t.translateText(texto);
    } finally {
      await t.close();
    }
  }
}

// ====================== ESTADO SOCIAL ======================
// Escucha solicitudes, amigos, bloqueados y mensajes nuevos mientras estás
// dentro del juego, para mostrar el punto rojo en la pestaña Social.

class Social extends ChangeNotifier {
  Social._();
  static final Social instancia = Social._();

  String? _uid;
  final List<AmigoSocial> amigos = [];
  final List<SolicitudSocial> solicitudes = [];
  final Map<String, String> bloqueados = {}; // uid -> nombre
  // Amigos que te escribieron y todavía no leíste (uid del amigo)
  final Set<String> noLeidos = {};
  final Map<String, int> _leido = {}; // par de chat -> último mensaje leído
  final Map<String, int> _ultimoMsPar = {};
  final Map<String, String> _ultimoDePar = {};
  final Map<String, String> _amigoDePar = {};

  final List<StreamSubscription<dynamic>> _subs = [];

  String? get uid => _uid;
  int get pendientes => solicitudes.length + noLeidos.length;

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  Future<void> iniciar() async {
    final u = FirebaseAuth.instance.currentUser?.uid;
    if (u == null || u == _uid) return;
    detener();
    _uid = u;
    try {
      final p = await SharedPreferences.getInstance();
      for (final k in p.getKeys()) {
        if (k.startsWith('chatLeido_$u|')) {
          _leido[k.substring('chatLeido_$u|'.length)] = p.getInt(k) ?? 0;
        }
      }
    } catch (_) {}

    _subs.add(_db
        .collection('solicitudes')
        .doc(u)
        .collection('entrantes')
        .snapshots()
        .listen((s) {
      solicitudes
        ..clear()
        ..addAll(s.docs.map((d) => SolicitudSocial(
            d.id, (d.data()['nombre'] ?? 'Jugador') as String, _entero(d.data()['nivel']))));
      notifyListeners();
    }, onError: (_) {}));

    _subs.add(_db
        .collection('amigos')
        .doc(u)
        .collection('lista')
        .snapshots()
        .listen((s) {
      amigos
        ..clear()
        ..addAll(s.docs.map((d) => AmigoSocial(
            d.id, (d.data()['nombre'] ?? 'Jugador') as String, _entero(d.data()['nivel']))));
      amigos.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
      _recalcularNoLeidos();
    }, onError: (_) {}));

    _subs.add(_db
        .collection('bloqueados')
        .doc(u)
        .collection('lista')
        .snapshots()
        .listen((s) {
      bloqueados
        ..clear()
        ..addEntries(s.docs
            .map((d) => MapEntry(d.id, (d.data()['nombre'] ?? 'Jugador') as String)));
      notifyListeners();
    }, onError: (_) {}));

    _subs.add(_db
        .collection('chats')
        .where('participantes', arrayContains: u)
        .snapshots()
        .listen((s) {
      for (final d in s.docs) {
        final x = d.data();
        final partes = List<String>.from((x['participantes'] as List?) ?? const []);
        final otro = partes.firstWhere((e) => e != u, orElse: () => '');
        final tUlt = x['ultimoMs'];
        _ultimoMsPar[d.id] =
        tUlt is Timestamp ? tUlt.millisecondsSinceEpoch : _entero(tUlt);
        _ultimoDePar[d.id] = (x['ultimoDe'] ?? '') as String;
        _amigoDePar[d.id] = otro;
      }
      _recalcularNoLeidos();
    }, onError: (_) {}));
  }

  void detener() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    amigos.clear();
    solicitudes.clear();
    bloqueados.clear();
    noLeidos.clear();
    _leido.clear();
    _ultimoMsPar.clear();
    _ultimoDePar.clear();
    _amigoDePar.clear();
    _uid = null;
  }

  void _recalcularNoLeidos() {
    final u = _uid;
    noLeidos.clear();
    if (u != null) {
      _ultimoMsPar.forEach((par, ms) {
        if (_ultimoDePar[par] != u && ms > (_leido[par] ?? 0)) {
          final amigo = _amigoDePar[par];
          if (amigo != null && amigo.isNotEmpty) noLeidos.add(amigo);
        }
      });
    }
    notifyListeners();
  }

  // Marca el chat como leído hasta el último mensaje conocido.
  Future<void> marcarLeido(String par, int ms) async {
    final u = _uid;
    if (u == null) return;
    if ((_leido[par] ?? 0) >= ms) return;
    _leido[par] = ms;
    _recalcularNoLeidos();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt('chatLeido_$u|$par', ms);
    } catch (_) {}
  }

  bool esAmigo(String otro) => amigos.any((a) => a.uid == otro);
  bool estaBloqueado(String otro) => bloqueados.containsKey(otro);

  // ---------- Acciones ----------

  // Devuelve un mensaje de error, o null si salió bien.
  Future<String?> enviarSolicitudPorUid(String otro, String nombreOtro) async {
    final yo = _uid;
    if (yo == null) return 'No hay sesión iniciada.';
    if (otro == yo) return 'Ese eres tú.';
    if (esAmigo(otro)) return '$nombreOtro ya es tu amigo.';
    if (amigos.length >= maxAmigos) {
      return 'Ya tienes $maxAmigos amigos, que es el máximo.';
    }
    try {
      await _db
          .collection('solicitudes')
          .doc(otro)
          .collection('entrantes')
          .doc(yo)
          .set({
        'nombre': juego.nombre,
        'nivel': juego.nivel,
        'ms': DateTime.now().millisecondsSinceEpoch,
      }).timeout(const Duration(seconds: 15));
      return null;
    } catch (_) {
      return 'No se pudo enviar la solicitud. Revisa tu conexión.';
    }
  }

  Future<String?> enviarSolicitudPorCodigo(String codigoTexto) async {
    final codigo = codigoTexto.trim().toUpperCase();
    if (!RegExp(r'^BD-[A-Z0-9]{4,8}$').hasMatch(codigo)) {
      return 'El código tiene que verse así: BD-XXXXXX.';
    }
    try {
      final r = await _db
          .collection('perfiles')
          .where('codigo', isEqualTo: codigo)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 15));
      if (r.docs.isEmpty) return 'No existe ningún jugador con ese código.';
      final d = r.docs.first;
      final nombre = (d.data()['nombre'] ?? 'Jugador') as String;
      final err = await enviarSolicitudPorUid(d.id, nombre);
      return err ?? 'Solicitud enviada a $nombre.';
    } catch (_) {
      return 'No se pudo buscar. Revisa tu conexión.';
    }
  }

  Future<String?> aceptar(SolicitudSocial s) async {
    final yo = _uid;
    if (yo == null) return 'No hay sesión iniciada.';
    if (amigos.length >= maxAmigos) {
      return 'Ya tienes $maxAmigos amigos, que es el máximo.';
    }
    final ahora = DateTime.now().millisecondsSinceEpoch;
    try {
      await _db
          .collection('amigos')
          .doc(yo)
          .collection('lista')
          .doc(s.uid)
          .set({'nombre': s.nombre, 'nivel': s.nivel, 'ms': ahora});
      // Su lado de la amistad: las reglas lo permiten porque tienes su solicitud.
      await _db
          .collection('amigos')
          .doc(s.uid)
          .collection('lista')
          .doc(yo)
          .set({'nombre': juego.nombre, 'nivel': juego.nivel, 'ms': ahora});
      await _db
          .collection('solicitudes')
          .doc(yo)
          .collection('entrantes')
          .doc(s.uid)
          .delete();
      return null;
    } catch (_) {
      return 'No se pudo aceptar. Revisa tu conexión.';
    }
  }

  Future<void> rechazar(SolicitudSocial s) async {
    final yo = _uid;
    if (yo == null) return;
    try {
      await _db
          .collection('solicitudes')
          .doc(yo)
          .collection('entrantes')
          .doc(s.uid)
          .delete();
    } catch (_) {}
  }

  Future<void> eliminarAmigo(String otro) async {
    final yo = _uid;
    if (yo == null) return;
    try {
      await _db.collection('amigos').doc(yo).collection('lista').doc(otro).delete();
    } catch (_) {}
    try {
      await _db.collection('amigos').doc(otro).collection('lista').doc(yo).delete();
    } catch (_) {}
  }

  Future<void> bloquear(String otro, String nombre) async {
    final yo = _uid;
    if (yo == null) return;
    try {
      await _db.collection('bloqueados').doc(yo).collection('lista').doc(otro).set({
        'nombre': nombre,
        'ms': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}
    await eliminarAmigo(otro);
    try {
      await _db
          .collection('solicitudes')
          .doc(yo)
          .collection('entrantes')
          .doc(otro)
          .delete();
    } catch (_) {}
  }

  Future<void> desbloquear(String otro) async {
    final yo = _uid;
    if (yo == null) return;
    try {
      await _db.collection('bloqueados').doc(yo).collection('lista').doc(otro).delete();
    } catch (_) {}
  }

  Future<void> reportar(
      {required String contra,
        required String nombreContra,
        required String texto,
        required String canal}) async {
    final yo = _uid;
    if (yo == null) return;
    try {
      await _db.collection('reportes').add({
        'de': yo,
        'deNombre': juego.nombre,
        'contra': contra,
        'contraNombre': nombreContra,
        'texto': texto,
        'canal': canal,
        'ts': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}

// ====================== MENSAJE (burbuja con traducir) ======================

class _Mensaje {
  final String id;
  final String uid;
  final String nombre;
  final int nivel;
  final int alin;
  final String texto;
  final int ms;
  const _Mensaje(this.id, this.uid, this.nombre, this.nivel, this.alin,
      this.texto, this.ms);

  static int _msDe(Map<String, dynamic> x) {
    final t = x['ts'];
    if (t is Timestamp) return t.millisecondsSinceEpoch;
    return DateTime.now().millisecondsSinceEpoch; // todavía sin confirmar
  }

  factory _Mensaje.global(String id, Map<String, dynamic> x) => _Mensaje(
      id,
      (x['uid'] ?? '') as String,
      (x['nombre'] ?? 'Jugador') as String,
      _entero(x['nivel']),
      _entero(x['alin']),
      (x['texto'] ?? '') as String,
      _msDe(x));

  factory _Mensaje.privado(String id, Map<String, dynamic> x, String nombre) =>
      _Mensaje(id, (x['de'] ?? '') as String, nombre, 0, 0,
          (x['texto'] ?? '') as String, _msDe(x));
}

void _aviso(BuildContext context, String texto) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(content: Text(texto)));
}

class _Burbuja extends StatefulWidget {
  final _Mensaje m;
  final bool mio;
  final bool conNombreTitulo; // chat global: muestra título y nivel
  final String canal;
  const _Burbuja(
      {super.key,
        required this.m,
        required this.mio,
        required this.canal,
        this.conNombreTitulo = false});

  @override
  State<_Burbuja> createState() => _BurbujaState();
}

class _BurbujaState extends State<_Burbuja> {
  String? _traduccion;
  bool _traduciendo = false;
  bool _verTraduccion = false;

  Future<void> _traducir() async {
    if (_traduccion != null) {
      setState(() => _verTraduccion = !_verTraduccion);
      return;
    }
    setState(() => _traduciendo = true);
    try {
      final r = await Traductor.traducir(widget.m.texto);
      if (!mounted) return;
      setState(() {
        _traduccion = r;
        _verTraduccion = true;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e is StateError
          ? e.message
          : 'No se pudo traducir. La primera vez de cada idioma necesita internet para descargarlo.';
      _aviso(context, msg);
    } finally {
      if (mounted) setState(() => _traduciendo = false);
    }
  }

  Future<void> _accion(String a) async {
    final m = widget.m;
    final social = Social.instancia;
    switch (a) {
      case 'amigo':
        final r = await social.enviarSolicitudPorUid(m.uid, m.nombre);
        if (mounted) _aviso(context, r ?? 'Solicitud enviada a ${m.nombre}.');
        break;
      case 'reportar':
        await social.reportar(
            contra: m.uid,
            nombreContra: m.nombre,
            texto: m.texto,
            canal: widget.canal);
        if (mounted) _aviso(context, 'Reporte enviado. Gracias.');
        break;
      case 'bloquear':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('¿Bloquear a ${m.nombre}?'),
            content: const Text(
                'No verás sus mensajes y, si eran amigos, dejarán de serlo. Puedes desbloquearlo en Social › Bloqueados.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Bloquear')),
            ],
          ),
        );
        if (ok == true) await social.bloquear(m.uid, m.nombre);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    final mio = widget.mio;
    final mostrando = (_verTraduccion && _traduccion != null) ? _traduccion! : m.texto;
    final ancho = MediaQuery.of(context).size.width * 0.78;
    return Align(
      alignment: mio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: ancho),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
        decoration: BoxDecoration(
          color: mio ? const Color(0xCC5A1B2B) : const Color(0xCC1E1418),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: mio ? const Color(0xFF8A3045) : Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.conNombreTitulo && !mio)
            // Tocar el nombre abre la ficha del jugador.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => mostrarPerfilJugador(context, m.uid),
                child: Row(
                  children: [
                    Flexible(
                        child: NombreConTitulo(m.nombre, m.alin, tamano: 13)),
                    Text('  Nv ${m.nivel}',
                        style: const TextStyle(fontSize: 11, color: Colors.white54)),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2, right: 4),
                    child: Text(mostrando, style: const TextStyle(fontSize: 14)),
                  ),
                ),
                if (!mio)
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: _traduciendo
                        ? const Padding(
                        padding: EdgeInsets.all(7),
                        child: CircularProgressIndicator(strokeWidth: 2))
                        : IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: 'Traducir',
                      iconSize: 20,
                      color: _verTraduccion
                          ? const Color(0xFF00F5E0)
                          : Colors.white60,
                      icon: const Icon(Icons.translate),
                      onPressed: _traducir,
                    ),
                  ),
                if (!mio)
                  SizedBox(
                    width: 28,
                    height: 30,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      icon: const Icon(Icons.more_vert, color: Colors.white54),
                      onSelected: _accion,
                      itemBuilder: (_) => [
                        if (widget.canal == 'global' &&
                            !Social.instancia.esAmigo(m.uid))
                          const PopupMenuItem(
                              value: 'amigo', child: Text('Agregar amigo')),
                        const PopupMenuItem(
                            value: 'reportar', child: Text('Reportar')),
                        const PopupMenuItem(
                            value: 'bloquear', child: Text('Bloquear')),
                      ],
                    ),
                  ),
              ],
            ),
            if (_verTraduccion && _traduccion != null)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text('Traducido · toca el ícono para ver el original',
                    style: TextStyle(fontSize: 10, color: Colors.white38)),
              ),
          ],
        ),
      ),
    );
  }
}

// ====================== CAJA PARA ESCRIBIR ======================

class _CajaEscribir extends StatefulWidget {
  final Future<String?> Function(String texto) enviar; // devuelve error o null
  const _CajaEscribir({required this.enviar});

  @override
  State<_CajaEscribir> createState() => _CajaEscribirState();
}

class _CajaEscribirState extends State<_CajaEscribir> {
  final TextEditingController _c = TextEditingController();
  DateTime _ultimo = DateTime.fromMillisecondsSinceEpoch(0);
  bool _enviando = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final texto = _c.text.trim();
    if (texto.isEmpty || _enviando) return;
    final espera = esperaEntreMensajes - DateTime.now().difference(_ultimo);
    if (espera > Duration.zero) {
      _aviso(context, 'Espera ${espera.inSeconds + 1} s para escribir otra vez.');
      return;
    }
    if (tieneEnlace(texto)) {
      _aviso(context, 'No se permiten enlaces en el chat.');
      return;
    }
    setState(() => _enviando = true);
    final err = await widget.enviar(limpiarTexto(texto));
    if (!mounted) return;
    setState(() => _enviando = false);
    if (err != null) {
      _aviso(context, err);
      return;
    }
    _ultimo = DateTime.now();
    _c.clear();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        color: const Color(0xCC1A0D12),
        padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _c,
                maxLength: maxCaracteresChat,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _enviar(),
                decoration: const InputDecoration(
                  hintText: 'Escribe un mensaje…',
                  counterText: '',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: _enviando
                  ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
              color: const Color(0xFFFFD54A),
              onPressed: _enviando ? null : _enviar,
            ),
          ],
        ),
      ),
    );
  }
}

// ====================== CHAT GLOBAL ======================

class PantallaChatGlobal extends StatelessWidget {
  const PantallaChatGlobal({super.key});

  Future<String?> _enviar(String texto) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return 'No hay sesión iniciada.';
    try {
      await FirebaseFirestore.instance.collection('chat_global').add({
        'uid': u.uid,
        'nombre': juego.nombre,
        'nivel': juego.nivel,
        'alin': juego.alineamiento,
        'texto': texto,
        'ts': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 15));
      return null;
    } catch (_) {
      return 'No se pudo enviar. Revisa tu conexión.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final yo = FirebaseAuth.instance.currentUser?.uid;
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('chat_global')
                .orderBy('ts', descending: true)
                .limit(maxMensajesChat)
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                          'No se pudo abrir el chat. Revisa tu conexión e inténtalo de nuevo.',
                          textAlign: TextAlign.center),
                    ));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListenableBuilder(
                listenable: Social.instancia,
                builder: (context, _) {
                  final msgs = snap.data!.docs
                      .map((d) => _Mensaje.global(d.id, d.data()))
                      .where((m) => !Social.instancia.estaBloqueado(m.uid))
                      .toList();
                  if (msgs.isEmpty) {
                    return const Center(
                        child: Text('Todavía no hay mensajes. ¡Escribe el primero!'));
                  }
                  return ListView.builder(
                    reverse: true, // el más nuevo abajo
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: msgs.length,
                    itemBuilder: (_, i) => _Burbuja(
                      key: ValueKey(msgs[i].id),
                      m: msgs[i],
                      mio: msgs[i].uid == yo,
                      canal: 'global',
                      conNombreTitulo: true,
                    ),
                  );
                },
              );
            },
          ),
        ),
        _CajaEscribir(enviar: _enviar),
      ],
    );
  }
}

// ====================== AMIGOS ======================

class PantallaAmigos extends StatefulWidget {
  const PantallaAmigos({super.key});

  @override
  State<PantallaAmigos> createState() => _PantallaAmigosState();
}

class _PantallaAmigosState extends State<PantallaAmigos> {
  final TextEditingController _codigo = TextEditingController();
  bool _buscando = false;

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _agregar() async {
    if (_buscando) return;
    setState(() => _buscando = true);
    final r = await Social.instancia.enviarSolicitudPorCodigo(_codigo.text);
    if (!mounted) return;
    setState(() => _buscando = false);
    if (r != null) _aviso(context, r);
    if (r != null && r.startsWith('Solicitud enviada')) _codigo.clear();
  }

  @override
  Widget build(BuildContext context) {
    final yo = FirebaseAuth.instance.currentUser?.uid ?? '';
    final miCodigo = yo.isEmpty ? '—' : codigoJugador(yo);
    return ListenableBuilder(
      listenable: Social.instancia,
      builder: (context, _) {
        final s = Social.instancia;
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tu código de jugador',
                        style: TextStyle(fontSize: 12)),
                    Row(
                      children: [
                        Text(miCodigo,
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFFD54A))),
                        IconButton(
                          tooltip: 'Copiar',
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: miCodigo));
                            _aviso(context, 'Código copiado.');
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _codigo,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              hintText: 'Código del amigo (BD-XXXXXX)',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _agregar(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _buscando ? null : _agregar,
                          child: _buscando
                              ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Agregar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (s.solicitudes.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                child: Text('Solicitudes (${s.solicitudes.length})',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              for (final sol in s.solicitudes)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.person_add),
                    title: Text(sol.nombre),
                    subtitle: Text('Nivel ${sol.nivel}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Aceptar',
                          icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
                          onPressed: () async {
                            final err = await s.aceptar(sol);
                            if (err != null && context.mounted) _aviso(context, err);
                          },
                        ),
                        IconButton(
                          tooltip: 'Rechazar',
                          icon: const Icon(Icons.cancel, color: Colors.redAccent),
                          onPressed: () => s.rechazar(sol),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
              child: Text('Amigos (${s.amigos.length}/$maxAmigos)',
                  style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            if (s.amigos.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                    'Aún no tienes amigos. Comparte tu código o toca el menú de un mensaje del chat global para agregar a alguien.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
              ),
            for (final a in s.amigos)
              Card(
                child: ListTile(
                  leading: Badge(
                    isLabelVisible: s.noLeidos.contains(a.uid),
                    child: const Icon(Icons.person),
                  ),
                  title: Text(a.nombre,
                      style: TextStyle(
                          fontWeight: s.noLeidos.contains(a.uid)
                              ? FontWeight.bold
                              : FontWeight.normal)),
                  subtitle: Text(s.noLeidos.contains(a.uid)
                      ? 'Mensaje nuevo'
                      : 'Nivel ${a.nivel}'),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => PantallaChatPrivado(a.uid, a.nombre))),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'perfil') {
                        await mostrarPerfilJugador(context, a.uid);
                      } else if (v == 'eliminar') {
                        await s.eliminarAmigo(a.uid);
                      } else if (v == 'bloquear') {
                        await s.bloquear(a.uid, a.nombre);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'perfil', child: Text('Ver perfil')),
                      PopupMenuItem(value: 'eliminar', child: Text('Eliminar amigo')),
                      PopupMenuItem(value: 'bloquear', child: Text('Bloquear')),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

// ====================== CHAT PRIVADO ======================

class PantallaChatPrivado extends StatefulWidget {
  final String uidAmigo;
  final String nombreAmigo;
  const PantallaChatPrivado(this.uidAmigo, this.nombreAmigo, {super.key});

  @override
  State<PantallaChatPrivado> createState() => _PantallaChatPrivadoState();
}

class _PantallaChatPrivadoState extends State<PantallaChatPrivado> {
  late final String _yo = FirebaseAuth.instance.currentUser?.uid ?? '';
  late final String _par = parDeChat(_yo, widget.uidAmigo);
  bool _listo = false; // el documento del chat ya existe
  bool _error = false;

  DocumentReference<Map<String, dynamic>> get _meta =>
      FirebaseFirestore.instance.collection('chats').doc(_par);

  @override
  void initState() {
    super.initState();
    _preparar();
  }

  // Las reglas leen este documento para saber quiénes participan.
  Future<void> _preparar() async {
    try {
      await _meta.set({
        'participantes': [_yo, widget.uidAmigo]..sort(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 15));
      if (mounted) setState(() => _listo = true);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<String?> _enviar(String texto) async {
    try {
      await _meta.set({
        'participantes': [_yo, widget.uidAmigo]..sort(),
        'ultimoMs': FieldValue.serverTimestamp(),
        'ultimoDe': _yo,
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 15));
      await _meta.collection('mensajes').add({
        'de': _yo,
        'texto': texto,
        'ts': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 15));
      return null;
    } catch (_) {
      return 'No se pudo enviar. ¿Siguen siendo amigos? Revisa tu conexión.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nombreAmigo),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'bloquear') {
                await Social.instancia.bloquear(widget.uidAmigo, widget.nombreAmigo);
                if (context.mounted) Navigator.of(context).pop();
              } else if (v == 'reportar') {
                await Social.instancia.reportar(
                    contra: widget.uidAmigo,
                    nombreContra: widget.nombreAmigo,
                    texto: '(reporte desde el chat privado)',
                    canal: 'privado');
                if (context.mounted) _aviso(context, 'Reporte enviado. Gracias.');
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'reportar', child: Text('Reportar')),
              PopupMenuItem(value: 'bloquear', child: Text('Bloquear')),
            ],
          ),
        ],
      ),
      body: _error
          ? const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
              'No se pudo abrir el chat. Solo puedes hablar con tus amigos y necesitas conexión.',
              textAlign: TextAlign.center),
        ),
      )
          : !_listo
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _meta
                  .collection('mensajes')
                  .orderBy('ts', descending: true)
                  .limit(maxMensajesChat)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(
                      child: Text('No se pudieron cargar los mensajes.'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final msgs = snap.data!.docs
                    .map((d) => _Mensaje.privado(
                    d.id, d.data(), widget.nombreAmigo))
                    .toList();
                if (msgs.isNotEmpty) {
                  // Al ver los mensajes, el chat queda como leído.
                  final ultimoMs = msgs.first.ms;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Social.instancia.marcarLeido(_par, ultimoMs);
                  });
                }
                if (msgs.isEmpty) {
                  return Center(
                      child: Text(
                          'Empieza la conversación con ${widget.nombreAmigo}.'));
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) => _Burbuja(
                    key: ValueKey(msgs[i].id),
                    m: msgs[i],
                    mio: msgs[i].uid == _yo,
                    canal: 'privado',
                  ),
                );
              },
            ),
          ),
          _CajaEscribir(enviar: _enviar),
        ],
      ),
    );
  }
}

// ====================== BLOQUEADOS ======================

class PantallaBloqueados extends StatelessWidget {
  const PantallaBloqueados({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Social.instancia,
      builder: (context, _) {
        final b = Social.instancia.bloqueados.entries.toList();
        if (b.isEmpty) {
          return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No tienes jugadores bloqueados.',
                    textAlign: TextAlign.center),
              ));
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            for (final e in b)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.block, color: Colors.redAccent),
                  title: Text(e.value),
                  trailing: TextButton(
                    onPressed: () => Social.instancia.desbloquear(e.key),
                    child: const Text('Desbloquear'),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}


// ====================== FICHA DE UN JUGADOR ======================
// Se abre al tocar el nombre de alguien (chat global, Arena, lista de amigos).
// Desde aquí se puede agregar como amigo, escribirle, reportar o bloquear.

Future<void> mostrarPerfilJugador(BuildContext context, String uid) async {
  final yo = FirebaseAuth.instance.currentUser?.uid;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1E1014),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => _FichaJugador(uid: uid, esYo: uid == yo),
  );
}

class _FichaJugador extends StatefulWidget {
  final String uid;
  final bool esYo;
  const _FichaJugador({required this.uid, required this.esYo});

  @override
  State<_FichaJugador> createState() => _FichaJugadorState();
}

class _FichaJugadorState extends State<_FichaJugador> {
  late final Future<PerfilRival?> _futuro = _cargar();
  bool _solicitudEnviada = false;
  bool _enviando = false;

  Future<PerfilRival?> _cargar() async {
    try {
      final d = await FirebaseFirestore.instance
          .collection('perfiles')
          .doc(widget.uid)
          .get()
          .timeout(const Duration(seconds: 15));
      if (!d.exists || d.data() == null) return null;
      return PerfilRival.desdeMapa(d.id, d.data()!);
    } catch (_) {
      return null;
    }
  }

  Future<void> _agregar(PerfilRival r) async {
    if (_enviando) return;
    setState(() => _enviando = true);
    final err = await Social.instancia.enviarSolicitudPorUid(r.uid, r.nombre);
    if (!mounted) return;
    setState(() {
      _enviando = false;
      _solicitudEnviada = err == null;
    });
    if (err != null) _aviso(context, err);
  }

  Future<void> _bloquear(PerfilRival r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Bloquear a ${r.nombre}?'),
        content: const Text(
            'No verás sus mensajes y, si eran amigos, dejarán de serlo. Puedes desbloquearlo en Social › Bloqueados.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Bloquear')),
        ],
      ),
    );
    if (ok != true) return;
    await Social.instancia.bloquear(r.uid, r.nombre);
    if (mounted) Navigator.of(context).pop();
  }

  Widget _dato(String etiqueta, int valor) => Column(
    children: [
      Text('$valor',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      Text(etiqueta,
          style: const TextStyle(fontSize: 10, color: Colors.white60)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: FutureBuilder<PerfilRival?>(
          future: _futuro,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()));
            }
            final r = snap.data;
            if (r == null) {
              return const SizedBox(
                height: 120,
                child: Center(
                    child: Text(
                        'No se pudo cargar este jugador. Revisa tu conexión.',
                        textAlign: TextAlign.center)),
              );
            }
            final total = r.victorias + r.derrotas;
            final pct = total == 0 ? 0 : (r.victorias * 100 / total).round();
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  NombreConTitulo(r.nombre, r.alineamiento,
                      tamano: 22, alinear: TextAlign.center),
                  const SizedBox(height: 4),
                  Text('${r.raza.nombre}  ·  Nivel ${r.nivel}',
                      style: const TextStyle(fontSize: 14)),
                  Text('Pasiva: ${r.raza.pasiva.nombre}',
                      style: const TextStyle(fontSize: 12, color: Colors.white60)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _dato('Victorias', r.victorias),
                      _dato('Derrotas', r.derrotas),
                      _dato('% victorias', pct),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      _dato('Poder', r.poder),
                      _dato('Vigor', r.vigor),
                      _dato('Agilidad', r.agilidad),
                      _dato('Maestría', r.maestria),
                      _dato('Guardia', r.guardia),
                      _dato('Aguante', r.aguante),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Equipo: oculto hasta el combate',
                      style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.white54)),
                  const SizedBox(height: 14),
                  if (widget.esYo)
                    const Text('Este eres tú.',
                        style: TextStyle(fontStyle: FontStyle.italic))
                  else
                    ListenableBuilder(
                      listenable: Social.instancia,
                      builder: (context, _) {
                        final s = Social.instancia;
                        final amigo = s.esAmigo(r.uid);
                        return Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: amigo
                                  ? FilledButton.icon(
                                icon: const Icon(Icons.chat),
                                label: const Text('Enviar mensaje'),
                                onPressed: () {
                                  final nav = Navigator.of(context);
                                  nav.pop();
                                  nav.push(MaterialPageRoute<void>(
                                      builder: (_) => PantallaChatPrivado(
                                          r.uid, r.nombre)));
                                },
                              )
                                  : FilledButton.icon(
                                icon: Icon(_solicitudEnviada
                                    ? Icons.check
                                    : Icons.person_add),
                                label: Text(_solicitudEnviada
                                    ? 'Solicitud enviada'
                                    : 'Agregar amigo'),
                                onPressed: (_solicitudEnviada || _enviando)
                                    ? null
                                    : () => _agregar(r),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextButton(
                                  onPressed: () async {
                                    await s.reportar(
                                        contra: r.uid,
                                        nombreContra: r.nombre,
                                        texto: '(reporte desde la ficha del jugador)',
                                        canal: 'perfil');
                                    if (context.mounted) {
                                      _aviso(context, 'Reporte enviado. Gracias.');
                                    }
                                  },
                                  child: const Text('Reportar'),
                                ),
                                TextButton(
                                  onPressed: () => _bloquear(r),
                                  child: const Text('Bloquear',
                                      style: TextStyle(color: Colors.redAccent)),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}