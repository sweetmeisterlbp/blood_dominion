import 'package:flutter/material.dart';
import 'idioma.dart';
import 'main.dart';

// ====================== TUTORIAL NUEVO ======================
// Una ventana con varias páginas que se deslizan. Cada página explica una
// parte del juego con íconos y frases cortas. Al terminar (o al saltarlo)
// se marca como visto. Para cambiar el contenido, edita la lista [_pasos].

class _Linea {
  final IconData icono;
  final String texto;
  const _Linea(this.icono, this.texto);
}

class _Paso {
  final IconData icono;
  final Color color;
  final String titulo;
  final String intro;
  final List<_Linea> lineas;
  const _Paso(this.icono, this.color, this.titulo, this.intro, this.lineas);
}

const List<_Paso> _pasos = [
  _Paso(
    Icons.shield_moon,
    Color(0xFFE03A3A),
    'Bienvenido a Blood Dominion',
    'Eres un aventurero que quiere dejar su nombre en el ranking. '
        'Abajo tienes 5 pestañas, y cada una tiene sus sub-pestañas arriba.',
    [
      _Linea(Icons.home, 'Inicio: tu perfil, equipo, entrenamiento, altar, logros y bestiario.'),
      _Linea(Icons.gavel, 'Combate: Arena, Cripta, Ciudadela, jefes, ranking y eventos.'),
      _Linea(Icons.map, 'Misiones: trabajos, taberna y dados.'),
      _Linea(Icons.store, 'Comercio: tienda, mercado negro, afilador y premium.'),
      _Linea(Icons.forum, 'Social: chat global con traductor, amigos y mensajes privados.'),
    ],
  ),
  _Paso(
    Icons.fitness_center,
    Color(0xFF4CAF50),
    'Hazte fuerte',
    'Tu personaje tiene 6 atributos. Entrénalos con oro en '
        'Inicio › Entrenar.',
    [
      _Linea(Icons.flash_on, 'Poder y Maestría: pegas más fuerte y más seguido.'),
      _Linea(Icons.favorite, 'Vigor y Aguante: más vida y más resistencia.'),
      _Linea(Icons.speed, 'Agilidad: esquivas y atacas antes.'),
      _Linea(Icons.shield, 'Guardia: bloqueas más daño.'),
      _Linea(Icons.touch_app, 'Toca cualquier atributo en tu perfil para ver qué hace.'),
    ],
  ),
  _Paso(
    Icons.monetization_on,
    Color(0xFFFFC107),
    'Consigue oro',
    'El oro sirve para entrenar y comprar equipo. Hay varias formas de ganarlo.',
    [
      _Linea(Icons.map, 'Misiones y Taberna: manda a tu aventurero a trabajar y cobra al volver.'),
      _Linea(Icons.lock_clock, 'Mientras trabajas no puedes pelear. Puedes abandonar el trabajo.'),
      _Linea(Icons.card_giftcard, 'Reclama la recompensa diaria: cuantos más días seguidos, mejor.'),
      _Linea(Icons.checklist, 'Misiones › Diarias: 3 desafíos nuevos cada día y un bono por completarlos.'),
      _Linea(Icons.emoji_events, 'Combate › Torneo: gana en la Arena toda la semana y los 10 mejores cobran premio.'),
      _Linea(Icons.health_and_safety, 'Defenderte de un ataque también te da oro.'),
      _Linea(Icons.casino, 'Los dados de la taberna son un riesgo: puedes ganar o perder.'),
    ],
  ),
  _Paso(
    Icons.gavel,
    Color(0xFFE03A3A),
    'Combate',
    'Ganar combates te da Fama. Con la Fama subes de nivel. '
        'Necesitas tener vida para pelear, y se recupera sola con el tiempo.',
    [
      _Linea(Icons.church, 'Cripta: hordas oscuras. Vencerlas te da puntos de bien.'),
      _Linea(Icons.location_city, 'Ciudadela: seres de luz. Atacarlos te da puntos de mal.'),
      _Linea(Icons.emoji_events, 'Arena: pelea contra otros jugadores y róbales oro.'),
      _Linea(Icons.whatshot, 'Jefes: 1 intento al día por jefe. Dan mucho oro.'),
      _Linea(Icons.menu_book, 'Bestiario (en Inicio): cada bestia que vences se anota y te da esquirlas.'),
    ],
  ),
  _Paso(
    Icons.balance,
    Color(0xFF2EE6D6),
    'Bien, mal y títulos',
    'Tus puntos de bien o de mal forman tu inclinación. Se ve en tu perfil.',
    [
      _Linea(Icons.auto_awesome, 'Con puntos de bien ganas títulos de Luz, como Heraldo de la Luz o Paladín.'),
      _Linea(Icons.nights_stay, 'Con puntos de mal ganas títulos de Sombra, como Verdugo o Señor del Terror.'),
      _Linea(Icons.lock_open, 'Las mejores armas y armaduras piden una inclinación mínima para usarlas.'),
      _Linea(Icons.swap_horiz, 'Puedes cambiar de camino: los puntos suben y bajan según lo que hagas.'),
    ],
  ),
  _Paso(
    Icons.backpack,
    Color(0xFF9C6BFF),
    'Equípate',
    'El equipo cambia todo en un combate.',
    [
      _Linea(Icons.store, 'Comercio › Tienda: compra armas, escudos, armaduras y joyas.'),
      _Linea(Icons.shield, 'Inicio › Equipo: elige qué llevas puesto y revisa tu inventario.'),
      _Linea(Icons.build, 'El Afilador mejora el filo de tu arma.'),
      _Linea(Icons.storefront, 'El Mercado negro tiene objetos especiales.'),
    ],
  ),
  _Paso(
    Icons.visibility,
    Color(0xFFFF8A65),
    'Te pueden atacar',
    'Otros jugadores pueden atacarte en la Arena, aunque no estés conectado.',
    [
      _Linea(Icons.notifications_active, 'Al abrir el juego te avisamos de los ataques que recibiste.'),
      _Linea(Icons.history, 'Combate › Historial › Defensas: mira cada ataque, quién ganó y las rondas.'),
      _Linea(Icons.health_and_safety, 'Después de un ataque quedas protegido durante una hora.'),
    ],
  ),
  _Paso(
    Icons.calendar_month,
    Color(0xFFFFD54A),
    'Vuelve cada día',
    'Todos los días hay algo nuevo.',
    [
      _Linea(Icons.card_giftcard, 'Recompensa diaria con racha.'),
      _Linea(Icons.whatshot, 'Los jefes se renuevan cada día.'),
      _Linea(Icons.local_fire_department, 'Los domingos llega el evento del Inmortal, en Combate › Eventos.'),
      _Linea(Icons.help_outline, 'Puedes ver este tutorial otra vez desde Ajustes.'),
    ],
  ),
];

