import 'package:easybus_app/screens/theme_preview_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/layout_checks.dart';

void main() {
  for (final scale in fontScales) {
    testWidgets('Vista del tema sin desbordes con la fuente al ${(scale * 100).round()} %', (tester) async {
      await pumpScreen(tester, const ThemePreviewScreen(), scale: scale);
      await expectLastItemAboveNavBar(tester, find.text('labelSmall'));
    });
  }

  testWidgets('"suspendido" queda en una sola línea', (tester) async {
    await pumpScreen(tester, const ThemePreviewScreen(), scale: 1.3);
    final size = tester.getSize(find.text('suspendido'));
    final oneLine = tester.getSize(find.text('navy')).height;
    expect(size.height, oneLine);
  });
}
