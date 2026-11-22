// Pestaña Embarcaderos: lista ordenada a lo largo del río con el próximo zarpe de
// cada uno. Los avisos de servicio van arriba, antes que cualquier horario.
// Estados: cargando (skeleton con la forma real), vacío, error y sin conexión,
// y "Actualizado hace X". Deslizar hacia abajo actualiza.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../models/aviso.dart';
import '../models/embarcadero.dart';
import '../models/enums.dart';
import '../models/geo.dart';
import '../models/transport_mode.dart';
import '../providers/clock_provider.dart';
import '../providers/data_providers.dart';
import '../providers/errors.dart';
import '../services/api_exception.dart';
import '../providers/piers_providers.dart';
import '../theme/eb_insets.dart';
import '../theme/eb_tokens.dart';
import '../theme/mode_style.dart';
import '../utils/time_format.dart';
import '../widgets/eb_async_view.dart';
import 'pier_detail_screen.dart';
import '../widgets/eb_avisos_section.dart';
import '../widgets/eb_next_departure_row.dart';
import '../widgets/eb_pier_card.dart';
import '../widgets/eb_screen_header.dart';
import '../widgets/eb_state_message.dart';

const _allAvisos = (rutaId: null, embarcaderoId: null);

class PiersScreen extends ConsumerWidget {
  const PiersScreen({super.key, required this.mode});

  final TransportMode mode;

