import 'package:flutter/material.dart';
import 'main.dart';

// ====================== SUBIDA DE NIVEL ======================

// Puntos de habilidad con los que empieza el personaje
const int puntosHabilidadIniciales = 3;

// Oro de regalo al subir de nivel: nivel nuevo x este valor
// (al llegar al nivel 3 ganas 30 de oro)
const int oroBonoPorNivel = 10;

// Mensaje pendiente de mostrar. Lo llena revisarSubidaDeNivel y lo
// muestra y borra mostrarMensajeSubidaNivel.
String? mensajeSubidaNivel;

// Sube de nivel mientras haya fama suficiente. Por cada nivel ganado da
// 3 puntos de habilidad y el bono de oro. Si subes varios niveles de golpe,
// suma el oro de todos y deja un solo mensaje con el nivel final.
void revisarSubidaDeNivel(EstadoJuego j) {
  final nivelInicial = j.nivel;
  int oroBono = 0;
  while (j.nivel < nivelMaximo && j.xp >= famaParaSubir(j.nivel)) {
    j.xp -= famaParaSubir(j.nivel);
    j.nivel++;
    j.puntosLibres += 3;
    oroBono += j.nivel * oroBonoPorNivel;
  }
  if (j.nivel >= nivelMaximo) j.xp = 0;
  if (j.nivel > nivelInicial) {
    j.oro += oroBono;
    mensajeSubidaNivel =
    '¡Felicidades!!! Has subido de nivel, ahora tienes nivel ${j.nivel}! '
        'Ganaste $oroBono de oro.';
  }
}

// Si hay un mensaje pendiente, abre la ventana de felicitación (una sola vez).
// Se llama desde el build del menú principal.
void mostrarMensajeSubidaNivel(BuildContext context) {
  final mensaje = mensajeSubidaNivel;
  if (mensaje == null) return;
  mensajeSubidaNivel = null;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¡Subiste de nivel!'),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  });
}