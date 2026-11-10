import 'package:flutter/material.dart';

// Rutas de las imágenes de fondo. Todas están en assets/fondos/.
// Si tus archivos no son .jpg (por ejemplo .jpeg o .png), cambia solo _ext.
// Si cambias un nombre de archivo, cámbialo aquí y en ningún otro lugar.
class Fondos {
  static const String _carpeta = 'assets/fondos';
  static const String _ext = 'jpg';

  static const String login = '$_carpeta/login.$_ext';
  static const String crearPersonaje = '$_carpeta/crear_personaje.$_ext';
  static const String personaje = '$_carpeta/personaje.$_ext';
  static const String misiones = '$_carpeta/misiones.$_ext';
  static const String combate = '$_carpeta/combate.$_ext';
  static const String arena = '$_carpeta/arena.$_ext';
  static const String cripta = '$_carpeta/cripta.$_ext';
  static const String ciudadela = '$_carpeta/ciudadela.$_ext';
  static const String tienda = '$_carpeta/tienda.$_ext';
  static const String entrenamiento = '$_carpeta/entrenamiento.$_ext';
  static const String inventario = '$_carpeta/inventario.$_ext';
  static const String taberna = '$_carpeta/taberna.$_ext';
  static const String altar = '$_carpeta/altar.$_ext';
  static const String ranking = '$_carpeta/ranking.$_ext';
  static const String armadoPj = '$_carpeta/armadopj.$_ext';
}

// Pone una imagen de fondo detrás de [child], con una capa oscura encima
// para que los textos se lean. [oscuridad] va de 0 (sin capa) a 1 (negro).
// Si no la indicas, usa 0.35, y la Ciudadela (muy clara) usa más.
class FondoPantalla extends StatelessWidget {
  final String imagen;
  final Widget child;
  final double? oscuridad;

  const FondoPantalla({
    super.key,
    required this.imagen,
    required this.child,
    this.oscuridad,
  });

  @override
  Widget build(BuildContext context) {
    final double capa =
        oscuridad ?? (imagen == Fondos.ciudadela ? 0.60 : 0.35);
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          imagen,
          fit: BoxFit.cover,
          // Reduce la memoria: las imágenes originales son muy grandes.
          cacheWidth: 720,
          gaplessPlayback: true,
          // Si falta la imagen, la app no se cae: muestra el color de siempre.
          // DIAGNÓSTICO: si no encuentra la imagen, lo escribe en pantalla.
          // Cuando todo funcione, puedes dejarlo: solo se ve si hay un error.
          errorBuilder: (_, error, __) {
            debugPrint('No se pudo cargar $imagen: $error');
            return ColoredBox(
              color: const Color(0xFF1A1014),
              child: Align(
                alignment: Alignment.topCenter,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      'No se encontró: $imagen',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          decoration: TextDecoration.none),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        ColoredBox(color: Colors.black.withAlpha((capa * 255).round())),
        child,
      ],
    );
  }
}