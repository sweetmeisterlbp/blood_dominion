// Catálogo de equipo de Blood Dominion.
//
// Generado desde la planilla Guia_Equipamiento_BloodDominion.xlsx
// (686 objetos en tienda). Si cambias números en la planilla,
// se vuelve a generar este archivo.
//
// main.dart usa este archivo con:  import 'catalogo.dart';

import 'package:flutter/material.dart';

// Categorías de objetos (cada una es un apartado de la tienda).
enum TipoObjeto {
  armaUnaMano,
  armaDosManos,
  escudo,
  armadura,
  anillo,
  colgante,
}

// Ranuras de equipo. Las armas de una y dos manos comparten la ranura "arma".
// El personaje lleva DOS anillos: anillo y anillo2 (los dos aceptan cualquier anillo).
enum Ranura { arma, escudo, armadura, anillo, anillo2, colgante }

extension InfoTipoObjeto on TipoObjeto {
  Ranura get ranura {
    switch (this) {
      case TipoObjeto.armaUnaMano:
      case TipoObjeto.armaDosManos:
        return Ranura.arma;
      case TipoObjeto.escudo:
        return Ranura.escudo;
      case TipoObjeto.armadura:
        return Ranura.armadura;
      case TipoObjeto.anillo:
        return Ranura.anillo;
      case TipoObjeto.colgante:
        return Ranura.colgante;
    }
  }

  // Nombre corto para las pestañas de la tienda
  String get pestana {
    switch (this) {
      case TipoObjeto.armaUnaMano:
        return 'Una mano';
      case TipoObjeto.armaDosManos:
        return 'Dos manos';
      case TipoObjeto.escudo:
        return 'Escudos';
      case TipoObjeto.armadura:
        return 'Armaduras';
      case TipoObjeto.anillo:
        return 'Anillos';
      case TipoObjeto.colgante:
        return 'Colgantes';
    }
  }

  // Qué significa el valor del objeto
  String get etiquetaValor {
    switch (this) {
      case TipoObjeto.armaUnaMano:
      case TipoObjeto.armaDosManos:
        return 'Daño';
      case TipoObjeto.escudo:
      case TipoObjeto.armadura:
        return 'Defensa';
      case TipoObjeto.anillo:
      case TipoObjeto.colgante:
        return 'Bonus';
    }
  }

  IconData get icono {
    switch (this) {
      case TipoObjeto.armaUnaMano:
      case TipoObjeto.armaDosManos:
        return Icons.gavel;
      case TipoObjeto.escudo:
        return Icons.shield;
      case TipoObjeto.armadura:
        return Icons.checkroom;
      case TipoObjeto.anillo:
        return Icons.circle_outlined;
      case TipoObjeto.colgante:
        return Icons.diamond;
    }
  }
}

extension InfoRanura on Ranura {
  String get nombre {
    switch (this) {
      case Ranura.arma:
        return 'Arma';
      case Ranura.escudo:
        return 'Escudo';
      case Ranura.armadura:
        return 'Armadura';
      case Ranura.anillo:
        return 'Anillo';
      case Ranura.anillo2:
        return 'Anillo 2';
      case Ranura.colgante:
        return 'Colgante';
    }
  }
}

// Un objeto de equipo.
//  - Armas: pegan un valor al azar entre [danoMin] y [danoMax] en cada golpe.
//  - Escudos y armaduras: defienden un valor al azar entre [danoMin] y [danoMax].
//  - Todos pueden dar bonos a los 6 atributos (positivos o negativos).
class Objeto {
  final String nombre;
  final TipoObjeto tipo;
  final int nivelRequerido; // nivel mínimo del jugador para equiparlo
  final int habilidadMin; // puntos mínimos en su habilidad para equiparlo
  final int danoMin; // daño (armas) o defensa (escudos, armaduras) mínimo
  final int danoMax; // daño o defensa máximo
  // Bonos a los atributos del personaje
  final int poder;
  final int vigor;
  final int agilidad;
  final int maestria; // Maestría de combate
  final int guardia;
  final int aguante;
  // Inclinación REQUERIDA para equiparlo: positivo = puntos de bien mínimos,
  // negativo = puntos de mal mínimos. No es un bono: el objeto da sus
  // atributos reales y la inclinación es solo lo que hay que tener para usarlo.
  // Valor = 50% de los puntos que se pueden juntar de un solo lado hasta ese nivel
  // (misiones de 5 min + taberna, promedio entre premium y sin premium).
  // Sale de la suma de famaParaSubir(l) / (10 * factorFamaMision(l)) * 1,114;
  // si cambias esas fórmulas de main.dart, hay que recalcular estos números.
  final int inclinacion;
  final int precio;
  final bool conGemas; // true: se paga con gemas; false: con oro
  final bool bazar; // true: viene del bazar; false: de la tienda
  // Veces que el afilador ambulante afiló esta copia (0 a 3). Cada afilado
  // suma +1 al daño mínimo y máximo (ya incluido en danoMin y danoMax).
  final int afilado;
  // Nombre que le puso el jugador (null = el de siempre). Solo se ve en tus
  // pantallas; no se publica a otros jugadores.
  final String? apodo;

  const Objeto(
      this.nombre,
      this.tipo, {
        int nivel = 1,
        int hab = 0,
        this.danoMin = 0,
        this.danoMax = 0,
        this.poder = 0,
        this.vigor = 0,
        this.agilidad = 0,
        this.maestria = 0,
        this.guardia = 0,
        this.aguante = 0,
        this.inclinacion = 0,
        this.precio = 0,
        this.conGemas = false,
        this.bazar = false,
        this.afilado = 0,
        this.apodo,
      })  : nivelRequerido = nivel,
        habilidadMin = hab;

  // Copia de este objeto con [n] afilados (0 = sin afilar). Pone el daño en
  // base + n: no se acumula sobre el afilado que ya tuviera.
  Objeto _copia(int n, String? apodoNuevo) => Objeto(nombre, tipo,
      nivel: nivelRequerido,
      hab: habilidadMin,
      danoMin: danoMin - afilado + n,
      danoMax: danoMax - afilado + n,
      poder: poder,
      vigor: vigor,
      agilidad: agilidad,
      maestria: maestria,
      guardia: guardia,
      aguante: aguante,
      inclinacion: inclinacion,
      precio: precio,
      conGemas: conGemas,
      bazar: bazar,
      afilado: n,
      apodo: apodoNuevo);

  Objeto conAfilado(int n) => _copia(n, apodo);
  Objeto conApodo(String? nuevo) => _copia(afilado, nuevo);

  // Lo que se muestra como nombre: el apodo o, si no hay, el de siempre.
  String get nombreMostrado => apodo ?? nombre;

  // Clave para apilar copias idénticas (mismo objeto, afilado y apodo).
  String get claveApilado => '$nombre|$afilado|${apodo ?? ''}';

  // Dos copias son "iguales" si son el mismo objeto con el mismo afilado y apodo.
  // Así se apilan juntas (x2) y una copia afilada no se confunde con otra.
  @override
  bool operator ==(Object otro) =>
      otro is Objeto &&
          otro.nombre == nombre &&
          otro.afilado == afilado &&
          otro.apodo == apodo;

  @override
  int get hashCode => Object.hash(nombre, afilado, apodo);

  // Valor medio del rango (se usa para comparar y mostrar)
  double get valorMedio => (danoMin + danoMax) / 2;
  int get valor => valorMedio.round();

  // Bono del objeto a un atributo, con el mismo nombre que usa el juego
  int bonoDe(String atributo) {
    switch (atributo) {
      case 'Poder':
        return poder;
      case 'Vigor':
        return vigor;
      case 'Agilidad':
        return agilidad;
      case 'Maestría de combate':
        return maestria;
      case 'Guardia':
        return guardia;
      case 'Aguante':
        return aguante;
    }
    return 0;
  }

  // Bonos como mapa {'Poder': 3, 'Vigor': -1} (los usa el juego para sumar atributos)
  Map<String, int> get bonos => {
    if (poder != 0) 'Poder': poder,
    if (vigor != 0) 'Vigor': vigor,
    if (agilidad != 0) 'Agilidad': agilidad,
    if (maestria != 0) 'Maestría de combate': maestria,
    if (guardia != 0) 'Guardia': guardia,
    if (aguante != 0) 'Aguante': aguante,
  };

  String get requisitos {
    final partes = <String>['nivel $nivelRequerido'];
    if (habilidadMin > 0) partes.add('habilidad $habilidadMin');
    if (inclinacion > 0) partes.add('$inclinacion puntos de bien');
    if (inclinacion < 0) partes.add('${-inclinacion} puntos de mal');
    return 'Pide ${partes.join(', ')}';
  }

  String get textoPrecio => conGemas ? '$precio esquirlas' : '$precio oro';

  // "+3 Poder, -2 Agilidad" (vacío si no da bonos)
  String get textoBonos {
    final partes = <String>[];
    void agregar(int v, String nombreAtributo) {
      if (v == 0) return;
      final signo = v > 0 ? '+' : '';
      partes.add('$signo$v $nombreAtributo');
    }

    agregar(poder, 'Poder');
    agregar(vigor, 'Vigor');
    agregar(agilidad, 'Agilidad');
    agregar(maestria, 'Maestría');
    agregar(guardia, 'Guardia');
    agregar(aguante, 'Aguante');
    return partes.join(', ');
  }

  bool get esArmaOProteccion =>
      tipo == TipoObjeto.armaUnaMano ||
          tipo == TipoObjeto.armaDosManos ||
          tipo == TipoObjeto.escudo ||
          tipo == TipoObjeto.armadura;

  // Resumen corto: "daño 5-8", "defensa 3-6" o los bonos (anillos, colgantes)
  String get resumen {
    if (esArmaOProteccion) {
      return '${tipo.etiquetaValor.toLowerCase()} $danoMin-$danoMax';
    }
    return textoBonos.isEmpty ? 'sin bonos' : textoBonos;
  }

  // Texto de varias líneas para la tienda y el inventario
  String detalle({bool conPrecio = true}) {
    final lineas = <String>[];
    if (esArmaOProteccion) {
      lineas.add('${tipo.etiquetaValor} $danoMin-$danoMax');
    }
    if (textoBonos.isNotEmpty) lineas.add(textoBonos);
    lineas.add(conPrecio ? '$requisitos  |  $textoPrecio' : requisitos);
    return lineas.join('\n');
  }
}

// Suma el bono de un atributo de varios objetos (los vacíos no cuentan)
int bonoDeObjetos(String atributo, Iterable<Objeto?> objetos) {
  int total = 0;
  for (final o in objetos) {
    if (o != null) total += o.bonoDe(atributo);
  }
  return total;
}