  /// Vuelve a pedir todo (deslizar para actualizar y "Reintentar").
  static Future<void> refresh(WidgetRef ref, TransportMode mode) async {
    ref
      ..invalidate(embarcaderosProvider)
      ..invalidate(rutasProvider)
      ..invalidate(rutaDetalleProvider)
      ..invalidate(avisosProvider)
      ..invalidate(proximaSalidaProvider);
    try {
      await ref.read(piersOverviewProvider(mode).future);
    } on Object {
      // El error se muestra en la pantalla
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = mode.style;
    final overview = ref.watch(piersOverviewProvider(mode));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EbScreenHeader(title: style.stopLabelPlural),
        Expanded(
          child: RefreshIndicator(
            color: EbColors.river,
            onRefresh: () => refresh(ref, mode),
            child: EbAsyncView<PiersOverview>(
              value: overview,
              skeleton: _PiersSkeleton(mode: mode),
              error: (error) => EbStateMessage.fromError(
                toApiException(error),
                what: 'los ${style.stopLabelPlural.toLowerCase()}',
                onRetry: () => refresh(ref, mode),
              ),
              data: (data) => data.items.isEmpty
                  ? EbStateMessage(
                      icon: style.icon,
                      title: 'Todavía no hay ${style.stopLabelPlural.toLowerCase()}',
                      message: 'Cuando se publiquen aparecerán aquí. Desliza hacia abajo para actualizar.',
                    )
                  : _PiersList(
                      mode: mode,
                      overview: data,
                      refreshError: overview.hasError ? toApiException(overview.error!) : null,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PiersList extends ConsumerWidget {
  const _PiersList({required this.mode, required this.overview, this.refreshError});

  final TransportMode mode;
  final PiersOverview overview;

  /// Falló la última actualización: se muestran los datos anteriores.
  final Object? refreshError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: EbColors.textMuted);
    final now = ref.watch(clockProvider).value ?? ref.watch(nowProvider)();
    final avisos = ref.watch(avisosProvider(_allAvisos)).value ?? const <Aviso>[];
    // Datos guardados por falta de conexión, o una actualización manual que falló
    final stale = overview.staleError ?? (refreshError == null ? null : toApiException(refreshError!));

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: context.ebScrollPadding(top: EbSpacing.s),
      children: [
        // Cuándo se actualizó y qué significa la hora
        Text(formatUpdatedAgo(overview.updatedAt, now), style: muted),
        Text('Horarios programados, no ubicación en tiempo real.', style: muted),
        const SizedBox(height: EbSpacing.m),
        if (stale != null) ...[
          _InlineNote(
            icon: stale.isOffline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
            text: switch (stale) {
              ApiException(isOffline: true) =>
                'Sin conexión a internet. Estás viendo los datos guardados en tu teléfono.',
              ApiException(kind: ApiErrorKind.server) => 'El servicio no está disponible en este momento. Estás viendo los datos guardados en tu teléfono.',
              _ => 'No se pudo actualizar. Estás viendo los datos anteriores.',
            },
          ),
          const SizedBox(height: EbSpacing.s),
        ],
        // Avisos antes que los horarios
        const EbAvisosSection(),
        if (overview.routesError != null) ...[
          _InlineNote(
            icon: Icons.info_outline_rounded,
            text: 'No se pudieron consultar las rutas: por ahora no se muestran los próximos zarpes.',
          ),
          const SizedBox(height: EbSpacing.s),
        ],
        if (overview.allSampleData) ...[
          _InlineNote(
            icon: Icons.science_outlined,
            text:
                'Datos de ejemplo: los ${mode.style.stopLabelPlural.toLowerCase()} y horarios aún se '
                'están validando en campo.',
          ),
          const SizedBox(height: EbSpacing.s),
        ],
        for (final item in overview.items) ...[
          EbPierCard(
            item: item,
            avisos: avisosDeEmbarcadero(avisos, item.embarcadero.id),
            showSampleTag: !overview.allSampleData,
            departureBuilder: (service) =>
                EbNextDepartureRow(service: service, embarcaderoId: item.embarcadero.id),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => PierDetailScreen(embarcadero: item.embarcadero))),
          ),
          const SizedBox(height: EbSpacing.s),
        ],
      ],
    );
  }
}

class _InlineNote extends StatelessWidget {
  const _InlineNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: EbColors.white, borderRadius: BorderRadius.circular(EbRadius.card)),
      child: Padding(
        padding: const EdgeInsets.all(EbSpacing.s + 4),
        child: Row(
          children: [
            ExcludeSemantics(child: Icon(icon, color: EbColors.textMuted, size: 20)),
            const SizedBox(width: EbSpacing.s),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: EbColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton con la forma real: las mismas tarjetas con datos de ejemplo.
class _PiersSkeleton extends StatelessWidget {
  const _PiersSkeleton({required this.mode});

  final TransportMode mode;

  static PierListItem _fake(int i) => PierListItem(
    embarcadero: Embarcadero(
      id: 'skeleton-$i',
      nombre: 'Embarcadero de ejemplo',
      referencia: 'Ronda del Sinú, frente al centro',
      ubicacion: const GeoPoint(8.75, -75.88),
      tipo: TipoParada.embarcadero,
      margen: null,
      estado: EstadoEmbarcadero.activo,
      tieneRampa: null,
      tieneTecho: null,
      tieneIluminacion: null,
      fotoUrl: null,
      esOficial: true,
      actualizadoEn: DateTime(2026),
    ),
    services: const [
      PierService(rutaId: '', rutaCodigo: 'BS-1', sentido: Sentido.ida, destino: 'Embarcadero Sur', orden: 1),
      PierService(rutaId: '', rutaCodigo: 'BS-1', sentido: Sentido.vuelta, destino: 'Ronda Norte', orden: 2),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall;
    return Semantics(
      label: 'Cargando ${mode.style.stopLabelPlural.toLowerCase()}',
      child: Skeletonizer(
        enabled: true,
        effect: const ShimmerEffect(
          baseColor: EbColors.skeleton,
          highlightColor: EbColors.surface,
          duration: Duration(milliseconds: 1200),
        ),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: context.ebScrollPadding(top: EbSpacing.s),
          children: [
            Text('Actualizado hace un momento', style: muted),
            Text('Horarios programados, no ubicación en tiempo real.', style: muted),
            const SizedBox(height: EbSpacing.m),
            for (var i = 0; i < 4; i++) ...[
              EbPierCard(
                item: _fake(i),
                departureBuilder: (s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: EbSpacing.xs),
                  child: Text('${s.rutaCodigo} · Hacia ${s.destino}   07:20 · en 15 min'),
                ),
              ),
              const SizedBox(height: EbSpacing.s),
            ],
          ],
        ),
      ),
    );
  }
}
