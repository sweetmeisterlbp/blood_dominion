import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main.dart';
import 'nube.dart';

// ====================== LEGAL Y BORRADO DE CUENTA ======================
// Lo que Google Play exige:
//  - Enlace a la política de privacidad (en la ficha de la tienda y en el juego)
//  - Poder borrar la cuenta desde el juego
//  - Una página web donde pedir el borrado sin instalar el juego
//
// IMPORTANTE: cambia estas direcciones por las tuyas cuando publiques las
// páginas de la carpeta "web_legal" (por ejemplo en GitHub Pages).

const String urlPoliticaPrivacidad =
    'https://TU-USUARIO.github.io/blood-dominion/privacidad.html';
const String urlBorrarCuenta =
    'https://TU-USUARIO.github.io/blood-dominion/borrar_cuenta.html';
const String urlReglas =
    'https://TU-USUARIO.github.io/blood-dominion/reglas.html';

Future<void> abrirUrl(BuildContext context, String url) async {
  bool ok = false;
  try {
    ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('No se pudo abrir el enlace.')));
  }
}

// Tres enlaces pequeños: política, reglas del chat y borrar cuenta.
class EnlacesLegales extends StatelessWidget {
  final bool conBorrar;
  const EnlacesLegales({super.key, this.conBorrar = false});

  @override
  Widget build(BuildContext context) {
    Widget enlace(String texto, String url) => TextButton(
      style: TextButton.styleFrom(
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      onPressed: () => abrirUrl(context, url),
      child: Text(texto, style: const TextStyle(fontSize: 12)),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        enlace('Política de privacidad', urlPoliticaPrivacidad),
        enlace('Reglas de la comunidad', urlReglas),
        if (conBorrar) enlace('Borrar mi cuenta (web)', urlBorrarCuenta),
      ],
    );
  }
}

// ---------- Enviar comentario (te llega a la consola de Firebase) ----------
// Cambia esto cuando subas una versión nueva, para saber de cuál te escriben.
const String versionJuego = '1.0.1+2';
DateTime? _ultimoComentario;

Future<void> mostrarEnviarComentario(BuildContext context) async {
  final texto = TextEditingController();
  String tipo = 'Idea';
  bool enviando = false;
  String? error;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: const Text('Enviar comentario'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Cuéntanos qué falla, qué te confunde o qué te gustaría ver.',
                  style: TextStyle(fontSize: 13)),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'Error', label: Text('Error')),
                  ButtonSegment(value: 'Idea', label: Text('Idea')),
                  ButtonSegment(value: 'Otro', label: Text('Otro')),
                ],
                selected: {tipo},
                onSelectionChanged: enviando
                    ? null
                    : (s) => setS(() => tipo = s.first),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: texto,
                enabled: !enviando,
                maxLength: 500,
                maxLines: 5,
                minLines: 3,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Escribe aquí...'),
              ),
              if (error != null)
                Text(error!,
                    style:
                    const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: enviando ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: enviando
                ? null
                : () async {
              final t = texto.text.trim();
              if (t.isEmpty) {
                setS(() => error = 'Escribe algo primero.');
                return;
              }
              final ult = _ultimoComentario;
              if (ult != null &&
                  DateTime.now().difference(ult).inSeconds < 60) {
                setS(() => error = 'Espera un minuto antes de enviar otro.');
                return;
              }
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid == null) {
                setS(() => error = 'No hay sesión iniciada.');
                return;
              }
              setS(() {
                enviando = true;
                error = null;
              });
              try {
                await FirebaseFirestore.instance
                    .collection('comentarios')
                    .add({
                  'uid': uid,
                  'nombre': juego.nombre,
                  'nivel': juego.nivel,
                  'version': versionJuego,
                  'tipo': tipo,
                  'texto': t,
                  'ts': FieldValue.serverTimestamp(),
                }).timeout(const Duration(seconds: 15));
                _ultimoComentario = DateTime.now();
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('¡Gracias! Recibimos tu comentario.')));
                }
              } catch (_) {
                setS(() {
                  enviando = false;
                  error = 'No se pudo enviar. Revisa tu conexión.';
                });
              }
            },
            child: Text(enviando ? 'Enviando...' : 'Enviar'),
          ),
        ],
      ),
    ),
  );
  texto.dispose();
}

// Diálogo para eliminar la cuenta: explica qué se borra y pide la contraseña.
Future<void> mostrarEliminarCuenta(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _DialogoEliminarCuenta(),
  );
}

class _DialogoEliminarCuenta extends StatefulWidget {
  const _DialogoEliminarCuenta();

  @override
  State<_DialogoEliminarCuenta> createState() => _DialogoEliminarCuentaState();
}

class _DialogoEliminarCuentaState extends State<_DialogoEliminarCuenta> {
  final TextEditingController _pass = TextEditingController();
  bool _verPass = false;
  bool _borrando = false;
  bool _entendido = false;
  String? _error;

  @override
  void dispose() {
    _pass.dispose();
    super.dispose();
  }