// Muestra el tutorial. Al cerrarlo (con "¡A jugar!" o "Saltar") queda como visto.
Future<void> mostrarTutorialNuevo(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _DialogoTutorial(),
  );
  juego.marcarTutorialVisto();
}

class _DialogoTutorial extends StatefulWidget {
  const _DialogoTutorial();

  @override
  State<_DialogoTutorial> createState() => _DialogoTutorialState();
}

class _DialogoTutorialState extends State<_DialogoTutorial> {
  final PageController _pagina = PageController();
  int _actual = 0;

  @override
  void dispose() {
    _pagina.dispose();
    super.dispose();
  }

  void _siguiente() {
    if (_actual >= _pasos.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    _pagina.nextPage(
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Widget _contenido(_Paso p) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.color.withAlpha(40),
              border: Border.all(color: p.color, width: 2),
            ),
            child: Icon(p.icono, color: p.color, size: 32),
          ),
          const SizedBox(height: 12),
          Text(tr(p.titulo),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(tr(p.intro),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
          const SizedBox(height: 14),
          for (final l in p.lineas)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(l.icono, size: 20, color: p.color),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(tr(l.texto),
                          style: const TextStyle(fontSize: 13.5))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ultima = _actual == _pasos.length - 1;
    final alto = MediaQuery.of(context).size.height;
    return Dialog(
      backgroundColor: const Color(0xFF1E1014),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF5A2030)),
      ),
      child: SizedBox(
        height: alto * 0.78 > 560 ? 560 : alto * 0.78,
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pagina,
                itemCount: _pasos.length,
                onPageChanged: (i) => setState(() => _actual = i),
                itemBuilder: (_, i) => _contenido(_pasos[i]),
              ),
            ),
            // Puntos que muestran en qué página vas
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < _pasos.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _actual ? 18 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == _actual
                          ? _pasos[_actual].color
                          : Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  TextButton(
                    onPressed: ultima ? null : () => Navigator.of(context).pop(),
                    child: Text(ultima ? '' : tr('Saltar')),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _siguiente,
                    child: Text(ultima ? tr('¡A jugar!') : tr('Siguiente')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}