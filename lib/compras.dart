import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'boton_oscuro.dart';
import 'idioma.dart';
import 'main.dart';

// ====================== CATÁLOGO DE COMPRAS REALES ======================
// IMPORTANTE: cada "id" debe ser IDÉNTICO al ID del producto que crees en
// Google Play Console (Monetización > Productos > Productos únicos).
// Gemas y Premium se crean como "consumibles" (se pueden comprar muchas veces).
// "sin_anuncios" es un producto de UNA sola compra (no consumible).
// Los precios REALES los pone la tienda; "precioPrueba" solo se ve en modo
// prueba (debug), cuando todavía no tienes los productos creados.

enum TipoProductoReal { gemas, premium, sinAnuncios }

// El ORO NO SE VENDE con dinero real (decisión de diseño: hay juegos de azar
// dentro del juego y el oro no debe poder comprarse). Solo las gemas se venden,
// y siguen ocultas mientras estén en modo prueba (se podían "comprar" infinitas
// gratis). Ponlo en true cuando tus productos reales existan en Google Play y
// la compra esté validada.
const bool ventaOroGemasActiva = false;

// Mientras no tengas los productos creados en Google Play, déjalo en true para
// que Premium y "Sin anuncios" se puedan "comprar" SIN cobrar (compra simulada)
// también en el APK final. Sirve para pruebas con amigos. Cuando publiques el
// juego en Google Play con los productos reales, ponlo en false.
const bool comprasSimuladas = true;

class ProductoReal {
  final String id;
  final TipoProductoReal tipo;
  final String titulo;
  final String descripcion;
  final int cantidad; // oro o gemas que entrega (0 si es premium)
  final int dias; // días de premium que entrega (0 si no es premium)
  final String precioPrueba;

  const ProductoReal({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.descripcion,
    required this.precioPrueba,
    this.cantidad = 0,
    this.dias = 0,
  });
}

const List<ProductoReal> productosPremium = [
  ProductoReal(
    id: 'premium_7d',
    tipo: TipoProductoReal.premium,
    titulo: 'Premium 7 días',
    descripcion: 'Una semana de ventajas premium.',
    dias: 7,
    precioPrueba: '\$1.99',
  ),
  ProductoReal(
    id: 'premium_30d',
    tipo: TipoProductoReal.premium,
    titulo: 'Premium 30 días',
    descripcion: 'Un mes de ventajas premium. El mejor valor.',
    dias: 30,
    precioPrueba: '\$5.99',
  ),
];

// Compra única: las recompensas por anuncio se dan al instante.
// Crea este producto en Google Play como "Producto único" NO consumible
// con el precio que quieras (por ejemplo 9.99 USD).
const List<ProductoReal> productosSinAnuncios = [
  ProductoReal(
    id: 'sin_anuncios',
    tipo: TipoProductoReal.sinAnuncios,
    titulo: 'Sin anuncios',
    descripcion:
    'Pago único. Todas las recompensas de anuncios se reciben al instante, sin ver ningún anuncio.',
    precioPrueba: '\$9.99',
  ),
];

const List<ProductoReal> productosGemas = [
  ProductoReal(
    id: 'gemas_50',
    tipo: TipoProductoReal.gemas,
    titulo: '50 esquirlas',
    descripcion: 'Un puñado de esquirlas.',
    cantidad: 50,
    precioPrueba: '\$0.99',
  ),
  ProductoReal(
    id: 'gemas_275',
    tipo: TipoProductoReal.gemas,
    titulo: '275 esquirlas',
    descripcion: 'Una bolsa de esquirlas.',
    cantidad: 275,
    precioPrueba: '\$4.99',
  ),
  ProductoReal(
    id: 'gemas_600',
    tipo: TipoProductoReal.gemas,
    titulo: '600 esquirlas',
    descripcion: 'Un cofre de esquirlas.',
    cantidad: 600,
    precioPrueba: '\$9.99',
  ),
];

final List<ProductoReal> todosLosProductos = [
  ...productosPremium,
  ...productosSinAnuncios,
  if (ventaOroGemasActiva) ...productosGemas,
];

// ====================== SERVICIO DE COMPRAS ======================

class ServicioCompras extends ChangeNotifier {
  ServicioCompras._();
  static final ServicioCompras instancia = ServicioCompras._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool _iniciado = false;

  bool tiendaDisponible = false;
  bool cargando = false; // hay un cobro en curso
  String? mensaje; // último aviso para mostrar al jugador

  final Map<String, ProductDetails> _detalles = {};
  final Set<String> _entregadas = {}; // evita entregar dos veces la misma compra

  // Se llama una vez al abrir el menú. Escucha las compras desde el inicio para
  // no perder una compra pagada que quedó pendiente en una sesión anterior.
  Future<void> iniciar() async {
    if (_iniciado) return;
    _iniciado = true;
    _sub = _iap.purchaseStream.listen(
      _alRecibirCompras,
      onError: (Object e) {
        cargando = false;
        mensaje = 'Error en la tienda: $e';
        notifyListeners();
      },
    );
    try {
      tiendaDisponible = await _iap.isAvailable();
      if (tiendaDisponible) {
        final respuesta = await _iap
            .queryProductDetails(todosLosProductos.map((p) => p.id).toSet());
        for (final d in respuesta.productDetails) {
          _detalles[d.id] = d;
        }
      }
    } catch (_) {
      tiendaDisponible = false;
    }
    notifyListeners();
  }

