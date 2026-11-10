import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ====================== BOTÓN OSCURO ======================
// Usa los PNG de assets/ui/ con este nombre:
//   marco_<tamano>_<color>.png
// Ejemplos: marco_chico_rojo.png, marco_grande_azul.png
//
// - CHICO: se estira a lo ancho sin deformar las esquinas (nine-patch).
// - GRANDE: se dibuja entero, con su proporción.
//
// Si falta un PNG, el botón se ve con un color liso de respaldo.

enum ColorBoton { rojo, verde, morado, rosa, azul, ambar }

enum TamanoBoton { chico, grande }

const double _corteX = 0.14; // fracción del ancho de la imagen
const double _corteY = 0.24; // fracción del alto de la imagen

Color _colorRespaldo(ColorBoton c) {
  switch (c) {
    case ColorBoton.rojo:
      return const Color(0xFF8B1A1A);
    case ColorBoton.verde:
      return const Color(0xFF1F6B2E);
    case ColorBoton.morado:
      return const Color(0xFF5B2A86);
    case ColorBoton.rosa:
      return const Color(0xFF9C1F7A);
    case ColorBoton.azul:
      return const Color(0xFF1F4FA8);
    case ColorBoton.ambar:
      return const Color(0xFFB07A1A);
  }
}

// Las imágenes se cargan una sola vez y se reutilizan.
final Map<String, Future<ui.Image?>> _imagenes = {};

Future<ui.Image?> _cargarImagen(String ruta) {
  return _imagenes.putIfAbsent(ruta, () async {
    try {
      final datos = await rootBundle.load(ruta);
      final codec = await ui.instantiateImageCodec(datos.buffer.asUint8List());
      final cuadro = await codec.getNextFrame();
      return cuadro.image;
    } catch (e) {
      debugPrint('>>> BOTON_OSCURO: no se pudo cargar "$ruta" -> $e');
      return null;
    }
  });
}

class BotonOscuro extends StatefulWidget {
  final String texto;
  final VoidCallback? onPressed; // null = botón desactivado (gris)
  final ColorBoton color;
  final TamanoBoton tamano;
  final double? ancho; // si no lo das, usa todo el ancho disponible
  final double? alto; // chico: 46 por defecto. Grande: sale del ancho
  final IconData? icono;
  final bool alerta; // muestra el círculo rojo con "!" en la esquina

  const BotonOscuro({
    super.key,
    required this.texto,
    required this.onPressed,
    this.color = ColorBoton.rojo,
    this.tamano = TamanoBoton.chico,
    this.ancho,
    this.alto,
    this.icono,
    this.alerta = false,
  });

  @override
  State<BotonOscuro> createState() => _BotonOscuroState();
}

class _BotonOscuroState extends State<BotonOscuro> {
  ui.Image? _img;
  bool _presionado = false;

  String get _ruta =>
      'assets/ui/marco_${widget.tamano.name}_${widget.color.name}.png';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(BotonOscuro viejo) {
    super.didUpdateWidget(viejo);
    if (viejo.color != widget.color || viejo.tamano != widget.tamano) {
      _img = null;
      _cargar();
    }
  }

  void _cargar() {
    final ruta = _ruta;
    _cargarImagen(ruta).then((i) {
      if (mounted && ruta == _ruta) setState(() => _img = i);
    });
  }

