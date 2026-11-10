import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// ====================== ANUNCIOS RECOMPENSADOS (AdMob) ======================
// El jugador decide ver un anuncio y, a cambio, recibe una recompensa.
// Mientras desarrollas se usan los IDs de PRUEBA de Google (kDebugMode).
// Antes de publicar, pon tu Ad Unit ID real en [_idRecompensadoReal].
// NUNCA toques tus propios anuncios reales mientras pruebas: AdMob puede
// suspender tu cuenta.

class Anuncios {
  Anuncios._();
  static final Anuncios instancia = Anuncios._();

  // ID de prueba oficial de Google para anuncios recompensados (Android).
  static const String _idPrueba = 'ca-app-pub-3940256099942544/5224354917';
  // <-- CAMBIA ESTO por tu Ad Unit ID real (ca-app-pub-xxx/zzz) al publicar.
  static const String _idRecompensadoReal = 'TU_ID_REAL_AQUI';

  static String get _idRecompensado =>
      kDebugMode ? _idPrueba : _idRecompensadoReal;

  // AdMob solo funciona en Android e iOS.
  static bool get _plataformaSoportada =>
      !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);

  RewardedAd? _anuncio;
  bool _cargando = false;
  bool _iniciado = false;

  Future<void> iniciar() async {
    if (_iniciado || !_plataformaSoportada) return;
    _iniciado = true;
    try {
      await MobileAds.instance.initialize();
      _cargar();
    } catch (_) {
      _iniciado = false;
    }
  }

  void _cargar() {
    if (!_plataformaSoportada || _cargando || _anuncio != null) return;
    _cargando = true;
    RewardedAd.load(
      adUnitId: _idRecompensado,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _anuncio = ad;
          _cargando = false;
        },
        onAdFailedToLoad: (_) {
          _cargando = false;
        },
      ),
    );
  }

  bool get listo => _anuncio != null;

  /// Muestra el anuncio. [alGanar] se llama solo si el jugador lo vio completo.
  /// Devuelve false si todavía no había un anuncio cargado.
  bool mostrar(VoidCallback alGanar) {
    // En plataformas sin AdMob (solo para probar en PC/web) se da la recompensa.
    if (!_plataformaSoportada) {
      if (kDebugMode) {
        alGanar();
        return true;
      }
      return false;
    }
    final ad = _anuncio;
    if (ad == null) {
      _cargar();
      return false;
    }
    _anuncio = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _cargar(); // deja listo el siguiente
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        _cargar();
      },
    );
    ad.show(onUserEarnedReward: (_, __) => alGanar());
    return true;
  }
}