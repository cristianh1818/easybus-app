// Muestra un AsyncValue con las reglas anti-parpadeo de easybus-motion:
//   - El skeleton aparece solo si la carga pasa de 300 ms.
//   - Si aparece, se mantiene al menos 400 ms.
//   - Del skeleton al contenido, fade de 200 ms (sin animación con "reducir movimiento").
//   - Si ya hay datos (actualización o caché), se muestran sin skeleton.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EbAsyncView<T> extends StatefulWidget {
  const EbAsyncView({
    super.key,
    required this.value,
    required this.data,
    required this.skeleton,
    required this.error,
    this.skeletonDelay = const Duration(milliseconds: 300),
    this.minSkeleton = const Duration(milliseconds: 400),
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget skeleton;
  final Widget Function(Object error) error;
  final Duration skeletonDelay;
  final Duration minSkeleton;

  @override
  State<EbAsyncView<T>> createState() => _EbAsyncViewState<T>();
}

enum _Shown { nothing, skeleton, data, error }

class _EbAsyncViewState<T> extends State<EbAsyncView<T>> {
  bool _skeletonVisible = false;
  DateTime? _skeletonSince;
  Timer? _delayTimer;
  Timer? _holdTimer;

  bool get _firstLoad => !widget.value.hasValue && !widget.value.hasError;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(EbAsyncView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (_firstLoad) {
      if (!_skeletonVisible && _delayTimer == null) {
        _delayTimer = Timer(widget.skeletonDelay, () {
          if (!mounted) return;
          setState(() {
            _skeletonVisible = true;
            _skeletonSince = DateTime.now();
          });
          _delayTimer = null;
        });
      }
      return;
    }
    _delayTimer?.cancel();
    _delayTimer = null;
    if (_skeletonVisible && _holdTimer == null) {
      final shown = DateTime.now().difference(_skeletonSince!);
      if (shown >= widget.minSkeleton) {
        _skeletonVisible = false;
      } else {
        _holdTimer = Timer(widget.minSkeleton - shown, () {
          if (!mounted) return;
          setState(() {
            _skeletonVisible = false;
            _holdTimer = null;
          });
        });
      }
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final _Shown shown;
    final Widget child;
    if (_skeletonVisible) {
      shown = _Shown.skeleton;
      child = widget.skeleton;
    } else if (value.hasValue) {
      shown = _Shown.data;
      child = widget.data(value.requireValue);
    } else if (value.hasError) {
      shown = _Shown.error;
      child = widget.error(value.error!);
    } else {
      // Primeros 300 ms de carga: nada (si llega rápido, no hubo parpadeo)
      shown = _Shown.nothing;
      child = const SizedBox.shrink();
    }

    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
      child: KeyedSubtree(key: ValueKey(shown), child: child),
    );
  }
}
