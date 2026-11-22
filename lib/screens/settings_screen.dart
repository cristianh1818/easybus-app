// Configuración: por ahora explica la privacidad de la ubicación (RNF-07) y abre
// los ajustes de permisos del sistema. No muestra ni guarda datos personales.

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../theme/eb_insets.dart';
import '../theme/eb_tokens.dart';
import '../widgets/eb_wrap_text.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.openAppSettings = Geolocator.openAppSettings});

  /// Abre los ajustes de EASYBUS en el sistema (reemplazable en las pruebas).
  final Future<bool> Function() openAppSettings;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = text.bodyMedium?.copyWith(color: EbColors.textMuted);

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: context.ebScrollPadding(),
        children: [
          Semantics(header: true, child: EbWrapText('Tu ubicación y tu privacidad', style: text.titleLarge)),
          const SizedBox(height: EbSpacing.m),
          const _Point(
            icon: Icons.phone_android_rounded,
            title: 'Se usa solo en tu teléfono',
            body:
                'La ubicación sirve únicamente para "cerca de mí": mostrar los embarcaderos más '
                'cercanos. La distancia se calcula en tu teléfono con la lista de embarcaderos.',
          ),
          const _Point(
            icon: Icons.cloud_off_rounded,
            title: 'No se envía ni se guarda en el servidor',
            body:
                'EASYBUS nunca envía tu ubicación a sus servidores, no la guarda y no la asocia a '
                'tu cuenta (requisito RNF-07 del proyecto).',
          ),
          const _Point(
            icon: Icons.gavel_rounded,
            title: 'Ley 1581 de 2012',
            body:
                'La ley colombiana de protección de datos personales exige tu autorización y una '
                'finalidad clara para tratar tus datos. Como tu ubicación no sale del teléfono, '
                'EASYBUS no la recolecta ni la trata.',
          ),
          const _Point(
            icon: Icons.toggle_on_outlined,
            title: 'Cómo activarla o desactivarla',
            body:
                'La función "cerca de mí" llegará pronto. Cuando la uses por primera vez, el '
                'teléfono te pedirá permiso y podrás aceptarlo o rechazarlo. Puedes cambiarlo '
                'cuando quieras en los ajustes del teléfono: en Android, Aplicaciones › EASYBUS › '
                'Permisos › Ubicación; en iPhone, Ajustes › EASYBUS › Ubicación. Sin el permiso, '
                'el resto de la app funciona igual.',
          ),
          const SizedBox(height: EbSpacing.m),
          FilledButton.icon(
            onPressed: () => openAppSettings(),
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Abrir ajustes de permisos'),
          ),
          const SizedBox(height: EbSpacing.s),
          Text(
            'Se abre la configuración de EASYBUS en tu teléfono.',
            style: muted,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: EbSpacing.s),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(EbSpacing.m),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(child: Icon(icon, color: EbColors.riverInk, size: 28)),
              const SizedBox(width: EbSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EbWrapText(title, style: text.titleMedium),
                    const SizedBox(height: EbSpacing.xs),
                    EbWrapText(body, style: text.bodyMedium?.copyWith(color: EbColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