  Widget _insignia() {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFC0392B),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE8D9B0), width: 1.5),
      ),
      child: const Text('!',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activo = widget.onPressed != null;
    final grande = widget.tamano == TamanoBoton.grande;

    return LayoutBuilder(builder: (context, c) {
      final double ancho = widget.ancho ??
          (c.hasBoundedWidth ? c.maxWidth : (grande ? 220.0 : 110.0));

      double alto;
      if (widget.alto != null) {
        alto = widget.alto!;
      } else if (grande && _img != null) {
        alto = ancho * _img!.height / _img!.width;
      } else {
        alto = grande ? ancho * 0.5 : 46.0;
      }

      final tamanoTexto = grande ? 20.0 : 15.0;
      final colorTexto =
      activo ? const Color(0xFFF1E3C0) : const Color(0xFF8A8A8A);
      const sombra = [
        Shadow(color: Colors.black, blurRadius: 3, offset: Offset(1, 1)),
        Shadow(color: Colors.black, blurRadius: 3, offset: Offset(-1, 1)),
        Shadow(color: Colors.black, blurRadius: 3, offset: Offset(1, -1)),
        Shadow(color: Colors.black, blurRadius: 3, offset: Offset(-1, -1)),
      ];

      final cuerpo = SizedBox(
        width: ancho,
        height: alto,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: _img != null
                  ? CustomPaint(
                painter: _PintorMarco(
                  imagen: _img!,
                  nuevePartes: !grande,
                  activo: activo,
                  presionado: _presionado,
                ),
              )
                  : Container(
                decoration: BoxDecoration(
                  color: activo
                      ? _colorRespaldo(widget.color)
                      : Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(8),
                  border:
                  Border.all(color: Colors.grey.shade500, width: 2),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: alto * 0.3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icono != null) ...[
                    Icon(widget.icono,
                        size: tamanoTexto + 3, color: colorTexto),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      widget.texto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: tamanoTexto,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: colorTexto,
                        shadows: sombra,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.alerta)
              Positioned(top: -6, right: -6, child: _insignia()),
          ],
        ),
      );

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: activo ? (_) => setState(() => _presionado = true) : null,
        onTapUp: activo ? (_) => setState(() => _presionado = false) : null,
        onTapCancel: activo ? () => setState(() => _presionado = false) : null,
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _presionado ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: cuerpo,
        ),
      );
    });
  }
}

const ColorFilter _filtroGris = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
]);

const ColorFilter _filtroOscuro = ColorFilter.matrix(<double>[
  0.75, 0, 0, 0, 0,
  0, 0.75, 0, 0, 0,
  0, 0, 0.75, 0, 0,
  0, 0, 0, 1, 0,
]);

class _PintorMarco extends CustomPainter {
  final ui.Image imagen;
  final bool nuevePartes; // true: marco chico (esquinas fijas, centro estirable)
  final bool activo;
  final bool presionado;

  _PintorMarco({
    required this.imagen,
    required this.nuevePartes,
    required this.activo,
    required this.presionado,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()..filterQuality = FilterQuality.high;
    if (!activo) {
      pincel.colorFilter = _filtroGris;
    } else if (presionado) {
      pincel.colorFilter = _filtroOscuro;
    }

    final w = imagen.width.toDouble();
    final h = imagen.height.toDouble();
    final origen = Rect.fromLTWH(0, 0, w, h);

    if (!nuevePartes) {
      canvas.drawImageRect(imagen, origen, Offset.zero & size, pincel);
      return;
    }

    final k = size.height / h;
    final destino = Rect.fromLTWH(0, 0, size.width / k, h);
    final esquinaX = w * _corteX;
    if (destino.width < esquinaX * 2 + 2) {
      canvas.drawImageRect(imagen, origen, Offset.zero & size, pincel);
      return;
    }
    final centro =
    Rect.fromLTRB(esquinaX, h * _corteY, w - esquinaX, h - h * _corteY);
    canvas.save();
    canvas.scale(k);
    canvas.drawImageNine(imagen, centro, destino, pincel);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PintorMarco v) =>
      v.imagen != imagen ||
          v.nuevePartes != nuevePartes ||
          v.activo != activo ||
          v.presionado != presionado;
}

// ====================== CÍRCULO CON ÍCONO ======================
// Usa assets/ui/circulo_<nombre>.png
// Nombres: calavera, pergamino, bolsa, sobre, corona, puerta

Widget _puntoAlerta() {
  return Container(
    width: 20,
    height: 20,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0xFFC0392B),
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFFE8D9B0), width: 1.5),
    ),
    child: const Text('!',
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
  );
}

class CirculoIcono extends StatefulWidget {
  final String nombre;
  final VoidCallback? onPressed;
  final double tamano;
  final bool alerta;

