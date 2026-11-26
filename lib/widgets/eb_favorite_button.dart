// Corazón para guardar una ruta o un embarcadero como favorito. Sin sesión, invita
// a iniciarla (la cuenta es opcional: consultar nunca la exige).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/account_providers.dart';
import '../screens/login_screen.dart';
import '../services/api_exception.dart';
import '../theme/eb_tokens.dart';

class EbFavoriteButton extends ConsumerStatefulWidget {
  const EbFavoriteButton.route({super.key, required this.id, required this.label}) : tipo = 'ruta';
  const EbFavoriteButton.pier({super.key, required this.id, required this.label}) : tipo = 'embarcadero';

  /// "ruta" o "embarcadero" (como en la API).
  final String tipo;
  final String id;

  /// Qué se guarda, para el lector de pantalla ("Ruta BS-1").
  final String label;

  @override
  ConsumerState<EbFavoriteButton> createState() => _EbFavoriteButtonState();
}

class _EbFavoriteButtonState extends ConsumerState<EbFavoriteButton> {
  bool _busy = false;

  Future<void> _toggle(bool saved) async {
    final sesion = ref.read(sessionProvider).value;
    if (sesion == null) {
      await _inviteLogin();
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(favoritesProvider.notifier).toggle(tipo: widget.tipo, id: widget.id, guardar: !saved);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              saved ? 'Se quitó de tus favoritos.' : 'Guardado en tus favoritos (pestaña Cuenta).',
            ),
          ),
        );
    } on ApiException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _inviteLogin() async {
    final go = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: EbColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(EbRadius.sheet)),
      ),
      builder: (sheetContext) {
        final text = Theme.of(sheetContext).textTheme;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            EbSpacing.l,
            0,
            EbSpacing.l,
            EbSpacing.l + MediaQuery.paddingOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.favorite_rounded, color: EbColors.alertSuspended, size: 40),
              const SizedBox(height: EbSpacing.s),
              Text('Guarda tus favoritos', style: text.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: EbSpacing.s),
              Text(
                'Con una cuenta gratuita guardas tus rutas y embarcaderos y los encuentras en '
                'cualquier teléfono. Puedes seguir consultando todo sin cuenta.',
                style: text.bodyMedium?.copyWith(color: EbColors.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: EbSpacing.l),
              FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                child: const Text('Iniciar sesión o crear cuenta'),
              ),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(false),
                child: const Text('Ahora no'),
              ),
            ],
          ),
        );
      },
    );
    if (go != true || !mounted) return;
    final logged = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const LoginScreen()));
    // Después de iniciar sesión se guarda lo que quería guardar
    if (logged == true && mounted) await _toggle(false);
  }

  @override
  Widget build(BuildContext context) {
    final favoritos = ref.watch(favoritesProvider).value;
    final saved = switch (widget.tipo) {
      'ruta' => favoritos?.tieneRuta(widget.id) ?? false,
      _ => favoritos?.tieneEmbarcadero(widget.id) ?? false,
    };
    return IconButton(
      tooltip: saved ? 'Quitar ${widget.label} de favoritos' : 'Guardar ${widget.label} en favoritos',
      isSelected: saved,
      onPressed: _busy ? null : () => _toggle(saved),
      icon: const Icon(Icons.favorite_border_rounded),
      selectedIcon: const Icon(Icons.favorite_rounded, color: EbColors.alertSuspended),
    );
  }
}
