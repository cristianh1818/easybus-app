// Pestaña Cuenta (mockup "Inicio_de_sesion"). En la beta la cuenta es opcional y el
// inicio de sesión llega más adelante. Pagos, tarifas y control de gastos están fuera
// de la beta (documento de infraestructura, 2.2), por eso no aparece "Gastos mensuales".

import 'package:flutter/material.dart';

import '../theme/eb_insets.dart';
import '../theme/eb_tokens.dart';
import '../widgets/eb_screen_header.dart';
import '../widgets/eb_wrap_text.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: context.ebScrollPadding(horizontal: 0, top: 0, bottom: EbSpacing.l),
      children: [
        // Cabecera curva de todo el ancho: ☰ y título en una fila, avatar centrado
        ClipPath(
          clipper: _CurvedBottom(),
          child: ColoredBox(
            color: EbColors.skeleton,
            child: Padding(
              padding: const EdgeInsets.only(bottom: EbSpacing.xl + EbSpacing.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // La lista tiene padding propio, así que el encabezado sigue
                  // recibiendo el alto de la barra de estado y se coloca debajo
                  const EbScreenHeader(title: 'Cuenta'),
                  const SizedBox(height: EbSpacing.m),
                  const Center(
                    child: CircleAvatar(
                      radius: 52,
                      backgroundColor: EbColors.white,
                      child: Icon(Icons.person_outline_rounded, size: 64, color: EbColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: EbSpacing.m),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: EbSpacing.m),
          child: EbWrapText(
            'Puedes usar EASYBUS sin cuenta. Muy pronto podrás iniciar sesión para guardar tus '
            'embarcaderos favoritos y tus últimas consultas.',
            style: text.bodyMedium?.copyWith(color: EbColors.textMuted),
          ),
        ),
        const SizedBox(height: EbSpacing.m),
        const _ComingSoonTile(icon: Icons.login_rounded, label: 'Iniciar sesión o registrarse'),
        const _ComingSoonTile(icon: Icons.history_rounded, label: 'Tus últimas consultas'),
      ],
    );
  }
}

/// Opción que aún no está disponible: el título y, si no cabe al lado, la etiqueta
/// "Próximamente" debajo (Wrap). Nunca parte palabras.
class _ComingSoonTile extends StatelessWidget {
  const _ComingSoonTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: EbSpacing.m, vertical: EbSpacing.xs),
      child: Card(
        child: Semantics(
          label: '$label. Próximamente',
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.all(EbSpacing.m),
            child: Row(
              children: [
                Icon(icon, color: EbColors.textMuted),
                const SizedBox(width: EbSpacing.m),
                Expanded(
                  child: Wrap(
                    spacing: EbSpacing.s,
                    runSpacing: EbSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      EbWrapText(label, style: text.titleMedium?.copyWith(color: EbColors.textMuted)),
                      const _ComingSoonBadge(),
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

class _ComingSoonBadge extends StatelessWidget {
  const _ComingSoonBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: EbColors.surface, borderRadius: BorderRadius.circular(EbRadius.pill)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: EbSpacing.s + 4, vertical: EbSpacing.xs),
        child: Text(
          'Próximamente',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: EbColors.textPrimary),
        ),
      ),
    );
  }
}

class _CurvedBottom extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..lineTo(0, size.height - 40)
    ..quadraticBezierTo(size.width / 2, size.height + 20, size.width, size.height - 40)
    ..lineTo(size.width, 0)
    ..close();

  @override
  bool shouldReclip(_CurvedBottom oldClipper) => false;
}
