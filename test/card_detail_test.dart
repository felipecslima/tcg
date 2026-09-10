import 'package:flutter_test/flutter_test.dart';
import 'package:pokecardex_scanner_mvp/models/card_detail.dart';

void main() {
  // shape real da TCGdex (me01-091 / me01-149), reduzido
  final common = {
    'id': 'me01-091',
    'name': 'Shroodle',
    'localId': '091',
    'rarity': 'Comum',
    'illustrator': 'osare',
    'category': 'Pokémon',
    'stage': 'Básico',
    'hp': 60,
    'types': ['Sombrio'],
    'regulationMark': 'I',
    'image': 'https://assets.tcgdex.net/pt/me/me01/091',
    'set': {
      'name': 'Megaevolução',
      'cardCount': {'official': 132, 'total': 188}
    },
    'variants': {'normal': true, 'holo': false, 'reverse': true},
    'attacks': [
      {'cost': ['Sombrio', 'Incolor'], 'name': 'Golpe Envenenado', 'damage': '20', 'effect': 'Fica Envenenado.'}
    ],
    'weaknesses': [{'type': 'Lutador', 'value': '×2'}],
    'retreat': 1,
    'updated': '2026-09-10T03:14:21.311Z',
    'pricing': {
      'cardmarket': {
        'unit': 'EUR', 'avg': 0.02, 'low': 0.02, 'trend': 0.03,
        'avg7': 0.03, 'avg30': 0.02, 'avg-holo': 0.09, 'trend-holo': 0.1, 'low-holo': 0.02
      },
      'tcgplayer': {
        'unit': 'USD',
        'normal': {'lowPrice': 0.01, 'midPrice': 0.15, 'highPrice': 999, 'marketPrice': 0.1},
        'reverse-holofoil': {'lowPrice': 0.02, 'midPrice': 0.25, 'highPrice': 999, 'marketPrice': 0.23},
      }
    }
  };

  test('parse: identidade + set', () {
    final d = CardDetail.fromJson(common);
    expect(d.name, 'Shroodle');
    expect(d.printedTotal, 132);
    expect(d.setName, 'Megaevolução');
    expect(d.hp, 60);
    expect(d.types, ['Sombrio']);
    expect(d.imageUrl('high'), 'https://assets.tcgdex.net/pt/me/me01/091/high.webp');
  });

  test('parse: ataques e combate', () {
    final d = CardDetail.fromJson(common);
    expect(d.attacks.single.name, 'Golpe Envenenado');
    expect(d.attacks.single.damage, '20');
    expect(d.weaknesses.single.type, 'Lutador');
    expect(d.retreat, 1);
  });

  test('parse: pricing cardmarket + holo', () {
    final p = CardDetail.fromJson(common).pricing!;
    expect(p.cardmarket!.unit, 'EUR');
    expect(p.cardmarket!.trend, 0.03);
    expect(p.cardmarket!.hasHolo, isTrue);
    expect(p.cardmarket!.avgHolo, 0.09);
  });

  test('parse: pricing tcgplayer ignora highPrice sentinela (999)', () {
    final p = CardDetail.fromJson(common).pricing!;
    expect(p.tcgplayer.keys.toSet(), {'normal', 'reverse-holofoil'});
    expect(p.tcgplayer['normal']!.market, 0.1);
    expect(p.tcgplayer['reverse-holofoil']!.mid, 0.25);
    // highPrice 999 não vira um campo
  });

  test('sem pricing → isEmpty', () {
    final d = CardDetail.fromJson({'id': 'x', 'name': 'X'});
    expect(d.pricing, isNull);
  });
}
