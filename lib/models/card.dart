/// Modelo de domínio único de carta, usado pela camada de repositório
/// (`lib/repositories/`). Consolida o que antes eram dois modelos vindos
/// direto da TCGdex (`TcgCard` brief, `CardDetail` completo) num único tipo
/// que mapeia a tabela `cards` do Supabase — a base é a fonte de dados a
/// partir de agora, não a API.
///
/// `TcgCard` e `CardDetail` continuam existindo e em uso (scanner e
/// `CardDetailScreen` ainda falam direto com `TcgdexApiService`) — este
/// modelo é o que as telas novas (Fase 3) e os repositórios devem usar.
/// As factories `fromBrief`/`fromDetail` convertem os modelos antigos pra
/// este quando um repositório precisa gravar o resultado de uma chamada de
/// API na base.
library;

import 'card_detail.dart' show CardAttack, CardWeakness, MarketPricing;
import 'card_detail.dart' as legacy show CardDetail;
import 'tcg_card.dart' as legacy show TcgCard;

class Card {
  const Card({
    required this.id,
    required this.setId,
    this.setName = '',
    required this.localId,
    this.printedTotal = 0,
    required this.name,
    this.imageBaseUrl,
    this.rarity,
    this.category,
    this.stage,
    this.hp,
    this.regulationMark,
    this.types = const [],
    this.attacks = const [],
    this.weaknesses = const [],
    this.retreat,
    this.illustrator,
    this.variants = const {},
    this.nationalDexIds = const [],
    this.priceBrl,
    this.pricing,
    this.updatedAt,
  });

  final String id;
  final String setId;
  final String setName;
  final String localId; // "025", "199"
  final int printedTotal; // total impresso do set ("132" de "091/132")
  final String name;
  final String? imageBaseUrl;
  final String? rarity;
  final String? category; // "Pokémon", "Treinador", "Energia"
  final String? stage; // "Básico", "Estágio 1", "Estágio 2", "V", "VMAX"...
  final int? hp;
  final String? regulationMark;
  final List<String> types;
  final List<CardAttack> attacks;
  final List<CardWeakness> weaknesses;
  final int? retreat;
  final String? illustrator;
  final Map<String, bool> variants; // normal / holo / reverse / firstEdition
  final List<int> nationalDexIds;

  /// Valor estimado em BRL, já convertido — vem de `PriceRepository`, não é
  /// gravado na tabela `cards` (mora em `card_prices`). `null` quando o
  /// repositório de preço ainda não foi consultado.
  final double? priceBrl;

  /// Preços brutos de mercado (Cardmarket EUR + TCGplayer USD). Transiente —
  /// vem da API via `CardDetail`, não é persistido na tabela `cards`.
  final MarketPricing? pricing;

  final DateTime? updatedAt;

  /// Se true, esta instância tem só os campos "brief" (id/nome/número/
  /// imagem) — attacks/hp/rarity ainda não foram buscados.
  bool get isBrief => rarity == null && attacks.isEmpty && hp == null;

  String? get thumbnailUrl => imageBaseUrl == null ? null : '$imageBaseUrl/low.webp';
  String? imageUrl(String quality) =>
      imageBaseUrl == null ? null : '$imageBaseUrl/$quality.webp';

