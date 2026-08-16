import 'package:flutter_test/flutter_test.dart';
import 'package:linos/di/locator.dart';
import 'package:linos/ui/core/linos_app.dart';
import 'package:linos/ui/features/tuner/view_models/tuner_view_model.dart';

void main() {
  setUp(() {
    Locator.init();
  });

  testWidgets('renders the Linos branding', (tester) async {
    await tester.pumpWidget(const LinosApp());

    expect(find.text('LINOS'), findsOneWidget);
  });

  test('TunerViewModel is resolvable from the locator', () {
    expect(locator<TunerViewModel>(), isA<TunerViewModel>());
  });
}