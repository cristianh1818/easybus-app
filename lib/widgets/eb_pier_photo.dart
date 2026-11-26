// Foto del embarcadero: portada en la hoja del mapa, más grande en el detalle y en
// pantalla completa con zoom. Las tres comparten la misma etiqueta Hero, así la foto
// "viaja" de una a otra. Sin foto (o si no carga) se ve el fondo del modo con su
// ícono, del mismo tamaño que tendría la foto.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/embarcadero.dart';
import '../theme/eb_tokens.dart';
import '../theme/mode_style.dart';

/// Etiqueta Hero de la foto (o del fondo con el ícono) de un embarcadero.
String pierPhotoHeroTag(String id) => 'pier-photo-$id';

class EbPierPhoto extends StatelessWidget {
  const EbPierPhoto({
    super.key,
    required this.embarcadero,
    required this.aspectRatio,
    this.borderRadius = const BorderRadius.all(Radius.circular(EbRadius.card)),
    this.onTap,
    this.hero = true,
  });

  final Embarcadero embarcadero;
  final double aspectRatio;
  final BorderRadius borderRadius;

  /// Solo si hay foto: se abre en pantalla completa.
  final VoidCallback? onTap;
  final bool hero;

  String? get url => AppConfig.mediaUrl(embarcadero.fotoUrl);

  @override
  Widget build(BuildContext context) {
    final e = embarcadero;
    final fotoUrl = url;
    final content = ClipRRect(
      borderRadius: borderRadius,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: fotoUrl == null
            ? _Placeholder(embarcadero: e)
            : CachedNetworkImage(
                imageUrl: fotoUrl,
                fit: BoxFit.cover,
                // No decodifica a más resolución que la pantalla
                memCacheWidth: (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round(),
                fadeInDuration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : EbDurations.normal,
                placeholder: (_, _) => _Placeholder(embarcadero: e),
                errorWidget: (_, _, _) => _Placeholder(embarcadero: e),
              ),
      ),
    );
    final withHero = hero
        ? Hero(
            tag: pierPhotoHeroTag(e.id),
            // Durante el vuelo no hay Material de fondo: evita el texto subrayado amarillo
            child: Material(type: MaterialType.transparency, child: content),
          )
        : content;
    final tappable = fotoUrl != null && onTap != null;
    return Semantics(
      image: true,
      button: tappable,
      label: fotoUrl == null
          ? null
          : 'Foto del ${e.nombre}${tappable ? '. Toca para verla en pantalla completa' : ''}',
      excludeSemantics: fotoUrl != null,
      child: tappable ? GestureDetector(onTap: onTap, child: withHero) : withHero,
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.embarcadero});

  final Embarcadero embarcadero;

  @override
  Widget build(BuildContext context) {
    final style = embarcadero.mode.style;
    return ColoredBox(
      color: style.tint,
      child: Center(
        child: CircleAvatar(
          radius: 36,
          backgroundColor: EbColors.white,
          child: Icon(style.icon, size: 40, color: style.color, semanticLabel: style.stopLabel),
        ),
      ),
    );
  }
}

/// Abre la foto en pantalla completa, con zoom (pellizcar o doble toque).
void openPierPhotoViewer(BuildContext context, Embarcadero embarcadero) {
  final url = AppConfig.mediaUrl(embarcadero.fotoUrl);
  if (url == null) return;
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : EbDurations.slow,
      reverseTransitionDuration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : EbDurations.normal,
      pageBuilder: (_, _, _) => _PhotoViewer(embarcadero: embarcadero, url: url),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.embarcadero, required this.url});

  final Embarcadero embarcadero;
  final String url;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  final _zoom = TransformationController();
  TapDownDetails? _doubleTap;

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    if (_zoom.value != Matrix4.identity()) {
      _zoom.value = Matrix4.identity();
      return;
    }
    final p = _doubleTap?.localPosition ?? Offset.zero;
    const scale = 2.5;
    _zoom.value = Matrix4.identity()
      ..translateByDouble(-p.dx * (scale - 1), -p.dy * (scale - 1), 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onDoubleTapDown: (d) => _doubleTap = d,
              onDoubleTap: _toggleZoom,
              child: InteractiveViewer(
                transformationController: _zoom,
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: Hero(
                    tag: pierPhotoHeroTag(widget.embarcadero.id),
                    child: Semantics(
                      image: true,
                      label: 'Foto del ${widget.embarcadero.nombre}. Pellizca para acercar.',
                      child: CachedNetworkImage(imageUrl: widget.url, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + EbSpacing.s,
            left: EbSpacing.s,
            child: IconButton.filled(
              tooltip: 'Cerrar',
              style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: EbColors.white),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ],
      ),
    );
  }
}
