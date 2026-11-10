import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'arena.dart';
import 'idioma.dart';
import 'main.dart';

// ====================== CONFIGURACIÓN DEL RANKING ======================

// El ranking lee SOLO jugadores reales de la colección pública "perfiles" (la
// misma de la Arena). Es una sola pantalla con dos pestañas:
//  - PvP: tus combates contra otros jugadores en la Arena (la principal).
//  - Cripta y Ciudadela: tus combates contra enemigos.
// Cada pestaña muestra victorias, empates, derrotas, oro y daño, y se puede
// ordenar por victorias, daño u oro. Solo aparecen los jugadores que ya
// guardaron con esta versión (los perfiles viejos no tienen estos campos).
// Cada orden usa un solo campo, así que Firestore no pide índices compuestos.
const String rankingColeccion = 'perfiles';
const String rankingCampoNombre = 'nombre';
const String rankingCampoNivel = 'nivel';

const int rankingTamano = 10;

// Estadísticas de un jugador en un modo de combate
class Estad {
  final int v; // victorias
  final int e; // empates
  final int d; // derrotas
  final int oroG; // oro ganado
  final int oroP; // oro perdido
  final int dano; // daño infligido
  const Estad(this.v, this.e, this.d, this.oroG, this.oroP, this.dano);
}

enum OrdenRanking { victorias, dano, oro }

class ModoRanking {
  final String pestana;
  final bool pierdeOro; // la Arena quita oro al perder; la Cripta no
  // Campos del perfil en Firestore
  final String cV, cE, cD, cOroG, cOroP, cDano;
  final Estad Function() tuyas; // tus números actuales
  const ModoRanking(this.pestana, this.pierdeOro, this.cV, this.cE, this.cD,
      this.cOroG, this.cOroP, this.cDano, this.tuyas);

  String campo(OrdenRanking o) {
    if (o == OrdenRanking.dano) return cDano;
    if (o == OrdenRanking.oro) return cOroG;
    return cV;
  }

  int valor(Estad s, OrdenRanking o) {
    if (o == OrdenRanking.dano) return s.dano;
    if (o == OrdenRanking.oro) return s.oroG;
    return s.v;
  }
}

// El orden de esta lista es el orden de las pestañas: la primera es la principal.
final List<ModoRanking> modosRanking = [
  ModoRanking(
      'PvP',
      true,
      'rkPvpV',
      'rkPvpE',
      'rkPvpD',
      'rkPvpOroG',
      'rkPvpOroP',
      'rkPvpDano',
          () => Estad(datosPvp.victorias, datosPvp.pvpEmpates, datosPvp.derrotas,
          datosPvp.pvpOroGanado, datosPvp.pvpOroPerdido, datosPvp.pvpDano)),
  ModoRanking(
      'Cripta y Ciudadela',
      false,
      'rkPveV',
      'rkPveE',
      'rkPveD',
      'rkPveOroG',
      '',
      'rkPveDano',
          () => Estad(datosPvp.pveVictorias, datosPvp.pveEmpates,
          datosPvp.pveDerrotas, datosPvp.pveOroGanado, 0, datosPvp.pveDano)),
];

// ====================== DATOS ======================

class EntradaRanking {
  final String nombre;
  final int nivel;
  final Estad s;
  final bool esTuyo;
  const EntradaRanking(this.nombre, this.nivel, this.s, {this.esTuyo = false});
}

class DatosRanking {
  final List<EntradaRanking> top; // los primeros [rankingTamano]
  final EntradaRanking tu;
  final int tuPosicion;
  const DatosRanking(this.top, this.tu, this.tuPosicion);
}