  Future<void> _borrar() async {
    if (_pass.text.isEmpty) {
      setState(() => _error = 'Escribe tu contraseña para confirmar.');
      return;
    }
    setState(() {
      _borrando = true;
      _error = null;
    });
    final r = await Nube.eliminarCuenta(_pass.text);
    if (!mounted) return;
    if (r == null) {
      // Cuenta borrada: el juego vuelve solo a la pantalla de inicio de sesión.
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _borrando = false;
      _error = r;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Eliminar cuenta'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Se borrarán para siempre tu cuenta y todos tus datos: tu '
                    'personaje, tu progreso, tus esquirlas y tu oro, tu perfil en '
                    'la Arena y el ranking, tus amigos, tus chats y tus mensajes '
                    'del chat global.',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            const Text(
                'Las compras hechas con dinero real no se reembolsan al borrar '
                    'la cuenta. Esto no se puede deshacer.',
                style: TextStyle(fontSize: 12, color: Colors.orangeAccent)),
            const SizedBox(height: 12),
            TextField(
              controller: _pass,
              obscureText: !_verPass,
              enabled: !_borrando,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Tu contraseña',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_verPass ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _verPass = !_verPass),
                ),
              ),
            ),
            CheckboxListTile(
              value: _entendido,
              onChanged:
              _borrando ? null : (v) => setState(() => _entendido = v ?? false),
              title: const Text('Entiendo que no se puede deshacer',
                  style: TextStyle(fontSize: 13)),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_error!,
                    style:
                    const TextStyle(color: Colors.redAccent, fontSize: 13)),
              ),
            if (_borrando)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: _borrando ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancelar')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800),
          onPressed: (_borrando || !_entendido) ? null : _borrar,
          child: const Text('Eliminar para siempre'),
        ),
      ],
    );
  }
}

// ---------- Guía de primeros pasos (tarjeta en el perfil) ----------
// Se muestra a los jugadores nuevos hasta que hacen las 6 cosas básicas, o
// hasta que la cierran con la X.

class _PasoGuia {
  final IconData icono;
  final String texto;
  final String donde;
  final bool Function() hecho;
  final int grupo;
  final int sub;
  const _PasoGuia(
      this.icono, this.texto, this.donde, this.hecho, this.grupo, this.sub);
}

// Función que pone MenuPrincipal para cambiar de pestaña desde cualquier lugar.
void Function(int grupo, int sub)? irAPestana;

final List<_PasoGuia> _pasosGuia = [
  _PasoGuia(Icons.fitness_center, 'Entrena un atributo con tu oro',
      'Inicio › Entrenar', () => juego.logros.stats['entrenados'] > 0, 0, 2),
  _PasoGuia(Icons.store, 'Compra un objeto en la tienda', 'Comercio › Tienda',
          () => juego.logros.stats['comprados'] > 0, 3, 0),
  _PasoGuia(Icons.backpack, 'Equípate con lo que compraste', 'Inicio › Equipo',
          () => juego.equipado.values.any((o) => o != null), 0, 1),
  _PasoGuia(Icons.gavel, 'Gana tu primer combate', 'Combate › Cripta',
          () => juego.logros.stats['victorias'] > 0, 1, 1),
  _PasoGuia(Icons.map, 'Completa una misión', 'Misiones › Misiones',
          () => juego.logros.stats['misiones'] > 0, 2, 0),
  _PasoGuia(Icons.emoji_events, 'Pelea contra otro jugador', 'Combate › Arena',
          () => juego.logros.stats['pvpPeleas'] > 0, 1, 0),
];

class GuiaInicial extends StatefulWidget {
  const GuiaInicial({super.key});

  @override
  State<GuiaInicial> createState() => _GuiaInicialState();
}

class _GuiaInicialState extends State<GuiaInicial> {
  bool _oculta = false;

  @override
  Widget build(BuildContext context) {
    if (_oculta) return const SizedBox.shrink();
    final hechos = _pasosGuia.where((p) => p.hecho()).length;
    if (hechos >= _pasosGuia.length) return const SizedBox.shrink();
    // Primer paso pendiente: se resalta con un botón "Ir"
    final siguiente = _pasosGuia.indexWhere((p) => !p.hecho());
    return Card(
      color: const Color(0xFF2A1218),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFFFC83D), width: 1),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.flag, color: Color(0xFFFFC83D), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Primeros pasos ($hechos/${_pasosGuia.length})',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                tooltip: 'Ocultar',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _oculta = true),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 6),
              child: LinearProgressIndicator(
                  value: hechos / _pasosGuia.length, minHeight: 5),
            ),
            for (int i = 0; i < _pasosGuia.length; i++)
              Builder(builder: (_) {
                final p = _pasosGuia[i];
                final hecho = p.hecho();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Icon(hecho ? Icons.check_circle : p.icono,
                        size: 18,
                        color: hecho ? Colors.greenAccent : Colors.white70),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.texto,
                              style: TextStyle(
                                  fontSize: 13,
                                  decoration: hecho
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: hecho ? Colors.white38 : null)),
                          if (!hecho)
                            Text(p.donde,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.white54)),
                        ],
                      ),
                    ),
                    if (i == siguiente)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 30),
                            padding: const EdgeInsets.symmetric(horizontal: 14)),
                        onPressed: () => irAPestana?.call(p.grupo, p.sub),
                        child: const Text('Ir'),
                      ),
                  ]),
                );
              }),
          ],
        ),
      ),
    );
  }
}