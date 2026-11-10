import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'boton_oscuro.dart';
import 'legal.dart';
import 'main.dart';
import 'nube.dart';

// ====================== PUERTA DE ENTRADA ======================
// Decide qué se ve al abrir el juego:
//  - sin sesión            -> pantalla de correo y contraseña
//  - con sesión            -> carga tu partida
//  - partida cargada       -> creación de personaje (cuenta nueva) o el juego

class PuertaDeEntrada extends StatelessWidget {
  const PuertaDeEntrada({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final user = snap.data;
        if (user == null) return const PantallaAuth();
        return _CargadorPartida(key: ValueKey(user.uid));
      },
    );
  }
}

class _CargadorPartida extends StatefulWidget {
  const _CargadorPartida({super.key});

  @override
  State<_CargadorPartida> createState() => _CargadorPartidaState();
}

class _CargadorPartidaState extends State<_CargadorPartida> {
  late Future<void> _futuro = Nube.cargarPartida();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _futuro,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cargando tu partida...'),
                ],
              ),
            ),
          );
        }
        if (snap.hasError) {
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.cloud_off, size: 56),
                    const SizedBox(height: 16),
                    const Text(
                      'No se pudo cargar tu partida.',
                      textAlign: TextAlign.center,
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Revisa tu conexión a internet e inténtalo de nuevo. '
                          'Tu progreso no se ha perdido.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text('${snap.error}',
                        textAlign: TextAlign.center,
                        style:
                        const TextStyle(fontSize: 11, color: Colors.white38)),
                    const SizedBox(height: 24),
                    BotonOscuro(
                      texto: 'Reintentar',
                      alto: 50,
                      color: ColorBoton.rojo,
                      onPressed: () =>
                          setState(() => _futuro = Nube.cargarPartida()),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      child: const Text('Usar otra cuenta'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        // Partida cargada: personaje nuevo o juego
        return ListenableBuilder(
          listenable: juego,
          builder: (context, _) => juego.personajeCreado
              ? const MenuPrincipal()
              : const PantallaCreacionPersonaje(),
        );
      },
    );
  }
}

// ====================== LOGIN / REGISTRO ======================

class PantallaAuth extends StatefulWidget {
  const PantallaAuth({super.key});

  @override
  State<PantallaAuth> createState() => _PantallaAuthState();
}

