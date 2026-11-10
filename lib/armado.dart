import 'package:flutter/material.dart';
import 'boton_oscuro.dart';
import 'imagenes.dart';
import 'main.dart';

const Color _dorado = Color(0xFFB08D57);
const Color _doradoClaro = Color(0xFFF1E3C0);

// Pantalla para equipar al personaje. Es el ÚNICO lugar donde se equipa:
// al tocar una casilla se abre la lista de objetos del inventario que van ahí,
// ordenados de mayor a menor (nivel, luego valor, luego bonos).
class PantallaArmado extends StatefulWidget {
  const PantallaArmado({super.key});

  @override
  State<PantallaArmado> createState() => _PantallaArmadoState();
}

class _PantallaArmadoState extends State<PantallaArmado> {
  Ranura? _sel; // casilla elegida

  Ranura? _ranuraDe(bool Function(String) cumple, {int indice = 0}) {
    final lista = Ranura.values
        .where((r) => cumple(r.name.toLowerCase()))
        .toList();
    return indice < lista.length ? lista[indice] : null;
  }

  bool _esAnillo(Ranura r) => r.name.toLowerCase().contains('anillo');

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  int _sumaBonos(Objeto o) => o.bonos.values.fold<int>(0, (a, b) => a + b);

  // De mayor a menor: nivel, valor, bonos, precio.
  int _mayorAMenor(Objeto a, Objeto b) {
    final porNivel = b.nivelRequerido.compareTo(a.nivelRequerido);
    if (porNivel != 0) return porNivel;
    final porValor = b.valorMedio.compareTo(a.valorMedio);
    if (porValor != 0) return porValor;
    final porBonos = _sumaBonos(b).compareTo(_sumaBonos(a));
    if (porBonos != 0) return porBonos;
    final porPrecio = b.precio.compareTo(a.precio);
    if (porPrecio != 0) return porPrecio;
    final porNombre = a.nombre.compareTo(b.nombre);
    if (porNombre != 0) return porNombre;
    return b.afilado.compareTo(a.afilado);
  }

  // Objetos del inventario que van en esa casilla, apilados y ordenados.
  List<MapEntry<Objeto, int>> _opciones(Ranura r) {
    final anillo = _esAnillo(r);
    final grupos = <String, List<Objeto>>{};
    for (final o in juego.inventario) {
      final va = anillo ? o.tipo == TipoObjeto.anillo : o.tipo.ranura == r;
      if (va) grupos.putIfAbsent(o.claveApilado, () => []).add(o);
    }
    final lista = grupos.values
        .map((l) => MapEntry(l.first, l.length))
        .toList()
      ..sort((a, b) => _mayorAMenor(a.key, b.key));
    return lista;
  }

  // Cuántas copias de [o] lleva puestas en OTRAS casillas distintas de [r]
  int _puestosEnOtras(Ranura r, Objeto o) => juego.equipado.entries
      .where((e) => e.key != r && e.value == o)
      .length;

