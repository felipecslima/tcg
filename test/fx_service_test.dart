import 'package:flutter_test/flutter_test.dart';
import 'package:pokecardex_scanner_mvp/services/fx_service.dart';

void main() {
  test('converte EUR e USD pra BRL', () {
    final fx = FxRates(eurToBrl: 5.93, usdToBrl: 5.09);
    expect(fx.toBrl('EUR', 2.0), closeTo(11.86, 0.001));
    expect(fx.toBrl('USD', 2.0), closeTo(10.18, 0.001));
    expect(fx.toBrl('usd', 1.0), closeTo(5.09, 0.001)); // case-insensitive
  });

  test('formatBrl: separador brasileiro', () {
    expect(formatBrl(1.5), r'R$ 1,50');
    expect(formatBrl(0.02), r'R$ 0,02');
    expect(formatBrl(1234.5), r'R$ 1.234,50');
    expect(formatBrl(12), r'R$ 12,00');
  });
}
