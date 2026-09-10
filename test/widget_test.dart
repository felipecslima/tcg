import 'package:flutter_test/flutter_test.dart';
import 'package:pokecardex_scanner_mvp/models/tcg_card.dart';
import 'package:pokecardex_scanner_mvp/services/card_matcher.dart';

TcgCard _c(String id, String name, String localId, {int total = 132}) => TcgCard(
      id: id,
      setId: 'me01',
      setName: 'Megaevolução',
      name: name,
      localId: localId,
      printedTotal: total,
      dexIds: const [],
    );

Iterable<String> _ids(MatchResult r) => r.choices.map((c) => c.id);

void main() {
  // set com comum + full art do mesmo Pokémon (o caso que confundia)
  final set = [
    _c('me01-091', 'Shroodle', '091'),
    _c('me01-149', 'Shroodle', '149'),
    _c('me01-080', 'Marshadow', '080'),
    _c('me01-146', 'Marshadow', '146'),
    _c('me01-071', 'Tyrogue', '071'),
  ];
  final matcher = CardMatcher();

  test('carta clara (nome + número) → 1 opção pra confirmar', () {
    final r = matcher.match('Tyrogue\n071/132\nGolpe', set);
    expect(_ids(r), ['me01-071']);
  });

  test('full art: número decide mesmo sem o nome sair', () {
    final r = matcher.match('ruído 149 / 132 mais ruído', set);
    expect(_ids(r), ['me01-149']);
  });

  test('mesmo nome, número ilegível → escolha entre as versões', () {
    final r = matcher.match('Shroodle\nGolpe Envenenado 20', set);
    expect(_ids(r).toSet(), {'me01-091', 'me01-149'});
  });

  test('mesmo nome (Marshadow), sem número → escolha', () {
    final r = matcher.match('Marshadow\nChute Lateral Sombrio 60', set);
    expect(_ids(r).toSet(), {'me01-080', 'me01-146'});
  });

  test('nome único, sem número → 1 opção pra confirmar', () {
    final r = matcher.match('Tyrogue\nSoco Soco Bate Bate', set);
    expect(_ids(r), ['me01-071']);
  });

  test('OCR troca 1 dígito no número (l→1) → ainda casa', () {
    final r = matcher.match('Tyrogue\n07l/132', set);
    expect(_ids(r), ['me01-071']);
  });

  test('OCR fraco (nome quase) → oferece a carta, não confirma sozinho', () {
    final r = matcher.match('Tyroque', set); // g virou q
    expect(_ids(r), ['me01-071']);
  });

  test('lixo total → nada (segue escaneando)', () {
    final r = matcher.match('xkcd zzz qwerty', set);
    expect(r.choices, isEmpty);
  });

  test('denominador de outro set não engorda a confiança', () {
    final r = matcher.match('149/198', set);
    expect(_ids(r), ['me01-149']);
    expect(r.score, lessThan(0.76)); // sem o bônus do denominador certo
  });
}