Future<DatosRanking> cargarRanking(ModoRanking modo, OrdenRanking orden) async {
  final miUid = FirebaseAuth.instance.currentUser?.uid;
  final coleccion = FirebaseFirestore.instance.collection(rankingColeccion);
  final mis = modo.tuyas();
  final miValor = modo.valor(mis, orden);
  final tu = EntradaRanking(juego.nombre, juego.nivel, mis, esTuyo: true);
  final campo = modo.campo(orden);

  final consulta = await coleccion
      .where(campo, isGreaterThan: 0)
      .orderBy(campo, descending: true)
      .limit(rankingTamano)
      .get();

  final top = consulta.docs.map((d) {
    final m = d.data();
    int g(String c) => c.isEmpty ? 0 : (m[c] as num?)?.toInt() ?? 0;
    return EntradaRanking(
      (m[rankingCampoNombre] ?? '?').toString(),
      (m[rankingCampoNivel] as num?)?.toInt() ?? 1,
      Estad(g(modo.cV), g(modo.cE), g(modo.cD), g(modo.cOroG), g(modo.cOroP),
          g(modo.cDano)),
      esTuyo: d.id == miUid,
    );
  }).toList()
    ..sort((a, b) {
      final x = modo.valor(b.s, orden).compareTo(modo.valor(a.s, orden));
      return x != 0 ? x : a.s.d.compareTo(b.s.d); // empate: menos derrotas
    });

  int posicion = top.indexWhere((e) => e.esTuyo) + 1;
  if (posicion == 0 && miValor > 0) {
    // Fuera del top: cuenta cuántos jugadores tienen más que tú.
    try {
      final mejores =
      await coleccion.where(campo, isGreaterThan: miValor).count().get();
      posicion = (mejores.count ?? 0) + 1;
    } catch (_) {
      posicion = 0; // se muestra como "—"
    }
  }
  return DatosRanking(top, tu, posicion);
}

// 12345 -> 12.345
String _fmt(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return n < 0 ? '-$b' : b.toString();
}

// ====================== PANTALLA ======================

const Color _oro = Color(0xFFD4A843);
const Color _plata = Color(0xFFB8BCC4);
const Color _bronce = Color(0xFFB87333);
const Color _crema = Color(0xFFE8D5A8);
const Color _rojoOscuro = Color(0xFF5A0F1B);
const Color _panel = Color(0xFF14090D);
const Color _borde = Color(0xFF6B5A3A);

// Anchos fijos de las columnas, compartidos por el encabezado, las filas y
// la barra "Tu posición", para que todo quede alineado.
const double _anchoPos = 44;
const double _anchoAvatar = 34;
const double _anchoNivel = 50;
const double _anchoValor = 88;

class PantallaRanking extends StatefulWidget {
  const PantallaRanking({super.key});

  @override
  State<PantallaRanking> createState() => _PantallaRankingState();
}

class _PantallaRankingState extends State<PantallaRanking> {
  int _tab = 0; // 0 = PvP (la principal)
  OrdenRanking _orden = OrdenRanking.victorias;
  ModoRanking get _modo => modosRanking[_tab];
  late Future<DatosRanking> _futuro = cargarRanking(_modo, _orden);

  void _actualizar() =>
      setState(() => _futuro = cargarRanking(_modo, _orden));

  void _cambiarTab(int t) => setState(() {
    _tab = t;
    _futuro = cargarRanking(_modo, _orden);
  });

  void _cambiarOrden(OrdenRanking o) => setState(() {
    _orden = o;
    _futuro = cargarRanking(_modo, _orden);
  });

  Color _colorPodio(int pos) =>
      pos == 1 ? _oro : (pos == 2 ? _plata : _bronce);

  String get _tituloValor => _orden == OrdenRanking.dano
      ? 'DAÑO'
      : (_orden == OrdenRanking.oro ? 'ORO' : 'VICTORIAS');

  IconData get _iconoValor => _orden == OrdenRanking.dano
      ? Icons.flash_on
      : (_orden == OrdenRanking.oro
      ? Icons.monetization_on
      : Icons.emoji_events);

