// Estructura principal: barra inferior Embarcaderos · Mapa · Cuenta, menú lateral
// (☰) y las tres pestañas. Las pestañas se conservan al cambiar (IndexedStack), así
// una lista no pierde su posición ni se vuelve a descargar.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../models/transport_mode.dart';
import '../providers/clock_provider.dart';
import '../providers/refresh.dart';
import '../theme/eb_tokens.dart';
import '../theme/mode_style.dart';
import '../widgets/eb_animated_logo.dart';
import '../widgets/eb_bottom_nav.dart';
import '../widgets/eb_menu_button.dart';
import '../widgets/eb_side_menu.dart';
import 'account_screen.dart';
import 'help_screen.dart';
import 'map_screen.dart';
import 'piers_screen.dart';
import 'settings_screen.dart';

enum HomeTab { piers, map, account }

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, this.initialTab = HomeTab.map, this.mode = TransportMode.fluvial});

  /// El mockup abre en el mapa.
  final HomeTab initialTab;
  final TransportMode mode;

  static const shareText =
      'EASYBUS: horarios y avisos del transporte fluvial Businú en los embarcaderos del río Sinú, '
      'en Montería.';

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  late int _index = widget.initialTab.index;

  // Al volver desde segundo plano, si pasaron más de 2 min, se actualiza todo
  // (los zarpes y avisos pudieron cambiar mientras tanto).
  late final AppLifecycleListener _lifecycle;
  DateTime? _hiddenAt;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () => _hiddenAt = ref.read(nowProvider)(),
      onShow: () {
        final hiddenAt = _hiddenAt;
        _hiddenAt = null;
        if (shouldRefreshOnResume(hiddenAt, ref.read(nowProvider)())) {
          refreshAllData(ref, widget.mode);
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

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
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: _index,
              children: [
                for (final (i, tab) in [
                  PiersScreen(mode: widget.mode),
                  MapScreen(mode: widget.mode),
                  const AccountScreen(),
                ].indexed)
                  // Las animaciones de las pestañas ocultas (pulso, flujo de la ruta) se pausan
                  TickerMode(enabled: i == _index, child: tab),
              ],
            ),
          ),
          // Un solo ☰ para las tres pestañas: siempre en la misma posición (arriba a la
          // izquierda, debajo de la barra de estado). Cada pestaña le deja su espacio.
          const Positioned(top: 0, left: 0, child: EbMenuButton()),
        ],
      ),
      bottomNavigationBar: EbBottomNav(items: _navItems, currentIndex: _index, onTap: _select),
    );
  }
}
