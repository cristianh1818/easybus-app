// Pestaña Cuenta (mockup "Inicio_de_sesion"). La cuenta es opcional: consultar
// rutas nunca exige sesión. Con sesión: favoritos (en la API). Sin sesión o con
// ella: "Tus últimas consultas", guardadas solo en este teléfono.
// Pagos, tarifas y gastos están fuera de la beta (documento de infraestructura,
// 2.2): no aparece "Gastos mensuales". Notificaciones y Viaje seguro: Próximamente.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/historial.dart';
import '../models/cuenta.dart';
import '../models/embarcadero.dart';
import '../providers/account_providers.dart';
import '../providers/data_providers.dart';
import '../providers/errors.dart';
import '../providers/history_providers.dart';
import '../theme/eb_tokens.dart';
import '../widgets/eb_screen_header.dart';
import '../widgets/eb_wrap_text.dart';
import 'login_screen.dart';
import 'pier_detail_screen.dart';
import 'route_detail_screen.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final sesion = ref.watch(sessionProvider).value;

    return ListView(
      // Sin el alto de la barra de estado arriba: lo suma el encabezado (si lo sumara
      // también la lista, el título quedaría más abajo que el ☰)
      padding: EdgeInsets.only(bottom: EbSpacing.l + MediaQuery.paddingOf(context).bottom),
      children: [
        // Cabecera curva de todo el ancho: título junto al ☰ y avatar centrado
        ClipPath(
          clipper: _CurvedBottom(),
          child: ColoredBox(
            color: EbColors.skeleton,
            child: Padding(
              padding: const EdgeInsets.only(bottom: EbSpacing.xl + EbSpacing.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const EbScreenHeader(title: 'Cuenta'),
                  const SizedBox(height: EbSpacing.m),
                  Center(
                    child: CircleAvatar(
                      radius: 52,
                      backgroundColor: sesion == null ? EbColors.white : EbColors.navy,
                      child: sesion == null
                          ? const Icon(Icons.person_outline_rounded, size: 64, color: EbColors.textPrimary)
                          : Text(
                              _initials(sesion.usuario.nombre),
                              style: text.headlineMedium?.copyWith(color: EbColors.white),
                            ),
                    ),
                  ),
                  if (sesion != null) ...[
                    const SizedBox(height: EbSpacing.s),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: EbSpacing.m),
                      child: Column(
                        children: [
                          EbWrapText(
                            sesion.usuario.nombre,
                            style: text.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          EbWrapText(
                            sesion.usuario.correo,
                            style: text.bodyMedium?.copyWith(color: EbColors.textMuted),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: EbSpacing.m),
        if (sesion == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: EbSpacing.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EbWrapText(
                  'Puedes usar EASYBUS sin cuenta. Inicia sesión para guardar tus rutas y '
                  'embarcaderos favoritos.',
                  style: text.bodyMedium?.copyWith(color: EbColors.textMuted),
                ),
                const SizedBox(height: EbSpacing.m),
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute<bool>(builder: (_) => const LoginScreen())),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Iniciar sesión o crear cuenta'),
                ),
              ],
            ),
          )
        else
          const _FavoritesSection(),
        const SizedBox(height: EbSpacing.m),
        const _HistorySection(),
        const SizedBox(height: EbSpacing.s),
        const _ComingSoonTile(icon: Icons.notifications_none_rounded, label: 'Notificaciones'),
        const _ComingSoonTile(icon: Icons.shield_outlined, label: 'Viaje seguro'),
        if (sesion != null) ...[
          const SizedBox(height: EbSpacing.m),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: EbSpacing.m),
            child: OutlinedButton.icon(
              onPressed: () => _confirmLogout(context, ref),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Cerrar sesión'),
            ),
          ),
        ],
      ],
    );
  }

  static String _initials(String nombre) {
    final parts = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2);
    return parts.map((p) => p.characters.first.toUpperCase()).join();
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Tus favoritos quedan guardados en tu cuenta para la próxima vez.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Cerrar sesión')),
        ],
      ),
    );
    if (ok == true) await ref.read(sessionProvider.notifier).logout();
  }
}