  // Escudo con un texto en el centro (posición o nivel)
  Widget _escudo(String texto, double tamano, Color borde, Color relleno,
      {Color colorTexto = Colors.white}) {
    return SizedBox(
      width: tamano,
      height: tamano,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.shield, size: tamano, color: borde),
          Icon(Icons.shield, size: tamano * 0.82, color: relleno),
          Padding(
            padding: EdgeInsets.only(bottom: tamano * 0.04),
            child: Text(texto,
                style: TextStyle(
                    fontSize: tamano * 0.34,
                    fontWeight: FontWeight.bold,
                    color: colorTexto)),
          ),
        ],
      ),
    );
  }

  Widget _cabecera() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 4),
      child: Row(
        children: [
          const SizedBox(width: 40),
          Expanded(
            child: Text(tr('RANKING'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    color: _crema)),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              tooltip: tr('Actualizar'),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.refresh, color: _crema),
              onPressed: _actualizar,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pestana(String texto, bool activa, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: activa ? _rojoOscuro : const Color(0xFF241A1D),
            border: Border.all(color: activa ? _oro : _borde),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(tr(texto),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: activa ? _crema : Colors.white54)),
        ),
      ),
    );
  }

  Widget _pestanas() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        children: [
          for (int i = 0; i < modosRanking.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            _pestana(modosRanking[i].pestana, _tab == i, () => _cambiarTab(i)),
          ],
        ],
      ),
    );
  }

  // Chips pequeños para ordenar por victorias, daño u oro
  Widget _chipOrden(String texto, OrdenRanking o) {
    final activa = _orden == o;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: GestureDetector(
        onTap: () => _cambiarOrden(o),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: activa ? _rojoOscuro : const Color(0xFF241A1D),
            border: Border.all(color: activa ? _oro : _borde),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(tr(texto),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: activa ? _crema : Colors.white54)),
        ),
      ),
    );
  }

  Widget _filtrosOrden() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(tr('Ordenar por:'),
              style: const TextStyle(fontSize: 11, color: Colors.white54)),
          _chipOrden('Victorias', OrdenRanking.victorias),
          _chipOrden('Daño', OrdenRanking.dano),
          _chipOrden('Oro', OrdenRanking.oro),
        ],
      ),
    );
  }

  // ---------- Textos de las estadísticas ----------

  String _lineaResultados(Estad s) =>
      '${tr('Vict.')} ${_fmt(s.v)}  ·  ${tr('Emp.')} ${_fmt(s.e)}  ·  ${tr('Der.')} ${_fmt(s.d)}';

  String _lineaOro(Estad s) {
    final oro = _modo.pierdeOro
        ? '${tr('Oro')} +${_fmt(s.oroG)} / -${_fmt(s.oroP)}'
        : '${tr('Oro')} +${_fmt(s.oroG)}';
    return '$oro  ·  ${tr('Daño')} ${_fmt(s.dano)}';
  }

  // ---------- Podio (1.º centro, 2.º izquierda, 3.º derecha) ----------

  Widget _puesto(EntradaRanking? e, int pos) {
    final grande = pos == 1;
    final color = _colorPodio(pos);
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (grande)
            const Icon(Icons.workspace_premium, color: _oro, size: 30)
          else
            const SizedBox(height: 30),
          _escudo('$pos', grande ? 96 : 78, color,
              grande ? _rojoOscuro : const Color(0xFF1E1A1C),
              colorTexto: grande ? Colors.white : color),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              border: Border.all(color: color.withAlpha(160)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: e == null
                ? const Text('-',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38))
                : Column(
              children: [
                Text(e.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: e.esTuyo ? Colors.amber : Colors.white)),
                Text('${tr('Nv')} ${e.nivel}',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white70)),
                Text(_fmt(_modo.valor(e.s, _orden)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _crema)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _podio(List<EntradaRanking> top) {
    EntradaRanking? en(int i) => i < top.length ? top[i] : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _puesto(en(1), 2),
          _puesto(en(0), 1),
          _puesto(en(2), 3),
        ],
      ),
    );
  }

  // ---------- Tabla ----------

  Widget _titulosTabla() {
    const estilo = TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
        color: _crema);
    return Container(
      height: 34,
      color: _rojoOscuro,
      child: Row(
        children: [
          SizedBox(
              width: _anchoPos,
              child: Text(tr('POS.'),
                  textAlign: TextAlign.center, style: estilo)),
          const SizedBox(width: _anchoAvatar),
          Expanded(
              child: Text(tr('JUGADOR'),
                  textAlign: TextAlign.center, style: estilo)),
          SizedBox(
              width: _anchoNivel,
              child: Text(tr('NIVEL'),
                  textAlign: TextAlign.center, style: estilo)),
          SizedBox(
              width: _anchoValor,
              child: Text(tr(_tituloValor),
                  textAlign: TextAlign.center, style: estilo)),
        ],
      ),
    );
  }

  Widget _valor(int valor) {
    return SizedBox(
      width: _anchoValor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_iconoValor, size: 14, color: _oro),
          const SizedBox(width: 4),
          Flexible(
            child: Text(_fmt(valor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _fila(int pos, EntradaRanking e) {
    final color = e.esTuyo ? Colors.amber : Colors.white;
    return Container(
      height: 66,
      decoration: BoxDecoration(
        color: e.esTuyo
            ? const Color(0x553A1A22)
            : (pos.isEven ? const Color(0x33000000) : const Color(0x55000000)),
        border: const Border(bottom: BorderSide(color: Color(0xFF2E2024))),
      ),
      child: Row(
        children: [
          SizedBox(
              width: _anchoPos,
              child: Text('$pos',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70))),
          SizedBox(
            width: _anchoAvatar,
            child: Icon(Icons.shield_moon,
                color: pos.isEven ? _oro : _plata, size: 24),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(height: 2),
                  Text(_lineaResultados(e.s),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10.5, color: Colors.white70)),
                  Text(_lineaOro(e.s),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10.5, color: Colors.white54)),
                ],
              ),
            ),
          ),
          SizedBox(
            width: _anchoNivel,
            child: Center(
              child:
              _escudo('${e.nivel}', 32, _plata, const Color(0xFF1A1014)),
            ),
          ),
          _valor(_modo.valor(e.s, _orden)),
        ],
      ),
    );
  }

  Widget _tuPosicion(DatosRanking d) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF1B0D12),
        border: Border(top: BorderSide(color: _borde)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 10),
              const Icon(Icons.shield_moon, color: _oro, size: 34),
              const SizedBox(width: 8),
              Text(tr('TU POSICIÓN'),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: _crema)),
              const SizedBox(width: 8),
              Text(d.tuPosicion > 0 ? '#${d.tuPosicion}' : '—',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(d.tu.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center),
                ),
              ),
              _escudo('${d.tu.nivel}', 34, _oro, _rojoOscuro),
              const SizedBox(width: 8),
              Icon(_iconoValor, size: 14, color: _oro),
              const SizedBox(width: 4),
              Text(_fmt(_modo.valor(d.tu.s, _orden)),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
            ],
          ),
          const SizedBox(height: 4),
          Text(_lineaResultados(d.tu.s),
              style: const TextStyle(fontSize: 11, color: Colors.white70)),
          Text(_lineaOro(d.tu.s),
              style: const TextStyle(fontSize: 11, color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _contenidoGlobal() {
    return FutureBuilder<DatosRanking>(
      future: _futuro,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(60),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError || snap.data == null) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(tr('No se pudo cargar el ranking.'),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                TextButton(
                    onPressed: _actualizar, child: Text(tr('Reintentar'))),
              ],
            ),
          );
        }
        final d = snap.data!;
        return Column(
          children: [
            _podio(d.top),
            _titulosTabla(),
            for (int i = 3; i < rankingTamano; i++)
              if (i < d.top.length)
                _fila(i + 1, d.top[i])
              else
                _filaVacia(i + 1),
            _tuPosicion(d),
          ],
        );
      },
    );
  }

  Widget _filaVacia(int pos) {
    return Container(
      height: 52,
      decoration: const BoxDecoration(
        color: Color(0x33000000),
        border: Border(bottom: BorderSide(color: Color(0xFF2E2024))),
      ),
      alignment: Alignment.centerLeft,
      child: SizedBox(
          width: _anchoPos,
          child: Text('$pos',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white24, fontSize: 16))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        Container(
          decoration: BoxDecoration(
            color: _panel.withAlpha(235),
            border: Border.all(color: _borde, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _cabecera(),
              _pestanas(),
              _filtrosOrden(),
              _contenidoGlobal(),
            ],
          ),
        ),
      ],
    );
  }
}