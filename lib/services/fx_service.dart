import 'dart:convert';

import 'package:http/http.dart' as http;

/// Cotações pra converter os preços da TCGdex (Cardmarket em EUR, TCGplayer
/// em USD) pra real. Fonte: frankfurter.app (grátis, sem chave, dados do BCE).
class FxRates {
  FxRates({required this.eurToBrl, required this.usdToBrl, this.date});

  final double eurToBrl;
  final double usdToBrl;
  final DateTime? date;

  double toBrl(String unit, double value) =>
      value * (unit.toUpperCase() == 'USD' ? usdToBrl : eurToBrl);
}

class FxService {
  static const _url =
      'https://api.frankfurter.app/latest?base=EUR&symbols=BRL,USD';

  static FxRates? _cached;

  /// Busca uma vez por sessão. Falha → `null` (a UI mostra em € / US\$).
  static Future<FxRates?> load({http.Client? client}) async {
    if (_cached != null) return _cached;
    final c = client ?? http.Client();
    try {
      final r = await c
          .get(Uri.parse(_url))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final rates = j['rates'] as Map<String, dynamic>;
      final eurBrl = (rates['BRL'] as num).toDouble();
      final eurUsd = (rates['USD'] as num?)?.toDouble();
      _cached = FxRates(
        eurToBrl: eurBrl,
        usdToBrl: (eurUsd != null && eurUsd > 0) ? eurBrl / eurUsd : eurBrl,
        date: DateTime.tryParse(j['date'] as String? ?? ''),
      );
      return _cached;
    } catch (_) {
      return null;
    } finally {
      if (client == null) c.close();
    }
  }
}

/// Formata um valor em BRL: `R$ 1.234,56`.
String formatBrl(double v) {
  final s = v.toStringAsFixed(2);
  final parts = s.split('.');
  final intPart = parts[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]}.',
  );
  return 'R\$ $intPart,${parts[1]}';
}
