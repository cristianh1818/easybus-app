// Iniciar sesión o crear cuenta (opcional: solo para guardar favoritos). Usa
// POST /auth/login y /auth/register; el token queda en el almacenamiento seguro.
// "Continuar con Google" está preparado como "Próximamente" (ver PROGRESO.md).
//
// Devuelve true al cerrarse si se inició sesión.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/account_providers.dart';
import '../services/api_exception.dart';
import '../theme/eb_insets.dart';
import '../theme/eb_tokens.dart';
import '../widgets/eb_wrap_text.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.startWithRegister = false});

  final bool startWithRegister;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _password = TextEditingController();
  late bool _register = widget.startWithRegister;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final session = ref.read(sessionProvider.notifier);
    try {
      if (_register) {
        await session.register(nombre: _nombre.text, correo: _correo.text, password: _password.text);
      } else {
        await session.login(correo: _correo.text, password: _password.text);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = _message(e));
    } on Object {
      setState(() => _error = 'Ocurrió un error inesperado. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Mensajes claros en español para los errores conocidos.
  String _message(ApiException e) => switch (e.code) {
    'CREDENCIALES_INVALIDAS' => 'Correo o contraseña incorrectos. Revísalos e intenta de nuevo.',
    'CORREO_REGISTRADO' => 'Ya existe una cuenta con ese correo. Inicia sesión con él.',
    _ when e.statusCode == 429 => 'Hiciste varios intentos seguidos. Espera un minuto e intenta de nuevo.',
    _ => e.message,
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: EbColors.textMuted);
    return Scaffold(
      appBar: AppBar(title: Text(_register ? 'Crear cuenta' : 'Iniciar sesión')),
      body: Form(
        key: _form,
        child: ListView(
          padding: context.ebScrollPadding(top: EbSpacing.m),
          children: [
            EbWrapText(
              'La cuenta es opcional: sirve para guardar tus rutas y embarcaderos favoritos. '
              'Consultar horarios nunca la exige.',
              style: text.bodyMedium?.copyWith(color: EbColors.textMuted),
            ),
            const SizedBox(height: EbSpacing.l),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Iniciar sesión')),
                ButtonSegment(value: true, label: Text('Crear cuenta')),
              ],
              selected: {_register},
              showSelectedIcon: false,
              onSelectionChanged: _busy
                  ? null
                  : (v) => setState(() {
                      _register = v.first;
                      _error = null;
                    }),
            ),
            const SizedBox(height: EbSpacing.l),
            if (_register) ...[
              TextFormField(
                controller: _nombre,
                enabled: !_busy,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
                validator: (v) {
                  final n = v?.trim() ?? '';
                  if (n.length < 2) return 'Escribe tu nombre (mínimo 2 letras).';
                  if (n.length > 120) return 'El nombre es muy largo (máximo 120 caracteres).';
                  return null;
                },
              ),
              const SizedBox(height: EbSpacing.m),
            ],
            TextFormField(
              controller: _correo,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                border: OutlineInputBorder(),
              ),
              validator: (v) => _emailRe.hasMatch(v?.trim() ?? '') ? null : 'Escribe un correo válido.',
            ),
            const SizedBox(height: EbSpacing.m),
            TextFormField(
              controller: _password,
              enabled: !_busy,
              obscureText: !_showPassword,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: [_register ? AutofillHints.newPassword : AutofillHints.password],
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Contraseña',
                helperText: _register ? 'Mínimo 8 caracteres.' : null,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _showPassword ? 'Ocultar contraseña' : 'Mostrar contraseña',
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                  icon: Icon(_showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                ),
              ),
              validator: (v) {
                final p = v ?? '';
                if (p.isEmpty) return 'Escribe tu contraseña.';
                if (_register && p.length < 8) return 'La contraseña debe tener al menos 8 caracteres.';
                if (_register && p.length > 72) return 'La contraseña es muy larga (máximo 72 caracteres).';
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: EbSpacing.m),
              Semantics(
                liveRegion: true,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: EbColors.alertSuspendedTint,
                    borderRadius: BorderRadius.circular(EbRadius.card),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(EbSpacing.s + 4),
                    child: Row(
                      children: [
                        const ExcludeSemantics(
                          child: Icon(Icons.error_outline_rounded, color: EbColors.alertSuspended),
                        ),
                        const SizedBox(width: EbSpacing.s),
                        Expanded(
                          child: Text(
                            _error!,
                            style: text.bodyMedium?.copyWith(color: EbColors.alertSuspended),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: EbSpacing.l),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: EbColors.white),
                    )
                  : Text(_register ? 'Crear cuenta' : 'Iniciar sesión'),
            ),
            if (_register) ...[
              const SizedBox(height: EbSpacing.s),
              Text(
                'Al crear la cuenta aceptas que EASYBUS guarde tu nombre y correo solo para tu '
                'cuenta y tus favoritos (Ley 1581 de 2012). Tu ubicación nunca se guarda.',
                style: muted,
              ),
            ],
            const SizedBox(height: EbSpacing.l),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: EbSpacing.s),
                  child: Text('o', style: muted),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: EbSpacing.m),
            // Preparado para después: pasos en PROGRESO.md (Google Cloud Console)
            Semantics(
              label: 'Continuar con Google. Próximamente',
              excludeSemantics: true,
              child: OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.g_mobiledata_rounded, size: 32),
                label: const Text('Continuar con Google · Próximamente'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