  void _abrirLista(Ranura r) {
    final opciones = _opciones(r);
    final actual = juego.equipado[r];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF2A1218),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.65),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(r.nombre.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: _doradoClaro)),
              ),
              if (actual != null)
                ListTile(
                  leading: const Icon(Icons.close, color: Colors.redAccent),
                  title: Text('Quitar ${actual.nombreMostrado}'),
                  onTap: () {
                    Navigator.pop(ctx);
                    juego.desequipar(r);
                    _aviso('Quitaste ${actual.nombreMostrado}');
                  },
                ),
              if (opciones.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                      'No tienes objetos para esta casilla.\nVisita la tienda.',
                      textAlign: TextAlign.center),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: opciones.map((e) {
                      final o = e.key;
                      final cantidad = e.value;
                      final puesto = juego.equipado[r] == o;
                      final enOtra = _puestosEnOtras(r, o);
                      String? motivo = juego.motivoNoEquipable(o);
                      if (motivo == null && !puesto && enOtra >= cantidad) {
                        motivo = 'Ya lo llevas puesto en otra casilla';
                      }
                      final sub = puesto
                          ? 'Equipado'
                          : motivo ??
                          'Nivel ${o.nivelRequerido} · '
                              '${o.detalle(conPrecio: false)}';
                      return ListTile(
                        leading: ImagenObjeto(
                          nombre: o.nombre,
                          tamano: 52,
                          respaldo: Container(
                            color: Colors.black26,
                            child: Icon(o.tipo.icono),
                          ),
                        ),
                        title: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          children: [
                            if (o.apodo != null)
                              ApodoBrillante(o.apodo!, tamano: 15)
                            else
                              Text(o.nombre),
                            if (o.afilado > 0)
                              Text('Filo +${o.afilado}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orangeAccent)),
                            if (cantidad > 1) Text('x$cantidad'),
                          ],
                        ),
                        subtitle: Text(o.apodo != null ? '(${o.nombre}) $sub' : sub),
                        enabled: motivo == null && !puesto,
                        onTap: () {
                          Navigator.pop(ctx);
                          _aviso(juego.equiparEn(r, o));
                        },
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _casilla(String etiqueta, IconData icono, Ranura? r,
      {bool redonda = false}) {
    final o = r == null ? null : juego.equipado[r];
    final sel = r != null && _sel == r;
    final Color borde = r == null
        ? Colors.white24
        : sel
        ? Colors.redAccent
        : _dorado;
    final double ancho = redonda ? 88 : 100;
    final double alto = redonda ? 88 : 132;
    final decoracion = redonda
        ? BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xCC1A1014),
      border: Border.all(color: borde, width: sel ? 3 : 2),
    )
        : BoxDecoration(
      color: const Color(0xCC1A1014),
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(8),
        topRight: Radius.circular(8),
        bottomLeft: Radius.circular(46),
        bottomRight: Radius.circular(46),
      ),
      border: Border.all(color: borde, width: sel ? 3 : 2),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: r == null
              ? null
              : () {
            setState(() => _sel = r);
            _abrirLista(r);
          },
          child: Container(
            width: ancho,
            height: alto,
            padding: const EdgeInsets.all(8),
            decoration: decoracion,
            child: o == null
                ? Center(
              child: Icon(icono,
                  size: redonda ? 32 : 38, color: Colors.white30),
            )
                : redonda
                ? ClipOval(
              child: ImagenObjeto(
                nombre: o.nombre,
                tamano: 68,
                respaldo: Container(
                  color: Colors.black26,
                  child: Icon(o.tipo.icono,
                      size: 32, color: _doradoClaro),
                ),
              ),
            )
                : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ImagenObjeto(
                  nombre: o.nombre,
                  tamano: 76,
                  respaldo: Container(
                    color: Colors.black26,
                    child: Icon(o.tipo.icono,
                        size: 38, color: _doradoClaro),
                  ),
                ),
                const SizedBox(height: 4),
                if (o.apodo != null)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ApodoBrillante(o.apodo!, tamano: 10),
                  )
                else
                  Text(o.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10)),
                if (o.afilado > 0)
                  Text('Filo +${o.afilado}',
                      style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.orangeAccent)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xCC2A1218),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: borde.withAlpha(180)),
          ),
          child: Text(etiqueta,
              style: const TextStyle(fontSize: 12, color: _doradoClaro)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final espada =
    _ranuraDe((n) => n.contains('arma') && !n.contains('armadura'));
    final armadura = _ranuraDe((n) => n.contains('armadura'));
    final escudo = _ranuraDe((n) => n.contains('escudo'));
    final colgante = _ranuraDe((n) => n.contains('colgante'));
    final anillo1 = _ranuraDe((n) => n.contains('anillo'));
    final anillo2 = _ranuraDe((n) => n.contains('anillo'), indice: 1);

    final sel = _sel;
    final objetoSel = sel == null ? null : juego.equipado[sel];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xCC1A1014),
            border: Border.all(color: _dorado, width: 2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text('ARMADO DEL PERSONAJE',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: _doradoClaro)),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _casilla('espada', Icons.gavel, espada),
            _casilla('armadura', Icons.checkroom, armadura),
            _casilla('escudo', Icons.shield, escudo),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: _casilla('anillo I', Icons.circle_outlined, anillo1,
                  redonda: true),
            ),
            _casilla('colgante', Icons.auto_awesome, colgante),
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: _casilla('anillo II', Icons.circle_outlined, anillo2,
                  redonda: true),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: sel == null
                ? const Text('Toca una casilla para ver tus objetos y equipar.',
                style:
                TextStyle(fontStyle: FontStyle.italic, fontSize: 13))
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                        objetoSel?.apodo != null
                            ? '${sel.nombre}: '
                            : '${sel.nombre}: ${objetoSel?.nombre ?? 'vacía'}',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    if (objetoSel?.apodo != null)
                      ApodoBrillante(objetoSel!.apodo!, tamano: 16),
                  ],
                ),
                if (objetoSel?.apodo != null)
                  Text('(${objetoSel!.nombre})',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.white54)),
                if ((objetoSel?.afilado ?? 0) > 0)
                  Text('Filo +${objetoSel!.afilado}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.orangeAccent)),
                if (objetoSel != null) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: ImagenObjeto(
                      nombre: objetoSel.nombre,
                      tamano: 130,
                      respaldo: Container(
                        color: Colors.black26,
                        child: Icon(objetoSel.tipo.icono,
                            size: 56, color: Colors.white38),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(objetoSel.detalle(conPrecio: false),
                      style: const TextStyle(fontSize: 12)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: BotonOscuro(
                texto: 'Desequipar',
                alto: 52,
                color: ColorBoton.rojo,
                onPressed: sel != null && objetoSel != null
                    ? () {
                  juego.desequipar(sel);
                  _aviso('Quitaste ${objetoSel.nombreMostrado}');
                }
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: BotonOscuro(
                texto: 'Ver objetos',
                alto: 52,
                color: ColorBoton.rojo,
                onPressed: sel != null ? () => _abrirLista(sel) : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}