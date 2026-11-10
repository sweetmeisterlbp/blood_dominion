import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'boton_oscuro.dart';
import 'main.dart';

// ====================== DADOS DE LA TABERNA ======================
// Juego de dados estilo "Diez mil" (Farkle) contra un tahúr. Se juega SOLO con
// oro (nunca con gemas). Gana quien llegue primero a [metaDados] puntos.
//
// Economía (calibrada con una simulación de miles de partidas):
//  - Un jugador que decide con criterio gana entre el 49% y el 54% de las veces.
//  - Ganar paga [pagoDados] veces lo apostado (la apuesta incluida); perder
//    pierde la apuesta. Retorno esperado: ~90% (normal) a ~97% (muy hábil).
//  - Máximo [partidasDadosPorDia] partidas al día. La apuesta se descuenta al
//    empezar: si abandonas a mitad, la pierdes.
// No da fama ni puntos de bien/mal.

const int metaDados = 3000;
const double pagoDados = 1.8;
const int partidasDadosPorDia = 8;
const int umbralTahur = 350; // el tahúr se planta al llevar esto o más

const List<String> nombresTahur = [
  'Barto el Tahúr',
  'Madame Cuervo',
  'El Tuerto Garrick',
  'Sir Dadoloco',
  'Vieja Nelda',
];

// Apuestas que se ofrecen según tu nivel (escalan con lo que paga un combate).
List<int> apuestasDados(int nivel) {
  final base = 1 + 2 * nivel + 0.5 * nivel * nivel;
  int redondear(double x) {
    final v = max(10, x.round());
    return v >= 100 ? (v / 10).round() * 10 : (v / 5).round() * 5;
  }

  final lista = <int>{
    for (final m in const [0.5, 1.0, 2.0, 3.0, 5.0]) redondear(base * m)
  }.toList()
    ..sort();
  return lista;
}

// ---------- Reglas de puntuación ----------

class OpcionDados {
  final int mascara; // bits de los dados que se apartan
  final int puntos;
  final int cantidad;
  const OpcionDados(this.mascara, this.puntos, this.cantidad);
}

class ReglasDados {
  // Puntos de un grupo de dados donde TODOS deben puntuar. null = no vale.
  //  - 1 vale 100, 5 vale 50
  //  - tres iguales: 100 x número (tres 1 = 1000); cada dado extra duplica
  //  - escalera 1-2-3-4-5-6 = 1500; tres pares = 1000
  static int? puntos(List<int> dados) {
    if (dados.isEmpty) return null;
    final c = <int, int>{};
    for (final d in dados) {
      c[d] = (c[d] ?? 0) + 1;
    }
    if (dados.length == 6 && c.length == 6) return 1500;
    if (dados.length == 6 &&
        c.length == 3 &&
        c.values.every((k) => k == 2)) {
      return 1000;
    }
    int total = 0;
    for (final e in c.entries) {
      final f = e.key;
      final k = e.value;
      if (k >= 3) {
        final base = f == 1 ? 1000 : f * 100;
        total += base * (1 << (k - 3));
      } else if (f == 1) {
        total += 100 * k;
      } else if (f == 5) {
        total += 50 * k;
      } else {
        return null;
      }
    }
    return total;
  }

  // ¿Hay al menos un dado (o combinación) que puntúe en esta tirada?
  static bool hayPuntos(List<int> dados) {
    if (dados.contains(1) || dados.contains(5)) return true;
    final c = <int, int>{};
    for (final d in dados) {
      c[d] = (c[d] ?? 0) + 1;
    }
    if (c.values.any((k) => k >= 3)) return true;
    if (dados.length == 6 &&
        (c.length == 6 || (c.length == 3 && c.values.every((k) => k == 2)))) {
      return true;
    }
    return false;
  }

  // La mejor selección para el tahúr: la de más puntos (y, a igualdad, más dados).
  static OpcionDados? mejorOpcion(List<int> dados) {
    OpcionDados? mejor;
    final n = dados.length;
    for (int m = 1; m < (1 << n); m++) {
      final sel = <int>[
        for (int i = 0; i < n; i++)
          if ((m >> i) & 1 == 1) dados[i]
      ];
      final p = puntos(sel);
      if (p == null) continue;
      if (mejor == null ||
          p > mejor.puntos ||
          (p == mejor.puntos && sel.length > mejor.cantidad)) {
        mejor = OpcionDados(m, p, sel.length);
      }
    }
    return mejor;
  }
}

