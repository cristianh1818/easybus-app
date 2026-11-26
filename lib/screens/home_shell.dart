// Estructura principal: barra inferior Embarcaderos · Mapa · Cuenta, menú lateral
// (☰) y las tres pestañas. Las pestañas se conservan al cambiar (IndexedStack), así
// una lista no pierde su posición ni se vuelve a descargar.

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../models/transport_mode.dart';
import '../theme/eb_tokens.dart';
import '../theme/mode_style.dart';
import '../widgets/eb_animated_logo.dart';
import '../widgets/eb_bottom_nav.dart';
import '../widgets/eb_side_menu.dart';
import 'account_screen.dart';
import 'help_screen.dart';
import 'map_screen.dart';
import 'piers_screen.dart';
import 'settings_screen.dart';

enum HomeTab { piers, map, account }

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialTab = HomeTab.map, this.mode = TransportMode.fluvial});

  /// El mockup abre en el mapa.
  final HomeTab initialTab;
  final TransportMode mode;

  static const shareText =
      'EASYBUS: horarios y avisos del transporte fluvial Businú en los embarcaderos del río Sinú, '
      'en Montería.';

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index = widget.initialTab.index;

  void _select(int i) => setState(() => _index = i);

  List<EbNavItem> get _navItems => [
    // "Embarcaderos" sale del estilo del modo (en la fase 2: "Paradas")
    EbNavItem(icon: Icons.directions_boat_outlined, label: widget.mode.style.stopLabelPlural),
    const EbNavItem(icon: Icons.map_outlined, label: 'Mapa'),
    const EbNavItem(icon: Icons.account_circle_outlined, label: 'Cuenta'),
  ];

  List<EbMenuEntry> _menuEntries(BuildContext context) => [
    EbMenuEntry(
      icon: Icons.help_outline_rounded,
      label: 'Centro de ayuda',
      onTap: () => _openFromMenu(context, (_) => const HelpScreen()),
    ),
    const EbMenuEntry(icon: Icons.notifications_none_rounded, label: 'Centro de notificaciones'),
    const EbMenuEntry(icon: Icons.shield_outlined, label: 'Viaje seguro'),
    EbMenuEntry(icon: Icons.share_outlined, label: 'Compartir', onTap: () => _share(context)),
    EbMenuEntry(
      icon: Icons.settings_outlined,
      label: 'Configuración',
      onTap: () => _openFromMenu(context, (_) => const SettingsScreen()),
    ),
    EbMenuEntry(icon: Icons.info_outline_rounded, label: 'Acerca de EASYBUS', onTap: () => _about(context)),
  ];

  void _openFromMenu(BuildContext context, WidgetBuilder page) {
    Navigator.of(context)
      ..pop() // cierra el menú
      ..push(MaterialPageRoute<void>(builder: page));
  }

  Future<void> _share(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    Navigator.of(context).pop();
    await SharePlus.instance.share(
      ShareParams(
        text: HomeShell.shareText,
        subject: 'EASYBUS',
        // En iPad el diálogo necesita un punto de origen
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  Future<void> _about(BuildContext context) async {
    final navigator = Navigator.of(context)..pop();
    final info = await PackageInfo.fromPlatform();
    if (!navigator.mounted) return;
    showAboutDialog(
      context: navigator.context,
      applicationName: 'EASYBUS',
      applicationVersion: 'Versión ${info.version} (${info.buildNumber})',
      applicationIcon: ClipRRect(
        borderRadius: BorderRadius.circular(EbRadius.card / 2),
        child: Image.asset(EbAnimatedLogo.asset, width: 56, height: 56),
      ),
      children: const [
        SizedBox(height: EbSpacing.s),
        Text(
          'Horarios, embarcaderos y avisos del transporte fluvial Businú sobre el río Sinú, '
          'en Montería. Los horarios son programados, no la ubicación en tiempo real.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // El contenido (sobre todo el mapa) pasa por detrás de la barra redondeada.
      // Las listas suman ese alto con ebScrollPadding (MediaQuery ya lo incluye).
      extendBody: true,
      drawer: Builder(builder: (context) => EbSideMenu(entries: _menuEntries(context))),
      body: IndexedStack(
        index: _index,
        children: [
          for (final (i, tab) in [
            PiersScreen(mode: widget.mode),
            MapScreen(mode: widget.mode, onOpenPiers: () => _select(HomeTab.piers.index)),
            const AccountScreen(),
          ].indexed)
            // Las animaciones de las pestañas ocultas (pulso, flujo de la ruta) se pausan
            TickerMode(enabled: i == _index, child: tab),
        ],
      ),
      bottomNavigationBar: EbBottomNav(items: _navItems, currentIndex: _index, onTap: _select),
    );
  }
}