  Card copyWith({
    String? setName,
    int? printedTotal,
    String? rarity,
    String? category,
    String? stage,
    int? hp,
    String? regulationMark,
    List<String>? types,
    List<CardAttack>? attacks,
    List<CardWeakness>? weaknesses,
    int? retreat,
    String? illustrator,
    Map<String, bool>? variants,
    List<int>? nationalDexIds,
    double? priceBrl,
    MarketPricing? pricing,
    DateTime? updatedAt,
  }) {
    return Card(
      id: id,
      setId: setId,
      setName: setName ?? this.setName,
      localId: localId,
      printedTotal: printedTotal ?? this.printedTotal,
      name: name,
      imageBaseUrl: imageBaseUrl,
      rarity: rarity ?? this.rarity,
      category: category ?? this.category,
      stage: stage ?? this.stage,
      hp: hp ?? this.hp,
      regulationMark: regulationMark ?? this.regulationMark,
      types: types ?? this.types,
      attacks: attacks ?? this.attacks,
      weaknesses: weaknesses ?? this.weaknesses,
      retreat: retreat ?? this.retreat,
      illustrator: illustrator ?? this.illustrator,
      variants: variants ?? this.variants,
      nationalDexIds: nationalDexIds ?? this.nationalDexIds,
      priceBrl: priceBrl ?? this.priceBrl,
      pricing: pricing ?? this.pricing,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Linha da tabela `cards` (join opcional com `sets.name` via
  /// `sets(name)` no `select`, daí o `row['sets']` opcional).
  factory Card.fromSupabaseRow(Map<String, dynamic> row) {
    final setJoin = row['sets'] as Map<String, dynamic>?;
    final attacksJson = row['attacks'] as List? ?? const [];
    final weaknessesJson = row['weaknesses'] as List? ?? const [];
    final variantsJson = row['variants'] as Map<String, dynamic>? ?? const {};
    final nationalDexId = row['national_dex_id'] as int?;
    return Card(
      id: row['id'] as String,
      setId: row['set_id'] as String? ?? '',
      setName: setJoin?['name'] as String? ?? '',
      localId: row['local_id'] as String? ?? '',
      name: row['name'] as String? ?? '',
      imageBaseUrl: row['image_url'] as String?,
      rarity: row['rarity'] as String?,
      category: row['category'] as String?,
      stage: row['stage'] as String?,
      hp: row['hp'] as int?,
      regulationMark: row['regulation_mark'] as String?,
      types: (row['types'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      attacks: attacksJson
          .map((e) => CardAttack.fromJson(e as Map<String, dynamic>))
          .toList(),
      weaknesses: weaknessesJson
          .map((e) => CardWeakness.fromJson(e as Map<String, dynamic>))
          .toList(),
      retreat: row['retreat'] as int?,
      illustrator: row['illustrator'] as String?,
      variants: variantsJson.map((k, v) => MapEntry(k, v == true)),
      nationalDexIds: nationalDexId == null ? const [] : [nationalDexId],
      updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? ''),
    );
  }

  /// Linha pronta pra `upsert` na tabela `cards`. Não inclui `set_id` —
  /// quem chama decide se o repositório já sabe o set (evita sobrescrever
  /// com vazio quando só temos o detalhe da carta, que não carrega setId).
  Map<String, dynamic> toUpsertRow({String? setId}) {
    final now = DateTime.now().toUtc().toIso8601String();
    return {
      'id': id,
      if (setId != null) 'set_id': setId,
      'local_id': localId,
      'name': name,
      if (imageBaseUrl != null) 'image_url': imageBaseUrl,
      if (rarity != null) 'rarity': rarity,
      if (category != null) 'category': category,
      // stage e regulation_mark: colunas ainda não existem na tabela cards
      // do Supabase — incluir aqui causa erro no upsert. Adicionar as
      // colunas no dashboard e descomentar quando prontas.
      // if (stage != null) 'stage': stage,
      if (hp != null) 'hp': hp,
      // if (regulationMark != null) 'regulation_mark': regulationMark,
      if (types.isNotEmpty) 'types': types,
      if (attacks.isNotEmpty)
        'attacks': attacks
            .map((a) => {
                  'name': a.name,
                  'cost': a.cost,
                  'damage': a.damage,
                  'effect': a.effect,
                })
            .toList(),
      if (weaknesses.isNotEmpty)
        'weaknesses':
            weaknesses.map((w) => {'type': w.type, 'value': w.value}).toList(),
      if (retreat != null) 'retreat': retreat,
      if (illustrator != null) 'illustrator': illustrator,
      if (variants.isNotEmpty) 'variants': variants,
      if (nationalDexIds.isNotEmpty) 'national_dex_id': nationalDexIds.first,
      'fetched_at': now,
      'updated_at': now,
    };
  }

  /// A partir do brief da TCGdex (`fetchCardsForSet`) — usado quando o
  /// repositório precisa popular `cards` pela primeira vez.
  factory Card.fromBrief(legacy.TcgCard c) => Card(
        id: c.id,
        setId: c.setId,
        setName: c.setName,
        localId: c.localId,
        printedTotal: c.printedTotal,
        name: c.name,
        imageBaseUrl: c.imageBaseUrl,
        nationalDexIds: c.dexIds,
      );

  /// A partir do detalhe completo da TCGdex (`fetchCard`). `CardDetail` não
  /// carrega `setId` (só `setName`) — quem chama informa.
  factory Card.fromDetail(legacy.CardDetail d, {required String setId}) => Card(
        id: d.id,
        setId: setId,
        setName: d.setName,
        localId: d.localId,
        printedTotal: d.printedTotal,
        name: d.name,
        imageBaseUrl: d.imageBaseUrl,
        rarity: d.rarity,
        category: d.category,
        stage: d.stage,
        hp: d.hp,
        regulationMark: d.regulationMark,
        types: d.types,
        attacks: d.attacks,
        weaknesses: d.weaknesses,
        retreat: d.retreat,
        illustrator: d.illustrator,
        variants: d.variants,
        nationalDexIds: d.dexIds,
        pricing: d.pricing,
        updatedAt: d.updated,
      );
}

/// Reexport pra quem só quer o pricing bruto da TCGdex sem importar
/// `card_detail.dart` diretamente (usado por `PriceRepository`).
typedef CardMarketPricing = MarketPricing;