// ---------- Pantalla ----------

enum _Fase { apuesta, jugando, fin }

class PantallaDados extends StatefulWidget {
  const PantallaDados({super.key});

  @override
  State<PantallaDados> createState() => _PantallaDadosState();
}

class _PantallaDadosState extends State<PantallaDados> {
  final Random _azar = Random();
  _Fase _fase = _Fase.apuesta;
  int _idxApuesta = 1;
  int _apuesta = 0;
  String _rival = nombresTahur[0];
  int _totalJ = 0;
  int _totalT = 0;
  int _puntosTurno = 0;
  int _quedan = 6;
  bool _turnoJ = true;
  bool _tirado = false;
  bool _ocupado = false;
  bool _gano = false;
  int _premio = 0;
  List<int> _dados = [];
  List<bool> _sel = [];
  String _mensaje = '';

  static const _oro = Color(0xFFE6C16A);

  void _snack(String texto) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _pausa(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

  // ----- inicio -----

  void _empezar() {
    final apuestas = apuestasDados(juego.nivel);
    final a = apuestas[_idxApuesta.clamp(0, apuestas.length - 1)];
    final aviso = juego.empezarPartidaDados(a);
    if (aviso != null) {
      _snack(aviso);
      return;
    }
    final empiezo = _azar.nextBool();
    final rival = nombresTahur[_azar.nextInt(nombresTahur.length)];
    setState(() {
      _fase = _Fase.jugando;
      _apuesta = a;
      _rival = rival;
      _totalJ = 0;
      _totalT = 0;
      _puntosTurno = 0;
      _quedan = 6;
      _dados = [];
      _sel = [];
      _tirado = false;
      _ocupado = false;
      _turnoJ = empiezo;
      _mensaje = empiezo
          ? 'Empiezas tú. ¡Tira los dados!'
          : '$rival empieza la partida.';
    });
    if (!empiezo) _turnoTahur();
  }

  // ----- turno del jugador -----

  Future<void> _tirar() async {
    if (_ocupado || _tirado || !_turnoJ) return;
    final d = [for (int i = 0; i < _quedan; i++) _azar.nextInt(6) + 1];
    setState(() {
      _dados = d;
      _sel = List<bool>.filled(d.length, false);
      _tirado = true;
    });
    if (!ReglasDados.hayPuntos(d)) {
      setState(() {
        _ocupado = true;
        _mensaje = _puntosTurno > 0
            ? '¡Fracaso! Ningún dado puntúa: pierdes los $_puntosTurno puntos de este turno.'
            : '¡Fracaso! Ningún dado puntúa.';
      });
      await _pausa(1700);
      if (!mounted) return;
      setState(() {
        _puntosTurno = 0;
        _quedan = 6;
        _dados = [];
        _sel = [];
        _tirado = false;
        _ocupado = false;
      });
      _turnoTahur();
    } else {
      setState(() => _mensaje =
      'Toca los dados que puntúan y elige qué hacer.');
    }
  }

  void _alternar(int i) {
    if (!_tirado || _ocupado) return;
    setState(() => _sel[i] = !_sel[i]);
  }

  // Puntos de los dados seleccionados (null si no hay selección o no vale).
  int? get _ptsSel {
    final v = <int>[
      for (int i = 0; i < _dados.length; i++)
        if (_sel.length > i && _sel[i]) _dados[i]
    ];
    return ReglasDados.puntos(v);
  }

  int get _cantSel => _sel.where((s) => s).length;

  void _apartar({required bool plantarse}) {
    final pts = _ptsSel;
    if (pts == null || !_tirado || _ocupado) return;
    final puntos = _puntosTurno + pts;
    var quedan = _quedan - _cantSel;
    var caliente = false;
    if (quedan <= 0) {
      quedan = 6;
      caliente = true;
    }
    final llega = _totalJ + puntos >= metaDados;
    if (plantarse || llega) {
      setState(() {
        _totalJ += puntos;
        _puntosTurno = 0;
        _quedan = 6;
        _dados = [];
        _sel = [];
        _tirado = false;
      });
      if (_totalJ >= metaDados) {
        _terminar(true);
        return;
      }
      setState(() => _mensaje = 'Cobraste $puntos puntos.');
      _turnoTahur();
    } else {
      setState(() {
        _puntosTurno = puntos;
        _quedan = quedan;
        _dados = [];
        _sel = [];
        _tirado = false;
        _mensaje = caliente
            ? '¡Dados calientes! Llevas $puntos puntos y tiras los 6 dados otra vez.'
            : 'Llevas $puntos puntos en este turno. ¿Tiras de nuevo?';
      });
    }
  }

  // ----- turno del tahúr -----

  Future<void> _turnoTahur() async {
    setState(() {
      _ocupado = true;
      _turnoJ = false;
      _puntosTurno = 0;
      _quedan = 6;
      _dados = [];
      _sel = [];
      _tirado = false;
      _mensaje = 'Turno de $_rival...';
    });
    int pts = 0;
    int left = 6;
    while (true) {
      await _pausa(1000);
      if (!mounted) return;
      final d = [for (int i = 0; i < left; i++) _azar.nextInt(6) + 1];
      setState(() {
        _dados = d;
        _sel = List<bool>.filled(d.length, false);
        _mensaje = '$_rival tira $left dados...';
      });
      await _pausa(900);
      if (!mounted) return;
      if (!ReglasDados.hayPuntos(d)) {
        setState(() => _mensaje = pts > 0
            ? '¡$_rival falla y pierde $pts puntos!'
            : '¡$_rival falla!');
        await _pausa(1500);
        if (!mounted) return;
        pts = 0;
        break;
      }
      final op = ReglasDados.mejorOpcion(d)!;
      pts += op.puntos;
      left -= op.cantidad;
      if (left <= 0) left = 6;
      setState(() {
        _sel = [for (int i = 0; i < d.length; i++) (op.mascara >> i) & 1 == 1];
        _puntosTurno = pts;
      });
      await _pausa(1100);
      if (!mounted) return;
      if (_totalT + pts >= metaDados ||
          (pts >= umbralTahur && left <= 4) ||
          pts >= (umbralTahur * 1.6).round()) {
        break;
      }
    }
    setState(() {
      _totalT += pts;
      _puntosTurno = 0;
      _quedan = 6;
      _dados = [];
      _sel = [];
    });
    if (_totalT >= metaDados) {
      _terminar(false);
      return;
    }
    setState(() {
      _ocupado = false;
      _turnoJ = true;
      _mensaje = pts > 0
          ? '$_rival cobra $pts puntos. Te toca.'
          : '$_rival no suma nada. Te toca.';
    });
  }

  // ----- final -----

  void _terminar(bool gano) {
    final premio = gano ? juego.cobrarDados(_apuesta) : 0;
    setState(() {
      _fase = _Fase.fin;
      _gano = gano;
      _premio = premio;
      _ocupado = false;
    });
  }

  void _otraVez() => setState(() => _fase = _Fase.apuesta);

  void _reglas() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cómo se juega'),
        content: const SingleChildScrollView(
          child: Text(
            'Gana quien llegue primero a $metaDados puntos.\n\n'
                'En tu turno tiras los dados y APARTAS los que puntúan. Después '
                'decides: tirar de nuevo con los que quedan o plantarte y cobrar los '
                'puntos del turno. Si en una tirada ningún dado puntúa, pierdes todos '
                'los puntos de ese turno.\n\n'
                'Puntúan:\n'
                '- Cada 1 = 100 puntos\n'
                '- Cada 5 = 50 puntos\n'
                '- Tres iguales = 100 x el número (tres 1 = 1000)\n'
                '- Cuatro, cinco o seis iguales: duplican cada vez\n'
                '- Escalera 1-2-3-4-5-6 = 1500\n'
                '- Tres pares = 1000\n\n'
                'Si apartas los 6 dados, ¡dados calientes!: tiras los 6 otra vez.\n\n'
                'Si ganas cobras la apuesta x $pagoDados. Si pierdes, la apuesta se pierde. '
                'Si abandonas a mitad de partida, también la pierdes. Se juega solo con oro.',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
        ],
      ),
    );
  }

  // ----- dibujo -----

  Widget _marcador() {
    Widget lado(String nombre, int total, bool activo, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xCC120A0A),
            border: Border.all(color: activo ? _oro : Colors.white24, width: activo ? 2 : 1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(nombre,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text('$total',
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: (total / metaDados).clamp(0.0, 1.0),
                minHeight: 6,
                color: color,
                backgroundColor: Colors.white12,
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        lado('Tú', _totalJ, _turnoJ && _fase == _Fase.jugando, Colors.greenAccent),
        const SizedBox(width: 8),
        lado(_rival, _totalT, !_turnoJ && _fase == _Fase.jugando, Colors.redAccent),
      ],
    );
  }

  Widget _mesa() {
    final pts = _ptsSel;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xCC0E2A1C),
        border: Border.all(color: const Color(0xFF5B3A1E), width: 3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 58,
            child: _dados.isEmpty
                ? Center(
                child: Text(
                    _turnoJ && !_ocupado
                        ? '$_quedan dados por tirar'
                        : '',
                    style: const TextStyle(fontSize: 12, color: Colors.white70)))
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < _dados.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _Dado(
                      valor: _dados[i],
                      elegido: _sel.length > i && _sel[i],
                      onTap: (_turnoJ && _tirado && !_ocupado)
                          ? () => _alternar(i)
                          : null,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('Puntos del turno: $_puntosTurno'
              '${(_tirado && pts != null && _turnoJ) ? '  (+$pts)' : ''}',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: _oro)),
          const SizedBox(height: 6),
          Text(_mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _controles() {
    if (_ocupado || !_turnoJ) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Center(
            child: Text('Espera tu turno...',
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12))),
      );
    }
    if (!_tirado) {
      return BotonOscuro(
        texto: 'Tirar $_quedan dados',
        alto: 52,
        color: ColorBoton.rojo,
        onPressed: _tirar,
      );
    }
    final pts = _ptsSel;
    final valida = pts != null;
    final total = _puntosTurno + (pts ?? 0);
    return Column(
      children: [
        Text(
            _cantSel == 0
                ? 'Selecciona los dados que puntúan.'
                : valida
                ? 'Selección: +$pts puntos'
                : 'Esa selección no vale: todos los dados elegidos deben puntuar.',
            style: TextStyle(
                fontSize: 12,
                color: valida ? Colors.greenAccent : Colors.orangeAccent)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: BotonOscuro(
                texto: 'Apartar y tirar',
                alto: 48,
                color: ColorBoton.azul,
                onPressed: valida ? () => _apartar(plantarse: false) : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: BotonOscuro(
                texto: valida && _totalJ + total >= metaDados
                    ? '¡Ganar!'
                    : 'Plantarse (+$total)',
                alto: 48,
                color: ColorBoton.verde,
                onPressed: valida ? () => _apartar(plantarse: true) : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _vistaApuesta() {
    final apuestas = apuestasDados(juego.nivel);
    final idx = _idxApuesta.clamp(0, apuestas.length - 1);
    final a = apuestas[idx];
    final hoy = juego.dadosPartidasHoy;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('Dados de la taberna',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text(
            'Estilo "Diez mil": el primero en llegar a $metaDados puntos gana. Se juega solo con oro.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xCC120A0A),
            border: Border.all(color: Colors.white24),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text('Partidas de hoy: $hoy / $partidasDadosPorDia'),
              const SizedBox(height: 4),
              Text('Tu oro: ${juego.oro}',
                  style: const TextStyle(color: Colors.amber)),
              const SizedBox(height: 12),
              const Text('Elige tu apuesta',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (int i = 0; i < apuestas.length; i++)
                    ChoiceChip(
                      label: Text('${apuestas[i]}'),
                      selected: i == idx,
                      onSelected: (_) => setState(() => _idxApuesta = i),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text('Si ganas cobras ${(a * pagoDados).round()} de oro.',
                  style: const TextStyle(color: Colors.greenAccent)),
              const Text('Si pierdes, pierdes la apuesta.',
                  style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        BotonOscuro(
          texto: 'Jugar por $a de oro',
          alto: 56,
          color: ColorBoton.rojo,
          onPressed: (hoy >= partidasDadosPorDia || juego.oro < a) ? null : _empezar,
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(onPressed: _reglas, child: const Text('¿Cómo se juega?')),
        ),
      ],
    );
  }

  Widget _vistaJuego() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _marcador(),
        const SizedBox(height: 4),
        Center(
          child: Text(
              'Apuesta: $_apuesta  |  Si ganas: ${(_apuesta * pagoDados).round()}',
              style: const TextStyle(fontSize: 12, color: Colors.amber)),
        ),
        const SizedBox(height: 8),
        _mesa(),
        const SizedBox(height: 12),
        _controles(),
        Center(
          child: TextButton(onPressed: _reglas, child: const Text('¿Cómo se juega?')),
        ),
      ],
    );
  }

  Widget _vistaFin() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _marcador(),
        const SizedBox(height: 20),
        Center(
          child: Text(_gano ? 'GANASTE' : 'PERDISTE',
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: _gano ? Colors.greenAccent : Colors.redAccent)),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
              _gano
                  ? '+$_premio de oro (ganancia neta ${_premio - _apuesta})'
                  : '-$_apuesta de oro',
              style: TextStyle(
                  fontSize: 18, color: _gano ? Colors.amber : Colors.white70)),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
              _gano
                  ? '«Bien jugado, forastero. La suerte te sonrió.»'
                  : '«Los dados no mienten... ¿probamos otra?»',
              style: const TextStyle(fontStyle: FontStyle.italic, color: _oro)),
        ),
        const SizedBox(height: 20),
        BotonOscuro(
          texto: 'Jugar otra vez',
          alto: 52,
          color: ColorBoton.rojo,
          onPressed: _otraVez,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_fase) {
      case _Fase.apuesta:
        return _vistaApuesta();
      case _Fase.jugando:
        return _vistaJuego();
      case _Fase.fin:
        return _vistaFin();
    }
  }
}

// ---------- Dado dibujado con puntos ----------

class _Dado extends StatelessWidget {
  final int valor;
  final bool elegido;
  final VoidCallback? onTap;
  const _Dado({required this.valor, required this.elegido, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 46,
        height: 46,
        transform: Matrix4.translationValues(0, elegido ? -6 : 0, 0),
        decoration: BoxDecoration(
          color: const Color(0xFFEADFC8),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
              color: elegido ? const Color(0xFFE6C16A) : Colors.black87,
              width: elegido ? 3 : 1.5),
          boxShadow: [
            BoxShadow(
                color: elegido ? const Color(0x99E6C16A) : Colors.black54,
                blurRadius: elegido ? 10 : 4,
                offset: const Offset(0, 2)),
          ],
        ),
        child: CustomPaint(painter: _PuntosPainter(valor)),
      ),
    );
  }
}

