// Pestaña Cuenta (mockup "Inicio_de_sesion"). En la beta la cuenta es opcional;
// el inicio de sesión llega más adelante y Gastos mensuales está fuera de la beta.

import 'package:flutter/material.dart';

import '../theme/eb_insets.dart';
import '../theme/eb_tokens.dart';
import '../widgets/eb_menu_button.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final top = MediaQuery.paddingOf(context).top;

    return ListView(
      padding: context.ebScrollPadding(horizontal: 0, top: 0),
      children: [
        // Cabecera curva con el avatar, como el mockup
        Stack(
          children: [
            ClipPath(
              clipper: _CurvedBottom(),
              child: Container(
                color: EbColors.skeleton,
                padding: EdgeInsets.only(top: top + EbSpacing.m, bottom: EbSpacing.xl),
                child: Column(
                  children: [
                    Semantics(header: true, child: Text('Cuenta', style: text.headlineMedium)),
                    const SizedBox(height: EbSpacing.m),
                    const CircleAvatar(
                      radius: 52,
                      backgroundColor: EbColors.white,
                      child: Icon(Icons.person_outline_rounded, size: 64, color: EbColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
            const Positioned(top: 0, left: 0, child: EbMenuButton()),
          ],
        ),
        const SizedBox(height: EbSpacing.m),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: EbSpacing.m),
          child: Text(
            'Puedes usar EASYBUS sin cuenta. Muy pronto podrás iniciar sesión para guardar tus '
            'embarcaderos favoritos y tus últimas consultas.',
            style: text.bodyMedium?.copyWith(color: EbColors.textMuted),
          ),
        ),
        const SizedBox(height: EbSpacing.m),
        const _ComingSoonTile(icon: Icons.login_rounded, label: 'Iniciar sesión o registrarse'),
        const _ComingSoonTile(icon: Icons.history_rounded, label: 'Tus últimas consultas'),
        const _ComingSoonTile(icon: Icons.attach_money_rounded, label: 'Gastos mensuales'),
      ],
    );
  }
}

class _ComingSoonTile extends StatelessWidget {
  const _ComingSoonTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: EbSpacing.m, vertical: EbSpacing.xs),
      child: Card(
        child: Semantics(
          label: '$label. Próximamente',
          excludeSemantics: true,
          child: ListTile(
            enabled: false,
            leading: Icon(icon, color: EbColors.textMuted),
            title: Text(label, style: const TextStyle(color: EbColors.textMuted)),
            trailing: const Chip(label: Text('Próximamente')),
          ),
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
