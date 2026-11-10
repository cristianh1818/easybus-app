// Splash animado (skill easybus-motion) con el logo oficial, como el mockup
// "Pantalla de carga". Continúa al splash nativo: mismo fondo y el logo en la misma
// posición y tamaño (90 %), así el paso no se nota.
//
// Dura lo que tarda la preparación real (descargar embarcaderos), con un mínimo de
// 600 ms para que la animación no se corte y un máximo de 2 s: si la red tarda,
// se entra igual y la pantalla muestra su propio estado de carga o error.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/data_providers.dart';
import '../theme/eb_tokens.dart';
import '../widgets/eb_animated_logo.dart';

/// Fondo del splash (nativo y animado). Si se cambia, regenerar el nativo:
/// ver tool/generate_brand_images_test.dart.
const splashBackground = EbColors.logoBlue;

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({
    super.key,
    required this.next,
    this.background = splashBackground,
    this.maxWait = maxDuration,
  });

  /// Pantalla a la que se pasa al terminar.
  final WidgetBuilder next;
  final Color background;

  /// Espera máxima por los datos antes de seguir (las pruebas la alargan).
  final Duration maxWait;

  static const minDuration = Duration(milliseconds: 600);
  static const maxDuration = Duration(seconds: 2);

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  ProviderSubscription<Object?>? _warmupSub;
  bool _started = false;
  bool _logoReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    unawaited(_showWhenLogoReady());
    unawaited(_prepareAndContinue());
  }

  // El splash nativo sigue visible (FlutterNativeSplash.preserve en main) hasta que
  // el logo esté decodificado; si no, el primer cuadro saldría sin logo. El logo se
  // monta recién entonces, para que su entrada empiece cuando ya se ve.
  Future<void> _showWhenLogoReady() async {
    await precacheImage(const AssetImage(EbAnimatedLogo.asset), context);
    if (!mounted) {
      FlutterNativeSplash.remove();
      return;
    }
    setState(() => _logoReady = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => FlutterNativeSplash.remove());
  }

  Future<void> _prepareAndContinue() async {
    // Precarga de embarcaderos: el provider conserva el resultado para la siguiente
    // pantalla. Hay que ESCUCHARLO (no basta ref.read): en Riverpod 3 un provider sin
    // oyentes queda en pausa y nunca terminaría de cargar.
    final ready = Completer<void>();
    final sub = ref.listenManual(embarcaderosProvider, (_, next) {
      // Datos o error definitivo: ya se puede seguir (la pantalla mostrará el error).
      if (!next.isLoading && !ready.isCompleted) ready.complete();
    }, fireImmediately: true);
    _warmupSub = sub;

    final warmup = ready.future.timeout(widget.maxWait, onTimeout: () {});
    await Future.wait([Future<void>.delayed(SplashScreen.minDuration), warmup]);
    if (!mounted) return;

    await Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: EbDurations.normal,
        pageBuilder: (context, _, _) => widget.next(context),
        transitionsBuilder: (context, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: EbCurves.enter),
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _warmupSub?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Íconos claros sobre el fondo oscuro
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: widget.background,
        // Sin SafeArea a propósito: el logo va centrado en la pantalla completa,
        // igual que en el splash nativo.
        body: _logoReady ? const Center(child: EbAnimatedLogo()) : const SizedBox.expand(),
      ),
    );
  }
}
