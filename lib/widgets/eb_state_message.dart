// Estados de pantalla completa: vacío, error y sin conexión. Va dentro de una lista
// desplazable para que funcione "deslizar para actualizar".

import 'package:flutter/material.dart';

import '../services/api_exception.dart';
import '../theme/eb_insets.dart';
import '../theme/eb_tokens.dart';

class EbStateMessage extends StatelessWidget {
  const EbStateMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  /// Error de la API: "Sin conexión" o "No pudimos cargar…", con Reintentar.
  factory EbStateMessage.fromError(
    ApiException error, {
    required String what,
    required VoidCallback onRetry,
  }) {
    if (error.isOffline) {
      return EbStateMessage(
        icon: Icons.wifi_off_rounded,
        title: 'Sin conexión',
        message: error.message,
        actionLabel: 'Reintentar',
        onAction: onRetry,
      );
    }
    return EbStateMessage(
      icon: Icons.error_outline_rounded,
      title: 'No pudimos cargar $what',
      message: error.message,
      actionLabel: 'Reintentar',
      onAction: onRetry,
    );
  }

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: context.ebScrollPadding(horizontal: EbSpacing.xl, top: EbSpacing.xl),
        children: [
          SizedBox(height: constraints.maxHeight * 0.08),
          ExcludeSemantics(child: Icon(icon, size: 56, color: EbColors.textMuted)),
          const SizedBox(height: EbSpacing.m),
          Semantics(
            header: true,
            child: Text(title, textAlign: TextAlign.center, style: text.titleLarge),
          ),
          const SizedBox(height: EbSpacing.s),
          Text(
            message,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: EbColors.textMuted),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: EbSpacing.l),
            Center(
              child: FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
