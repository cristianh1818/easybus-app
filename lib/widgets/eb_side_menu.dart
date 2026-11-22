// Menú lateral (mockup "Menu_despegable"): fondo marino, ítems con ícono y
// separadores azules, y el logo abajo. Lo que no está en la beta se muestra como
// "Próximamente" y no se puede tocar.

import 'package:flutter/material.dart';

import '../theme/eb_tokens.dart';
import '../widgets/eb_animated_logo.dart';
import 'eb_wrap_text.dart';

@immutable
class EbMenuEntry {
  const EbMenuEntry({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;

  /// null = "Próximamente".
  final VoidCallback? onTap;

  bool get comingSoon => onTap == null;
}

class EbSideMenu extends StatelessWidget {
  const EbSideMenu({super.key, required this.entries});

  final List<EbMenuEntry> entries;

  static const _separator = Color(0x994A90E2); // azul claro del mockup, 60 %

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Drawer(
      width: (width * 0.84).clamp(0, 360),
      // Mismo azul del cuadro del logo: el logo de abajo no deja halo
      backgroundColor: EbColors.logoBlue,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: EbSpacing.l, bottom: EbSpacing.l),
          children: [
            for (final entry in entries) ...[
              _MenuTile(entry: entry),
              const Divider(color: _separator, height: 1, thickness: 1),
            ],
            const SizedBox(height: EbSpacing.xl),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(EbRadius.card),
                child: Image.asset(EbAnimatedLogo.asset, width: 140, height: 140, semanticLabel: 'EASYBUS'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.entry});

  final EbMenuEntry entry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // "Próximamente" se ve atenuado, pero con contraste suficiente (blanco al 75 %
    // sobre marino ≈ 9:1).
    final color = entry.comingSoon ? EbColors.white.withValues(alpha: 0.75) : EbColors.white;

    return Semantics(
      button: !entry.comingSoon,
      enabled: !entry.comingSoon,
      label: entry.comingSoon ? '${entry.label}. Próximamente' : entry.label,
      onTap: entry.onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: entry.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: EbSpacing.l, vertical: EbSpacing.m),
            child: Row(
              children: [
                Icon(entry.icon, color: color, size: 34),
                const SizedBox(width: EbSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      EbWrapText(entry.label, style: text.titleLarge?.copyWith(color: color)),
                      if (entry.comingSoon) ...[
                        const SizedBox(height: EbSpacing.xs),
                        const _ComingSoonChip(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComingSoonChip extends StatelessWidget {
  const _ComingSoonChip();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: EbColors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(EbRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: EbSpacing.s, vertical: 2),
        child: Text(
          'Próximamente',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: EbColors.white),
        ),
      ),
    );
  }
}
