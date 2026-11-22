// Centro de ayuda: preguntas frecuentes de la fase fluvial.

import 'package:flutter/material.dart';

import '../theme/eb_insets.dart';
import '../theme/eb_tokens.dart';
import '../widgets/eb_wrap_text.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faq = [
    (
      '¿De dónde salen las horas de salida?',
      'Son los horarios programados de la ruta fluvial. No muestran la ubicación en tiempo real '
          'de la embarcación: la hora de paso por cada embarcadero es una estimación.',
    ),
    (
      '¿Qué pasa si el servicio está suspendido?',
      'Cuando hay un aviso (por ejemplo, por el nivel del río o por el clima) aparece arriba, '
          'antes de los horarios. Si la ruta está suspendida, la app no muestra el próximo zarpe.',
    ),
    (
      '¿EASYBUS usa mi ubicación?',
      'Solo si eliges ver los embarcaderos cercanos. La distancia se calcula en tu teléfono: '
          'tu ubicación nunca se envía al servidor ni se guarda.',
    ),
    (
      '¿Los datos son oficiales?',
      'Algunos embarcaderos y horarios están marcados como datos de ejemplo mientras se '
          'validan en campo. Cuando se confirmen, dejarán de llevar esa marca.',
    ),
    ('¿Necesito internet?', 'Por ahora sí, para consultar horarios y avisos actualizados.'),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Centro de ayuda')),
      body: ListView.separated(
        padding: context.ebScrollPadding(),
        itemCount: _faq.length,
        separatorBuilder: (_, _) => const SizedBox(height: EbSpacing.s),
        itemBuilder: (context, i) {
          final (question, answer) = _faq[i];
          return Card(
            child: Theme(
              // Sin las líneas que ExpansionTile dibuja al abrirse
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: i == 0,
                tilePadding: const EdgeInsets.symmetric(horizontal: EbSpacing.m),
                childrenPadding: const EdgeInsets.fromLTRB(EbSpacing.m, 0, EbSpacing.m, EbSpacing.m),
                expandedAlignment: Alignment.centerLeft,
                title: EbWrapText(question, style: text.titleMedium),
                children: [EbWrapText(answer, style: text.bodyMedium?.copyWith(color: EbColors.textMuted))],
              ),
            ),
          );
        },
      ),
    );
  }
}