  const CirculoIcono({
    super.key,
    required this.nombre,
    required this.onPressed,
    this.tamano = 64,
    this.alerta = false,
  });

  @override
  State<CirculoIcono> createState() => _CirculoIconoState();
}

class _CirculoIconoState extends State<CirculoIcono> {
  bool _presionado = false;

  @override
  Widget build(BuildContext context) {
    final activo = widget.onPressed != null;
    final t = widget.tamano;

    Widget imagen = Image.asset(
      'assets/ui/circulo_${widget.nombre}.png',
      width: t,
      height: t,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, error, ___) {
        debugPrint(
            '>>> BOTON_OSCURO: no se pudo cargar "assets/ui/circulo_${widget.nombre}.png" -> $error');
        return Container(
          width: t,
          height: t,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF2A1218),
            border: Border.all(color: Colors.grey.shade600, width: 2),
          ),
          child: const Icon(Icons.help_outline, color: Colors.white38),
        );
      },
    );
    if (!activo) {
      imagen = ColorFiltered(colorFilter: _filtroGris, child: imagen);
    } else if (_presionado) {
      imagen = ColorFiltered(colorFilter: _filtroOscuro, child: imagen);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: activo ? (_) => setState(() => _presionado = true) : null,
      onTapUp: activo ? (_) => setState(() => _presionado = false) : null,
      onTapCancel: activo ? () => setState(() => _presionado = false) : null,
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _presionado ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: SizedBox(
          width: t,
          height: t,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              imagen,
              if (widget.alerta)
                Positioned(top: -2, right: -2, child: _puntoAlerta()),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================== BARRA GÓTICA (vida, fama...) ======================
// Usa assets/ui/barra_verde.png o assets/ui/barra_roja.png.
// Al cargar, recorta SOLO el margen transparente de la imagen, así el marco
// ocupa todo el ancho y la capa oscura de la parte vacía queda dentro del
// cristal (ya no sobresale el cuadro negro).

enum ColorBarra { verde, roja }

class _BarraImg {
  final ui.Image imagen;
  final Rect recorte; // zona visible de la imagen (sin margen transparente)
  const _BarraImg(this.imagen, this.recorte);
}

final Map<String, Future<_BarraImg?>> _barras = {};

Future<_BarraImg?> _cargarBarra(String ruta) {
  return _barras.putIfAbsent(ruta, () async {
    final img = await _cargarImagen(ruta);
    if (img == null) return null;
    final w = img.width;
    final h = img.height;
    final completo = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
    try {
      final datos = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (datos == null) return _BarraImg(img, completo);
      int minX = w, minY = h, maxX = -1, maxY = -1;
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final alfa = datos.getUint8((y * w + x) * 4 + 3);
          if (alfa > 40) {
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
          }
        }
      }
      if (maxX < minX || maxY < minY) return _BarraImg(img, completo);
      return _BarraImg(
          img,
          Rect.fromLTRB(minX.toDouble(), minY.toDouble(), (maxX + 1).toDouble(),
              (maxY + 1).toDouble()));
    } catch (e) {
      return _BarraImg(img, completo);
    }
  });
}

class _PintorBarra extends CustomPainter {
  final _BarraImg barra;
  _PintorBarra(this.barra);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(barra.imagen, barra.recorte, Offset.zero & size,
        Paint()..filterQuality = FilterQuality.high);
  }

  @override
  bool shouldRepaint(_PintorBarra v) => v.barra != barra;
}

class BarraMarco extends StatefulWidget {
  final double valor; // de 0.0 a 1.0
  final String? texto; // por ejemplo '85 / 100'
  final ColorBarra color;
  final double? ancho; // si no lo das, usa todo el ancho disponible

  const BarraMarco({
    super.key,
    required this.valor,
    this.texto,
    this.color = ColorBarra.verde,
    this.ancho,
  });

  @override
  State<BarraMarco> createState() => _BarraMarcoState();
}

class _BarraMarcoState extends State<BarraMarco> {
  _BarraImg? _barra;