/// Abre el detalle de un embarcadero por su id (de la lista guardada en el teléfono).
Future<void> _openPier(BuildContext context, WidgetRef ref, String id) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  Embarcadero? e;
  try {
    e = (await ref.read(embarcaderosProvider.future)).data.where((x) => x.id == id).firstOrNull;
  } on Object {
    e = null;
  }
  if (e == null) {
    messenger.showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Ese embarcadero ya no está disponible.'),
      ),
    );
    return;
  }
  final found = e;
  navigator.push(MaterialPageRoute<void>(builder: (_) => PierDetailScreen(embarcadero: found)));
}

void _openRoute(BuildContext context, {required String id, required String codigo}) => Navigator.of(context)
    .push(
      MaterialPageRoute<void>(
        builder: (_) => RouteDetailScreen(rutaId: id, codigo: codigo),
      ),
    );

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.action});

  final String title;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: EbSpacing.m),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: EbSpacing.s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(EbSpacing.m, 0, EbSpacing.xs, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(header: true, child: EbWrapText(title, style: text.titleMedium)),
                    ),
                    ?action,
                  ],
                ),
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(EbSpacing.m, EbSpacing.xs, EbSpacing.m, EbSpacing.s),
    child: EbWrapText(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: EbColors.textMuted),
    ),
  );
}

class _FavoritesSection extends ConsumerWidget {
  const _FavoritesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritos = ref.watch(favoritesProvider);
    final f = favoritos.value ?? Favoritos.vacio;
    return _Section(
      title: 'Tus favoritos',
      children: [
        if (favoritos.hasError && !favoritos.hasValue) ...[
          _Note(toApiException(favoritos.error!).message),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: EbSpacing.s),
              child: TextButton(
                onPressed: () => ref.invalidate(favoritesProvider),
                child: const Text('Reintentar'),
              ),
            ),
          ),
        ] else if (!favoritos.hasValue)
          const _Note('Cargando tus favoritos…')
        else if (f.rutas.isEmpty && f.embarcaderos.isEmpty)
          const _Note('Toca el corazón en una ruta o un embarcadero para guardarlo aquí.')
        else ...[
          for (final r in f.rutas)
            ListTile(
              leading: const Icon(Icons.timeline_rounded, color: EbColors.riverInk),
              title: Text('Ruta ${r.codigo}'),
              subtitle: Text(r.nombre),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _openRoute(context, id: r.id, codigo: r.codigo),
            ),
          for (final e in f.embarcaderos)
            ListTile(
              leading: const Icon(Icons.directions_boat_filled_rounded, color: EbColors.river),
              title: Text(e.nombre),
              subtitle: e.referencia == null ? null : Text(e.referencia!),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _openPier(context, ref, e.id),
            ),
        ],
      ],
    );
  }
}

class _HistorySection extends ConsumerWidget {
  const _HistorySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historial = ref.watch(historyProvider).value ?? const <Consulta>[];
    return _Section(
      title: 'Tus últimas consultas',
      action: historial.isEmpty
          ? null
          : TextButton(onPressed: () => _confirmClear(context, ref), child: const Text('Borrar')),
      children: [
        if (historial.isEmpty)
          const _Note(
            'Aquí verás las últimas rutas y embarcaderos que abras. Se guardan solo en este teléfono.',
          )
        else ...[
          for (final c in historial)
            ListTile(
              leading: Icon(
                c.tipo == TipoConsulta.ruta ? Icons.timeline_rounded : Icons.directions_boat_filled_rounded,
                color: EbColors.riverInk,
              ),
              title: Text(c.titulo),
              subtitle: c.detalle == null
                  ? null
                  : Text(c.detalle!, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => c.tipo == TipoConsulta.ruta
                  ? _openRoute(context, id: c.id, codigo: c.titulo.replaceFirst('Ruta ', ''))
                  : _openPier(context, ref, c.id),
            ),
          const _Note('Se guardan solo en este teléfono, sin cuenta.'),
        ],
      ],
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Borrar tus últimas consultas?'),
        content: const Text('Se borran de este teléfono. No afecta tus favoritos.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Borrar')),
        ],
      ),
    );
    if (ok == true) await ref.read(historyProvider.notifier).clear();
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
