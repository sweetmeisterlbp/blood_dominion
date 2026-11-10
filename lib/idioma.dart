import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ====================== IDIOMA ======================
// Cómo se usa: en vez de escribir  Text('Misiones')  se escribe
//   Text(tr('Misiones'))
// El texto en español es la "llave": si existe en el diccionario de abajo se
// muestra su traducción; si no existe, se muestra tal cual (en español).
// Para textos con datos: tr('Ganaste {n} de oro', {'n': oro}).
// Así se puede ir traduciendo el juego pantalla por pantalla sin romper nada.

class Idioma extends ChangeNotifier {
  Idioma._();
  static final Idioma instancia = Idioma._();

  static const Map<String, String> nombres = {
    'es': 'Español',
    'en': 'English',
    'pt': 'Português',
  };

  String codigo = 'es';

  // Se llama al abrir el juego: usa el idioma guardado o, si no hay, el del teléfono.
  Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final guardado = prefs.getString('idioma');
      if (guardado != null && nombres.containsKey(guardado)) {
        codigo = guardado;
      } else {
        final sistema =
            WidgetsBinding.instance.platformDispatcher.locale.languageCode;
        codigo = nombres.containsKey(sistema) ? sistema : 'en';
      }
    } catch (_) {
      // Si falla la lectura, se queda en español.
    }
    notifyListeners();
  }

  Future<void> cambiar(String nuevo) async {
    if (!nombres.containsKey(nuevo) || nuevo == codigo) return;
    codigo = nuevo;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('idioma', nuevo);
    } catch (_) {}
  }
}

String tr(String es, [Map<String, Object> datos = const {}]) {
  final c = Idioma.instancia.codigo;
  var r = es;
  if (c != 'es') {
    final t = _textos[es];
    if (t != null) r = t[c == 'en' ? 0 : 1];
  }
  datos.forEach((k, v) => r = r.replaceAll('{$k}', '$v'));
  return r;
}

