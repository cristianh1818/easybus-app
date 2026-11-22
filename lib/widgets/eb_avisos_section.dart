// Avisos vigentes, antes que cualquier horario. Si no se pueden consultar, se dice
// claramente: nunca se ocultan en silencio (un aviso de suspensión perdido es peor
// que un mensaje de error).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/aviso.dart';
import '../models/enums.dart';
import '../providers/data_providers.dart';
import '../theme/eb_tokens.dart';
import 'eb_alert_banner.dart';

class EbAvisosSection extends ConsumerWidget {
  const EbAvisosSection({super.key, this.rutaId, this.embarcaderoId});

  final String? rutaId;
  final String? embarcaderoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (rutaId: rutaId, embarcaderoId: embarcaderoId);
    final avisos = ref.watch(avisosProvider(args));

    if (avisos.hasValue) {
      final vigentes = avisos.requireValue.where((a) => a.vigencia == VigenciaAviso.vigente).toList()
        ..sort(compareAvisos);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final a in vigentes) ...[EbAlertBanner(aviso: a), const SizedBox(height: EbSpacing.s)],
        ],
      );
    }
    if (avisos.hasError) {
      return Padding(
        padding: const EdgeInsets.only(bottom: EbSpacing.s),
        child: _AvisosUnavailable(onRetry: () => ref.invalidate(avisosProvider(args))),
      );
    }
    // Cargando: no ocupa espacio; el banner entra deslizando cuando llega
    return const SizedBox.shrink();
  }
}

/// Lista de avisos ya cargada, por si una pantalla la necesita sin el provider.
List<Aviso> avisosDeEmbarcadero(List<Aviso> avisos, String embarcaderoId) =>
    avisos.where((a) => a.embarcadero?.id == embarcaderoId && a.vigencia == VigenciaAviso.vigente).toList();

class _AvisosUnavailable extends StatelessWidget {
  const _AvisosUnavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: EbColors.alertDelayTint,
        borderRadius: BorderRadius.circular(EbRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(EbSpacing.m, EbSpacing.s, EbSpacing.xs, EbSpacing.s),
        child: Row(
          children: [
            const ExcludeSemantics(child: Icon(Icons.warning_amber_rounded, color: EbColors.alertDelay)),
            const SizedBox(width: EbSpacing.s),
            Expanded(
              child: Text(
                'No se pudieron verificar los avisos de servicio. Puede haber cambios que aún no ves.',
                style: text.bodyMedium?.copyWith(color: EbColors.alertDelayInk),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