// Todos los objetos del juego.
const List<Objeto> catalogo = [
  // ---------------- ARMAS DE UNA MANO (154) ----------------
  Objeto('Espada de entrenamiento de madera', TipoObjeto.armaUnaMano, danoMin: 1, danoMax: 3),
  Objeto('Sable de hierro oxidado', TipoObjeto.armaUnaMano, hab: 2, danoMin: 5, danoMax: 8, poder: 1, precio: 200),
  Objeto('Kris de hierro oxidado', TipoObjeto.armaUnaMano, nivel: 2, hab: 4, danoMin: 6, danoMax: 9, agilidad: 1, maestria: 1, precio: 400),
  Objeto('Lamento de la Tormenta', TipoObjeto.armaUnaMano, nivel: 3, hab: 5, danoMin: 8, danoMax: 11, poder: 1, agilidad: 1, precio: 200, conGemas: true),
  Objeto('Espada de hierro oxidado', TipoObjeto.armaUnaMano, nivel: 5, hab: 8, danoMin: 6, danoMax: 11, aguante: -1, precio: 800),
  Objeto('Furia de la Forja Negra', TipoObjeto.armaUnaMano, nivel: 5, hab: 9, danoMin: 8, danoMax: 11, precio: 1100, bazar: true),
  Objeto('Aguijón del Rey Caído', TipoObjeto.armaUnaMano, nivel: 5, hab: 9, danoMin: 9, danoMax: 11, agilidad: 1, maestria: 1, aguante: 1, precio: 280, conGemas: true, bazar: true),
  Objeto('Misericordia de hierro oxidado', TipoObjeto.armaUnaMano, nivel: 6, hab: 9, danoMin: 8, danoMax: 11, agilidad: 1, precio: 1000),
  Objeto('Falcata de hierro oxidado', TipoObjeto.armaUnaMano, nivel: 6, hab: 11, danoMin: 8, danoMax: 12, aguante: -1, precio: 1400),
  Objeto('Sentencia de la Niebla', TipoObjeto.armaUnaMano, nivel: 7, hab: 12, danoMin: 9, danoMax: 14, aguante: -2, precio: 500, conGemas: true),
  Objeto('Promesa del Cazador', TipoObjeto.armaUnaMano, nivel: 9, hab: 15, danoMin: 9, danoMax: 12, aguante: -3, precio: 1800),
  Objeto('Cimitarra de hierro oxidado', TipoObjeto.armaUnaMano, nivel: 9, hab: 15, danoMin: 9, danoMax: 14, maestria: 1, aguante: -2, precio: 2000, bazar: true),
  Objeto('Venganza de la Hoguera', TipoObjeto.armaUnaMano, nivel: 9, hab: 15, danoMin: 11, danoMax: 14, aguante: -1, precio: 500, conGemas: true, bazar: true),
  Objeto('Martillo de los Malditos', TipoObjeto.armaUnaMano, nivel: 9, hab: 16, danoMin: 11, danoMax: 14, agilidad: -3, aguante: 2, poder: 1, inclinacion: -315, precio: 2120),
  Objeto('Yunque de la Absolución', TipoObjeto.armaUnaMano, nivel: 9, hab: 16, danoMin: 11, danoMax: 14, poder: 2, agilidad: -3, aguante: 2, maestria: 1, inclinacion: 315, precio: 2120),
  Objeto('Promesa del Rey Caído', TipoObjeto.armaUnaMano, nivel: 10, hab: 18, danoMin: 11, danoMax: 15, aguante: -4, precio: 2400),
  Objeto('Lamento del Cazador', TipoObjeto.armaUnaMano, nivel: 12, hab: 20, danoMin: 14, danoMax: 17, agilidad: 1, maestria: 2, aguante: -5, precio: 1000, conGemas: true),
  Objeto('Estoque de hierro viejo', TipoObjeto.armaUnaMano, nivel: 13, hab: 22, danoMin: 12, danoMax: 17, agilidad: 2, maestria: 1, aguante: -2, precio: 2770, bazar: true),
  Objeto('Suspiro de la Niebla', TipoObjeto.armaUnaMano, nivel: 13, hab: 22, danoMin: 14, danoMax: 17, poder: 1, agilidad: 1, maestria: 1, aguante: -5, precio: 950, conGemas: true, bazar: true),
  Objeto('Alfanje de hierro viejo', TipoObjeto.armaUnaMano, nivel: 14, hab: 23, danoMin: 12, danoMax: 17, aguante: -5, precio: 3230),
  Objeto('Colmillo del Verdugo', TipoObjeto.armaUnaMano, nivel: 15, hab: 26, danoMin: 14, danoMax: 18, agilidad: 1, maestria: 1, aguante: -6, precio: 3950),
  Objeto('Martillo de la Profanación', TipoObjeto.armaUnaMano, nivel: 16, hab: 26, danoMin: 17, danoMax: 20, poder: 2, agilidad: -7, aguante: 4, inclinacion: -900, precio: 4510),
  Objeto('Beso del Redentor', TipoObjeto.armaUnaMano, nivel: 16, hab: 26, danoMin: 17, danoMax: 20, agilidad: 4, maestria: 2, aguante: -7, inclinacion: 900, precio: 4510),
  Objeto('Martillo de hierro forjado', TipoObjeto.armaUnaMano, nivel: 16, hab: 27, danoMin: 17, danoMax: 21, poder: 2, agilidad: -2, aguante: -6, precio: 4760, bazar: true),
  Objeto('Venganza de la Ruina', TipoObjeto.armaUnaMano, nivel: 16, hab: 27, danoMin: 17, danoMax: 23, poder: 1, vigor: 1, aguante: -4, precio: 950, conGemas: true, bazar: true),
  Objeto('Juramento del Invierno', TipoObjeto.armaUnaMano, nivel: 17, hab: 28, danoMin: 17, danoMax: 21, poder: 2, maestria: 1, aguante: -6, precio: 4970),
  Objeto('Sentencia de la Luna Roja', TipoObjeto.armaUnaMano, nivel: 17, hab: 28, danoMin: 20, danoMax: 26, poder: 1, aguante: -6, precio: 1100, conGemas: true),
  Objeto('Espada corta de hierro forjado', TipoObjeto.armaUnaMano, nivel: 18, hab: 30, danoMin: 18, danoMax: 23, poder: 1, maestria: 1, aguante: -5, precio: 5450, bazar: true),
  Objeto('Aguijón del Penitente', TipoObjeto.armaUnaMano, nivel: 18, hab: 30, danoMin: 20, danoMax: 26, poder: 1, agilidad: 1, maestria: 2, aguante: -4, precio: 1100, conGemas: true, bazar: true),
  Objeto('Gladius de hierro forjado', TipoObjeto.armaUnaMano, nivel: 19, hab: 31, danoMin: 18, danoMax: 24, maestria: 2, aguante: -7, precio: 6420),
  Objeto('Susurro de los Condenados', TipoObjeto.armaUnaMano, nivel: 20, hab: 34, danoMin: 20, danoMax: 24, poder: 1, agilidad: 1, maestria: 1, aguante: -7, precio: 7580),
  Objeto('Sable de hierro forjado', TipoObjeto.armaUnaMano, nivel: 22, hab: 35, danoMin: 21, danoMax: 26, poder: 1, maestria: 1, guardia: 1, aguante: -8, precio: 9370),
  Objeto('Colmillo del Lobo Gris', TipoObjeto.armaUnaMano, nivel: 22, hab: 36, danoMin: 24, danoMax: 30, poder: 1, agilidad: 2, maestria: 2, aguante: -7, precio: 1300, conGemas: true),
  Objeto('Daga de hierro forjado', TipoObjeto.armaUnaMano, nivel: 23, hab: 38, danoMin: 23, danoMax: 27, poder: 2, agilidad: 1, maestria: 1, aguante: -8, precio: 10700),
  Objeto('Espada corta de bronce', TipoObjeto.armaUnaMano, nivel: 24, hab: 39, danoMin: 23, danoMax: 32, poder: 2, vigor: 1, maestria: 1, guardia: 1, aguante: -7, precio: 11300, bazar: true),
  Objeto('Garra del Exiliado', TipoObjeto.armaUnaMano, nivel: 24, hab: 39, danoMin: 26, danoMax: 32, poder: 2, agilidad: 2, maestria: 1, aguante: -6, precio: 1300, conGemas: true, bazar: true),
  Objeto('Cuchilla de bronce', TipoObjeto.armaUnaMano, nivel: 25, hab: 41, danoMin: 26, danoMax: 30, poder: 2, agilidad: 2, aguante: -9, precio: 12100),
  Objeto('Estilete de bronce', TipoObjeto.armaUnaMano, nivel: 26, hab: 43, danoMin: 27, danoMax: 32, poder: 2, vigor: 1, agilidad: 2, maestria: 1, aguante: -9, precio: 14000),
  Objeto('Colmillo de la Hoguera', TipoObjeto.armaUnaMano, nivel: 28, hab: 45, danoMin: 29, danoMax: 35, poder: 1, agilidad: 4, maestria: 2, aguante: -8, precio: 1400, conGemas: true),
  Objeto('Daga de bronce', TipoObjeto.armaUnaMano, nivel: 28, hab: 45, danoMin: 27, danoMax: 33, poder: 2, agilidad: 2, maestria: 1, aguante: -12, precio: 15500, bazar: true),
  Objeto('Colmillo del Exiliado', TipoObjeto.armaUnaMano, nivel: 28, hab: 46, danoMin: 29, danoMax: 36, poder: 2, agilidad: 5, maestria: 1, aguante: -4, precio: 1500, conGemas: true, bazar: true),
  Objeto('Kris de bronce', TipoObjeto.armaUnaMano, nivel: 29, hab: 47, danoMin: 29, danoMax: 32, poder: 2, agilidad: 3, maestria: 1, aguante: -10, precio: 16300),
  Objeto('Lamento de la Plegaria', TipoObjeto.armaUnaMano, nivel: 31, hab: 50, danoMin: 29, danoMax: 33, poder: 2, agilidad: 3, maestria: 3, aguante: -9, inclinacion: 3325, precio: 18300),
  Objeto('Susurro del Tirano', TipoObjeto.armaUnaMano, nivel: 31, hab: 50, danoMin: 29, danoMax: 33, agilidad: 3, maestria: 1, aguante: -9, poder: 1, inclinacion: -3325, precio: 18300),
  Objeto('Estoque de bronce', TipoObjeto.armaUnaMano, nivel: 31, hab: 51, danoMin: 27, danoMax: 38, agilidad: 2, maestria: 2, aguante: -10, precio: 18000, bazar: true),
  Objeto('Lamento del Nómada', TipoObjeto.armaUnaMano, nivel: 31, hab: 51, danoMin: 29, danoMax: 38, agilidad: 5, maestria: 2, aguante: -8, precio: 1500, conGemas: true, bazar: true),
  Objeto('Estilete de acero', TipoObjeto.armaUnaMano, nivel: 32, hab: 51, danoMin: 30, danoMax: 35, poder: 2, agilidad: 4, maestria: 3, aguante: -10, precio: 20500),
  Objeto('Mordisco del Penitente', TipoObjeto.armaUnaMano, nivel: 33, hab: 54, danoMin: 32, danoMax: 38, poder: 1, agilidad: 5, maestria: 2, aguante: -9, precio: 1500, conGemas: true),
  Objeto('Daga de acero', TipoObjeto.armaUnaMano, nivel: 35, hab: 57, danoMin: 30, danoMax: 36, poder: 2, agilidad: 4, maestria: 3, aguante: -11, precio: 22800),
  Objeto('Florete de acero', TipoObjeto.armaUnaMano, nivel: 36, hab: 58, danoMin: 32, danoMax: 38, poder: 1, agilidad: 5, maestria: 2, aguante: -8, precio: 24000, bazar: true),
  Objeto('Aguijón de la Tormenta', TipoObjeto.armaUnaMano, nivel: 36, hab: 58, danoMin: 33, danoMax: 41, agilidad: 6, maestria: 2, aguante: -7, precio: 1500, conGemas: true, bazar: true),
  Objeto('Estoque de acero', TipoObjeto.armaUnaMano, nivel: 36, hab: 59, danoMin: 32, danoMax: 39, poder: 1, agilidad: 4, maestria: 2, aguante: -11, precio: 24400),
  Objeto('Hoja corta de acero', TipoObjeto.armaUnaMano, nivel: 38, hab: 61, danoMin: 33, danoMax: 41, poder: 2, agilidad: 4, maestria: 1, aguante: -11, precio: 25500),
  Objeto('Cuchilla de acero', TipoObjeto.armaUnaMano, nivel: 39, hab: 62, danoMin: 33, danoMax: 42, poder: 2, agilidad: 4, maestria: 2, aguante: -10, precio: 26000, bazar: true),
  Objeto('Aguijón de las Sombras', TipoObjeto.armaUnaMano, nivel: 39, hab: 62, danoMin: 36, danoMax: 45, vigor: 2, agilidad: 5, maestria: 2, aguante: -8, precio: 1600, conGemas: true, bazar: true),
  Objeto('Garra del Herrero Ciego', TipoObjeto.armaUnaMano, nivel: 39, hab: 63, danoMin: 38, danoMax: 45, vigor: 2, agilidad: 5, maestria: 2, aguante: -10, precio: 1600, conGemas: true),
  Objeto('Hoja corta de acero templado', TipoObjeto.armaUnaMano, nivel: 41, hab: 66, danoMin: 35, danoMax: 42, agilidad: 5, maestria: 3, aguante: -12, precio: 26900),
  Objeto('Kris de acero templado', TipoObjeto.armaUnaMano, nivel: 41, hab: 68, danoMin: 36, danoMax: 44, poder: 2, agilidad: 3, maestria: 2, aguante: -14, precio: 27000, bazar: true),
  Objeto('Lamento del Ocaso', TipoObjeto.armaUnaMano, nivel: 41, hab: 68, danoMin: 39, danoMax: 47, poder: 1, agilidad: 6, maestria: 1, aguante: -10, precio: 1600, conGemas: true, bazar: true),
  Objeto('Estoque de acero templado', TipoObjeto.armaUnaMano, nivel: 42, hab: 69, danoMin: 36, danoMax: 45, poder: 1, agilidad: 5, maestria: 3, aguante: -12, precio: 28000),
  Objeto('Suspiro de Sangre Vieja', TipoObjeto.armaUnaMano, nivel: 44, hab: 70, danoMin: 38, danoMax: 47, poder: 1, agilidad: 5, maestria: 3, aguante: -12, precio: 29400),
  Objeto('Misericordia de acero templado', TipoObjeto.armaUnaMano, nivel: 44, hab: 72, danoMin: 38, danoMax: 48, poder: 2, agilidad: 6, maestria: 1, aguante: -11, precio: 30000, bazar: true),
  Objeto('Colmillo de la Ruina', TipoObjeto.armaUnaMano, nivel: 44, hab: 72, danoMin: 41, danoMax: 51, poder: 1, agilidad: 6, maestria: 1, aguante: -11, precio: 1700, conGemas: true, bazar: true),
  Objeto('Florete de acero templado', TipoObjeto.armaUnaMano, nivel: 45, hab: 73, danoMin: 39, danoMax: 50, agilidad: 5, maestria: 2, aguante: -12, precio: 30500),
  Objeto('Mordisco del Cazador', TipoObjeto.armaUnaMano, nivel: 47, hab: 76, danoMin: 44, danoMax: 54, poder: 1, agilidad: 7, maestria: 2, aguante: -11, precio: 1700, conGemas: true),
  Objeto('Suspiro del Cazador', TipoObjeto.armaUnaMano, nivel: 47, hab: 77, danoMin: 41, danoMax: 51, agilidad: 5, maestria: 2, aguante: -13, precio: 31000, bazar: true),
  Objeto('Aguijón de la Ruina', TipoObjeto.armaUnaMano, nivel: 47, hab: 77, danoMin: 44, danoMax: 54, poder: 1, agilidad: 8, maestria: 1, aguante: -10, precio: 1700, conGemas: true, bazar: true),
  Objeto('Kris de plata', TipoObjeto.armaUnaMano, nivel: 48, hab: 78, danoMin: 42, danoMax: 51, agilidad: 6, maestria: 2, aguante: -13, precio: 31900),
  Objeto('Beso de la Noche Eterna', TipoObjeto.armaUnaMano, nivel: 49, hab: 80, danoMin: 44, danoMax: 53, agilidad: 7, maestria: 2, aguante: -13, poder: 1, inclinacion: -7640, precio: 33000),
  Objeto('Mordisco del Alba', TipoObjeto.armaUnaMano, nivel: 49, hab: 80, danoMin: 44, danoMax: 53, poder: 1, agilidad: 7, maestria: 3, aguante: -13, inclinacion: 7640, precio: 33000),
  Objeto('Colmillo del Páramo', TipoObjeto.armaUnaMano, nivel: 50, hab: 81, danoMin: 44, danoMax: 53, agilidad: 5, maestria: 1, aguante: -13, precio: 33000, bazar: true),
  Objeto('Beso del Centinela', TipoObjeto.armaUnaMano, nivel: 50, hab: 81, danoMin: 47, danoMax: 56, poder: 2, agilidad: 6, maestria: 2, aguante: -12, precio: 1700, conGemas: true, bazar: true),
  Objeto('Hoja corta de plata', TipoObjeto.armaUnaMano, nivel: 51, hab: 82, danoMin: 44, danoMax: 54, poder: 1, agilidad: 6, maestria: 3, aguante: -13, precio: 34100),
  Objeto('Beso de la Forja Negra', TipoObjeto.armaUnaMano, nivel: 52, hab: 85, danoMin: 50, danoMax: 60, poder: 2, agilidad: 8, maestria: 4, aguante: -12, precio: 1800, conGemas: true),
  Objeto('Daga de plata', TipoObjeto.armaUnaMano, nivel: 54, hab: 86, danoMin: 47, danoMax: 57, agilidad: 6, maestria: 4, aguante: -13, precio: 35500),
  Objeto('Beso del Lobo Gris', TipoObjeto.armaUnaMano, nivel: 55, hab: 88, danoMin: 50, danoMax: 57, poder: 2, vigor: 2, agilidad: 7, maestria: 3, aguante: -14, precio: 37000, bazar: true),
  Objeto('Suspiro de la Hoguera', TipoObjeto.armaUnaMano, nivel: 55, hab: 88, danoMin: 51, danoMax: 62, poder: 1, agilidad: 8, maestria: 3, aguante: -13, precio: 1800, conGemas: true, bazar: true),
  Objeto('Misericordia de plata', TipoObjeto.armaUnaMano, nivel: 58, hab: 93, danoMin: 51, danoMax: 60, poder: 2, vigor: 2, agilidad: 7, maestria: 4, aguante: -15, precio: 40000, bazar: true),
  Objeto('Lamento del Verdugo', TipoObjeto.armaUnaMano, nivel: 58, hab: 93, danoMin: 54, danoMax: 65, poder: 1, agilidad: 8, maestria: 3, aguante: -13, precio: 1900, conGemas: true, bazar: true),
  Objeto('Estilete de obsidiana', TipoObjeto.armaUnaMano, nivel: 60, hab: 96, danoMin: 53, danoMax: 63, poder: 1, vigor: 2, agilidad: 7, maestria: 3, aguante: -15, precio: 39800),
  Objeto('Lamento de la Ruina', TipoObjeto.armaUnaMano, nivel: 62, hab: 100, danoMin: 54, danoMax: 65, poder: 2, agilidad: 7, maestria: 2, aguante: -15, precio: 41100),
  Objeto('Lamento de los Condenados', TipoObjeto.armaUnaMano, nivel: 64, hab: 103, danoMin: 60, danoMax: 74, poder: 2, agilidad: 9, maestria: 3, aguante: -14, precio: 2000, conGemas: true),
  Objeto('Daga de obsidiana', TipoObjeto.armaUnaMano, nivel: 66, hab: 107, danoMin: 57, danoMax: 69, poder: 2, agilidad: 8, maestria: 2, aguante: -16, precio: 46300, bazar: true),
  Objeto('Hoja corta de obsidiana', TipoObjeto.armaUnaMano, nivel: 68, hab: 109, danoMin: 59, danoMax: 71, poder: 2, agilidad: 8, maestria: 4, aguante: -16, precio: 47500, bazar: true),
  Objeto('Lamento del Pantano', TipoObjeto.armaUnaMano, nivel: 68, hab: 111, danoMin: 63, danoMax: 80, poder: 3, agilidad: 9, maestria: 2, aguante: -14, precio: 2100, conGemas: true),
  Objeto('Lamento del Pecado', TipoObjeto.armaUnaMano, nivel: 69, hab: 112, danoMin: 60, danoMax: 75, poder: 4, agilidad: 9, maestria: 2, aguante: -15, inclinacion: -13525, precio: 48700, bazar: true),
  Objeto('Mordisco del Mártir', TipoObjeto.armaUnaMano, nivel: 69, hab: 112, danoMin: 60, danoMax: 75, poder: 1, agilidad: 9, maestria: 5, aguante: -15, inclinacion: 13525, precio: 48700, bazar: true),
  Objeto('Cuchilla de obsidiana', TipoObjeto.armaUnaMano, nivel: 71, hab: 115, danoMin: 62, danoMax: 75, poder: 3, agilidad: 8, maestria: 5, aguante: -16, precio: 49900, bazar: true),
  Objeto('Susurro del Pantano', TipoObjeto.armaUnaMano, nivel: 73, hab: 117, danoMin: 68, danoMax: 84, poder: 2, agilidad: 9, maestria: 4, aguante: -14, precio: 2200, conGemas: true, bazar: true),
  Objeto('Estilete de hueso', TipoObjeto.armaUnaMano, nivel: 75, hab: 122, danoMin: 66, danoMax: 80, poder: 2, agilidad: 8, maestria: 4, aguante: -16, precio: 49200),
  Objeto('Mordisco de la Cripta', TipoObjeto.armaUnaMano, nivel: 77, hab: 124, danoMin: 66, danoMax: 81, poder: 2, agilidad: 8, maestria: 3, aguante: -16, precio: 50300),
  Objeto('Beso del Penitente', TipoObjeto.armaUnaMano, nivel: 79, hab: 127, danoMin: 74, danoMax: 90, poder: 3, agilidad: 10, maestria: 5, aguante: -15, precio: 2100, conGemas: true),
  Objeto('Misericordia de hueso', TipoObjeto.armaUnaMano, nivel: 81, hab: 130, danoMin: 71, danoMax: 84, poder: 2, agilidad: 8, maestria: 4, aguante: -16, precio: 52800),
  Objeto('Estoque de hueso', TipoObjeto.armaUnaMano, nivel: 82, hab: 132, danoMin: 72, danoMax: 87, poder: 2, agilidad: 8, maestria: 4, aguante: -16, precio: 53900),
  Objeto('Beso de la Luna Roja', TipoObjeto.armaUnaMano, nivel: 84, hab: 135, danoMin: 78, danoMax: 96, poder: 2, agilidad: 10, maestria: 3, aguante: -15, precio: 2200, conGemas: true),
  Objeto('Beso de los Condenados', TipoObjeto.armaUnaMano, nivel: 84, hab: 136, danoMin: 74, danoMax: 89, poder: 2, agilidad: 9, maestria: 4, aguante: -17, precio: 55300),
  Objeto('Susurro de la Sangre Negra', TipoObjeto.armaUnaMano, nivel: 87, hab: 139, danoMin: 77, danoMax: 92, poder: 6, agilidad: 9, maestria: 4, aguante: -16, inclinacion: -19450, precio: 60700, bazar: true),
  Objeto('Garra de la Bendición', TipoObjeto.armaUnaMano, nivel: 87, hab: 139, danoMin: 77, danoMax: 92, poder: 1, agilidad: 9, maestria: 7, aguante: -16, inclinacion: 19450, precio: 60700, bazar: true),
  Objeto('Beso del Ocaso', TipoObjeto.armaUnaMano, nivel: 89, hab: 143, danoMin: 83, danoMax: 99, poder: 3, agilidad: 10, maestria: 4, aguante: -15, precio: 2300, conGemas: true, bazar: true),
  Objeto('Cuchilla de hueso', TipoObjeto.armaUnaMano, nivel: 90, hab: 146, danoMin: 78, danoMax: 96, poder: 2, agilidad: 10, maestria: 5, aguante: -17, precio: 61200),
  Objeto('Susurro del Mercenario', TipoObjeto.armaUnaMano, nivel: 92, hab: 149, danoMin: 80, danoMax: 98, poder: 2, agilidad: 10, maestria: 5, aguante: -17, precio: 62500, bazar: true),
  Objeto('Garra del Rey Caído', TipoObjeto.armaUnaMano, nivel: 94, hab: 151, danoMin: 87, danoMax: 110, poder: 3, vigor: 4, agilidad: 11, maestria: 5, aguante: -16, precio: 2375, conGemas: true, bazar: true),
  Objeto('Hoja corta de hierro negro', TipoObjeto.armaUnaMano, nivel: 96, hab: 154, danoMin: 83, danoMax: 102, poder: 2, agilidad: 10, maestria: 5, aguante: -17, precio: 64100, bazar: true),
  Objeto('Estilete de hierro negro', TipoObjeto.armaUnaMano, nivel: 98, hab: 157, danoMin: 84, danoMax: 104, poder: 2, agilidad: 10, maestria: 4, aguante: -17, precio: 65700, bazar: true),
  Objeto('Lamento de la Luna Roja', TipoObjeto.armaUnaMano, nivel: 99, hab: 159, danoMin: 93, danoMax: 116, poder: 2, agilidad: 11, maestria: 6, aguante: -16, precio: 2450, conGemas: true),
  Objeto('Garra del Tirano', TipoObjeto.armaUnaMano, nivel: 101, hab: 163, danoMin: 89, danoMax: 107, poder: 5, vigor: 4, agilidad: 10, maestria: 4, aguante: -17, inclinacion: -24345, precio: 68900),
  Objeto('Mordisco de la Bendición', TipoObjeto.armaUnaMano, nivel: 101, hab: 163, danoMin: 89, danoMax: 107, poder: 2, agilidad: 10, maestria: 8, aguante: -17, inclinacion: 24345, precio: 68900),
  Objeto('Colmillo del Cuervo', TipoObjeto.armaUnaMano, nivel: 103, hab: 166, danoMin: 96, danoMax: 117, poder: 2, agilidad: 12, maestria: 4, aguante: -16, precio: 2525, conGemas: true),
  Objeto('Misericordia de hierro negro', TipoObjeto.armaUnaMano, nivel: 105, hab: 169, danoMin: 92, danoMax: 110, poder: 4, vigor: 4, agilidad: 10, maestria: 6, aguante: -18, precio: 70500),
  Objeto('Colmillo de la Ceniza', TipoObjeto.armaUnaMano, nivel: 107, hab: 173, danoMin: 99, danoMax: 122, poder: 4, agilidad: 12, maestria: 4, aguante: -16, precio: 2550, conGemas: true),
  Objeto('Garra de los Huesos', TipoObjeto.armaUnaMano, nivel: 107, hab: 173, danoMin: 93, danoMax: 111, poder: 3, agilidad: 10, maestria: 5, aguante: -18, precio: 71900),
  Objeto('Misericordia de sangre', TipoObjeto.armaUnaMano, nivel: 109, hab: 176, danoMin: 95, danoMax: 114, poder: 3, agilidad: 10, maestria: 5, aguante: -18, precio: 73300),
  Objeto('Aguijón del Centinela', TipoObjeto.armaUnaMano, nivel: 111, hab: 180, danoMin: 102, danoMax: 125, poder: 4, agilidad: 12, maestria: 5, aguante: -16, precio: 2575, conGemas: true),
  Objeto('Beso de la Sangre Negra', TipoObjeto.armaUnaMano, nivel: 122, hab: 196, danoMin: 102, danoMax: 125, poder: 7, agilidad: 11, maestria: 6, aguante: -18, inclinacion: -32040, precio: 79200),
  Objeto('Mordisco de la Luz Eterna', TipoObjeto.armaUnaMano, nivel: 122, hab: 196, danoMin: 102, danoMax: 125, poder: 2, agilidad: 11, maestria: 10, aguante: -18, inclinacion: 32040, precio: 79200),
  Objeto('Suspiro de la Tormenta', TipoObjeto.armaUnaMano, nivel: 122, hab: 196, danoMin: 110, danoMax: 134, poder: 4, agilidad: 12, maestria: 7, aguante: -16, precio: 2675, conGemas: true),
  Objeto('Estoque de sangre', TipoObjeto.armaUnaMano, nivel: 124, hab: 198, danoMin: 104, danoMax: 125, poder: 3, agilidad: 10, maestria: 7, aguante: -19, precio: 82900),
  Objeto('Lamento de la Cripta', TipoObjeto.armaUnaMano, nivel: 126, hab: 203, danoMin: 113, danoMax: 137, poder: 4, agilidad: 12, maestria: 6, aguante: -17, precio: 2700, conGemas: true),
  Objeto('Estilete de sangre', TipoObjeto.armaUnaMano, nivel: 128, hab: 205, danoMin: 107, danoMax: 128, poder: 4, agilidad: 10, maestria: 5, aguante: -19, precio: 85700),
  Objeto('Susurro de la Niebla', TipoObjeto.armaUnaMano, nivel: 130, hab: 209, danoMin: 116, danoMax: 141, poder: 3, agilidad: 12, maestria: 7, aguante: -17, precio: 2725, conGemas: true),
  Objeto('Beso de las Sombras', TipoObjeto.armaUnaMano, nivel: 130, hab: 209, danoMin: 108, danoMax: 129, poder: 2, vigor: 5, agilidad: 10, maestria: 7, aguante: -19, precio: 87100),
  Objeto('Lamento del Desterrado', TipoObjeto.armaUnaMano, nivel: 143, hab: 230, danoMin: 128, danoMax: 156, poder: 3, agilidad: 13, maestria: 6, aguante: -17, precio: 2800, conGemas: true),
  Objeto('Beso de la Bendición', TipoObjeto.armaUnaMano, nivel: 145, hab: 232, danoMin: 119, danoMax: 146, poder: 4, agilidad: 12, maestria: 11, aguante: -18, inclinacion: 40830, precio: 92400),
  Objeto('Garra de la Profanación', TipoObjeto.armaUnaMano, nivel: 145, hab: 232, danoMin: 119, danoMax: 146, poder: 8, agilidad: 12, maestria: 7, aguante: -18, inclinacion: -40830, precio: 92400),
  Objeto('Mordisco del Nómada', TipoObjeto.armaUnaMano, nivel: 147, hab: 236, danoMin: 131, danoMax: 161, poder: 5, agilidad: 13, maestria: 7, aguante: -17, precio: 2825, conGemas: true),
  Objeto('Garra del Mercenario', TipoObjeto.armaUnaMano, nivel: 147, hab: 236, danoMin: 123, danoMax: 147, poder: 4, vigor: 6, agilidad: 10, maestria: 7, aguante: -19, precio: 95600),
  Objeto('Cuchilla de ónix', TipoObjeto.armaUnaMano, nivel: 149, hab: 239, danoMin: 123, danoMax: 149, poder: 4, agilidad: 11, maestria: 8, aguante: -20, precio: 100000),
  Objeto('Suspiro del Cuervo', TipoObjeto.armaUnaMano, nivel: 151, hab: 243, danoMin: 135, danoMax: 165, poder: 3, vigor: 6, agilidad: 13, maestria: 9, aguante: -17, precio: 2850, conGemas: true, bazar: true),
  Objeto('Daga de ónix', TipoObjeto.armaUnaMano, nivel: 153, hab: 246, danoMin: 125, danoMax: 150, poder: 4, agilidad: 11, maestria: 8, aguante: -20, precio: 102000, bazar: true),
  Objeto('Florete de ónix', TipoObjeto.armaUnaMano, nivel: 155, hab: 250, danoMin: 129, danoMax: 155, poder: 5, vigor: 6, agilidad: 11, maestria: 7, aguante: -20, precio: 104000, bazar: true),
  Objeto('Mordisco de los Huesos', TipoObjeto.armaUnaMano, nivel: 155, hab: 250, danoMin: 138, danoMax: 170, poder: 4, agilidad: 13, maestria: 7, aguante: -17, precio: 2875, conGemas: true, bazar: true),
  Objeto('Misericordia de ónix', TipoObjeto.armaUnaMano, nivel: 157, hab: 252, danoMin: 131, danoMax: 156, poder: 5, agilidad: 11, maestria: 8, aguante: -20, precio: 105000),
  Objeto('Beso del Cuervo', TipoObjeto.armaUnaMano, nivel: 160, hab: 257, danoMin: 141, danoMax: 173, poder: 4, agilidad: 14, maestria: 7, aguante: -17, precio: 2900, conGemas: true, bazar: true),
  Objeto('Susurro del Serafín', TipoObjeto.armaUnaMano, nivel: 162, hab: 259, danoMin: 134, danoMax: 164, poder: 4, agilidad: 12, maestria: 14, aguante: -19, inclinacion: 47520, precio: 110000),
  Objeto('Mordisco del Hambre', TipoObjeto.armaUnaMano, nivel: 162, hab: 259, danoMin: 134, danoMax: 164, poder: 9, agilidad: 12, maestria: 8, aguante: -19, inclinacion: -47520, precio: 110000),
  Objeto('Aguijón del Pantano', TipoObjeto.armaUnaMano, nivel: 162, hab: 261, danoMin: 144, danoMax: 177, poder: 3, agilidad: 14, maestria: 8, aguante: -17, precio: 2925, conGemas: true),
  Objeto('Florete de runas antiguas', TipoObjeto.armaUnaMano, nivel: 164, hab: 263, danoMin: 135, danoMax: 164, poder: 4, vigor: 7, agilidad: 11, maestria: 8, aguante: -20, precio: 104000),
  Objeto('Suspiro del Pantano', TipoObjeto.armaUnaMano, nivel: 166, hab: 266, danoMin: 147, danoMax: 180, poder: 4, agilidad: 14, maestria: 8, aguante: -18, precio: 2950, conGemas: true),
  Objeto('Daga de runas antiguas', TipoObjeto.armaUnaMano, nivel: 168, hab: 270, danoMin: 140, danoMax: 168, poder: 5, agilidad: 11, maestria: 8, aguante: -20, precio: 112000),
  Objeto('Estoque de runas antiguas', TipoObjeto.armaUnaMano, nivel: 170, hab: 273, danoMin: 144, danoMax: 177, poder: 3, agilidad: 14, maestria: 8, aguante: -17, precio: 114000),
  Objeto('Aguijón del Verdugo', TipoObjeto.armaUnaMano, nivel: 170, hab: 273, danoMin: 152, danoMax: 185, poder: 3, agilidad: 14, maestria: 9, aguante: -18, precio: 2975, conGemas: true, bazar: true),
  Objeto('Hoja corta de runas antiguas', TipoObjeto.armaUnaMano, nivel: 172, hab: 277, danoMin: 143, danoMax: 173, poder: 3, agilidad: 11, maestria: 9, aguante: -20, precio: 115000, bazar: true),
  Objeto('Colmillo de Sangre Vieja', TipoObjeto.armaUnaMano, nivel: 174, hab: 279, danoMin: 155, danoMax: 189, poder: 4, agilidad: 14, maestria: 9, aguante: -18, precio: 3000, conGemas: true),
  Objeto('Misericordia de runas antiguas', TipoObjeto.armaUnaMano, nivel: 176, hab: 284, danoMin: 156, danoMax: 191, poder: 5, vigor: 7, agilidad: 15, maestria: 9, aguante: -18, precio: 113000),
  Objeto('Garra del Verdugo', TipoObjeto.armaUnaMano, nivel: 177, hab: 285, danoMin: 158, danoMax: 194, poder: 5, vigor: 7, agilidad: 15, maestria: 10, aguante: -18, precio: 3025, conGemas: true, bazar: true),
  Objeto('Colmillo del Custodio', TipoObjeto.armaUnaMano, nivel: 178, hab: 286, danoMin: 149, danoMax: 182, poder: 4, vigor: 7, agilidad: 12, maestria: 14, aguante: -19, inclinacion: 53930, precio: 121000),
  Objeto('Colmillo del Inquisidor Caído', TipoObjeto.armaUnaMano, nivel: 178, hab: 286, danoMin: 149, danoMax: 182, poder: 9, vigor: 7, agilidad: 12, maestria: 8, aguante: -19, inclinacion: -53930, precio: 121000),
  Objeto('Colmillo de la Luna Roja', TipoObjeto.armaUnaMano, nivel: 181, hab: 290, danoMin: 161, danoMax: 197, poder: 5, vigor: 7, agilidad: 15, maestria: 9, aguante: -18, precio: 3050, conGemas: true),
  Objeto('Estilete del abismo', TipoObjeto.armaUnaMano, nivel: 184, hab: 294, danoMin: 152, danoMax: 183, poder: 4, agilidad: 11, maestria: 9, aguante: -20, precio: 129000),
  Objeto('Daga del abismo', TipoObjeto.armaUnaMano, nivel: 187, hab: 300, danoMin: 153, danoMax: 186, poder: 6, agilidad: 12, maestria: 8, aguante: -21, precio: 138000),
  Objeto('Beso del Rey Caído', TipoObjeto.armaUnaMano, nivel: 190, hab: 305, danoMin: 170, danoMax: 206, poder: 5, agilidad: 15, maestria: 9, aguante: -18, precio: 3100, conGemas: true),
  Objeto('Cuchilla del abismo', TipoObjeto.armaUnaMano, nivel: 193, hab: 311, danoMin: 159, danoMax: 192, poder: 5, agilidad: 12, maestria: 10, aguante: -21, precio: 148000),
  Objeto('Florete del abismo', TipoObjeto.armaUnaMano, nivel: 197, hab: 316, danoMin: 162, danoMax: 195, poder: 6, agilidad: 12, maestria: 10, aguante: -21, precio: 157000),
  Objeto('Suspiro del Herrero Ciego', TipoObjeto.armaUnaMano, nivel: 200, hab: 321, danoMin: 179, danoMax: 215, poder: 6, agilidad: 16, maestria: 11, aguante: -18, precio: 3200, conGemas: true),

  // ---------------- ARMAS DE DOS MANOS (166) ----------------
  Objeto('Espadón de entrenamiento', TipoObjeto.armaDosManos, danoMin: 3, danoMax: 5, maestria: 1, precio: 80),
  Objeto('Montante de hierro oxidado', TipoObjeto.armaDosManos, nivel: 3, hab: 4, danoMin: 6, danoMax: 14, agilidad: -1, precio: 600),
  Objeto('Aniquilador del Cuervo', TipoObjeto.armaDosManos, nivel: 4, hab: 5, danoMin: 9, danoMax: 14, poder: 1, agilidad: -1, precio: 200, conGemas: true),
  Objeto('Hoja de guerra de hierro oxidado', TipoObjeto.armaDosManos, nivel: 5, hab: 8, danoMin: 11, danoMax: 15, agilidad: -2, aguante: -1, precio: 1200),
  Objeto('Plañidera de la Forja Negra', TipoObjeto.armaDosManos, nivel: 6, hab: 9, danoMin: 12, danoMax: 15, poder: 1, agilidad: -2, aguante: -1, precio: 1400, bazar: true),
  Objeto('Segadora del Cazador', TipoObjeto.armaDosManos, nivel: 6, hab: 9, danoMin: 12, danoMax: 17, agilidad: -1, aguante: -1, precio: 350, conGemas: true, bazar: true),
  Objeto('Espadón de hierro oxidado', TipoObjeto.armaDosManos, nivel: 6, hab: 11, danoMin: 12, danoMax: 15, poder: 1, agilidad: -3, aguante: -2, precio: 1600),
  Objeto('Mandato de la Tormenta', TipoObjeto.armaDosManos, nivel: 7, hab: 12, danoMin: 12, danoMax: 18, poder: 1, agilidad: -4, aguante: -3, precio: 500, conGemas: true),
  Objeto('Cortacabezas de hierro oxidado', TipoObjeto.armaDosManos, nivel: 8, hab: 14, danoMin: 14, danoMax: 18, poder: 1, agilidad: -4, aguante: -3, precio: 1700, bazar: true),
  Objeto('Sentencia Final del Rey Caído', TipoObjeto.armaDosManos, nivel: 8, hab: 14, danoMin: 15, danoMax: 18, poder: 1, agilidad: -4, maestria: 1, aguante: -4, precio: 600, conGemas: true, bazar: true),
  Objeto('Gran espada de hierro oxidado', TipoObjeto.armaDosManos, nivel: 8, hab: 15, danoMin: 14, danoMax: 18, poder: 2, agilidad: -5, aguante: -4, precio: 2300),
  Objeto('Aniquilador del Cuervo Maldito', TipoObjeto.armaDosManos, nivel: 9, hab: 16, danoMin: 15, danoMax: 20, poder: 3, agilidad: -5, aguante: -2, inclinacion: -315, precio: 2800),
  Objeto('Rompemundos de la Gracia', TipoObjeto.armaDosManos, nivel: 9, hab: 16, danoMin: 15, danoMax: 20, poder: 2, agilidad: -2, aguante: -4, inclinacion: 315, precio: 2800),
  Objeto('Gran espada de hierro viejo', TipoObjeto.armaDosManos, nivel: 9, hab: 16, danoMin: 18, danoMax: 23, agilidad: -5, aguante: -4, precio: 3600),
  Objeto('Mandato del Páramo', TipoObjeto.armaDosManos, nivel: 9, hab: 18, danoMin: 21, danoMax: 26, poder: 1, agilidad: -7, aguante: -6, precio: 4600),
  Objeto('Montante de hierro viejo', TipoObjeto.armaDosManos, nivel: 10, hab: 19, danoMin: 21, danoMax: 27, agilidad: -6, aguante: -5, precio: 4800),
  Objeto('Mandoble de hierro viejo', TipoObjeto.armaDosManos, nivel: 11, hab: 20, danoMin: 21, danoMax: 29, poder: 1, agilidad: -7, aguante: -6, precio: 5200),
  Objeto('Cortacabezas de hierro viejo', TipoObjeto.armaDosManos, nivel: 11, hab: 22, danoMin: 23, danoMax: 29, poder: 1, vigor: 1, agilidad: -6, aguante: -5, precio: 5400),
  Objeto('Mandato de la Ruina', TipoObjeto.armaDosManos, nivel: 12, hab: 23, danoMin: 24, danoMax: 32, poder: 1, agilidad: -7, maestria: 1, aguante: -6, precio: 1000, conGemas: true),
  Objeto('Decreto del Verdugo', TipoObjeto.armaDosManos, nivel: 13, hab: 26, danoMin: 24, danoMax: 32, poder: 1, agilidad: -8, aguante: -7, precio: 6190),
  Objeto('Mandato del Tirano', TipoObjeto.armaDosManos, nivel: 14, hab: 26, danoMin: 26, danoMax: 32, poder: 2, agilidad: -6, aguante: -4, inclinacion: -695, precio: 7140),
  Objeto('Sentencia Final de la Absolución', TipoObjeto.armaDosManos, nivel: 14, hab: 26, danoMin: 26, danoMax: 32, poder: 2, agilidad: -6, aguante: -3, inclinacion: 695, precio: 7140),
  Objeto('Hoja de guerra de hierro viejo', TipoObjeto.armaDosManos, nivel: 14, hab: 27, danoMin: 27, danoMax: 32, poder: 1, agilidad: -8, maestria: 1, aguante: -7, precio: 7360, bazar: true),
  Objeto('Segadora de las Sombras', TipoObjeto.armaDosManos, nivel: 14, hab: 27, danoMin: 27, danoMax: 35, poder: 1, agilidad: -8, aguante: -7, precio: 1100, conGemas: true, bazar: true),
  Objeto('Plañidera de Sangre Vieja', TipoObjeto.armaDosManos, nivel: 15, hab: 28, danoMin: 26, danoMax: 32, poder: 1, agilidad: -8, aguante: -8, precio: 8140),
  Objeto('Gran espada de hierro forjado', TipoObjeto.armaDosManos, nivel: 15, hab: 28, danoMin: 27, danoMax: 33, poder: 2, agilidad: -9, maestria: 1, aguante: -8, precio: 8840),
  Objeto('Quebrantahuesos de la Ruina', TipoObjeto.armaDosManos, nivel: 16, hab: 31, danoMin: 29, danoMax: 36, poder: 2, agilidad: -8, aguante: -9, precio: 1300, conGemas: true),
  Objeto('Lanza larga de hierro forjado', TipoObjeto.armaDosManos, nivel: 17, hab: 34, danoMin: 29, danoMax: 36, poder: 2, agilidad: -9, aguante: -10, precio: 11000),
  Objeto('Pica de asalto de hierro forjado', TipoObjeto.armaDosManos, nivel: 18, hab: 35, danoMin: 30, danoMax: 38, poder: 1, agilidad: -10, aguante: -11, precio: 12300),
  Objeto('Destructor de la Tormenta', TipoObjeto.armaDosManos, nivel: 19, hab: 36, danoMin: 32, danoMax: 39, poder: 3, agilidad: -10, aguante: -12, precio: 13900),
  Objeto('Derrumbe de los Huesos', TipoObjeto.armaDosManos, nivel: 20, hab: 38, danoMin: 35, danoMax: 41, poder: 3, agilidad: -10, aguante: -12, precio: 1700, conGemas: true),
  Objeto('Alabarda de hierro forjado', TipoObjeto.armaDosManos, nivel: 21, hab: 41, danoMin: 36, danoMax: 42, poder: 3, agilidad: -11, aguante: -14, precio: 16700),
  Objeto('Mangual pesado de hierro forjado', TipoObjeto.armaDosManos, nivel: 22, hab: 43, danoMin: 36, danoMax: 44, poder: 4, vigor: 1, agilidad: -11, aguante: -15, precio: 18700),
  Objeto('Hacha de guerra de hierro forjado', TipoObjeto.armaDosManos, nivel: 23, hab: 45, danoMin: 36, danoMax: 45, poder: 4, vigor: 1, agilidad: -11, aguante: -15, precio: 19900, bazar: true),
  Objeto('Destructor de la Forja Negra', TipoObjeto.armaDosManos, nivel: 23, hab: 45, danoMin: 38, danoMax: 47, poder: 3, vigor: 1, agilidad: -11, aguante: -15, precio: 1800, conGemas: true, bazar: true),
  Objeto('Guadaña de guerra de hierro forjado', TipoObjeto.armaDosManos, nivel: 23, hab: 46, danoMin: 38, danoMax: 45, poder: 3, agilidad: -12, aguante: -15, precio: 20500),
  Objeto('Gran maza de bronce', TipoObjeto.armaDosManos, nivel: 25, hab: 49, danoMin: 39, danoMax: 47, poder: 2, agilidad: -12, aguante: -15, precio: 23900),
  Objeto('Coloso del Herrero Ciego', TipoObjeto.armaDosManos, nivel: 26, hab: 51, danoMin: 42, danoMax: 51, poder: 3, agilidad: -11, aguante: -15, precio: 1900, conGemas: true),
  Objeto('Guadaña de guerra de bronce', TipoObjeto.armaDosManos, nivel: 28, hab: 55, danoMin: 41, danoMax: 50, poder: 5, agilidad: -12, aguante: -16, precio: 27000),
  Objeto('Destructor del Nómada', TipoObjeto.armaDosManos, nivel: 28, hab: 57, danoMin: 42, danoMax: 50, poder: 3, agilidad: -12, aguante: -16, precio: 27700, bazar: true),
  Objeto('Trueno de las Sombras', TipoObjeto.armaDosManos, nivel: 28, hab: 57, danoMin: 44, danoMax: 51, poder: 4, agilidad: -11, aguante: -16, precio: 2000, conGemas: true, bazar: true),
  Objeto('Castigo de la Sangre Negra', TipoObjeto.armaDosManos, nivel: 29, hab: 58, danoMin: 44, danoMax: 51, poder: 6, agilidad: -12, aguante: -16, inclinacion: -2930, precio: 29900),
  Objeto('Cataclismo del Mártir', TipoObjeto.armaDosManos, nivel: 29, hab: 58, danoMin: 44, danoMax: 51, poder: 4, agilidad: -12, aguante: -14, inclinacion: 2930, precio: 29900),
  Objeto('Lanza larga de bronce', TipoObjeto.armaDosManos, nivel: 30, hab: 61, danoMin: 45, danoMax: 53, poder: 5, agilidad: -13, aguante: -17, precio: 32300),
  Objeto('Castigo del Verdugo', TipoObjeto.armaDosManos, nivel: 32, hab: 63, danoMin: 50, danoMax: 57, poder: 4, agilidad: -12, aguante: -16, precio: 2100, conGemas: true),
  Objeto('Mangual pesado de bronce', TipoObjeto.armaDosManos, nivel: 33, hab: 66, danoMin: 48, danoMax: 56, poder: 3, agilidad: -13, aguante: -17, precio: 36700),
  Objeto('Hacha doble de bronce', TipoObjeto.armaDosManos, nivel: 34, hab: 68, danoMin: 48, danoMax: 56, poder: 4, agilidad: -13, aguante: -17, precio: 38500, bazar: true),
  Objeto('Derrumbe del Rey Caído', TipoObjeto.armaDosManos, nivel: 34, hab: 68, danoMin: 50, danoMax: 59, poder: 4, agilidad: -12, aguante: -17, precio: 2200, conGemas: true, bazar: true),
  Objeto('Pica de asalto de acero', TipoObjeto.armaDosManos, nivel: 35, hab: 70, danoMin: 51, danoMax: 57, poder: 4, agilidad: -13, aguante: -17, precio: 40100),
  Objeto('Rompemundos de la Peste', TipoObjeto.armaDosManos, nivel: 36, hab: 73, danoMin: 53, danoMax: 59, poder: 5, agilidad: -13, aguante: -18, precio: 42000),
  Objeto('Castigo de la Ceniza', TipoObjeto.armaDosManos, nivel: 38, hab: 76, danoMin: 56, danoMax: 63, poder: 6, agilidad: -13, aguante: -17, precio: 2300, conGemas: true),
  Objeto('Hacha doble de acero', TipoObjeto.armaDosManos, nivel: 39, hab: 78, danoMin: 56, danoMax: 63, poder: 5, agilidad: -14, aguante: -18, precio: 43900),
  Objeto('Mangual pesado de acero', TipoObjeto.armaDosManos, nivel: 40, hab: 80, danoMin: 54, danoMax: 65, poder: 4, agilidad: -13, aguante: -18, precio: 44800, bazar: true),
  Objeto('Derrumbe del Mercenario', TipoObjeto.armaDosManos, nivel: 40, hab: 80, danoMin: 56, danoMax: 68, poder: 4, agilidad: -12, aguante: -18, precio: 2400, conGemas: true, bazar: true),
  Objeto('Coloso del Verdugo Oscuro', TipoObjeto.armaDosManos, nivel: 41, hab: 82, danoMin: 57, danoMax: 65, poder: 9, agilidad: -13, aguante: -18, inclinacion: -5580, precio: 45500),
  Objeto('Cataclismo de la Absolución', TipoObjeto.armaDosManos, nivel: 41, hab: 82, danoMin: 57, danoMax: 65, poder: 4, agilidad: -13, aguante: -15, inclinacion: 5580, precio: 45500),
  Objeto('Martillo de guerra de acero', TipoObjeto.armaDosManos, nivel: 43, hab: 85, danoMin: 59, danoMax: 66, poder: 6, agilidad: -14, aguante: -19, precio: 47100),
  Objeto('Trueno del Ocaso', TipoObjeto.armaDosManos, nivel: 44, hab: 88, danoMin: 62, danoMax: 72, poder: 6, agilidad: -14, aguante: -18, precio: 2500, conGemas: true),
  Objeto('Lanza larga de acero', TipoObjeto.armaDosManos, nivel: 46, hab: 92, danoMin: 62, danoMax: 69, poder: 6, agilidad: -14, aguante: -19, precio: 49000),
  Objeto('Cataclismo del Rey Caído', TipoObjeto.armaDosManos, nivel: 47, hab: 95, danoMin: 63, danoMax: 71, poder: 6, agilidad: -15, aguante: -19, precio: 50600),
  Objeto('Alabarda de acero templado', TipoObjeto.armaDosManos, nivel: 48, hab: 96, danoMin: 63, danoMax: 72, poder: 5, agilidad: -15, aguante: -19, precio: 51500, bazar: true),
  Objeto('Rompemundos de la Forja Negra', TipoObjeto.armaDosManos, nivel: 48, hab: 96, danoMin: 65, danoMax: 75, poder: 6, agilidad: -14, aguante: -19, precio: 2600, conGemas: true, bazar: true),
  Objeto('Hacha doble de acero templado', TipoObjeto.armaDosManos, nivel: 49, hab: 97, danoMin: 65, danoMax: 72, poder: 6, agilidad: -14, aguante: -18, precio: 52500),
  Objeto('Pica de asalto de acero templado', TipoObjeto.armaDosManos, nivel: 50, hab: 100, danoMin: 65, danoMax: 75, poder: 6, agilidad: -15, aguante: -19, precio: 54100),
  Objeto('Derrumbe de Sangre Vieja', TipoObjeto.armaDosManos, nivel: 52, hab: 104, danoMin: 69, danoMax: 80, poder: 8, agilidad: -14, aguante: -19, precio: 2700, conGemas: true),
  Objeto('Hacha de guerra de acero templado', TipoObjeto.armaDosManos, nivel: 53, hab: 107, danoMin: 68, danoMax: 78, poder: 6, agilidad: -15, aguante: -20, precio: 56000),
  Objeto('Mangual pesado de acero templado', TipoObjeto.armaDosManos, nivel: 55, hab: 109, danoMin: 69, danoMax: 81, poder: 6, agilidad: -15, aguante: -20, precio: 57600),
  Objeto('Martillo de guerra de acero templado', TipoObjeto.armaDosManos, nivel: 55, hab: 111, danoMin: 71, danoMax: 83, poder: 7, agilidad: -15, aguante: -20, precio: 58200, bazar: true),
  Objeto('Rompemundos del Cazador', TipoObjeto.armaDosManos, nivel: 55, hab: 111, danoMin: 72, danoMax: 84, poder: 7, agilidad: -15, aguante: -20, precio: 2750, conGemas: true, bazar: true),
  Objeto('Trueno del Cazador', TipoObjeto.armaDosManos, nivel: 56, hab: 112, danoMin: 72, danoMax: 84, poder: 7, agilidad: -15, aguante: -20, precio: 59500),
  Objeto('Guadaña de guerra de acero templado', TipoObjeto.armaDosManos, nivel: 58, hab: 116, danoMin: 74, danoMax: 87, poder: 6, agilidad: -16, aguante: -20, precio: 61100),
  Objeto('Gran maza de acero templado', TipoObjeto.armaDosManos, nivel: 59, hab: 117, danoMin: 75, danoMax: 89, poder: 7, agilidad: -16, aguante: -21, precio: 62200, bazar: true),
  Objeto('Cataclismo del Centinela', TipoObjeto.armaDosManos, nivel: 59, hab: 117, danoMin: 77, danoMax: 92, poder: 8, agilidad: -16, aguante: -21, precio: 2800, conGemas: true, bazar: true),
  Objeto('Hacha doble de plata', TipoObjeto.armaDosManos, nivel: 60, hab: 122, danoMin: 80, danoMax: 90, poder: 8, agilidad: -16, aguante: -21, precio: 65000, bazar: true),
  Objeto('Trueno del Invierno', TipoObjeto.armaDosManos, nivel: 60, hab: 122, danoMin: 83, danoMax: 93, poder: 7, agilidad: -16, aguante: -21, precio: 2850, conGemas: true, bazar: true),
  Objeto('Gran maza de plata', TipoObjeto.armaDosManos, nivel: 62, hab: 124, danoMin: 83, danoMax: 92, poder: 7, agilidad: -17, aguante: -21, precio: 66800, bazar: true),
  Objeto('Rompemundos del Herrero Ciego', TipoObjeto.armaDosManos, nivel: 62, hab: 124, danoMin: 84, danoMax: 95, poder: 8, vigor: 3, agilidad: -17, aguante: -21, precio: 2900, conGemas: true, bazar: true),
  Objeto('Martillo de guerra de plata', TipoObjeto.armaDosManos, nivel: 63, hab: 127, danoMin: 84, danoMax: 93, poder: 7, agilidad: -17, aguante: -22, precio: 68500, bazar: true),
  Objeto('Coloso del Mercenario', TipoObjeto.armaDosManos, nivel: 63, hab: 127, danoMin: 86, danoMax: 96, poder: 7, agilidad: -17, aguante: -22, precio: 2950, conGemas: true, bazar: true),
  Objeto('Destructor del Herrero Ciego', TipoObjeto.armaDosManos, nivel: 62, hab: 124, danoMin: 86, danoMax: 96, poder: 8, agilidad: -18, aguante: -22, precio: 70000, bazar: true),
  Objeto('Cataclismo de los Huesos', TipoObjeto.armaDosManos, nivel: 65, hab: 131, danoMin: 87, danoMax: 98, poder: 8, agilidad: -18, aguante: -22, precio: 3000, conGemas: true, bazar: true),
  Objeto('Lanza larga de plata', TipoObjeto.armaDosManos, nivel: 66, hab: 134, danoMin: 89, danoMax: 96, poder: 8, agilidad: -18, aguante: -23, precio: 72000, bazar: true),
  Objeto('Cataclismo de la Niebla', TipoObjeto.armaDosManos, nivel: 66, hab: 134, danoMin: 90, danoMax: 99, poder: 7, agilidad: -18, aguante: -23, precio: 3050, conGemas: true, bazar: true),
  Objeto('Pica de asalto de obsidiana', TipoObjeto.armaDosManos, nivel: 68, hab: 136, danoMin: 90, danoMax: 99, poder: 8, agilidad: -19, aguante: -23, precio: 73800, bazar: true),
  Objeto('Destructor de la Viuda', TipoObjeto.armaDosManos, nivel: 68, hab: 136, danoMin: 92, danoMax: 102, poder: 10, vigor: 3, agilidad: -19, aguante: -23, precio: 3100, conGemas: true, bazar: true),
  Objeto('Hacha doble de obsidiana', TipoObjeto.armaDosManos, nivel: 70, hab: 140, danoMin: 92, danoMax: 101, poder: 9, vigor: 3, agilidad: -19, aguante: -23, precio: 75000, bazar: true),
  Objeto('Derrumbe de las Sombras', TipoObjeto.armaDosManos, nivel: 70, hab: 140, danoMin: 93, danoMax: 105, poder: 9, agilidad: -19, aguante: -24, precio: 3150, conGemas: true, bazar: true),
  Objeto('Hacha de guerra de obsidiana', TipoObjeto.armaDosManos, nivel: 71, hab: 143, danoMin: 93, danoMax: 102, poder: 8, agilidad: -20, aguante: -24, precio: 77000, bazar: true),
  Objeto('Castigo de los Huesos', TipoObjeto.armaDosManos, nivel: 71, hab: 143, danoMin: 95, danoMax: 105, poder: 9, agilidad: -20, aguante: -24, precio: 3200, conGemas: true, bazar: true),
  Objeto('Destructor de la Hoguera', TipoObjeto.armaDosManos, nivel: 73, hab: 146, danoMin: 96, danoMax: 102, poder: 9, agilidad: -20, aguante: -25, precio: 79000, bazar: true),
  Objeto('Coloso de la Niebla', TipoObjeto.armaDosManos, nivel: 73, hab: 146, danoMin: 96, danoMax: 108, poder: 9, agilidad: -20, aguante: -25, precio: 3250, conGemas: true, bazar: true),
  Objeto('Alabarda de obsidiana', TipoObjeto.armaDosManos, nivel: 74, hab: 150, danoMin: 96, danoMax: 105, poder: 11, agilidad: -21, aguante: -25, precio: 80500, bazar: true),
  Objeto('Rompemundos de las Sombras', TipoObjeto.armaDosManos, nivel: 74, hab: 150, danoMin: 98, danoMax: 110, poder: 10, agilidad: -21, aguante: -25, precio: 3300, conGemas: true, bazar: true),
  Objeto('Mangual pesado de obsidiana', TipoObjeto.armaDosManos, nivel: 76, hab: 153, danoMin: 96, danoMax: 107, poder: 10, agilidad: -21, aguante: -25, precio: 82000),
  Objeto('Quebrantahuesos de la Cripta', TipoObjeto.armaDosManos, nivel: 77, hab: 155, danoMin: 101, danoMax: 113, poder: 10, agilidad: -21, aguante: -24, precio: 3350, conGemas: true),
  Objeto('Derrumbe del Demonio', TipoObjeto.armaDosManos, nivel: 79, hab: 159, danoMin: 98, danoMax: 108, poder: 16, agilidad: -22, aguante: -26, inclinacion: -16755, precio: 85000),
  Objeto('Castigo del Serafín', TipoObjeto.armaDosManos, nivel: 79, hab: 159, danoMin: 98, danoMax: 108, poder: 11, agilidad: -22, aguante: -20, inclinacion: 16755, precio: 85000),
  Objeto('Gran maza de hueso', TipoObjeto.armaDosManos, nivel: 80, hab: 162, danoMin: 99, danoMax: 108, poder: 9, agilidad: -22, aguante: -26, precio: 86500),
  Objeto('Derrumbe del Centinela', TipoObjeto.armaDosManos, nivel: 82, hab: 165, danoMin: 104, danoMax: 116, poder: 10, agilidad: -21, aguante: -25, precio: 3400, conGemas: true),
  Objeto('Rompemundos de la Ceniza', TipoObjeto.armaDosManos, nivel: 83, hab: 169, danoMin: 101, danoMax: 110, poder: 11, agilidad: -22, aguante: -26, precio: 88500),
  Objeto('Alabarda de hueso', TipoObjeto.armaDosManos, nivel: 85, hab: 171, danoMin: 102, danoMax: 113, poder: 11, agilidad: -22, aguante: -27, precio: 91000, bazar: true),
  Objeto('Rompemundos del Invierno', TipoObjeto.armaDosManos, nivel: 86, hab: 174, danoMin: 107, danoMax: 120, poder: 11, vigor: 4, agilidad: -22, aguante: -26, precio: 3500, conGemas: true, bazar: true),
  Objeto('Pica de asalto de hueso', TipoObjeto.armaDosManos, nivel: 88, hab: 178, danoMin: 104, danoMax: 114, poder: 11, agilidad: -22, aguante: -27, precio: 94000, bazar: true),
  Objeto('Hacha doble de hueso', TipoObjeto.armaDosManos, nivel: 90, hab: 181, danoMin: 105, danoMax: 116, poder: 12, vigor: 4, agilidad: -23, aguante: -27, precio: 97000, bazar: true),
  Objeto('Quebrantahuesos del Pantano', TipoObjeto.armaDosManos, nivel: 91, hab: 184, danoMin: 111, danoMax: 126, poder: 12, agilidad: -22, aguante: -26, precio: 3450, conGemas: true),
  Objeto('Guadaña de guerra de hueso', TipoObjeto.armaDosManos, nivel: 91, hab: 184, danoMin: 107, danoMax: 119, poder: 11, agilidad: -23, aguante: -28, precio: 97200),
  Objeto('Lanza larga de hueso', TipoObjeto.armaDosManos, nivel: 94, hab: 190, danoMin: 108, danoMax: 120, poder: 12, agilidad: -23, aguante: -28, precio: 98000),
  Objeto('Rompemundos del Cuervo', TipoObjeto.armaDosManos, nivel: 96, hab: 193, danoMin: 117, danoMax: 131, poder: 12, agilidad: -23, aguante: -27, precio: 3500, conGemas: true),
  Objeto('Coloso de la Condenación', TipoObjeto.armaDosManos, nivel: 98, hab: 197, danoMin: 110, danoMax: 132, poder: 22, agilidad: -23, aguante: -28, inclinacion: -23275, precio: 104000),
  Objeto('Derrumbe de la Vela Eterna', TipoObjeto.armaDosManos, nivel: 98, hab: 197, danoMin: 110, danoMax: 132, poder: 12, agilidad: -23, aguante: -20, inclinacion: 23275, precio: 104000),
  Objeto('Alabarda de hierro negro', TipoObjeto.armaDosManos, nivel: 99, hab: 201, danoMin: 111, danoMax: 134, poder: 13, agilidad: -24, aguante: -28, precio: 106000),
  Objeto('Trueno del Rey Caído', TipoObjeto.armaDosManos, nivel: 101, hab: 204, danoMin: 128, danoMax: 146, poder: 13, agilidad: -22, aguante: -27, precio: 3550, conGemas: true),
  Objeto('Lanza larga de hierro negro', TipoObjeto.armaDosManos, nivel: 103, hab: 208, danoMin: 116, danoMax: 138, poder: 13, agilidad: -24, aguante: -29, precio: 110000),
  Objeto('Martillo de guerra de hierro negro', TipoObjeto.armaDosManos, nivel: 105, hab: 212, danoMin: 117, danoMax: 140, poder: 13, agilidad: -24, aguante: -29, precio: 112000, bazar: true),
  Objeto('Castigo del Páramo', TipoObjeto.armaDosManos, nivel: 106, hab: 215, danoMin: 135, danoMax: 153, poder: 14, agilidad: -23, aguante: -28, precio: 3600, conGemas: true, bazar: true),
  Objeto('Mangual pesado de hierro negro', TipoObjeto.armaDosManos, nivel: 108, hab: 219, danoMin: 122, danoMax: 146, poder: 14, vigor: 5, agilidad: -24, aguante: -29, precio: 116000, bazar: true),
  Objeto('Gran maza de hierro negro', TipoObjeto.armaDosManos, nivel: 110, hab: 223, danoMin: 123, danoMax: 149, poder: 14, agilidad: -24, aguante: -29, precio: 118000),
  Objeto('Cataclismo del Cazador', TipoObjeto.armaDosManos, nivel: 112, hab: 225, danoMin: 146, danoMax: 161, poder: 16, agilidad: -23, aguante: -28, precio: 3700, conGemas: true),
  Objeto('Quebrantahuesos de la Podredumbre', TipoObjeto.armaDosManos, nivel: 114, hab: 230, danoMin: 128, danoMax: 153, poder: 23, agilidad: -24, aguante: -29, inclinacion: -29065, precio: 116000),
  Objeto('Derrumbe de la Catedral', TipoObjeto.armaDosManos, nivel: 114, hab: 230, danoMin: 128, danoMax: 153, poder: 16, agilidad: -24, aguante: -20, inclinacion: 29065, precio: 116000),
  Objeto('Pica de asalto de sangre', TipoObjeto.armaDosManos, nivel: 115, hab: 234, danoMin: 129, danoMax: 156, poder: 15, agilidad: -25, aguante: -30, precio: 124000),
  Objeto('Quebrantahuesos del Desterrado', TipoObjeto.armaDosManos, nivel: 117, hab: 236, danoMin: 149, danoMax: 168, poder: 15, agilidad: -24, aguante: -29, precio: 3750, conGemas: true, bazar: true),
  Objeto('Alabarda de sangre', TipoObjeto.armaDosManos, nivel: 119, hab: 240, danoMin: 134, danoMax: 161, poder: 14, agilidad: -25, aguante: -30, precio: 128000),
  Objeto('Gran maza de sangre', TipoObjeto.armaDosManos, nivel: 121, hab: 244, danoMin: 135, danoMax: 162, poder: 16, agilidad: -25, aguante: -30, precio: 130000),
  Objeto('Cataclismo de Sangre Vieja', TipoObjeto.armaDosManos, nivel: 122, hab: 247, danoMin: 155, danoMax: 177, poder: 17, agilidad: -24, aguante: -30, precio: 3800, conGemas: true),
  Objeto('Lanza larga de sangre', TipoObjeto.armaDosManos, nivel: 124, hab: 251, danoMin: 140, danoMax: 168, poder: 15, agilidad: -25, aguante: -30, precio: 134000),
  Objeto('Trueno del Eclipse', TipoObjeto.armaDosManos, nivel: 125, hab: 254, danoMin: 141, danoMax: 170, poder: 25, agilidad: -25, aguante: -30, inclinacion: -33165, precio: 135000),
  Objeto('Castigo de la Vela Eterna', TipoObjeto.armaDosManos, nivel: 125, hab: 254, danoMin: 141, danoMax: 170, poder: 17, agilidad: -25, aguante: -20, inclinacion: 33165, precio: 135000),
  Objeto('Derrumbe del Ocaso', TipoObjeto.armaDosManos, nivel: 127, hab: 258, danoMin: 162, danoMax: 185, poder: 17, agilidad: -24, aguante: -30, precio: 3850, conGemas: true, bazar: true),
  Objeto('Castigo de la Hoguera', TipoObjeto.armaDosManos, nivel: 129, hab: 262, danoMin: 146, danoMax: 174, poder: 17, agilidad: -25, aguante: -31, precio: 135000),
  Objeto('Mangual pesado de sangre', TipoObjeto.armaDosManos, nivel: 131, hab: 266, danoMin: 147, danoMax: 177, poder: 18, agilidad: -26, aguante: -31, precio: 136000),
  Objeto('Derrumbe del Invierno', TipoObjeto.armaDosManos, nivel: 133, hab: 269, danoMin: 168, danoMax: 192, poder: 16, vigor: 7, agilidad: -25, aguante: -30, precio: 3900, conGemas: true),
  Objeto('Coloso del Juramento Sagrado', TipoObjeto.armaDosManos, nivel: 136, hab: 277, danoMin: 168, danoMax: 192, poder: 17, vigor: 7, agilidad: -25, aguante: -19, inclinacion: 37350, precio: 139000, bazar: true),
  Objeto('Destructor de la Luna Roja', TipoObjeto.armaDosManos, nivel: 138, hab: 279, danoMin: 176, danoMax: 200, poder: 17, agilidad: -25, aguante: -31, precio: 3950, conGemas: true),
  Objeto('Coloso de la Luz Eterna', TipoObjeto.armaDosManos, nivel: 140, hab: 284, danoMin: 158, danoMax: 189, poder: 17, agilidad: -25, aguante: -20, inclinacion: 38890, precio: 140000),
  Objeto('Destructor de la Condenación', TipoObjeto.armaDosManos, nivel: 140, hab: 284, danoMin: 158, danoMax: 189, poder: 28, agilidad: -25, aguante: -31, inclinacion: -38890, precio: 140000),
  Objeto('Lanza larga de ónix', TipoObjeto.armaDosManos, nivel: 142, hab: 288, danoMin: 158, danoMax: 189, poder: 17, agilidad: -25, aguante: -32, precio: 142000),
  Objeto('Coloso del Lobo Gris', TipoObjeto.armaDosManos, nivel: 143, hab: 290, danoMin: 182, danoMax: 207, poder: 18, agilidad: -26, aguante: -31, precio: 4000, conGemas: true),
  Objeto('Gran maza de ónix', TipoObjeto.armaDosManos, nivel: 145, hab: 294, danoMin: 164, danoMax: 197, poder: 20, agilidad: -27, aguante: -32, precio: 143000),
  Objeto('Trueno del Custodio', TipoObjeto.armaDosManos, nivel: 150, hab: 305, danoMin: 170, danoMax: 203, poder: 20, vigor: 7, agilidad: -27, aguante: -19, inclinacion: 42785, precio: 145000),
  Objeto('Hacha de guerra de ónix', TipoObjeto.armaDosManos, nivel: 151, hab: 306, danoMin: 171, danoMax: 204, poder: 20, agilidad: -28, aguante: -33, precio: 161000),
  Objeto('Pica de asalto de ónix', TipoObjeto.armaDosManos, nivel: 152, hab: 308, danoMin: 171, danoMax: 204, poder: 19, agilidad: -26, aguante: -32, precio: 146000),
  Objeto('Mangual pesado de ónix', TipoObjeto.armaDosManos, nivel: 153, hab: 311, danoMin: 173, danoMax: 206, poder: 21, agilidad: -27, aguante: -32, precio: 150000),
  Objeto('Cataclismo del Penitente', TipoObjeto.armaDosManos, nivel: 154, hab: 312, danoMin: 207, danoMax: 242, poder: 20, agilidad: -26, aguante: -31, precio: 4100, conGemas: true, bazar: true),
  Objeto('Rompemundos del Exiliado', TipoObjeto.armaDosManos, nivel: 155, hab: 315, danoMin: 189, danoMax: 216, poder: 21, vigor: 8, agilidad: -27, aguante: -32, precio: 157000),
  Objeto('Gran maza de runas antiguas', TipoObjeto.armaDosManos, nivel: 157, hab: 319, danoMin: 191, danoMax: 219, poder: 19, agilidad: -27, aguante: -33, precio: 159000),
  Objeto('Cataclismo del Desterrado', TipoObjeto.armaDosManos, nivel: 161, hab: 325, danoMin: 218, danoMax: 254, poder: 20, agilidad: -26, aguante: -32, precio: 4150, conGemas: true),
  Objeto('Destructor del Hambre', TipoObjeto.armaDosManos, nivel: 163, hab: 329, danoMin: 201, danoMax: 231, poder: 34, agilidad: -27, aguante: -32, inclinacion: -47915, precio: 169000),
  Objeto('Quebrantahuesos de los Justos', TipoObjeto.armaDosManos, nivel: 163, hab: 329, danoMin: 201, danoMax: 231, poder: 22, agilidad: -27, aguante: -19, inclinacion: 47915, precio: 169000),
  Objeto('Castigo del Pantano', TipoObjeto.armaDosManos, nivel: 166, hab: 338, danoMin: 225, danoMax: 263, poder: 22, agilidad: -26, aguante: -32, precio: 4200, conGemas: true),
  Objeto('Guadaña de guerra de runas antiguas', TipoObjeto.armaDosManos, nivel: 168, hab: 340, danoMin: 204, danoMax: 234, poder: 22, agilidad: -27, aguante: -33, precio: 170000),
  Objeto('Coloso del Rey Caído', TipoObjeto.armaDosManos, nivel: 173, hab: 351, danoMin: 234, danoMax: 273, poder: 22, agilidad: -26, aguante: -32, precio: 4250, conGemas: true),
  Objeto('Alabarda de runas antiguas', TipoObjeto.armaDosManos, nivel: 175, hab: 355, danoMin: 213, danoMax: 245, poder: 24, agilidad: -27, aguante: -34, precio: 178000),
  Objeto('Cataclismo de la Sangre Negra', TipoObjeto.armaDosManos, nivel: 177, hab: 359, danoMin: 219, danoMax: 252, poder: 37, agilidad: -27, aguante: -33, inclinacion: -53525, precio: 184000),
  Objeto('Cataclismo del Peregrino Santo', TipoObjeto.armaDosManos, nivel: 177, hab: 359, danoMin: 219, danoMax: 252, poder: 23, agilidad: -27, aguante: -19, inclinacion: 53525, precio: 184000),
  Objeto('Castigo del Penitente', TipoObjeto.armaDosManos, nivel: 179, hab: 363, danoMin: 242, danoMax: 282, poder: 22, vigor: 9, agilidad: -26, aguante: -32, precio: 4250, conGemas: true),
  Objeto('Lanza larga del abismo', TipoObjeto.armaDosManos, nivel: 180, hab: 366, danoMin: 219, danoMax: 252, poder: 23, agilidad: -28, aguante: -33, precio: 185000),
  Objeto('Gran maza del abismo', TipoObjeto.armaDosManos, nivel: 184, hab: 374, danoMin: 225, danoMax: 258, poder: 23, agilidad: -28, aguante: -33, precio: 187000, bazar: true),
  Objeto('Mangual pesado del abismo', TipoObjeto.armaDosManos, nivel: 188, hab: 382, danoMin: 228, danoMax: 263, poder: 25, agilidad: -28, aguante: -34, precio: 191000, bazar: true),
  Objeto('Cataclismo de la Podredumbre', TipoObjeto.armaDosManos, nivel: 190, hab: 386, danoMin: 236, danoMax: 270, poder: 40, vigor: 9, agilidad: -28, aguante: -33, inclinacion: -58805, precio: 197000),
  Objeto('Castigo del Peregrino Santo', TipoObjeto.armaDosManos, nivel: 190, hab: 386, danoMin: 236, danoMax: 270, poder: 26, agilidad: -28, aguante: -18, inclinacion: 58805, precio: 197000),
  Objeto('Cataclismo del Pantano', TipoObjeto.armaDosManos, nivel: 192, hab: 389, danoMin: 260, danoMax: 303, poder: 24, agilidad: -27, aguante: -32, precio: 4350, conGemas: true),
  Objeto('Pica de asalto del abismo', TipoObjeto.armaDosManos, nivel: 194, hab: 394, danoMin: 237, danoMax: 273, poder: 26, agilidad: -28, aguante: -34, precio: 207000),
  Objeto('Alabarda del abismo', TipoObjeto.armaDosManos, nivel: 197, hab: 400, danoMin: 240, danoMax: 276, poder: 27, vigor: 10, agilidad: -28, aguante: -34, precio: 218000),
  Objeto('Destructor de la Peste', TipoObjeto.armaDosManos, nivel: 199, hab: 404, danoMin: 263, danoMax: 308, poder: 26, agilidad: -27, aguante: -33, precio: 4400, conGemas: true),
  Objeto('Derrumbe del Penitente', TipoObjeto.armaDosManos, nivel: 200, hab: 406, danoMin: 272, danoMax: 317, poder: 26, agilidad: -27, aguante: -32, precio: 4500, conGemas: true),

  // ---------------- ESCUDOS (97) ----------------
  Objeto('Rodela de madera', TipoObjeto.escudo, hab: 1, danoMin: 0, danoMax: 1, precio: 100),
  Objeto('Broquel de madera', TipoObjeto.escudo, nivel: 3, hab: 2, danoMin: 0, danoMax: 1, guardia: 2, precio: 200),
  Objeto('Último Aliento de la Peste', TipoObjeto.escudo, nivel: 4, hab: 4, guardia: 3, precio: 200, conGemas: true),
  Objeto('Muro de la Ruina', TipoObjeto.escudo, nivel: 6, hab: 7, danoMin: 3, danoMax: 6, guardia: 3, precio: 400),
  Objeto('Muro de la Tormenta', TipoObjeto.escudo, nivel: 8, hab: 9, danoMin: 3, danoMax: 8, guardia: 3, precio: 480),
  Objeto('Parapeto del Ocaso', TipoObjeto.escudo, nivel: 10, hab: 12, danoMin: 6, danoMax: 8, agilidad: -1, guardia: 4, precio: 800),
  Objeto('Resguardo del Verdugo', TipoObjeto.escudo, nivel: 12, hab: 15, danoMin: 6, danoMax: 9, agilidad: -1, guardia: 5, precio: 1020),
  Objeto('Muro del Desterrado', TipoObjeto.escudo, nivel: 14, hab: 18, danoMin: 8, danoMax: 9, agilidad: -1, guardia: 6, precio: 1340),
  Objeto('Bastión de la Tormenta', TipoObjeto.escudo, nivel: 16, hab: 20, danoMin: 8, danoMax: 11, vigor: 1, agilidad: -1, guardia: 6, aguante: -1, precio: 2000),
  Objeto('Santuario del Penitente', TipoObjeto.escudo, nivel: 19, hab: 23, danoMin: 9, danoMax: 12, agilidad: -2, guardia: 7, aguante: -1, precio: 400, conGemas: true),
  Objeto('Baluarte del Hambre', TipoObjeto.escudo, nivel: 19, hab: 23, danoMin: 9, danoMax: 12, agilidad: 0, guardia: 8, aguante: -2, inclinacion: -1270, precio: 2800),
  Objeto('Refugio de la Catedral', TipoObjeto.escudo, nivel: 19, hab: 23, danoMin: 9, danoMax: 12, agilidad: -2, guardia: 9, aguante: -1, inclinacion: 1270, precio: 2800),
  Objeto('Broquel de madera reforzada', TipoObjeto.escudo, nivel: 20, hab: 24, danoMin: 8, danoMax: 15, vigor: 1, agilidad: -3, guardia: 7, aguante: -2, precio: 3030),
  Objeto('Rodela de madera reforzada', TipoObjeto.escudo, nivel: 21, hab: 26, danoMin: 9, danoMax: 12, agilidad: -3, guardia: 8, aguante: -3, precio: 3580),
  Objeto('Parapeto del Cazador', TipoObjeto.escudo, nivel: 22, hab: 27, danoMin: 9, danoMax: 15, agilidad: -4, guardia: 8, aguante: -3, precio: 4350),
  Objeto('Santuario del Cazador', TipoObjeto.escudo, nivel: 24, hab: 28, danoMin: 11, danoMax: 15, agilidad: -4, guardia: 8, aguante: -3, precio: 5220),
  Objeto('Guardián del Invierno', TipoObjeto.escudo, nivel: 25, hab: 30, danoMin: 11, danoMax: 17, vigor: 1, agilidad: -4, guardia: 9, aguante: -4, precio: 6140),
  Objeto('Bastión del Herrero Ciego', TipoObjeto.escudo, nivel: 26, hab: 31, danoMin: 12, danoMax: 18, vigor: 1, agilidad: -4, guardia: 8, aguante: -4, precio: 800, conGemas: true),
  Objeto('Adarga de cobre', TipoObjeto.escudo, nivel: 27, hab: 32, danoMin: 12, danoMax: 17, vigor: 1, agilidad: -5, guardia: 8, aguante: -4, precio: 7080),
  Objeto('Guardián del Hambre', TipoObjeto.escudo, nivel: 28, hab: 34, danoMin: 12, danoMax: 18, vigor: 1, agilidad: -3, guardia: 9, aguante: -3, inclinacion: -2735, precio: 7900),
  Objeto('Último Aliento del Serafín', TipoObjeto.escudo, nivel: 28, hab: 34, danoMin: 12, danoMax: 18, agilidad: -4, guardia: 10, aguante: -3, inclinacion: 2735, precio: 7900),
  Objeto('Escudo redondo de cobre', TipoObjeto.escudo, nivel: 29, hab: 35, danoMin: 12, danoMax: 18, agilidad: -5, guardia: 9, aguante: -4, precio: 8550),
  Objeto('Parapeto del Exiliado', TipoObjeto.escudo, nivel: 30, hab: 36, danoMin: 15, danoMax: 18, agilidad: -6, guardia: 9, aguante: -5, precio: 9350),
  Objeto('Muro de la Hoguera', TipoObjeto.escudo, nivel: 32, hab: 39, danoMin: 15, danoMax: 20, agilidad: -5, guardia: 10, aguante: -4, precio: 10800),
  Objeto('Parapeto de la Tormenta', TipoObjeto.escudo, nivel: 33, hab: 41, danoMin: 17, danoMax: 20, vigor: 2, agilidad: -8, guardia: 10, aguante: -5, precio: 11700),
  Objeto('Parapeto del Mercenario', TipoObjeto.escudo, nivel: 34, hab: 42, danoMin: 18, danoMax: 21, agilidad: -7, guardia: 10, aguante: -4, precio: 1200, conGemas: true),
  Objeto('Adarga de hierro', TipoObjeto.escudo, nivel: 35, hab: 43, danoMin: 17, danoMax: 21, agilidad: -8, guardia: 10, aguante: -6, precio: 13000),
  Objeto('Escudo redondo de hierro', TipoObjeto.escudo, nivel: 36, hab: 45, danoMin: 18, danoMax: 21, agilidad: -9, guardia: 10, aguante: -6, precio: 13800),
  Objeto('Bastilla del Rey Caído', TipoObjeto.escudo, nivel: 37, hab: 46, danoMin: 18, danoMax: 24, vigor: 2, agilidad: -9, guardia: 11, aguante: -6, precio: 14600),
  Objeto('Refugio del Rey Caído', TipoObjeto.escudo, nivel: 39, hab: 47, danoMin: 20, danoMax: 26, vigor: 2, agilidad: -9, guardia: 12, aguante: -6, precio: 19100),
  Objeto('Bastión de la Cripta', TipoObjeto.escudo, nivel: 41, hab: 50, danoMin: 21, danoMax: 27, agilidad: -9, guardia: 11, aguante: -6, precio: 20800),
  Objeto('Muro del Herrero Ciego', TipoObjeto.escudo, nivel: 43, hab: 53, danoMin: 26, danoMax: 30, vigor: 2, agilidad: -7, guardia: 12, aguante: -5, precio: 1400, conGemas: true),
  Objeto('Santuario del Verdugo Oscuro', TipoObjeto.escudo, nivel: 45, hab: 55, danoMin: 26, danoMax: 30, agilidad: -7, guardia: 12, aguante: -7, inclinacion: -6585, precio: 22000),
  Objeto('Bastión de la Bendición', TipoObjeto.escudo, nivel: 45, hab: 55, danoMin: 26, danoMax: 30, vigor: 2, agilidad: -9, guardia: 14, aguante: -7, inclinacion: 6585, precio: 22000),
  Objeto('Guardián de la Peste', TipoObjeto.escudo, nivel: 47, hab: 57, danoMin: 26, danoMax: 33, agilidad: -10, guardia: 11, aguante: -7, precio: 23300),
  Objeto('Tarja de acero', TipoObjeto.escudo, nivel: 49, hab: 59, danoMin: 27, danoMax: 33, agilidad: -10, guardia: 12, aguante: -7, precio: 24800),
  Objeto('Baluarte del Rey Caído', TipoObjeto.escudo, nivel: 50, hab: 61, danoMin: 30, danoMax: 36, vigor: 2, agilidad: -9, guardia: 13, aguante: -6, precio: 1450, conGemas: true),
  Objeto('Escudo ligero de acero', TipoObjeto.escudo, nivel: 51, hab: 62, danoMin: 29, danoMax: 35, vigor: 3, agilidad: -10, guardia: 12, aguante: -7, precio: 26100),
  Objeto('Parapeto del Nómada', TipoObjeto.escudo, nivel: 53, hab: 65, danoMin: 29, danoMax: 36, vigor: 3, agilidad: -10, guardia: 12, aguante: -7, precio: 27500),
  Objeto('Último Aliento de la Niebla', TipoObjeto.escudo, nivel: 54, hab: 66, danoMin: 30, danoMax: 36, vigor: 3, agilidad: -10, guardia: 12, aguante: -8, precio: 28900),
  Objeto('Guardián de la Viuda', TipoObjeto.escudo, nivel: 56, hab: 69, danoMin: 30, danoMax: 38, agilidad: -10, guardia: 12, aguante: -8, precio: 30300),
  Objeto('Bastilla de los Condenados', TipoObjeto.escudo, nivel: 58, hab: 72, danoMin: 35, danoMax: 42, agilidad: -9, guardia: 13, aguante: -7, precio: 1500, conGemas: true),
  Objeto('Escudo ligero de acero templado', TipoObjeto.escudo, nivel: 60, hab: 73, danoMin: 33, danoMax: 38, agilidad: -11, guardia: 12, aguante: -8, precio: 31800),
  Objeto('Guardián del Verdugo Oscuro', TipoObjeto.escudo, nivel: 62, hab: 76, danoMin: 33, danoMax: 39, agilidad: -8, guardia: 13, aguante: -8, inclinacion: -11370, precio: 33300),
  Objeto('Último Aliento del Paladín', TipoObjeto.escudo, nivel: 62, hab: 76, danoMin: 33, danoMax: 39, agilidad: -11, guardia: 16, aguante: -8, inclinacion: 11370, precio: 33300),
  Objeto('Tarja de acero templado', TipoObjeto.escudo, nivel: 64, hab: 78, danoMin: 36, danoMax: 39, vigor: 3, agilidad: -11, guardia: 13, aguante: -7, precio: 34900),
  Objeto('Baluarte del Pantano', TipoObjeto.escudo, nivel: 66, hab: 81, danoMin: 36, danoMax: 41, vigor: 3, agilidad: -11, guardia: 13, aguante: -8, precio: 36500),
  Objeto('Refugio del Exiliado', TipoObjeto.escudo, nivel: 67, hab: 82, danoMin: 39, danoMax: 48, vigor: 3, agilidad: -10, guardia: 15, aguante: -7, precio: 1600, conGemas: true),
  Objeto('Muro de la Ceniza', TipoObjeto.escudo, nivel: 68, hab: 84, danoMin: 38, danoMax: 42, agilidad: -11, guardia: 14, aguante: -8, precio: 38200),
  Objeto('Muro del Cuervo', TipoObjeto.escudo, nivel: 70, hab: 86, danoMin: 39, danoMax: 44, agilidad: -12, guardia: 14, aguante: -9, precio: 39800),
  Objeto('Pavés de plata', TipoObjeto.escudo, nivel: 72, hab: 88, danoMin: 39, danoMax: 45, vigor: 4, agilidad: -12, guardia: 13, aguante: -9, precio: 41400),
  Objeto('Bastión de la Viuda', TipoObjeto.escudo, nivel: 74, hab: 90, danoMin: 45, danoMax: 54, agilidad: -11, guardia: 15, aguante: -8, precio: 1700, conGemas: true),
  Objeto('Escudo cometa de plata', TipoObjeto.escudo, nivel: 77, hab: 93, danoMin: 39, danoMax: 48, agilidad: -12, guardia: 13, aguante: -9, precio: 42500),
  Objeto('Muro del Rey Caído', TipoObjeto.escudo, nivel: 79, hab: 96, danoMin: 42, danoMax: 48, vigor: 4, agilidad: -12, guardia: 14, aguante: -9, precio: 44000),
  Objeto('Bastión del Desterrado', TipoObjeto.escudo, nivel: 81, hab: 99, danoMin: 44, danoMax: 51, agilidad: -13, guardia: 14, aguante: -10, precio: 45600),
  Objeto('Baluarte de la Peste', TipoObjeto.escudo, nivel: 81, hab: 100, danoMin: 50, danoMax: 60, agilidad: -12, guardia: 16, aguante: -9, precio: 1750, conGemas: true),
  Objeto('Parapeto del Hambre', TipoObjeto.escudo, nivel: 83, hab: 101, danoMin: 47, danoMax: 56, agilidad: -9, guardia: 15, aguante: -9, inclinacion: -18090, precio: 46000),
  Objeto('Guardián de la Catedral', TipoObjeto.escudo, nivel: 83, hab: 101, danoMin: 47, danoMax: 56, vigor: 4, agilidad: -13, guardia: 19, aguante: -9, inclinacion: 18090, precio: 46000),
  Objeto('Pavés de obsidiana', TipoObjeto.escudo, nivel: 85, hab: 104, danoMin: 48, danoMax: 54, agilidad: -13, guardia: 15, aguante: -10, precio: 46400),
  Objeto('Resguardo del Cuervo', TipoObjeto.escudo, nivel: 88, hab: 107, danoMin: 48, danoMax: 56, agilidad: -13, guardia: 15, aguante: -10, precio: 47000),
  Objeto('Parapeto de Sangre Vieja', TipoObjeto.escudo, nivel: 90, hab: 109, danoMin: 54, danoMax: 65, agilidad: -12, guardia: 16, aguante: -9, precio: 1825, conGemas: true),
  Objeto('Escudo cometa de obsidiana', TipoObjeto.escudo, nivel: 92, hab: 112, danoMin: 51, danoMax: 59, vigor: 5, agilidad: -13, guardia: 15, aguante: -10, precio: 48000),
  Objeto('Muro del Ocaso', TipoObjeto.escudo, nivel: 94, hab: 115, danoMin: 53, danoMax: 60, agilidad: -14, guardia: 16, aguante: -10, precio: 48500),
  Objeto('Guardián del Pantano', TipoObjeto.escudo, nivel: 96, hab: 117, danoMin: 57, danoMax: 69, agilidad: -13, guardia: 17, aguante: -10, precio: 1900, conGemas: true),
  Objeto('Santuario del Nómada', TipoObjeto.escudo, nivel: 99, hab: 120, danoMin: 54, danoMax: 63, vigor: 5, agilidad: -14, guardia: 16, aguante: -10, precio: 49100),
  Objeto('Resguardo de la Herejía', TipoObjeto.escudo, nivel: 101, hab: 123, danoMin: 57, danoMax: 65, agilidad: -9, guardia: 16, aguante: -10, inclinacion: -24345, precio: 49600),
  Objeto('Resguardo del Serafín', TipoObjeto.escudo, nivel: 101, hab: 123, danoMin: 57, danoMax: 65, agilidad: -14, guardia: 21, aguante: -10, inclinacion: 24345, precio: 49600),
  Objeto('Guardián de la Ruina', TipoObjeto.escudo, nivel: 103, hab: 126, danoMin: 62, danoMax: 74, agilidad: -13, guardia: 17, aguante: -10, precio: 1975, conGemas: true),
  Objeto('Escudo pesado de hueso', TipoObjeto.escudo, nivel: 105, hab: 128, danoMin: 59, danoMax: 68, vigor: 5, agilidad: -14, guardia: 16, aguante: -11, precio: 50000),
  Objeto('Santuario del Cuervo', TipoObjeto.escudo, nivel: 107, hab: 131, danoMin: 60, danoMax: 69, agilidad: -14, guardia: 16, aguante: -11, precio: 50600),
  Objeto('Parapeto de la Ceniza', TipoObjeto.escudo, nivel: 110, hab: 134, danoMin: 66, danoMax: 78, agilidad: -13, guardia: 18, aguante: -10, precio: 2050, conGemas: true),
  Objeto('Escudo de batalla de hueso', TipoObjeto.escudo, nivel: 112, hab: 136, danoMin: 63, danoMax: 71, agilidad: -15, guardia: 16, aguante: -11, precio: 51000),
  Objeto('Refugio de las Sombras', TipoObjeto.escudo, nivel: 114, hab: 139, danoMin: 63, danoMax: 74, vigor: 6, agilidad: -15, guardia: 17, aguante: -11, precio: 51400),
  Objeto('Guardián del Exiliado', TipoObjeto.escudo, nivel: 116, hab: 142, danoMin: 69, danoMax: 84, agilidad: -14, guardia: 18, aguante: -11, precio: 2125, conGemas: true),
  Objeto('Parapeto del Pecado', TipoObjeto.escudo, nivel: 118, hab: 144, danoMin: 66, danoMax: 77, agilidad: -8, guardia: 18, aguante: -12, inclinacion: -30545, precio: 52000),
  Objeto('Baluarte del Peregrino Santo', TipoObjeto.escudo, nivel: 118, hab: 144, danoMin: 66, danoMax: 77, agilidad: -14, guardia: 24, aguante: -12, inclinacion: 30545, precio: 52000),
  Objeto('Escudo pesado de hierro negro', TipoObjeto.escudo, nivel: 121, hab: 147, danoMin: 68, danoMax: 77, agilidad: -15, guardia: 17, aguante: -12, precio: 52600),
  Objeto('Guardián del Herrero Ciego', TipoObjeto.escudo, nivel: 123, hab: 150, danoMin: 74, danoMax: 89, vigor: 6, agilidad: -14, guardia: 18, aguante: -11, precio: 2200, conGemas: true),
  Objeto('Escudo de batalla de hierro negro', TipoObjeto.escudo, nivel: 125, hab: 153, danoMin: 69, danoMax: 81, agilidad: -15, guardia: 17, aguante: -12, precio: 53000),
  Objeto('Muro de la Cripta', TipoObjeto.escudo, nivel: 127, hab: 155, danoMin: 71, danoMax: 83, vigor: 6, agilidad: -15, guardia: 17, aguante: -12, precio: 53400),
  Objeto('Bastión de la Ceniza', TipoObjeto.escudo, nivel: 129, hab: 158, danoMin: 77, danoMax: 93, agilidad: -14, guardia: 19, aguante: -11, precio: 2275, conGemas: true),
  Objeto('Escudo torre de sangre', TipoObjeto.escudo, nivel: 132, hab: 161, danoMin: 74, danoMax: 84, agilidad: -16, guardia: 18, aguante: -13, precio: 54000),
  Objeto('Refugio del Hambre', TipoObjeto.escudo, nivel: 135, hab: 165, danoMin: 75, danoMax: 87, vigor: 7, agilidad: -8, guardia: 18, aguante: -12, inclinacion: -36970, precio: 62000),
  Objeto('Santuario del Amanecer', TipoObjeto.escudo, nivel: 135, hab: 165, danoMin: 75, danoMax: 87, vigor: 7, agilidad: -15, guardia: 25, aguante: -12, inclinacion: 36970, precio: 62000),
  Objeto('Muro del Invierno', TipoObjeto.escudo, nivel: 138, hab: 169, danoMin: 84, danoMax: 90, agilidad: -15, guardia: 19, aguante: -11, precio: 2350, conGemas: true),
  Objeto('Muro portátil de sangre', TipoObjeto.escudo, nivel: 142, hab: 173, danoMin: 77, danoMax: 90, agilidad: -16, guardia: 18, aguante: -13, precio: 66500),
  Objeto('Guardián de la Niebla', TipoObjeto.escudo, nivel: 145, hab: 177, danoMin: 80, danoMax: 93, agilidad: -16, guardia: 18, aguante: -13, precio: 70800),
  Objeto('Guardián de la Ceniza', TipoObjeto.escudo, nivel: 148, hab: 181, danoMin: 81, danoMax: 108, vigor: 7, agilidad: -16, guardia: 19, aguante: -13, precio: 72300),
  Objeto('Santuario de la Luna Roja', TipoObjeto.escudo, nivel: 151, hab: 185, danoMin: 90, danoMax: 101, agilidad: -15, guardia: 20, aguante: -12, precio: 2425, conGemas: true),
  Objeto('Parapeto de la Ruina', TipoObjeto.escudo, nivel: 155, hab: 189, danoMin: 84, danoMax: 102, agilidad: -16, guardia: 19, aguante: -13, precio: 75600),
  Objeto('Muro portátil de ónix', TipoObjeto.escudo, nivel: 160, hab: 196, danoMin: 87, danoMax: 102, vigor: 8, agilidad: -16, guardia: 19, aguante: -13, precio: 77200),
  Objeto('Escudo torre de ónix', TipoObjeto.escudo, nivel: 166, hab: 203, danoMin: 90, danoMax: 105, vigor: 8, agilidad: -16, guardia: 19, aguante: -13, precio: 80000),
  Objeto('Bastilla del Cazador', TipoObjeto.escudo, nivel: 172, hab: 211, danoMin: 105, danoMax: 120, agilidad: -15, guardia: 21, aguante: -12, precio: 2550, conGemas: true),
  Objeto('Bastilla del Pantano', TipoObjeto.escudo, nivel: 177, hab: 216, danoMin: 96, danoMax: 108, agilidad: -17, guardia: 19, aguante: -14, precio: 83000),
  Objeto('Parapeto del Cuervo', TipoObjeto.escudo, nivel: 183, hab: 224, danoMin: 99, danoMax: 114, vigor: 9, agilidad: -17, guardia: 19, aguante: -14, precio: 87000),
  Objeto('Resguardo del Exiliado', TipoObjeto.escudo, nivel: 192, hab: 235, danoMin: 105, danoMax: 117, agilidad: -17, guardia: 19, aguante: -14, precio: 91500),
  Objeto('Santuario del Pantano', TipoObjeto.escudo, nivel: 200, hab: 244, danoMin: 123, danoMax: 138, agilidad: -15, guardia: 21, aguante: -12, precio: 2800, conGemas: true),

  // ---------------- ARMADURAS (99) ----------------
  Objeto('Túnica de aprendiz', TipoObjeto.armadura, danoMax: 2),
  Objeto('Harapos de mensajero', TipoObjeto.armadura, danoMin: 3, danoMax: 6, precio: 480),
  Objeto('Harapos de campesino', TipoObjeto.armadura, nivel: 3, hab: 2, danoMin: 4, danoMax: 8, precio: 840),
  Objeto('Harapos de leñador', TipoObjeto.armadura, nivel: 5, hab: 5, danoMin: 6, danoMax: 10, precio: 1200),
  Objeto('Harapos de recluta', TipoObjeto.armadura, nivel: 7, hab: 8, danoMin: 7, danoMax: 11, precio: 1560),
  Objeto('Armadura de la Peste', TipoObjeto.armadura, nivel: 9, hab: 11, danoMin: 8, danoMax: 13, precio: 325, conGemas: true),
  Objeto('Coraza del Exiliado', TipoObjeto.armadura, nivel: 11, hab: 14, danoMin: 10, danoMax: 15, vigor: 1, precio: 2280),
  Objeto('Sudario de la Plegaria', TipoObjeto.armadura, nivel: 13, hab: 16, danoMin: 11, danoMax: 17, vigor: 1, agilidad: -1, guardia: 1, inclinacion: 600, precio: 3050),
  Objeto('Harapos de aldeano', TipoObjeto.armadura, nivel: 15, hab: 19, danoMin: 13, danoMax: 18, vigor: 1, agilidad: -1, aguante: -1, precio: 3490),
  Objeto('Mortaja del Demonio', TipoObjeto.armadura, nivel: 17, hab: 23, danoMin: 14, danoMax: 20, vigor: 1, agilidad: 0, aguante: -1, inclinacion: -1020, precio: 4730),
  Objeto('Sudario del Mercenario', TipoObjeto.armadura, nivel: 19, hab: 26, danoMin: 15, danoMax: 22, vigor: 1, agilidad: -1, aguante: -1, precio: 500, conGemas: true),
  Objeto('Jubón de vagabundo', TipoObjeto.armadura, nivel: 21, hab: 28, danoMin: 17, danoMax: 23, vigor: 1, agilidad: -1, guardia: 1, aguante: -1, precio: 6410),
  Objeto('Coraza de las Sombras', TipoObjeto.armadura, nivel: 23, hab: 31, danoMin: 18, danoMax: 25, agilidad: -1, guardia: 1, aguante: -1, precio: 7680),
  Objeto('Jubón de mendigo', TipoObjeto.armadura, nivel: 25, hab: 34, danoMin: 19, danoMax: 27, agilidad: -2, aguante: -1, precio: 9090),
  Objeto('Vestidura de la Gracia', TipoObjeto.armadura, nivel: 27, hab: 36, danoMin: 21, danoMax: 29, vigor: 2, agilidad: -2, guardia: 2, aguante: -1, inclinacion: 2550, precio: 11000),
  Objeto('Mortaja de la Luna Roja', TipoObjeto.armadura, nivel: 29, hab: 39, danoMin: 22, danoMax: 30, agilidad: -2, guardia: 1, aguante: -2, precio: 675, conGemas: true),
  Objeto('Jubón de pastor', TipoObjeto.armadura, nivel: 31, hab: 42, danoMin: 23, danoMax: 32, vigor: 2, agilidad: -2, guardia: 1, aguante: -2, precio: 13100),
  Objeto('Gambesón de recluta', TipoObjeto.armadura, nivel: 34, hab: 45, danoMin: 25, danoMax: 34, vigor: 2, agilidad: -2, guardia: 1, aguante: -2, precio: 15200),
  Objeto('Sudario del Cuervo Maldito', TipoObjeto.armadura, nivel: 36, hab: 47, danoMin: 26, danoMax: 36, vigor: 2, agilidad: -1, aguante: -2, inclinacion: -4400, precio: 17600),
  Objeto('Gambesón de leñador', TipoObjeto.armadura, nivel: 38, hab: 50, danoMin: 27, danoMax: 37, vigor: 3, agilidad: -3, aguante: -2, precio: 17400),
  Objeto('Mortaja de la Viuda', TipoObjeto.armadura, nivel: 40, hab: 53, danoMin: 29, danoMax: 39, vigor: 3, agilidad: -3, guardia: 1, aguante: -2, precio: 850, conGemas: true),
  Objeto('Panoplia de los Justos', TipoObjeto.armadura, nivel: 42, hab: 55, danoMin: 30, danoMax: 41, agilidad: -3, aguante: -3, guardia: 2, inclinacion: 5825, precio: 20400),
  Objeto('Gambesón de cazador', TipoObjeto.armadura, nivel: 44, hab: 58, danoMin: 32, danoMax: 43, vigor: 3, agilidad: -3, guardia: 1, aguante: -3, precio: 20100),
  Objeto('Gambesón de aldeano', TipoObjeto.armadura, nivel: 46, hab: 61, danoMin: 33, danoMax: 44, vigor: 3, agilidad: -3, guardia: 1, aguante: -3, precio: 21000),
  Objeto('Mortaja del Ocaso', TipoObjeto.armadura, nivel: 48, hab: 63, danoMin: 34, danoMax: 46, vigor: 3, agilidad: -4, aguante: -3, precio: 21900),
  Objeto('Vestidura del Desterrado', TipoObjeto.armadura, nivel: 50, hab: 68, danoMin: 35, danoMax: 48, agilidad: -4, guardia: 1, aguante: -3, precio: 1025, conGemas: true),
  Objeto('Gambesón de mensajero', TipoObjeto.armadura, nivel: 52, hab: 70, danoMin: 37, danoMax: 50, vigor: 4, agilidad: -4, aguante: -3, precio: 23700),
  Objeto('Égida de la Sangre Negra', TipoObjeto.armadura, nivel: 54, hab: 73, danoMin: 38, danoMax: 51, vigor: 4, agilidad: -1, guardia: 1, aguante: -3, inclinacion: -9025, precio: 26200),
  Objeto('Égida del Alba', TipoObjeto.armadura, nivel: 56, hab: 76, danoMin: 40, danoMax: 53, agilidad: -4, aguante: -4, guardia: 3, inclinacion: 9600, precio: 27100),
  Objeto('Gambesón de pastor', TipoObjeto.armadura, nivel: 58, hab: 78, danoMin: 41, danoMax: 55, vigor: 4, agilidad: -5, guardia: 1, aguante: -4, precio: 26400),
  Objeto('Manto del Nómada', TipoObjeto.armadura, nivel: 60, hab: 81, danoMin: 42, danoMax: 56, vigor: 4, agilidad: -5, aguante: -4, precio: 1200, conGemas: true),
  Objeto('Cota de malla de veterano', TipoObjeto.armadura, nivel: 62, hab: 84, danoMin: 44, danoMax: 58, vigor: 4, agilidad: -5, aguante: -4, precio: 28200),
  Objeto('Cota de malla de batidor', TipoObjeto.armadura, nivel: 65, hab: 86, danoMin: 45, danoMax: 60, agilidad: -5, guardia: 2, aguante: -4, precio: 29100),
  Objeto('Cota de malla de explorador', TipoObjeto.armadura, nivel: 67, hab: 89, danoMin: 46, danoMax: 62, vigor: 5, agilidad: -5, aguante: -4, precio: 30000),
  Objeto('Cota de malla de asaltante', TipoObjeto.armadura, nivel: 69, hab: 92, danoMin: 47, danoMax: 63, agilidad: -5, aguante: -4, precio: 30900),
  Objeto('Sudario del Pantano', TipoObjeto.armadura, nivel: 71, hab: 95, danoMin: 49, danoMax: 65, vigor: 5, agilidad: -6, guardia: 2, aguante: -5, precio: 1375, conGemas: true),
  Objeto('Sudario del Eclipse', TipoObjeto.armadura, nivel: 73, hab: 97, danoMin: 50, danoMax: 67, vigor: 5, agilidad: -2, aguante: -5, inclinacion: -14800, precio: 34700),
  Objeto('Cota de malla de duelista', TipoObjeto.armadura, nivel: 75, hab: 100, danoMin: 52, danoMax: 69, agilidad: -6, guardia: 2, aguante: -5, precio: 33600),
  Objeto('Cota de malla de soldado', TipoObjeto.armadura, nivel: 77, hab: 103, danoMin: 53, danoMax: 71, agilidad: -6, guardia: 2, aguante: -5, precio: 34500),
  Objeto('Cota de malla de guardia', TipoObjeto.armadura, nivel: 79, hab: 105, danoMin: 54, danoMax: 72, vigor: 5, agilidad: -6, aguante: -5, precio: 35400),
  Objeto('Égida del Desterrado', TipoObjeto.armadura, nivel: 81, hab: 109, danoMin: 56, danoMax: 74, vigor: 6, agilidad: -7, guardia: 2, aguante: -5, precio: 1550, conGemas: true),
  Objeto('Cota de malla de sargento', TipoObjeto.armadura, nivel: 83, hab: 112, danoMin: 57, danoMax: 76, vigor: 6, agilidad: -7, guardia: 2, aguante: -6, precio: 37200),
  Objeto('Mortaja del Peregrino Santo', TipoObjeto.armadura, nivel: 85, hab: 115, danoMin: 58, danoMax: 77, vigor: 6, agilidad: -7, aguante: -6, guardia: 4, inclinacion: 18770, precio: 40400),
  Objeto('Brigandina de guardia', TipoObjeto.armadura, nivel: 87, hab: 117, danoMin: 60, danoMax: 79, agilidad: -7, guardia: 2, aguante: -6, precio: 39000),
  Objeto('Brigandina de sargento', TipoObjeto.armadura, nivel: 89, hab: 120, danoMin: 61, danoMax: 81, agilidad: -7, aguante: -6, precio: 39900),
  Objeto('Mortaja de la Forja Negra', TipoObjeto.armadura, nivel: 91, hab: 123, danoMin: 62, danoMax: 83, vigor: 6, agilidad: -7, guardia: 2, aguante: -6, precio: 1725, conGemas: true),
  Objeto('Brigandina de veterano', TipoObjeto.armadura, nivel: 93, hab: 126, danoMin: 64, danoMax: 84, agilidad: -8, guardia: 2, aguante: -6, precio: 41700),
  Objeto('Brigandina de duelista', TipoObjeto.armadura, nivel: 95, hab: 128, danoMin: 65, danoMax: 86, agilidad: -8, guardia: 2, aguante: -6, precio: 42600),
  Objeto('Égida de la Hoguera', TipoObjeto.armadura, nivel: 98, hab: 131, danoMin: 67, danoMax: 88, agilidad: -8, aguante: -7, precio: 43500),
  Objeto('Armadura del Peregrino Santo', TipoObjeto.armadura, nivel: 100, hab: 134, danoMin: 68, danoMax: 89, vigor: 7, agilidad: -8, aguante: -7, guardia: 5, inclinacion: 23985, precio: 47000),
  Objeto('Manto de Sangre Vieja', TipoObjeto.armadura, nivel: 101, hab: 136, danoMin: 69, danoMax: 91, vigor: 7, agilidad: -8, guardia: 3, aguante: -7, precio: 1900, conGemas: true),
  Objeto('Brigandina de batidor', TipoObjeto.armadura, nivel: 103, hab: 139, danoMin: 71, danoMax: 93, vigor: 7, agilidad: -9, aguante: -7, precio: 46200),
  Objeto('Brigandina de soldado', TipoObjeto.armadura, nivel: 105, hab: 142, danoMin: 72, danoMax: 95, vigor: 7, agilidad: -9, aguante: -7, precio: 47100),
  Objeto('Brigandina de asaltante', TipoObjeto.armadura, nivel: 107, hab: 144, danoMin: 73, danoMax: 97, agilidad: -9, guardia: 3, aguante: -7, precio: 48000),
  Objeto('Panoplia del Pacto Rojo', TipoObjeto.armadura, nivel: 109, hab: 147, danoMin: 75, danoMax: 98, vigor: 8, agilidad: -4, aguante: -7, inclinacion: -27230, precio: 51800),
  Objeto('Manto de la Forja Negra', TipoObjeto.armadura, nivel: 112, hab: 151, danoMin: 76, danoMax: 100, vigor: 8, agilidad: -9, guardia: 3, aguante: -8, precio: 2075, conGemas: true),
  Objeto('Armadura del Amanecer', TipoObjeto.armadura, nivel: 114, hab: 154, danoMin: 77, danoMax: 102, agilidad: -9, aguante: -8, guardia: 6, inclinacion: 29065, precio: 53700),
  Objeto('Armadura de escamas de centinela', TipoObjeto.armadura, nivel: 116, hab: 157, danoMin: 79, danoMax: 104, vigor: 8, agilidad: -10, aguante: -8, precio: 51600),
  Objeto('Armadura de escamas de soldado', TipoObjeto.armadura, nivel: 118, hab: 159, danoMin: 80, danoMax: 105, agilidad: -10, guardia: 3, aguante: -8, precio: 52500),
  Objeto('Armadura de escamas de duelista', TipoObjeto.armadura, nivel: 120, hab: 162, danoMin: 81, danoMax: 107, agilidad: -10, aguante: -8, precio: 53400),
  Objeto('Manto de la Viuda', TipoObjeto.armadura, nivel: 122, hab: 165, danoMin: 83, danoMax: 109, agilidad: -10, guardia: 3, aguante: -8, precio: 2250, conGemas: true),
  Objeto('Armadura de escamas de explorador', TipoObjeto.armadura, nivel: 124, hab: 167, danoMin: 84, danoMax: 110, agilidad: -10, guardia: 3, aguante: -9, precio: 55200),
  Objeto('Armadura de escamas de guardia', TipoObjeto.armadura, nivel: 126, hab: 170, danoMin: 85, danoMax: 112, vigor: 9, agilidad: -10, guardia: 3, aguante: -9, precio: 56100),
  Objeto('Égida de la Vela Eterna', TipoObjeto.armadura, nivel: 128, hab: 173, danoMin: 87, danoMax: 114, agilidad: -11, guardia: 9, aguante: -9, inclinacion: 34300, precio: 60400),
  Objeto('Armadura de escamas de veterano', TipoObjeto.armadura, nivel: 130, hab: 176, danoMin: 88, danoMax: 116, agilidad: -11, guardia: 3, aguante: -9, precio: 57900),
  Objeto('Manto del Verdugo', TipoObjeto.armadura, nivel: 132, hab: 178, danoMin: 89, danoMax: 117, agilidad: -11, aguante: -9, precio: 2425, conGemas: true),
  Objeto('Manto del Centinela', TipoObjeto.armadura, nivel: 134, hab: 181, danoMin: 91, danoMax: 119, vigor: 9, agilidad: -11, aguante: -9, precio: 59700),
  Objeto('Coraza de cruzado', TipoObjeto.armadura, nivel: 136, hab: 184, danoMin: 92, danoMax: 121, vigor: 9, agilidad: -11, aguante: -9, precio: 60600),
  Objeto('Coraza de comandante', TipoObjeto.armadura, nivel: 138, hab: 186, danoMin: 94, danoMax: 123, agilidad: -12, aguante: -10, precio: 61500),
  Objeto('Coraza de capitán', TipoObjeto.armadura, nivel: 140, hab: 189, danoMin: 95, danoMax: 124, agilidad: -12, guardia: 3, aguante: -10, precio: 62400),
  Objeto('Manto del Exiliado', TipoObjeto.armadura, nivel: 142, hab: 192, danoMin: 96, danoMax: 126, agilidad: -12, aguante: -10, precio: 2600, conGemas: true),
  Objeto('Coraza de inquisidor', TipoObjeto.armadura, nivel: 145, hab: 196, danoMin: 98, danoMax: 128, vigor: 10, agilidad: -12, guardia: 4, aguante: -10, precio: 64200),
  Objeto('Armadura de la Sed', TipoObjeto.armadura, nivel: 147, hab: 198, danoMin: 99, danoMax: 130, vigor: 10, agilidad: -5, guardia: 4, aguante: -10, inclinacion: -41610, precio: 68900),
  Objeto('Coraza de paladín', TipoObjeto.armadura, nivel: 149, hab: 201, danoMin: 100, danoMax: 131, agilidad: -12, guardia: 4, aguante: -10, precio: 66000),
  Objeto('Coraza de campeón', TipoObjeto.armadura, nivel: 151, hab: 204, danoMin: 102, danoMax: 133, agilidad: -13, aguante: -10, precio: 66900),
  Objeto('Mortaja de la Ruina', TipoObjeto.armadura, nivel: 153, hab: 207, danoMin: 103, danoMax: 135, agilidad: -13, guardia: 4, aguante: -11, precio: 2775, conGemas: true),
  Objeto('Coraza de caballero', TipoObjeto.armadura, nivel: 155, hab: 209, danoMin: 104, danoMax: 137, agilidad: -13, guardia: 4, aguante: -11, precio: 68700),
  Objeto('Coraza de los Justos', TipoObjeto.armadura, nivel: 157, hab: 212, danoMin: 106, danoMax: 138, agilidad: -13, guardia: 12, aguante: -11, inclinacion: 45535, precio: 73600),
  Objeto('Coraza de la Forja Negra', TipoObjeto.armadura, nivel: 159, hab: 215, danoMin: 107, danoMax: 140, vigor: 11, agilidad: -13, guardia: 4, aguante: -11, precio: 70500),
  Objeto('Armadura de placas de campeón', TipoObjeto.armadura, nivel: 161, hab: 217, danoMin: 108, danoMax: 142, agilidad: -14, guardia: 4, aguante: -11, precio: 71400),
  Objeto('Mortaja del Páramo', TipoObjeto.armadura, nivel: 163, hab: 220, danoMin: 110, danoMax: 143, agilidad: -14, aguante: -11, precio: 2950, conGemas: true),
  Objeto('Armadura de la Sangre Negra', TipoObjeto.armadura, nivel: 165, hab: 223, danoMin: 111, danoMax: 145, vigor: 12, agilidad: -6, aguante: -12, inclinacion: -48710, precio: 77400),
  Objeto('Armadura de placas de paladín', TipoObjeto.armadura, nivel: 167, hab: 225, danoMin: 113, danoMax: 147, agilidad: -14, aguante: -12, precio: 74100),
  Objeto('Armadura de placas de general', TipoObjeto.armadura, nivel: 169, hab: 228, danoMin: 114, danoMax: 149, vigor: 12, agilidad: -14, guardia: 4, aguante: -12, precio: 75000),
  Objeto('Vestidura del Cielo Abierto', TipoObjeto.armadura, nivel: 171, hab: 231, danoMin: 115, danoMax: 150, vigor: 12, agilidad: -14, guardia: 13, aguante: -12, inclinacion: 51110, precio: 80300),
  Objeto('Coraza de la Luna Roja', TipoObjeto.armadura, nivel: 173, hab: 234, danoMin: 116, danoMax: 152, vigor: 12, agilidad: -15, aguante: -12, precio: 3125, conGemas: true),
  Objeto('Armadura de placas de cruzado', TipoObjeto.armadura, nivel: 176, hab: 238, danoMin: 118, danoMax: 154, agilidad: -15, aguante: -12, precio: 77700),
  Objeto('Armadura de placas de inquisidor', TipoObjeto.armadura, nivel: 178, hab: 240, danoMin: 119, danoMax: 156, vigor: 12, agilidad: -15, aguante: -12, precio: 78600),
  Objeto('Armadura de placas de comandante', TipoObjeto.armadura, nivel: 180, hab: 243, danoMin: 120, danoMax: 158, agilidad: -15, guardia: 4, aguante: -13, precio: 79500),
  Objeto('Armadura de placas de verdugo', TipoObjeto.armadura, nivel: 182, hab: 246, danoMin: 122, danoMax: 159, vigor: 13, agilidad: -15, guardia: 5, aguante: -13, precio: 80400),
  Objeto('Égida de Sangre Vieja', TipoObjeto.armadura, nivel: 184, hab: 248, danoMin: 123, danoMax: 161, vigor: 13, agilidad: -16, aguante: -13, precio: 3300, conGemas: true),
  Objeto('Manto de la Gracia', TipoObjeto.armadura, nivel: 186, hab: 251, danoMin: 125, danoMax: 163, vigor: 13, agilidad: -16, aguante: -13, guardia: 9, inclinacion: 57175, precio: 87000),
  Objeto('Armadura completa de capitán', TipoObjeto.armadura, nivel: 188, hab: 254, danoMin: 126, danoMax: 164, vigor: 13, agilidad: -16, guardia: 5, aguante: -13, precio: 83100),
  Objeto('Armadura completa de campeón', TipoObjeto.armadura, nivel: 190, hab: 257, danoMin: 127, danoMax: 166, vigor: 13, agilidad: -16, guardia: 5, aguante: -13, precio: 84000),
  Objeto('Armadura completa de caballero', TipoObjeto.armadura, nivel: 192, hab: 259, danoMin: 129, danoMax: 168, vigor: 13, agilidad: -16, guardia: 5, aguante: -13, precio: 84900),
  Objeto('Mortaja de la Peste', TipoObjeto.armadura, nivel: 194, hab: 262, danoMin: 130, danoMax: 170, agilidad: -16, aguante: -14, precio: 3475, conGemas: true),
  Objeto('Sudario de la Hoguera', TipoObjeto.armadura, nivel: 196, hab: 265, danoMin: 131, danoMax: 171, agilidad: -17, aguante: -14, precio: 86700),
  Objeto('Armadura completa de cruzado', TipoObjeto.armadura, nivel: 198, hab: 267, danoMin: 133, danoMax: 173, agilidad: -17, guardia: 5, aguante: -14, precio: 87600),
  Objeto('Mortaja de los Justos', TipoObjeto.armadura, nivel: 200, hab: 270, danoMin: 134, danoMax: 175, vigor: 14, agilidad: -17, aguante: -14, guardia: 10, inclinacion: 62900, precio: 93600),

  // ---------------- ANILLOS (89) ----------------
  Objeto('Banda del Coloso', TipoObjeto.anillo, nivel: 6, poder: 3, vigor: 2, precio: 200),
  Objeto('Banda del Susurro', TipoObjeto.anillo, nivel: 7, vigor: 1, agilidad: 2, guardia: 2, precio: 300),
  Objeto('Sortija del Oso Pardo', TipoObjeto.anillo, nivel: 7, poder: 2, maestria: 2, aguante: 1, precio: 400),
  Objeto('Anillo de la Alianza Eterna', TipoObjeto.anillo, nivel: 8, poder: 2, agilidad: 2, maestria: 1, guardia: 1, aguante: 2, precio: 250, conGemas: true),
  Objeto('Anillo del Halcón', TipoObjeto.anillo, nivel: 10, agilidad: 2, guardia: 2, aguante: 2, precio: 500),
  Objeto('Anillo del Muro', TipoObjeto.anillo, nivel: 12, vigor: 3, aguante: 5, precio: 610),
  Objeto('Banda de la Condenación', TipoObjeto.anillo, nivel: 13, poder: 5, agilidad: 3, inclinacion: -600, precio: 1070),
  Objeto('Banda del Cielo Abierto', TipoObjeto.anillo, nivel: 13, agilidad: 4, guardia: 4, vigor: 1, inclinacion: 600, precio: 1070),
  Objeto('Sortija de la Armonía', TipoObjeto.anillo, nivel: 14, poder: 3, agilidad: 3, maestria: 2, guardia: 2, aguante: 3, precio: 750, conGemas: true),
  Objeto('Anillo de la Tenacidad', TipoObjeto.anillo, nivel: 16, aguante: 7, precio: 1750),
  Objeto('Banda de la Furia', TipoObjeto.anillo, nivel: 18, poder: 4, maestria: 3, precio: 2180),
  Objeto('Sortija del Cuervo Ligero', TipoObjeto.anillo, nivel: 19, agilidad: 4, aguante: 4, precio: 2630),
  Objeto('Banda del Viajero', TipoObjeto.anillo, nivel: 20, poder: 4, vigor: 2, agilidad: 4, maestria: 3, guardia: 3, aguante: 4, precio: 1000, conGemas: true),
  Objeto('Sortija de la Noche Eterna', TipoObjeto.anillo, nivel: 21, poder: 7, maestria: 4, aguante: 1, inclinacion: -1555, precio: 3610),
  Objeto('Banda de la Vela Eterna', TipoObjeto.anillo, nivel: 21, vigor: 4, agilidad: 6, guardia: 4, aguante: 1, inclinacion: 1555, precio: 3610),
  Objeto('Aro del Zorro', TipoObjeto.anillo, nivel: 22, agilidad: 5, guardia: 3, precio: 4350),
  Objeto('Sortija del Viajero', TipoObjeto.anillo, nivel: 23, poder: 5, agilidad: 5, maestria: 4, guardia: 4, aguante: 5, precio: 1250, conGemas: true),
  Objeto('Banda de la Embestida', TipoObjeto.anillo, nivel: 24, poder: 5, maestria: 5, precio: 5360),
  Objeto('Sortija del Eclipse', TipoObjeto.anillo, nivel: 26, poder: 10, vigor: 4, maestria: 5, aguante: 2, inclinacion: -2370, precio: 6220),
  Objeto('Sortija de la Catedral', TipoObjeto.anillo, nivel: 26, agilidad: 8, guardia: 5, aguante: 2, vigor: 2, inclinacion: 2370, precio: 6220),
  Objeto('Aro del Círculo', TipoObjeto.anillo, nivel: 27, poder: 1, agilidad: 5, maestria: 5, guardia: 1, aguante: 1, precio: 7160),
  Objeto('Alianza de la Armonía', TipoObjeto.anillo, nivel: 28, poder: 3, agilidad: 3, maestria: 3, guardia: 3, aguante: 2, precio: 7740),
  Objeto('Sello de la Alianza Eterna', TipoObjeto.anillo, nivel: 30, poder: 6, vigor: 3, agilidad: 6, maestria: 5, guardia: 5, aguante: 6, precio: 1400, conGemas: true),
  Objeto('Anillo del Nómada Errante', TipoObjeto.anillo, nivel: 32, poder: 5, vigor: 3, agilidad: 1, maestria: 1, guardia: 5, aguante: 2, precio: 9820),
  Objeto('Anillo de la Sangre Negra', TipoObjeto.anillo, nivel: 34, poder: 6, agilidad: 5, maestria: 3, guardia: 3, aguante: 4, inclinacion: -3960, precio: 11000),
  Objeto('Aro de los Justos', TipoObjeto.anillo, nivel: 34, poder: 5, agilidad: 4, maestria: 3, guardia: 3, aguante: 4, vigor: 2, inclinacion: 3960, precio: 11000),
  Objeto('Sortija de la Alianza Eterna', TipoObjeto.anillo, nivel: 36, poder: 1, vigor: 4, agilidad: 1, maestria: 7, guardia: 7, aguante: 2, precio: 12000),
  Objeto('Sello de las Mil Batallas', TipoObjeto.anillo, nivel: 38, poder: 7, agilidad: 7, maestria: 7, guardia: 7, aguante: 7, precio: 1500, conGemas: true),
  Objeto('Alianza del Viajero', TipoObjeto.anillo, nivel: 39, poder: 6, agilidad: 6, maestria: 1, guardia: 1, aguante: 3, precio: 13000),
  Objeto('Sello del Aventurero', TipoObjeto.anillo, nivel: 41, poder: 4, agilidad: 3, maestria: 5, guardia: 5, aguante: 5, precio: 13600),
  Objeto('Alianza del Círculo', TipoObjeto.anillo, nivel: 43, poder: 5, agilidad: 5, maestria: 4, guardia: 4, aguante: 4, precio: 14200),
  Objeto('Sortija del Triunfo', TipoObjeto.anillo, nivel: 44, poder: 8, agilidad: 9, maestria: 8, guardia: 8, aguante: 9, precio: 1525, conGemas: true),
  Objeto('Aro del Pecado', TipoObjeto.anillo, nivel: 45, poder: 8, vigor: 3, agilidad: 5, maestria: 6, guardia: 6, aguante: 5, inclinacion: -6585, precio: 15000),
  Objeto('Aro del Custodio', TipoObjeto.anillo, nivel: 45, poder: 5, agilidad: 5, maestria: 6, guardia: 6, aguante: 5, vigor: 3, inclinacion: 6585, precio: 15000),
  Objeto('Aro del Viajero', TipoObjeto.anillo, nivel: 47, poder: 5, agilidad: 5, maestria: 4, guardia: 5, aguante: 4, precio: 15500),
  Objeto('Sortija de los Cuatro Vientos', TipoObjeto.anillo, nivel: 49, poder: 9, vigor: 5, agilidad: 9, maestria: 10, guardia: 10, aguante: 9, precio: 1550, conGemas: true),
  Objeto('Anillo del Triunfo', TipoObjeto.anillo, nivel: 51, poder: 5, agilidad: 5, maestria: 5, guardia: 4, aguante: 5, precio: 16200),
  Objeto('Sello del Triunfo', TipoObjeto.anillo, nivel: 52, poder: 5, agilidad: 5, maestria: 5, guardia: 5, aguante: 6, precio: 16600),
  Objeto('Sortija del Aventurero', TipoObjeto.anillo, nivel: 53, poder: 11, agilidad: 10, maestria: 9, guardia: 10, aguante: 11, precio: 1575, conGemas: true),
  Objeto('Sello del Equilibrio', TipoObjeto.anillo, nivel: 54, poder: 5, vigor: 3, agilidad: 6, maestria: 6, guardia: 6, aguante: 5, precio: 17200),
  Objeto('Anillo del Equilibrio', TipoObjeto.anillo, nivel: 56, poder: 6, vigor: 3, agilidad: 6, maestria: 5, guardia: 6, aguante: 6, precio: 17800),
  Objeto('Sello del Vacío', TipoObjeto.anillo, nivel: 57, poder: 10, vigor: 4, agilidad: 7, maestria: 6, guardia: 6, aguante: 6, inclinacion: -9885, precio: 18200),
  Objeto('Aro del Cielo Abierto', TipoObjeto.anillo, nivel: 57, poder: 7, agilidad: 7, maestria: 6, guardia: 6, aguante: 6, vigor: 3, inclinacion: 9885, precio: 18200),
  Objeto('Sello de la Constelación', TipoObjeto.anillo, nivel: 59, poder: 12, agilidad: 12, maestria: 10, guardia: 10, aguante: 11, precio: 1600, conGemas: true),
  Objeto('Anillo de la Constelación', TipoObjeto.anillo, nivel: 61, poder: 6, agilidad: 6, maestria: 6, guardia: 6, aguante: 7, precio: 19200),
  Objeto('Banda del Círculo', TipoObjeto.anillo, nivel: 63, poder: 6, vigor: 4, agilidad: 6, maestria: 7, guardia: 7, aguante: 7, precio: 19700),
  Objeto('Anillo de las Mil Batallas', TipoObjeto.anillo, nivel: 64, poder: 12, agilidad: 13, maestria: 12, guardia: 11, aguante: 13, precio: 1625, conGemas: true),
  Objeto('Banda de las Mil Batallas', TipoObjeto.anillo, nivel: 64, poder: 7, vigor: 4, agilidad: 7, maestria: 6, guardia: 6, aguante: 7, precio: 20100),
  Objeto('Banda del Nómada Errante', TipoObjeto.anillo, nivel: 66, poder: 8, agilidad: 7, maestria: 7, guardia: 5, aguante: 5, precio: 20600),
  Objeto('Aro del Zodiaco', TipoObjeto.anillo, nivel: 68, poder: 7, agilidad: 8, maestria: 6, guardia: 6, aguante: 7, precio: 21100),
  Objeto('Alianza de la Alianza Eterna', TipoObjeto.anillo, nivel: 69, poder: 14, agilidad: 13, maestria: 14, guardia: 14, aguante: 14, precio: 1650, conGemas: true),
  Objeto('Anillo de la Armonía', TipoObjeto.anillo, nivel: 71, poder: 8, vigor: 4, agilidad: 7, maestria: 7, guardia: 8, aguante: 8, precio: 21600),
  Objeto('Aro del Mártir', TipoObjeto.anillo, nivel: 73, poder: 8, vigor: 9, agilidad: 8, maestria: 8, guardia: 8, aguante: 9, inclinacion: 14800, precio: 22100),
  Objeto('Sello del Eclipse', TipoObjeto.anillo, nivel: 73, poder: 12, agilidad: 8, maestria: 8, guardia: 8, aguante: 9, inclinacion: -14800, precio: 22100),
  Objeto('Aro del Triunfo', TipoObjeto.anillo, nivel: 74, poder: 8, agilidad: 8, maestria: 8, guardia: 8, aguante: 8, precio: 22500),
  Objeto('Sortija del Zodiaco', TipoObjeto.anillo, nivel: 76, poder: 16, vigor: 8, agilidad: 16, maestria: 15, guardia: 15, aguante: 15, precio: 1700, conGemas: true),
  Objeto('Sortija del Equilibrio', TipoObjeto.anillo, nivel: 78, poder: 9, vigor: 5, agilidad: 8, maestria: 8, guardia: 9, aguante: 9, precio: 23000),
  Objeto('Aro del Aventurero', TipoObjeto.anillo, nivel: 80, poder: 9, agilidad: 9, maestria: 9, guardia: 9, aguante: 9, precio: 23400),
  Objeto('Alianza del Triunfo', TipoObjeto.anillo, nivel: 81, poder: 10, vigor: 5, agilidad: 9, maestria: 9, guardia: 9, aguante: 10, precio: 24000),
  Objeto('Anillo del Zodiaco', TipoObjeto.anillo, nivel: 83, poder: 17, agilidad: 17, maestria: 17, guardia: 17, aguante: 17, precio: 1750, conGemas: true),
  Objeto('Sello del Viajero', TipoObjeto.anillo, nivel: 85, poder: 10, agilidad: 10, maestria: 10, guardia: 10, aguante: 9, precio: 24400),
  Objeto('Banda del Aventurero', TipoObjeto.anillo, nivel: 86, poder: 10, agilidad: 11, maestria: 11, guardia: 10, aguante: 10, precio: 24900),
  Objeto('Alianza de la Plegaria', TipoObjeto.anillo, nivel: 89, poder: 11, vigor: 11, agilidad: 11, maestria: 11, guardia: 10, aguante: 11, inclinacion: 20135, precio: 26500),
  Objeto('Aro del Tirano', TipoObjeto.anillo, nivel: 89, poder: 16, vigor: 6, agilidad: 11, maestria: 11, guardia: 10, aguante: 11, inclinacion: -20135, precio: 26500),
  Objeto('Alianza del Equilibrio', TipoObjeto.anillo, nivel: 91, poder: 18, agilidad: 19, maestria: 19, guardia: 18, aguante: 18, precio: 1800, conGemas: true),
  Objeto('Anillo de los Cuatro Vientos', TipoObjeto.anillo, nivel: 93, poder: 11, agilidad: 11, maestria: 11, guardia: 11, aguante: 11, precio: 27700),
  Objeto('Aro de las Mil Batallas', TipoObjeto.anillo, nivel: 95, poder: 12, agilidad: 11, maestria: 11, guardia: 12, aguante: 11, precio: 28400),
  Objeto('Sortija del Nómada Errante', TipoObjeto.anillo, nivel: 97, poder: 12, agilidad: 12, maestria: 12, guardia: 11, aguante: 12, precio: 28900),
  Objeto('Alianza del Zodiaco', TipoObjeto.anillo, nivel: 99, poder: 19, vigor: 10, agilidad: 20, maestria: 20, guardia: 20, aguante: 19, precio: 1850, conGemas: true),
  Objeto('Anillo del Círculo', TipoObjeto.anillo, nivel: 102, poder: 12, vigor: 7, agilidad: 12, maestria: 12, guardia: 12, aguante: 13, precio: 30400),
  Objeto('Anillo del Viajero', TipoObjeto.anillo, nivel: 103, poder: 13, vigor: 7, agilidad: 13, maestria: 13, guardia: 12, aguante: 13, precio: 30900),
  Objeto('Banda de la Gracia', TipoObjeto.anillo, nivel: 106, poder: 13, agilidad: 14, maestria: 13, guardia: 13, aguante: 14, vigor: 6, inclinacion: 26140, precio: 31600),
  Objeto('Aro del Eclipse', TipoObjeto.anillo, nivel: 106, poder: 19, agilidad: 14, maestria: 13, guardia: 13, aguante: 14, inclinacion: -26140, precio: 31600),
  Objeto('Alianza del Nómada Errante', TipoObjeto.anillo, nivel: 107, poder: 21, vigor: 11, agilidad: 21, maestria: 21, guardia: 21, aguante: 21, precio: 1925, conGemas: true),
  Objeto('Banda del Zodiaco', TipoObjeto.anillo, nivel: 110, poder: 14, agilidad: 13, maestria: 14, guardia: 14, aguante: 14, precio: 32800),
  Objeto('Sortija de la Constelación', TipoObjeto.anillo, nivel: 111, poder: 14, agilidad: 14, maestria: 14, guardia: 15, aguante: 15, precio: 33200),
  Objeto('Aro del Nómada Errante', TipoObjeto.anillo, nivel: 113, poder: 15, agilidad: 15, maestria: 14, guardia: 15, aguante: 15, precio: 33800),
  Objeto('Sello de los Cuatro Vientos', TipoObjeto.anillo, nivel: 115, poder: 23, vigor: 12, agilidad: 22, maestria: 23, guardia: 23, aguante: 22, precio: 1975, conGemas: true),
  Objeto('Sello de la Armonía', TipoObjeto.anillo, nivel: 117, poder: 15, agilidad: 15, maestria: 15, guardia: 15, aguante: 16, precio: 35000),
  Objeto('Sello del Nómada Errante', TipoObjeto.anillo, nivel: 123, poder: 16, vigor: 9, agilidad: 15, maestria: 17, guardia: 16, aguante: 16, precio: 40000),
  Objeto('Banda del Equilibrio', TipoObjeto.anillo, nivel: 130, poder: 26, agilidad: 25, maestria: 26, guardia: 26, aguante: 25, precio: 2500, conGemas: true),
  Objeto('Aro de la Constelación', TipoObjeto.anillo, nivel: 137, poder: 17, agilidad: 15, maestria: 17, guardia: 16, aguante: 17, precio: 46000),
  Objeto('Banda de los Cuatro Vientos', TipoObjeto.anillo, nivel: 145, poder: 17, agilidad: 16, maestria: 17, guardia: 17, aguante: 17, precio: 52000),
  Objeto('Banda de la Constelación', TipoObjeto.anillo, nivel: 153, poder: 18, agilidad: 17, maestria: 18, guardia: 17, aguante: 17, precio: 60000),
  Objeto('Anillo del Aventurero', TipoObjeto.anillo, nivel: 162, poder: 28, agilidad: 27, maestria: 28, guardia: 29, aguante: 28, precio: 2800, conGemas: true),
  Objeto('Aro de los Cuatro Vientos', TipoObjeto.anillo, nivel: 170, poder: 18, agilidad: 17, maestria: 18, guardia: 18, aguante: 18, precio: 6700),
  Objeto('Aro de la Armonía', TipoObjeto.anillo, nivel: 180, poder: 19, agilidad: 18, maestria: 19, guardia: 18, aguante: 18, precio: 75000),
  Objeto('Alianza de los Cuatro Vientos', TipoObjeto.anillo, nivel: 190, poder: 19, vigor: 10, agilidad: 19, maestria: 19, guardia: 19, aguante: 19, precio: 83000),
  Objeto('Alianza de la Constelación', TipoObjeto.anillo, nivel: 200, poder: 31, agilidad: 30, maestria: 31, guardia: 31, aguante: 30, precio: 3100, conGemas: true),

  // ---------------- COLGANTES (81) ----------------
  Objeto('Relicario del Estratega', TipoObjeto.colgante, nivel: 6, maestria: 1, precio: 200),
  Objeto('Amuleto del Ancla', TipoObjeto.colgante, nivel: 8, guardia: 1, aguante: 1, precio: 50, conGemas: true),
  Objeto('Talismán de los Condenados', TipoObjeto.colgante, nivel: 9, guardia: 1, aguante: 2, precio: 300),
  Objeto('Relicario de la Forja Negra', TipoObjeto.colgante, nivel: 9, poder: 2, maestria: 1, precio: 400),
  Objeto('Amuleto de la Plegaria', TipoObjeto.colgante, nivel: 11, agilidad: 2, guardia: 2, vigor: 1, inclinacion: 440, precio: 600),
  Objeto('Medallón del Eclipse', TipoObjeto.colgante, nivel: 11, poder: 3, vigor: 1, maestria: 2, inclinacion: -440, precio: 600),
  Objeto('Amuleto del Rey Caído', TipoObjeto.colgante, nivel: 14, agilidad: 2, guardia: 3, aguante: 2, precio: 250, conGemas: true),
  Objeto('Medallón del Lobo Gris', TipoObjeto.colgante, nivel: 16, maestria: 2, precio: 1000),
  Objeto('Relicario de la Cripta', TipoObjeto.colgante, nivel: 19, poder: 2, maestria: 2, precio: 1600),
  Objeto('Talismán de la Luna Roja', TipoObjeto.colgante, nivel: 21, agilidad: 2, guardia: 2, precio: 400, conGemas: true),
  Objeto('Amuleto del Ocaso', TipoObjeto.colgante, nivel: 23, poder: 2, aguante: 2, precio: 2250),
  Objeto('Dije del Juramento Sagrado', TipoObjeto.colgante, nivel: 25, agilidad: 2, guardia: 2, aguante: 2, vigor: 1, inclinacion: 2195, precio: 3030),
  Objeto('Dije del Cuervo Maldito', TipoObjeto.colgante, nivel: 25, poder: 3, maestria: 2, aguante: 2, inclinacion: -2195, precio: 3030),
  Objeto('Relicario del Martillo', TipoObjeto.colgante, nivel: 27, poder: 4, vigor: 2, agilidad: 4, aguante: 4, precio: 500, conGemas: true),
  Objeto('Medallón de la Furia', TipoObjeto.colgante, nivel: 30, poder: 4, maestria: 3, precio: 4370),
  Objeto('Medallón del Cielo Abierto', TipoObjeto.colgante, nivel: 32, vigor: 3, guardia: 3, inclinacion: 3530, precio: 5610),
  Objeto('Talismán del Vacío', TipoObjeto.colgante, nivel: 32, vigor: 2, guardia: 3, poder: 1, inclinacion: -3530, precio: 5610),
  Objeto('Amuleto del Triunfo', TipoObjeto.colgante, nivel: 34, poder: 5, vigor: 3, agilidad: 5, maestria: 2, guardia: 2, aguante: 5, precio: 750, conGemas: true),
  Objeto('Amuleto del Invierno', TipoObjeto.colgante, nivel: 38, poder: 3, vigor: 2, maestria: 2, guardia: 2, precio: 7000),
  Objeto('Amuleto de la Hoguera', TipoObjeto.colgante, nivel: 40, vigor: 2, aguante: 3, precio: 8000),
  Objeto('Talismán de Sangre Vieja', TipoObjeto.colgante, nivel: 43, poder: 4, vigor: 2, agilidad: 3, maestria: 2, precio: 8000),
  Objeto('Medallón de la Vela Eterna', TipoObjeto.colgante, nivel: 45, poder: 1, vigor: 4, agilidad: 1, maestria: 4, inclinacion: 6585, precio: 10500),
  Objeto('Relicario del Vacío', TipoObjeto.colgante, nivel: 45, poder: 3, agilidad: 1, maestria: 4, inclinacion: -6585, precio: 10500),
  Objeto('Dije del Aventurero', TipoObjeto.colgante, nivel: 48, poder: 7, vigor: 4, agilidad: 6, maestria: 3, guardia: 3, aguante: 5, precio: 800, conGemas: true),
  Objeto('Amuleto de Sangre Vieja', TipoObjeto.colgante, nivel: 50, poder: 2, agilidad: 4, maestria: 2, guardia: 2, precio: 13000),
  Objeto('Relicario del Círculo', TipoObjeto.colgante, nivel: 54, poder: 4, agilidad: 2, maestria: 4, guardia: 2, precio: 14500),
  Objeto('Dije de la Roca', TipoObjeto.colgante, nivel: 56, vigor: 2, maestria: 4, guardia: 4, aguante: 4, precio: 15500),
  Objeto('Talismán del Zodiaco', TipoObjeto.colgante, nivel: 58, poder: 7, vigor: 4, agilidad: 7, maestria: 7, guardia: 7, aguante: 5, precio: 900, conGemas: true),
  Objeto('Medallón de la Plegaria', TipoObjeto.colgante, nivel: 58, poder: 3, agilidad: 3, maestria: 3, guardia: 3, aguante: 3, vigor: 3, inclinacion: 10180, precio: 17500),
  Objeto('Amuleto de la Condenación', TipoObjeto.colgante, nivel: 58, poder: 6, agilidad: 3, maestria: 3, guardia: 3, aguante: 3, inclinacion: -10180, precio: 17500),
  Objeto('Dije de Sangre Vieja', TipoObjeto.colgante, nivel: 63, poder: 6, vigor: 3, agilidad: 3, maestria: 5, aguante: 2, precio: 18500),
  Objeto('Colgante del Verdugo', TipoObjeto.colgante, nivel: 65, poder: 3, vigor: 3, agilidad: 6, guardia: 5, aguante: 2, precio: 20000),
  Objeto('Talismán del Herrero Ciego', TipoObjeto.colgante, nivel: 67, poder: 1, agilidad: 1, maestria: 6, guardia: 6, aguante: 1, precio: 21000),
  Objeto('Dije de la Forja Negra', TipoObjeto.colgante, nivel: 70, poder: 9, agilidad: 9, maestria: 6, guardia: 7, aguante: 6, precio: 1000, conGemas: true),
  Objeto('Dije del Viajero', TipoObjeto.colgante, nivel: 72, poder: 5, vigor: 3, agilidad: 4, guardia: 3, aguante: 3, precio: 23000),
  Objeto('Talismán de la Gracia', TipoObjeto.colgante, nivel: 74, poder: 4, agilidad: 5, maestria: 5, aguante: 3, vigor: 3, inclinacion: 15120, precio: 24000),
  Objeto('Talismán del Hambre', TipoObjeto.colgante, nivel: 74, poder: 7, agilidad: 5, maestria: 5, aguante: 3, inclinacion: -15120, precio: 24000),
  Objeto('Talismán del Aventurero', TipoObjeto.colgante, nivel: 76, poder: 4, vigor: 2, agilidad: 4, maestria: 4, guardia: 4, aguante: 4, precio: 25500),
  Objeto('Dije del Centinela', TipoObjeto.colgante, nivel: 79, poder: 4, vigor: 3, agilidad: 5, maestria: 4, guardia: 4, aguante: 4, precio: 26500),
  Objeto('Talismán de la Luna Carmesí', TipoObjeto.colgante, nivel: 82, poder: 10, agilidad: 10, maestria: 9, guardia: 8, aguante: 8, precio: 1100, conGemas: true),
  Objeto('Amuleto de la Absolución', TipoObjeto.colgante, nivel: 85, poder: 5, agilidad: 5, maestria: 4, guardia: 5, aguante: 4, vigor: 4, inclinacion: 18770, precio: 28000),
  Objeto('Dije de la Condenación', TipoObjeto.colgante, nivel: 85, poder: 9, agilidad: 5, maestria: 4, guardia: 5, aguante: 4, inclinacion: -18770, precio: 28000),
  Objeto('Medallón del Invierno', TipoObjeto.colgante, nivel: 88, poder: 5, agilidad: 5, maestria: 5, guardia: 5, aguante: 4, precio: 29500),
  Objeto('Dije de la Armonía', TipoObjeto.colgante, nivel: 91, poder: 5, vigor: 3, agilidad: 5, maestria: 5, guardia: 6, aguante: 6, precio: 30500),
  Objeto('Relicario de las Sombras', TipoObjeto.colgante, nivel: 92, poder: 11, agilidad: 11, maestria: 9, guardia: 10, aguante: 9, precio: 1125, conGemas: true),
  Objeto('Dije del Equilibrio', TipoObjeto.colgante, nivel: 94, poder: 6, agilidad: 6, maestria: 5, guardia: 6, aguante: 6, precio: 32600),
  Objeto('Amuleto de la Ceniza', TipoObjeto.colgante, nivel: 98, poder: 5, vigor: 3, agilidad: 5, maestria: 6, guardia: 6, aguante: 6, precio: 33000),
  Objeto('Talismán del Amanecer', TipoObjeto.colgante, nivel: 100, poder: 6, agilidad: 7, maestria: 6, guardia: 6, aguante: 6, vigor: 4, inclinacion: 23985, precio: 34000),
  Objeto('Relicario de los Malditos', TipoObjeto.colgante, nivel: 100, poder: 10, agilidad: 7, maestria: 6, guardia: 6, aguante: 6, inclinacion: -23985, precio: 34000),
  Objeto('Dije del Ocaso', TipoObjeto.colgante, nivel: 103, poder: 11, agilidad: 12, maestria: 11, guardia: 11, aguante: 10, precio: 1150, conGemas: true),
  Objeto('Relicario del Exiliado', TipoObjeto.colgante, nivel: 107, poder: 6, agilidad: 6, maestria: 7, guardia: 6, aguante: 7, precio: 36000),
  Objeto('Colgante del Verdugo Oscuro', TipoObjeto.colgante, nivel: 111, poder: 7, agilidad: 7, maestria: 6, guardia: 6, aguante: 7, precio: 37500),
  Objeto('Talismán de la Tormenta', TipoObjeto.colgante, nivel: 113, poder: 13, vigor: 7, agilidad: 12, maestria: 12, guardia: 11, aguante: 11, precio: 1200, conGemas: true),
  Objeto('Talismán del Círculo', TipoObjeto.colgante, nivel: 114, poder: 7, vigor: 4, agilidad: 7, maestria: 8, guardia: 8, aguante: 7, precio: 39000),
  Objeto('Talismán del Viajero', TipoObjeto.colgante, nivel: 118, poder: 7, vigor: 5, agilidad: 8, maestria: 9, guardia: 8, aguante: 7, precio: 41000),
  Objeto('Amuleto del Verdugo', TipoObjeto.colgante, nivel: 120, poder: 13, agilidad: 13, maestria: 12, guardia: 13, aguante: 12, precio: 1250, conGemas: true),
  Objeto('Talismán de la Noche Eterna', TipoObjeto.colgante, nivel: 124, poder: 14, agilidad: 8, maestria: 8, guardia: 7, aguante: 8, inclinacion: -32790, precio: 43000),
  Objeto('Amuleto del Cielo Abierto', TipoObjeto.colgante, nivel: 124, poder: 8, agilidad: 8, maestria: 8, guardia: 7, aguante: 8, vigor: 6, inclinacion: 32790, precio: 43000),
  Objeto('Amuleto del Mercenario', TipoObjeto.colgante, nivel: 127, poder: 8, agilidad: 8, maestria: 8, guardia: 8, aguante: 9, precio: 46000),
  Objeto('Dije de los Condenados', TipoObjeto.colgante, nivel: 130, poder: 13, agilidad: 14, maestria: 14, guardia: 15, aguante: 13, precio: 1275, conGemas: true),
  Objeto('Talismán de la Alianza Eterna', TipoObjeto.colgante, nivel: 133, poder: 9, agilidad: 9, maestria: 9, guardia: 10, aguante: 9, precio: 47500),
  Objeto('Medallón de las Sombras', TipoObjeto.colgante, nivel: 136, poder: 9, agilidad: 9, maestria: 9, guardia: 9, aguante: 10, precio: 49000),
  Objeto('Amuleto del Herrero Ciego', TipoObjeto.colgante, nivel: 139, poder: 15, agilidad: 15, maestria: 15, guardia: 16, aguante: 14, precio: 1350, conGemas: true),
  Objeto('Medallón de la Constelación', TipoObjeto.colgante, nivel: 143, poder: 10, vigor: 6, agilidad: 11, maestria: 11, guardia: 11, aguante: 10, precio: 51000),
  Objeto('Relicario del Pantano', TipoObjeto.colgante, nivel: 147, poder: 11, agilidad: 10, maestria: 10, guardia: 11, aguante: 11, precio: 51800),
  Objeto('Colgante de las Sombras', TipoObjeto.colgante, nivel: 151, poder: 16, vigor: 9, agilidad: 16, maestria: 16, guardia: 16, aguante: 17, precio: 1400, conGemas: true),
  Objeto('Dije del Eclipse', TipoObjeto.colgante, nivel: 155, poder: 18, agilidad: 11, maestria: 11, guardia: 11, aguante: 11, inclinacion: -44745, precio: 54400),
  Objeto('Dije del Custodio', TipoObjeto.colgante, nivel: 155, poder: 11, agilidad: 11, maestria: 11, guardia: 11, aguante: 11, vigor: 7, inclinacion: 44745, precio: 54400),
  Objeto('Dije de los Huesos', TipoObjeto.colgante, nivel: 158, poder: 18, agilidad: 17, maestria: 18, guardia: 17, aguante: 18, precio: 1450, conGemas: true),
  Objeto('Relicario del Zodiaco', TipoObjeto.colgante, nivel: 162, poder: 11, agilidad: 12, maestria: 12, guardia: 12, aguante: 11, precio: 57200),
  Objeto('Dije de la Ruina', TipoObjeto.colgante, nivel: 166, poder: 12, agilidad: 11, maestria: 11, guardia: 11, aguante: 12, precio: 58400),
  Objeto('Talismán del Páramo', TipoObjeto.colgante, nivel: 170, poder: 19, agilidad: 19, maestria: 19, guardia: 19, aguante: 19, precio: 1500, conGemas: true),
  Objeto('Amuleto de la Luna Roja', TipoObjeto.colgante, nivel: 173, poder: 11, vigor: 6, agilidad: 12, maestria: 12, guardia: 12, aguante: 12, precio: 61200),
  Objeto('Amuleto del Zodiaco', TipoObjeto.colgante, nivel: 177, poder: 12, agilidad: 13, maestria: 12, guardia: 13, aguante: 12, precio: 62400),
  Objeto('Talismán del Lobo Gris', TipoObjeto.colgante, nivel: 182, poder: 20, agilidad: 21, maestria: 21, guardia: 20, aguante: 21, precio: 1550, conGemas: true),
  Objeto('Talismán de la Condenación', TipoObjeto.colgante, nivel: 185, poder: 21, agilidad: 12, maestria: 12, guardia: 13, aguante: 13, inclinacion: -56765, precio: 65200),
  Objeto('Medallón de la Luz Eterna', TipoObjeto.colgante, nivel: 185, poder: 13, vigor: 15, agilidad: 12, maestria: 12, guardia: 13, aguante: 13, inclinacion: 56765, precio: 65200),
  Objeto('Relicario del Lobo Gris', TipoObjeto.colgante, nivel: 189, poder: 22, agilidad: 22, maestria: 22, guardia: 22, aguante: 22, precio: 1600, conGemas: true),
  Objeto('Amuleto de las Cenizas', TipoObjeto.colgante, nivel: 192, poder: 12, agilidad: 13, maestria: 13, guardia: 12, aguante: 13, precio: 67800),
  Objeto('Medallón del Triunfo', TipoObjeto.colgante, nivel: 196, poder: 13, vigor: 7, agilidad: 13, maestria: 13, guardia: 13, aguante: 13, precio: 69200),
  Objeto('Dije del Cazador', TipoObjeto.colgante, nivel: 200, poder: 23, agilidad: 23, maestria: 23, guardia: 23, aguante: 23, precio: 1650, conGemas: true),
];

// Lo que se vende en la tienda (sin los objetos del bazar),
// ordenado por nivel y precio.
final List<Objeto> catalogoTienda = (catalogo
    .where((o) => !o.bazar)
    .toList()
  ..sort((a, b) {
    final porNivel = a.nivelRequerido.compareTo(b.nivelRequerido);
    return porNivel != 0 ? porNivel : a.precio.compareTo(b.precio);
  }));