  // Recupera compras únicas (como "Sin anuncios") al cambiar de teléfono.
  Future<void> restaurar() async {
    if (!tiendaDisponible) {
      mensaje = tr('La tienda no está disponible ahora. Inténtalo más tarde.');
      notifyListeners();
      return;
    }
    try {
      await _iap.restorePurchases();
    } catch (e) {
      mensaje = 'No se pudo restaurar: $e';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // Precio que muestra el botón: el real de la tienda (con su moneda local).
  String precioDe(ProductoReal p) {
    final d = _detalles[p.id];
    if (d != null) return d.price;
    return (kDebugMode || comprasSimuladas)
        ? '${p.precioPrueba} (test)'
        : tr('No disponible');
  }

  ProductoReal? _buscar(String id) {
    for (final p in todosLosProductos) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> comprar(BuildContext context, ProductoReal p) async {
    // Las gemas están ocultas mientras ventaOroGemasActiva sea false.
    if (!ventaOroGemasActiva && p.tipo == TipoProductoReal.gemas) {
      return;
    }
    if (p.tipo == TipoProductoReal.sinAnuncios && juego.sinAnuncios) {
      mensaje = tr('Ya tienes la versión sin anuncios.');
      notifyListeners();
      return;
    }
    final d = _detalles[p.id];

    // Sin tienda o sin el producto creado: solo se puede simular en debug o
    // mientras comprasSimuladas sea true.
    if (d == null) {
      if (kDebugMode || comprasSimuladas) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Modo prueba'),
            content: Text(
                'La tienda no tiene este producto todavía. ¿Simular la compra de "${p.titulo}" sin cobrar?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Simular')),
            ],
          ),
        );
        if (ok == true) _entregar(p);
        return;
      }
      mensaje = tr('La tienda no está disponible ahora. Inténtalo más tarde.');
      notifyListeners();
      return;
    }

    cargando = true;
    notifyListeners();
    try {
      final param = PurchaseParam(productDetails: d);
      final iniciada = p.tipo == TipoProductoReal.sinAnuncios
          ? await _iap.buyNonConsumable(purchaseParam: param)
          : await _iap.buyConsumable(purchaseParam: param);
      if (!iniciada) {
        cargando = false;
        mensaje = tr('No se pudo iniciar la compra.');
        notifyListeners();
      }
    } catch (e) {
      cargando = false;
      mensaje = 'No se pudo iniciar la compra: $e';
      notifyListeners();
    }
  }

  Future<void> _alRecibirCompras(List<PurchaseDetails> lista) async {
    for (final c in lista) {
      switch (c.status) {
        case PurchaseStatus.pending:
          cargando = true;
          break;
        case PurchaseStatus.error:
          cargando = false;
          mensaje = 'La compra falló: ${c.error?.message ?? 'error desconocido'}';
          break;
        case PurchaseStatus.canceled:
          cargando = false;
          mensaje = tr('Compra cancelada.');
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final clave = c.purchaseID ?? '${c.productID}-${c.transactionDate}';
          if (_entregadas.add(clave)) {
            final p = _buscar(c.productID);
            if (p != null) {
              _entregar(p, silencioso: c.status == PurchaseStatus.restored);
            }
          }
          cargando = false;
          break;
      }
      // Le avisa a la tienda que ya entregamos el producto (y lo "consume").
      if (c.pendingCompletePurchase) {
        await _iap.completePurchase(c);
      }
    }
    notifyListeners();
  }

  // ÚNICO lugar donde se entrega lo comprado.
  // TODO (recomendado antes de publicar): validar la compra en un servidor
  // (Cloud Function) antes de entregar, para que nadie pueda falsificarla.
  void _entregar(ProductoReal p, {bool silencioso = false}) {
    switch (p.tipo) {
      case TipoProductoReal.gemas:
        juego.gemas += p.cantidad;
        break;
      case TipoProductoReal.premium:
        juego.agregarPremium(p.dias);
        break;
      case TipoProductoReal.sinAnuncios:
        juego.sinAnuncios = true;
        break;
    }
    juego.avisarCambio();
    mensaje = silencioso ? null : '${tr('¡Compra lista!')} ${tr(p.titulo)}';
    notifyListeners();
  }
}

// ====================== MEDALLA PREMIUM ======================
// Medalla dorada que se muestra mientras el jugador tiene Premium activo.

class MedallaPremium extends StatelessWidget {
  final double tamano;
  const MedallaPremium({super.key, this.tamano = 22});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tr('Jugador Premium'),
      child: Container(
        width: tamano,
        height: tamano,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFE082), Color(0xFFFFA000)],
          ),
          border: Border.all(color: const Color(0xFFFFF8E1), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.amber.withAlpha(120), blurRadius: 6),
          ],
        ),
        child: Icon(Icons.workspace_premium,
            size: tamano * 0.7, color: const Color(0xFF5A0F1B)),
      ),
    );
  }
}

