import 'dart:async';
import 'package:flutter/material.dart';
import 'boton_oscuro.dart';
import 'main.dart';

// Una ofrenda del altar: cuesta oro y recupera una parte de la vida máxima.
class Ofrenda {
  final String nombre;
  final String descripcion;
  final int costo;
  final double porcentaje; // 0.10 = 10% de la vida máxima
  final ColorBoton color;
  const Ofrenda(
      this.nombre, this.descripcion, this.costo, this.porcentaje, this.color);
}

// Para cambiar precios o curación del altar, toca solo esta lista.
// Precios: 10% = 20 de oro, 50% = 60 de oro, 100% = 100 de oro.
// Cuanta más vida recuperas de una vez, más barato sale cada punto.
const List<Ofrenda> ofrendasAltar = [
  Ofrenda('Ofrenda pobre', 'Una plegaria humilde. Recupera el 10% de tu vida.',
      20, 0.10, ColorBoton.morado),
  Ofrenda('Ofrenda decente',
      'Los dioses te escuchan con atención. Recupera el 50% de tu vida.', 60,
      0.50, ColorBoton.azul),
  Ofrenda('Ofrenda generosa',
      'Los dioses quedan complacidos. Recupera el 100% de tu vida.', 100, 1.0,
      ColorBoton.verde),
];

class PantallaAltar extends StatefulWidget {
  const PantallaAltar({super.key});

  @override
  State<PantallaAltar> createState() => _PantallaAltarState();
}

class _PantallaAltarState extends State<PantallaAltar> {
  Timer? _reloj;
  String? _mensaje;

  @override
  void initState() {
    super.initState();
    // Refresca la pantalla para ver cómo se recupera la vida sola
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  // Devuelve el mensaje de lo que pasó
  String _ofrecer(Ofrenda o) {
    final vida = juego.vida;
    final maxima = juego.vidaMaxima;
    if (vida >= maxima) {
      return 'Tu vida ya está completa. Los dioses no necesitan tu ofrenda.';
    }
    if (juego.oro < o.costo) {
      return 'No te alcanza el oro (${o.costo} necesarios).';
    }
    final cura = (maxima * o.porcentaje).round();
    final nueva = (vida + cura).clamp(0, maxima);
    final recuperada = nueva - vida;
    juego.oro -= o.costo;
    juego.fijarVida(nueva);
    juego.avisarCambio();
    return 'Hiciste una ${o.nombre.toLowerCase()} de ${o.costo} de oro y '
        'recuperaste $recuperada de vida.';
  }

  @override
  Widget build(BuildContext context) {
    final vida = juego.vida;
    final maxima = juego.vidaMaxima;
    final hijos = <Widget>[
      const Padding(
        padding: EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: Text('Altar de los dioses',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Text(
          'Deja una ofrenda en el altar y los dioses curarán tus heridas.',
          style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
        ),
      ),
      Card(
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
                  value: (vida / maxima).clamp(0.0, 1.0),
                  minHeight: 12,
                  color: Colors.green,
                  backgroundColor: const Color(0xFF3A2A30),
                ),
              ),
              const SizedBox(height: 8),
              Text('Tu oro: ${juego.oro}',
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    ];

    if (_mensaje != null) {
      hijos.add(Card(
        color: const Color(0xFF3A1A22),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(_mensaje!),
        ),
      ));
    }

    hijos.add(const SizedBox(height: 8));
    for (final o in ofrendasAltar) {
      hijos.add(Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(o.nombre,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(o.descripcion, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 10),
              BotonOscuro(
                texto: 'Ofrecer ${o.costo} oro',
                alto: 44,
                color: o.color,
                onPressed: juego.oro >= o.costo && vida < maxima
                    ? () => setState(() => _mensaje = _ofrecer(o))
                    : null,
              ),
            ],
          ),
        ),
      ));
    }

    return ListView(padding: const EdgeInsets.all(12), children: hijos);
  }
}