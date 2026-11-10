import 'package:flutter/material.dart';

// ====================== PALETA ======================
const Color colFondo = Color(0xFF140A0E);
const Color colPanel = Color(0xFF2A1218);
const Color colPanelAlto = Color(0xFF341A21);
const Color colBorde = Color(0xFF5A2A33);
const Color colSangre = Color(0xFFC0392B);
const Color colSangreOscura = Color(0xFF5A0F1B);
const Color colOro = Color(0xFFD4A64A);
const Color colTexto = Color(0xFFEDE3DC);
const Color colTextoSuave = Color(0xFFB9A9A3);

// ====================== TEMA GENERAL ======================
ThemeData construirTema() {
  final esquema = ColorScheme.dark(
    primary: colSangre,
    onPrimary: Colors.white,
    secondary: colOro,
    onSecondary: Colors.black,
    surface: colPanel,
    onSurface: colTexto,
  );
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: esquema,
  );

  return base.copyWith(
    scaffoldBackgroundColor: colFondo,
    textTheme: base.textTheme.apply(bodyColor: colTexto, displayColor: colTexto),

    appBarTheme: const AppBarTheme(
      backgroundColor: colSangreOscura,
      foregroundColor: colTexto,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      shape: Border(bottom: BorderSide(color: colSangre, width: 2)),
      titleTextStyle: TextStyle(
        fontFamily: 'serif',
        fontSize: 21,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: colTexto,
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colPanel,
      surfaceTintColor: Colors.transparent,
      indicatorColor: colSangreOscura,
      labelTextStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 11)),
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((s) =>
          IconThemeData(
              color: s.contains(WidgetState.selected) ? colOro : colTextoSuave)),
    ),

    cardTheme: CardThemeData(
      color: colPanel,
      elevation: 3,
      shadowColor: Colors.black87,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: colBorde),
      ),
    ),

    listTileTheme: const ListTileThemeData(
      iconColor: colOro,
      subtitleTextStyle: TextStyle(fontSize: 12, color: colTextoSuave),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colSangreOscura,
        foregroundColor: colTexto,
        disabledBackgroundColor: const Color(0xFF2E2226),
        disabledForegroundColor: Colors.white30,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colTexto,
        side: const BorderSide(color: colSangre),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: colOro),
    ),

    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith<Color?>((s) =>
        s.contains(WidgetState.selected) ? colSangreOscura : colPanelAlto),
        foregroundColor: WidgetStateProperty.resolveWith<Color?>((s) =>
        s.contains(WidgetState.disabled) ? Colors.white30 : colTexto),
        side: const WidgetStatePropertyAll(BorderSide(color: colBorde)),
      ),
    ),

    tabBarTheme: const TabBarThemeData(
      labelColor: colTexto,
      unselectedLabelColor: colTextoSuave,
      indicatorColor: colSangre,
      dividerColor: colBorde,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: colPanel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: colBorde),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colPanelAlto,
      contentTextStyle: const TextStyle(color: colTexto),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: colBorde),
      ),
    ),

    sliderTheme: const SliderThemeData(
      activeTrackColor: colSangre,
      inactiveTrackColor: colBorde,
      thumbColor: colOro,
      valueIndicatorColor: colSangreOscura,
    ),

    chipTheme: ChipThemeData(
      backgroundColor: colPanelAlto,
      selectedColor: colSangreOscura,
      side: const BorderSide(color: colBorde),
    ),
  );
}

// ====================== PIEZAS REUTILIZABLES ======================

// Fondo con degradado para todas las pantallas
class FondoApp extends StatelessWidget {
  final Widget child;
  const FondoApp({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF241018), colFondo, Color(0xFF0C0608)],
          ),
        ),
        child: child,
      ),
    );
  }
}

// Marco dorado con brillo rojo para el retrato del personaje.
// Si la imagen no existe todavía, muestra el ícono de respaldo.
class RetratoPersonaje extends StatelessWidget {
  final String ruta;
  final IconData iconoRespaldo;
  final double ancho;
  final double alto;

  const RetratoPersonaje({
    super.key,
    required this.ruta,
    required this.iconoRespaldo,
    this.ancho = 180,
    this.alto = 220,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ancho,
      height: alto,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A1A22), Color(0xFF1A0C10)],
        ),
        border: Border.all(color: colOro.withAlpha(190), width: 2),
        boxShadow: [
          BoxShadow(
            color: colSangre.withAlpha(90),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.asset(
          ruta,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(
            child:
            Icon(iconoRespaldo, size: ancho * 0.75, color: Colors.white38),
          ),
        ),
      ),
    );
  }
}

// Barra de vida / fama / inclinación con relleno degradado
class BarraEstado extends StatelessWidget {
  final String etiqueta;
  final String texto;
  final double valor;
  final Color color;

  const BarraEstado({
    super.key,
    required this.etiqueta,
    required this.texto,
    required this.valor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(etiqueta,
                style: const TextStyle(
                    fontSize: 12, color: colTextoSuave, letterSpacing: 0.5)),
            Text(texto,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 14,
          decoration: BoxDecoration(
            color: const Color(0xFF0E0709),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: colBorde),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: valor.clamp(0.0, 1.0).toDouble(),
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withAlpha(140), color],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}