  // Parte del marco (a cada lado y arriba/abajo) que NO es cristal.
  // Si la capa oscura se sale del cristal, sube estos números; si deja
  // cristal sin cubrir, bájalos.
  static const double _margenX = 0.115;
  static const double _margenY = 0.25;

  String get _ruta => 'assets/ui/barra_${widget.color.name}.png';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(BarraMarco viejo) {
    super.didUpdateWidget(viejo);
    if (viejo.color != widget.color) {
      _barra = null;
      _cargar();
    }
  }

  void _cargar() {
    final ruta = _ruta;
    _cargarBarra(ruta).then((b) {
      if (mounted && ruta == _ruta) setState(() => _barra = b);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final double w =
          widget.ancho ?? (c.hasBoundedWidth ? c.maxWidth : 260.0);
      final b = _barra;
      final double relacion = b == null
          ? 3.4
          : b.recorte.width / b.recorte.height;
      final double h = w / relacion;
      final v = widget.valor.clamp(0.0, 1.0);
      final vacia = 1.0 - v;

      return SizedBox(
        width: w,
        height: h,
        child: Stack(
          children: [
            Positioned.fill(
              child: b != null
                  ? CustomPaint(painter: _PintorBarra(b))
                  : Container(
                decoration: BoxDecoration(
                  color: widget.color == ColorBarra.verde
                      ? const Color(0xFF1F6B2E)
                      : const Color(0xFF8B1A1A),
                  borderRadius: BorderRadius.circular(6),
                  border:
                  Border.all(color: Colors.grey.shade500, width: 2),
                ),
              ),
            ),
            if (b != null)
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: w * _margenX, vertical: h * _margenY),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FractionallySizedBox(
                        widthFactor: vacia,
                        heightFactor: 1,
                        child: const ColoredBox(color: Color(0xB3000000)),
                      ),
                    ),
                  ),
                ),
              ),
            if (widget.texto != null)
              Center(
                child: Text(
                  widget.texto!,
                  style: TextStyle(
                    fontSize: h * 0.30,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFF1E3C0),
                    shadows: const [
                      Shadow(
                          color: Colors.black,
                          blurRadius: 3,
                          offset: Offset(1, 1)),
                      Shadow(
                          color: Colors.black,
                          blurRadius: 3,
                          offset: Offset(-1, -1)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}

// ====================== FILA CON BOTÓN ======================
// Tarjeta con ícono y título arriba, descripción y botón abajo a la derecha.
// Se usa en Tienda, Inventario y Taberna para que el texto no quede aplastado.

class FilaConBoton extends StatelessWidget {
  final Widget icono;
  final String titulo;
  final String detalle;
  final Widget boton;
  final Color? colorTitulo;
  final Color? colorFondo;
  final Color? colorBorde;

  const FilaConBoton({
    super.key,
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.boton,
    this.colorTitulo,
    this.colorFondo,
    this.colorBorde,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: colorFondo,
      shape: colorBorde == null
          ? null
          : RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorBorde!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                icono,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(titulo,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colorTitulo)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(detalle, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerRight, child: boton),
          ],
        ),
      ),
    );
  }
}

// ====================== PANTALLA DE PRUEBA ======================

class PantallaPruebaBotones extends StatelessWidget {
  const PantallaPruebaBotones({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prueba de botones')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Chico (ancho completo)'),
          const SizedBox(height: 8),
          BotonOscuro(texto: 'Comprar', onPressed: () {}),
          const SizedBox(height: 16),
          const Text('Chico desactivado'),
          const SizedBox(height: 8),
          const BotonOscuro(texto: 'Comprada', onPressed: null),
          const SizedBox(height: 24),
          const Text('Barras'),
          const SizedBox(height: 8),
          const BarraMarco(valor: 0.7, texto: '70 / 100'),
          const SizedBox(height: 10),
          const BarraMarco(
              valor: 0.35, texto: '35 / 100', color: ColorBarra.roja),
        ],
      ),
    );
  }
}