// ====================== PANTALLA ======================

class PantallaCompras extends StatelessWidget {
  const PantallaCompras({super.key});

  String _textoEstadoPremium() {
    final hasta = juego.premiumHasta;
    if (!juego.premium || hasta == null) {
      return tr('No tienes Premium activo.');
    }
    final falta = hasta.difference(RelojServidor.instante());
    final dias = falta.inDays;
    final horas = falta.inHours % 24;
    return tr('Premium activo: quedan {d} d {h} h.', {'d': dias, 'h': horas});
  }

  List<String> _ventajas() => [
    tr('Misiones: {n} min al día (en vez de {m}).', {
      'n': bloquesPorDiaPremium * minutosPorBloque,
      'm': bloquesPorDia * minutosPorBloque,
    }),
    tr('Taberna: +{p}% de sueldo.',
        {'p': (bonusPremiumTaberna * 100).round()}),
    tr('Esquirlas en la taberna: {p}% por hora (en vez de {q}%).', {
      'p': (probGemasPorHoraTabernaPremium * 100).round(),
      'q': (probGemasPorHoraTaberna * 100).round(),
    }),
    tr('Espera entre ataques: {n} min (en vez de {m}).', {
      'n': esperaEntreAtaquesPremium.inMinutes,
      'm': esperaEntreAtaques.inMinutes,
    }),
  ];

  Widget _titulo(String texto) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 6),
    child: Text(texto,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
  );

  Widget _tarjeta(BuildContext context, ServicioCompras s, ProductoReal p,
      IconData icono, Color colorIcono, ColorBoton colorBoton) {
    return Card(
      child: ListTile(
        leading: Icon(icono, color: colorIcono, size: 32),
        title: Text(tr(p.titulo),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle:
        Text(tr(p.descripcion), style: const TextStyle(fontSize: 12)),
        trailing: BotonOscuro(
          texto: s.precioDe(p),
          ancho: 120,
          alto: 40,
          color: colorBoton,
          onPressed: s.cargando ? null : () => s.comprar(context, p),
        ),
      ),
    );
  }

  Widget _tarjetaSinAnuncios(BuildContext context, ServicioCompras s) {
    final p = productosSinAnuncios.first;
    final tiene = juego.sinAnuncios;
    return Card(
      child: ListTile(
        leading:
        const Icon(Icons.block, color: Colors.lightGreenAccent, size: 32),
        title: Text(tr(p.titulo),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle:
        Text(tr(p.descripcion), style: const TextStyle(fontSize: 12)),
        trailing: BotonOscuro(
          texto: tiene ? tr('Comprado') : s.precioDe(p),
          ancho: 120,
          alto: 40,
          color: ColorBoton.verde,
          onPressed: (s.cargando || tiene) ? null : () => s.comprar(context, p),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ServicioCompras.instancia;
    return ListenableBuilder(
      listenable: Listenable.merge([s, juego]),
      builder: (context, _) {
        // Avisos (compra lista, cancelada, error...) como mensaje emergente.
        final msg = s.mensaje;
        if (msg != null) {
          s.mensaje = null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(msg)));
            }
          });
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (s.cargando) const LinearProgressIndicator(),

            // ---------- PREMIUM ----------
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (juego.premium)
                          const MedallaPremium(tamano: 28)
                        else
                          const Icon(Icons.workspace_premium,
                              color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_textoEstadoPremium(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final v in _ventajas())
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text('•  $v',
                            style: const TextStyle(fontSize: 13)),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      tr('Si compras Premium estando activo, los días se suman.'),
                      style:
                      TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ),
            _titulo(tr('Premium')),
            for (final p in productosPremium)
              _tarjeta(context, s, p, Icons.workspace_premium, Colors.amber,
                  ColorBoton.rojo),

            _titulo(tr('Anuncios')),
            _tarjetaSinAnuncios(context, s),

            // Gemas: ocultas mientras ventaOroGemasActiva sea false.
            // (El oro ya no se vende.)
            if (ventaOroGemasActiva) ...[
              _titulo(tr('Esquirlas')),
              for (final p in productosGemas)
                _tarjeta(context, s, p, Icons.diamond, Colors.redAccent,
                    ColorBoton.azul),
            ],

            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: s.cargando ? null : s.restaurar,
                child: Text(tr('Restaurar compras')),
              ),
            ),
            const SizedBox(height: 8),
            if (!s.tiendaDisponible)
              Text(
                (kDebugMode || comprasSimuladas)
                    ? tr('Modo prueba: la tienda no está conectada, las compras se simulan sin cobrar.')
                    : tr('La tienda no está disponible en este momento.'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            const SizedBox(height: 4),
            Text(
              tr('Las compras se procesan con la tienda de tu dispositivo. El Premium no se renueva solo.'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        );
      },
    );
  }
}