class _PantallaAuthState extends State<PantallaAuth> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _pass = TextEditingController();
  final TextEditingController _pass2 = TextEditingController();
  bool _registro = false;
  bool _cargando = false;
  bool _verPass = false;
  bool _recordar = true; // recordar el correo en este teléfono
  bool _acepto = false; // acepta la política y las reglas (solo al registrarse)
  String? _error;
  String? _info;

  static const String _claveCorreo = 'correo_recordado';

  @override
  void initState() {
    super.initState();
    _cargarCorreo();
  }

  // Si la última vez marcaste "Recordar mi correo", lo vuelve a poner.
  Future<void> _cargarCorreo() async {
    try {
      final p = await SharedPreferences.getInstance();
      final guardado = p.getString(_claveCorreo);
      if (!mounted) return;
      if (guardado != null && guardado.isNotEmpty) {
        setState(() {
          _email.text = guardado;
          _recordar = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _guardarCorreo(String email) async {
    try {
      final p = await SharedPreferences.getInstance();
      if (_recordar) {
        await p.setString(_claveCorreo, email);
      } else {
        await p.remove(_claveCorreo);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _pass2.dispose();
    super.dispose();
  }

  String _traducir(String codigo) {
    switch (codigo) {
      case 'invalid-email':
        return 'El correo no es válido.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos.';
      case 'email-already-in-use':
        return 'Ese correo ya tiene una cuenta. Prueba a iniciar sesión.';
      case 'weak-password':
        return 'La contraseña es muy débil. Usa al menos 6 caracteres.';
      case 'user-disabled':
        return 'Esta cuenta está desactivada.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera un momento e inténtalo otra vez.';
      case 'network-request-failed':
        return 'Sin conexión. Revisa tu internet.';
      case 'operation-not-allowed':
        return 'El inicio con correo no está activado en Firebase '
            '(Authentication > Sign-in method > Correo electrónico).';
      default:
        return 'No se pudo completar ($codigo).';
    }
  }

  Future<void> _enviar() async {
    final email = _email.text.trim();
    final pass = _pass.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() {
        _error = 'Escribe tu correo y tu contraseña.';
        _info = null;
      });
      return;
    }
    if (_registro && !_acepto) {
      setState(() {
        _error = 'Para crear la cuenta acepta la política de privacidad y las reglas.';
        _info = null;
      });
      return;
    }
    if (_registro && pass != _pass2.text) {
      setState(() {
        _error = 'Las contraseñas no coinciden.';
        _info = null;
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _cargando = true;
      _error = null;
      _info = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      if (_registro) {
        await auth.createUserWithEmailAndPassword(
            email: email, password: pass);
      } else {
        await auth.signInWithEmailAndPassword(email: email, password: pass);
      }
      // Entró bien: guarda el correo y avisa al teléfono para que ofrezca
      // guardar la contraseña (Google / el administrador de contraseñas).
      await _guardarCorreo(email);
      TextInput.finishAutofillContext(shouldSave: true);
      // Al entrar, PuertaDeEntrada cambia sola de pantalla.
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _traducir(e.code));
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'No se pudo conectar. Revisa tu internet.');
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _olvide() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() {
        _error = 'Escribe tu correo arriba y vuelve a pulsar esta opción.';
        _info = null;
      });
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        setState(() {
          _error = null;
          _info = 'Te enviamos un correo para cambiar tu contraseña. '
              'Revisa también la carpeta de spam.';
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = _traducir(e.code);
          _info = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                    Text(
                      _registro ? 'Crea tu cuenta' : 'Inicia sesión',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.username, AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Correo',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _pass,
                      obscureText: !_verPass,
                      autocorrect: false,
                      autofillHints: [
                        _registro
                            ? AutofillHints.newPassword
                            : AutofillHints.password
                      ],
                      onSubmitted: (_) => _registro ? null : _enviar(),
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                              _verPass ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _verPass = !_verPass),
                        ),
                      ),
                    ),
                    if (_registro) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: _pass2,
                        obscureText: !_verPass,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.newPassword],
                        onSubmitted: (_) => _enviar(),
                        decoration: const InputDecoration(
                          labelText: 'Repite la contraseña',
                          prefixIcon: Icon(Icons.lock_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text('Mínimo 6 caracteres.',
                            style:
                            TextStyle(fontSize: 12, color: Colors.white54)),
                      ),
                    ],
                    if (_registro)
                      CheckboxListTile(
                        value: _acepto,
                        onChanged: _cargando
                            ? null
                            : (v) => setState(() => _acepto = v ?? false),
                        title: const Text(
                            'Acepto la política de privacidad y las reglas de la comunidad (chat sin insultos, acoso ni contenido ofensivo).',
                            style: TextStyle(fontSize: 12)),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    if (!_registro)
                      CheckboxListTile(
                        value: _recordar,
                        onChanged: _cargando
                            ? null
                            : (v) => setState(() => _recordar = v ?? false),
                        title: const Text('Recordar mi correo',
                            style: TextStyle(fontSize: 14)),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.redAccent, fontSize: 13)),
                      ),
                    if (_info != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_info!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.lightBlueAccent, fontSize: 13)),
                      ),
                    const SizedBox(height: 22),
                    _cargando
                        ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: CircularProgressIndicator(),
                      ),
                    )
                        : BotonOscuro(
                      texto: _registro ? 'Crear cuenta' : 'Entrar',
                      alto: 52,
                      color: ColorBoton.rojo,
                      onPressed: _enviar,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _cargando
                          ? null
                          : () => setState(() {
                        _registro = !_registro;
                        _error = null;
                        _info = null;
                      }),
                      child: Text(_registro
                          ? 'Ya tengo cuenta. Iniciar sesión'
                          : 'No tengo cuenta. Crear una'),
                    ),
                    if (!_registro)
                      TextButton(
                        onPressed: _cargando ? null : _olvide,
                        child: const Text('¿Olvidaste tu contraseña? Recupérala'),
                      ),
                    const SizedBox(height: 8),
                    const EnlacesLegales(conBorrar: true),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}