class _PuntosPainter extends CustomPainter {
  final int valor;
  _PuntosPainter(this.valor);

  static const Map<int, List<Offset>> _pos = {
    1: [Offset(0.5, 0.5)],
    2: [Offset(0.27, 0.27), Offset(0.73, 0.73)],
    3: [Offset(0.27, 0.27), Offset(0.5, 0.5), Offset(0.73, 0.73)],
    4: [Offset(0.27, 0.27), Offset(0.73, 0.27), Offset(0.27, 0.73), Offset(0.73, 0.73)],
    5: [
      Offset(0.27, 0.27), Offset(0.73, 0.27), Offset(0.5, 0.5),
      Offset(0.27, 0.73), Offset(0.73, 0.73)
    ],
    6: [
      Offset(0.27, 0.22), Offset(0.73, 0.22), Offset(0.27, 0.5),
      Offset(0.73, 0.5), Offset(0.27, 0.78), Offset(0.73, 0.78)
    ],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = valor == 1 ? const Color(0xFF8B1A1A) : const Color(0xFF1B1B1B);
    final r = size.width * (valor == 1 ? 0.13 : 0.09);
    for (final o in _pos[valor] ?? const <Offset>[]) {
      canvas.drawCircle(Offset(o.dx * size.width, o.dy * size.height), r, p);
    }
  }

  @override
  bool shouldRepaint(covariant _PuntosPainter old) => old.valor != valor;
}