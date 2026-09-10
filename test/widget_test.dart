import 'package:flutter_test/flutter_test.dart';
import 'package:pokecardex_scanner_mvp/models/tcg_card.dart';
import 'package:pokecardex_scanner_mvp/repositories/set_repository.dart';
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

  // ---- parseSetCode ----

  group('parseSetCode', () {
    test('extrai código antes do número + sufixo de idioma', () {
      expect(matcher.parseSetCode('MEG PT 034/132'), 'MEG');
    });

    test('extrai código sem sufixo de idioma', () {
      expect(matcher.parseSetCode('SSP 145/132'), 'SSP');
    });

    test('extrai código com sufixo EN', () {
      expect(matcher.parseSetCode('CRZ EN 001/159'), 'CRZ');
    });

    test('código de 2 letras (BS)', () {
      expect(matcher.parseSetCode('BS 050/102'), 'BS');
    });

    test('código de 4 letras', () {
      expect(matcher.parseSetCode('SWSH PT 001/202'), 'SWSH');
    });

    test('retorna null pra texto sem código de set', () {
      expect(matcher.parseSetCode('Pikachu 025/165'), isNull);
    });

    test('não retorna sufixo de idioma isolado como código', () {
      expect(matcher.parseSetCode('PT 034/132'), isNull);
    });

    test('lida com espaços extras do OCR', () {
      expect(matcher.parseSetCode('MEG  PT  034 / 132'), 'MEG');
    });
  });

  // ---- matchGlobal ----

  group('matchGlobal', () {
    final sets = [
      const CardSetBrief(id: 'meg', name: 'Megaevolução', abbreviation: 'MEG', printedTotal: 132),
      const CardSetBrief(id: 'ssp', name: 'Surto Estelar', abbreviation: 'SSP', printedTotal: 132),
      const CardSetBrief(id: 'crz', name: 'Crown Zenith', abbreviation: 'CRZ', printedTotal: 159),
    ];

    TcgCard gc(String id, String setId, String name, String localId) => TcgCard(
          id: id, setId: setId, setName: '', name: name, localId: localId,
          printedTotal: sets.firstWhere((s) => s.id == setId).printedTotal,
          dexIds: const [],
        );

    final allCards = [
      gc('meg-034', 'meg', 'Shroodle', '034'),
      gc('meg-091', 'meg', 'Tyrogue', '091'),
      gc('ssp-034', 'ssp', 'Pikachu', '034'),
      gc('ssp-091', 'ssp', 'Magikarp', '091'),
      gc('crz-034', 'crz', 'Charizard', '034'),
    ];

    test('com set code: confia no código + número (nome opcional)', () {
      final r = matcher.matchGlobal('MEG PT 034/132', allCards, sets);
      expect(_ids(r), contains('meg-034'));
      expect(_ids(r).where((id) => id.startsWith('ssp')), isEmpty);
    });

    test('com set code diferente: filtra pro set certo', () {
      final r = matcher.matchGlobal('SSP 034/132', allCards, sets);
      expect(_ids(r), contains('ssp-034'));
      expect(_ids(r).where((id) => id.startsWith('meg')), isEmpty);
    });

    test('sem set code + denominador: exige nome no OCR', () {
      final r = matcher.matchGlobal('Charizard 034/159', allCards, sets);
      expect(_ids(r), contains('crz-034'));
    });

    test('sem set code + denominador + nome errado: rejeita', () {
      final r = matcher.matchGlobal('Kyogre 034/159', allCards, sets);
      expect(_ids(r).where((id) => id == 'crz-034'), isEmpty,
          reason: 'Charizard #034 não deve casar com OCR que diz Kyogre');
    });

    test('sem código e sem fração → não mostra nada (evita falso-positivo)', () {
      final r = matcher.matchGlobal('Tyrogue', allCards, sets);
      expect(r.choices, isEmpty);
    });

    test('com fração mas sem código de set → ainda busca em todos', () {
      final r = matcher.matchGlobal('Tyrogue 091/132', allCards, sets);
      expect(r.choices, isNotEmpty);
    });
  });
}
