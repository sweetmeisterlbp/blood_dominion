import 'package:flutter/material.dart';

import 'boton_oscuro.dart';
import 'idioma.dart';
import 'main.dart';

// ====================== AVISOS DE INICIO ======================
// Tutorial para jugadores nuevos y recompensa diaria.

// Se llama una vez al abrir el menú principal.
Future<void> avisosDeInicio(BuildContext context) async {
  if (!juego.personajeCreado) return;
  if (!juego.tutorialVisto) {
    await mostrarTutorial(context);
  }
  if (!context.mounted) return;
  if (juego.puedeReclamarDiaria) {
    await mostrarRecompensaDiaria(context);
  }
}

// ====================== TUTORIAL ======================

class _PaginaTutorial {
  final IconData icono;
  final String titulo;
  final String texto;
  const _PaginaTutorial(this.icono, this.titulo, this.texto);
}

List<_PaginaTutorial> _paginasTutorial() => [
  const _PaginaTutorial(
    Icons.auto_stories,
    'Bienvenido a Blood Dominion',
    'Eres un aventurero que elige su propio camino: el bien o el mal. '
        'Casi todo lo que haces suma puntos de inclinación hacia uno de los dos lados.',
  ),
  _PaginaTutorial(
    Icons.map,
    'Misiones',
    'Sal a una aventura de 5 a 30 minutos y vuelve a cobrar oro y fama. '
        'Cada salida cuesta $costoMision de oro y tienes '
        '${bloquesPorDia * minutosPorBloque} minutos de misión al día, que se reinician a las 00:00. '
        'Puedes cerrar el juego mientras esperas: te avisaremos cuando termine.',
  ),
  const _PaginaTutorial(
    Icons.local_bar,
    'Taberna',
    'Trabaja de 1 a 12 horas por un sueldo seguro. Si abandonas antes de terminar, no cobras. '
        'Mientras trabajas no puedes salir de misión ni pelear.',
  ),
  const _PaginaTutorial(
    Icons.fitness_center,
    'Entrenamiento',
    'Cada nivel te da 3 puntos de habilidad (armadura, una mano y dos manos) '
        'que te dejan usar mejor equipo. Atributos como Poder o Vigor se compran con oro.',
  ),
  const _PaginaTutorial(
    Icons.gavel,
    'Combate y equipo',
    'En la Cripta y la Ciudadela peleas contra enemigos; en la Arena, contra otros jugadores. '
        'Compra y equipa armas y armaduras en la Tienda. Tu vida se recupera sola con el tiempo.',
  ),
];

Future<void> mostrarTutorial(BuildContext context) async {
  final paginas = _paginasTutorial();
  int pagina = 0;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setStateDialogo) {
        final p = paginas[pagina];
        final ultima = pagina == paginas.length - 1;
        return AlertDialog(
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(p.icono, size: 56, color: Colors.amber),
                  const SizedBox(height: 12),
                  Text(tr(p.titulo),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(tr(p.texto),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < paginas.length; i++)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                            i == pagina ? Colors.amber : Colors.white24,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (!ultima)
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(tr('Saltar')),
              ),
            ElevatedButton(
              onPressed: () {
                if (ultima) {
                  Navigator.pop(ctx);
                } else {
                  setStateDialogo(() => pagina++);
                }
              },
              child: Text(ultima ? tr('¡A jugar!') : tr('Siguiente')),
            ),
          ],
        );
      },
    ),
  );
  // Tanto al terminar como al saltar: no se vuelve a mostrar solo.
  juego.marcarTutorialVisto();
}

// ====================== RECOMPENSA DIARIA ======================

IconData _iconoRecompensa(RecompensaDiaria r) {
  if (r.gemas > 0) return Icons.diamond;
  if (r.bloques > 0) return Icons.schedule;
  return Icons.monetization_on;
}

String _textoRecompensa(RecompensaDiaria r, {bool doble = false}) {
  final partes = <String>[
    '${juego.oroDiario(r) * (doble ? 2 : 1)} ${tr('de oro')}',
    if (r.gemas > 0) '${r.gemas} ${r.gemas == 1 ? tr('gema') : tr('gemas')}',
    if (r.bloques > 0) '+${r.bloques * minutosPorBloque} ${tr('min de misión hoy')}',
  ];
  return partes.join('  |  ');
}

Future<void> mostrarRecompensaDiaria(BuildContext context) async {
  if (!juego.puedeReclamarDiaria) return;
  final messenger = ScaffoldMessenger.of(context);
  final racha = juego.rachaParaReclamar;
  final indice = (racha - 1) % recompensasDiarias.length;
  final hoy = recompensasDiarias[indice];

  void aviso(String texto) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(texto)));
  }

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.card_giftcard, color: Colors.amber),
          const SizedBox(width: 8),
          Expanded(child: Text(tr('Recompensa diaria'))),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${tr('Racha')}: $racha ${racha == 1 ? tr('día') : tr('días')}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(tr('Entra cada día para no perder la racha.'),
                style: const TextStyle(
                    fontStyle: FontStyle.italic, fontSize: 12)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (int i = 0; i < recompensasDiarias.length; i++)
                  Container(
                    width: 40,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: i == indice
                          ? const Color(0xFF5A0F1B)
                          : const Color(0xFF241419),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: i == indice
                              ? Colors.amber
                              : const Color(0xFF3F2A31)),
                    ),
                    child: Column(
                      children: [
                        Text('${i + 1}', style: const TextStyle(fontSize: 11)),
                        const SizedBox(height: 2),
                        Icon(
                          i < indice
                              ? Icons.check_circle
                              : _iconoRecompensa(recompensasDiarias[i]),
                          size: 18,
                          color: i < indice ? Colors.lightGreenAccent : Colors.amber,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text('${tr('Hoy')}: ${_textoRecompensa(hoy)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: BotonOscuro(
                texto: tr('Reclamar'),
                alto: 46,
                color: ColorBoton.azul,
                onPressed: () {
                  final msg = juego.reclamarRecompensaDiaria();
                  Navigator.pop(ctx);
                  aviso(msg);
                },
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: BotonOscuro(
                texto: juego.sinAnuncios
                    ? tr('Reclamar con oro x2')
                    : tr('Reclamar con oro x2 (ver anuncio)'),
                alto: 46,
                color: ColorBoton.verde,
                onPressed: juego.puedeVerAnuncio
                    ? () {
                  final r = juego.pedirAnuncio(() {
                    final msg = juego.recompensaDiariaDoble();
                    if (ctx.mounted) Navigator.pop(ctx);
                    aviso(msg);
                  });
                  if (r != null) aviso(r);
                }
                    : null,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(tr('Más tarde')),
        ),
      ],
    ),
  );
}