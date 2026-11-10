import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';

/// Imágenes de objetos.
///
/// Guarda cada imagen en  assets/objetos/<nombre_en_minusculas>.png
/// (sin tildes, espacios -> "_"), por ejemplo:
///   "Kris de hierro oxidado"  ->  assets/objetos/kris_de_hierro_oxidado.png
///
/// Si todavía no existe la imagen, se muestra [respaldo] (o un icono genérico),
/// así puedes ir agregando imágenes de a poco sin que el juego falle.
String archivoImagenObjeto(String nombre) {
  const de = 'áàäâéèëêíìïîóòöôúùüûñ';
  const a = 'aaaaeeeeiiiioooouuuun';
  final b = StringBuffer();
  for (final r in nombre.toLowerCase().runes) {
    final c = String.fromCharCode(r);
    final i = de.indexOf(c);
    b.write(i >= 0 ? a[i] : c);
  }
  final s = b
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return 'assets/objetos/$s.png';
}

class ImagenObjeto extends StatelessWidget {
  final String nombre;
  final double tamano;
  final Widget? respaldo;
  const ImagenObjeto(
      {super.key, required this.nombre, this.tamano = 56, this.respaldo});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: tamano,
      height: tamano,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(lerpDouble(4, 10, tamano / 128)!),
        child: Image.asset(
          archivoImagenObjeto(nombre),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
          respaldo ??
              Container(
                color: Colors.black26,
                child: Icon(Icons.shield_outlined,
                    size: tamano * 0.5, color: Colors.white38),
              ),
        ),
      ),
    );
  }
}