// Español -> [inglés, portugués]
const Map<String, List<String>> _textos = {
  // ---- Secciones y menús ----
  'Personaje': ['Character', 'Personagem'],
  'Misiones': ['Missions', 'Missões'],
  'Combate': ['Combat', 'Combate'],
  'Tienda': ['Shop', 'Loja'],
  'Entrenamiento': ['Training', 'Treinamento'],
  'Entrenar': ['Train', 'Treinar'],
  'Inventario': ['Inventory', 'Inventário'],
  'Armado del personaje': ['Character loadout', 'Equipamento do personagem'],
  'Armado': ['Loadout', 'Equipamento'],
  'Ranking': ['Ranking', 'Ranking'],
  'Taberna': ['Tavern', 'Taverna'],
  'Altar de los dioses': ['Altar of the Gods', 'Altar dos Deuses'],
  'Altar': ['Altar', 'Altar'],
  'Premium y compras': ['Premium & purchases', 'Premium e compras'],
  'Premium': ['Premium', 'Premium'],
  'Más': ['More', 'Mais'],
  // ---- Ajustes y sesión ----
  'Ajustes': ['Settings', 'Configurações'],
  'Idioma': ['Language', 'Idioma'],
  'Cerrar sesión': ['Log out', 'Sair da conta'],
  '¿Cerrar sesión?': ['Log out?', 'Sair da conta?'],
  'Tu progreso queda guardado en tu cuenta.': [
    'Your progress is saved to your account.',
    'Seu progresso fica salvo na sua conta.'
  ],
  'Cancelar': ['Cancel', 'Cancelar'],
  'Salir': ['Exit', 'Sair'],
  'Cerrar': ['Close', 'Fechar'],
  // ---- Reloj y medalla ----
  'Hora del servidor. Las misiones se reinician a las 00:00.': [
    'Server time. Missions reset at 00:00.',
    'Hora do servidor. As missões reiniciam às 00:00.'
  ],
  'Jugador Premium': ['Premium player', 'Jogador Premium'],
  // ---- Pantalla Premium y compras ----
  'Gemas': ['Gems', 'Gemas'],
  'Oro': ['Gold', 'Ouro'],
  'No tienes Premium activo.': [
    'You have no active Premium.',
    'Você não tem Premium ativo.'
  ],
  'Premium activo: quedan {d} d {h} h.': [
    'Premium active: {d} d {h} h left.',
    'Premium ativo: faltam {d} d {h} h.'
  ],
  'Misiones: {n} min al día (en vez de {m}).': [
    'Missions: {n} min per day (instead of {m}).',
    'Missões: {n} min por dia (em vez de {m}).'
  ],
  'Taberna: +{p}% de sueldo.': [
    'Tavern: +{p}% pay.',
    'Taverna: +{p}% de salário.'
  ],
  'Gemas en la taberna: {p}% por hora (en vez de {q}%).': [
    'Gems at the tavern: {p}% per hour (instead of {q}%).',
    'Gemas na taverna: {p}% por hora (em vez de {q}%).'
  ],
  'Espera entre ataques: {n} min (en vez de {m}).': [
    'Wait between attacks: {n} min (instead of {m}).',
    'Espera entre ataques: {n} min (em vez de {m}).'
  ],
  'Si compras Premium estando activo, los días se suman.': [
    'If you buy Premium while it is active, the days add up.',
    'Se você comprar Premium com ele ativo, os dias se somam.'
  ],
  'Modo prueba: la tienda no está conectada, las compras se simulan sin cobrar.': [
    'Test mode: the store is not connected, purchases are simulated at no charge.',
    'Modo de teste: a loja não está conectada, as compras são simuladas sem cobrança.'
  ],
  'La tienda no está disponible en este momento.': [
    'The store is not available right now.',
    'A loja não está disponível no momento.'
  ],
  'Las compras se procesan con la tienda de tu dispositivo. El Premium no se renueva solo.': [
    'Purchases are processed by your device\'s store. Premium does not renew automatically.',
    'As compras são processadas pela loja do seu dispositivo. O Premium não renova sozinho.'
  ],
  'No disponible': ['Not available', 'Indisponível'],
  'Premium 7 días': ['Premium 7 days', 'Premium 7 dias'],
  'Premium 30 días': ['Premium 30 days', 'Premium 30 dias'],
  'Una semana de ventajas premium.': [
    'One week of premium perks.',
    'Uma semana de vantagens premium.'
  ],
  'Un mes de ventajas premium. El mejor valor.': [
    'One month of premium perks. Best value.',
    'Um mês de vantagens premium. O melhor valor.'
  ],
  '50 gemas': ['50 gems', '50 gemas'],
  '275 gemas': ['275 gems', '275 gemas'],
  '600 gemas': ['600 gems', '600 gemas'],
  'Un puñado de gemas.': ['A handful of gems.', 'Um punhado de gemas.'],
  'Una bolsa de gemas.': ['A bag of gems.', 'Uma bolsa de gemas.'],
  'Un cofre de gemas.': ['A chest of gems.', 'Um baú de gemas.'],
  '2.000 de oro': ['2,000 gold', '2.000 de ouro'],
  '11.000 de oro': ['11,000 gold', '11.000 de ouro'],
  '25.000 de oro': ['25,000 gold', '25.000 de ouro'],
  'Una bolsa de monedas.': ['A bag of coins.', 'Uma bolsa de moedas.'],
  'Un saco de monedas.': ['A sack of coins.', 'Um saco de moedas.'],
  'Un cofre del tesoro.': ['A treasure chest.', 'Um baú do tesouro.'],
  'La tienda no está disponible ahora. Inténtalo más tarde.': [
    'The store is not available right now. Please try again later.',
    'A loja não está disponível agora. Tente novamente mais tarde.'
  ],
  'Compra cancelada.': ['Purchase canceled.', 'Compra cancelada.'],
  'No se pudo iniciar la compra.': [
    'Could not start the purchase.',
    'Não foi possível iniciar a compra.'
  ],
  '¡Compra lista!': ['Purchase complete!', 'Compra concluída!'],
};