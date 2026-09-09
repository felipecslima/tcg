/// Versão enxuta de uma carta, só com o que o scanner precisa pra
/// identificar e exibir: nome, número dentro do set, imagem, e o Pokémon
/// (dexId) associado. Nada de preço/raridade/variante aqui ainda — isso só
/// importa quando construirmos o catálogo/coleção, depois que o scanner
/// provar que funciona.
///
/// Vem da TCGdex (`https://api.tcgdex.net`). O endpoint de set já devolve
/// essa versão "brief" de cada carta — não precisamos buscar carta por
/// carta, então isso é rápido de carregar mesmo pra sets grandes.
class TcgCard {
  final String id;
  final String setId;
  final String setName;
  final String name;
  final String localId; // número da carta dentro do set (ex: "025", "199")
  final String? imageBaseUrl;
  final List<int> dexIds;

  const TcgCard({
    required this.id,
    required this.setId,
    required this.setName,
    required this.name,
    required this.localId,
    required this.dexIds,
    this.imageBaseUrl,
  });

  /// Monta a URL completa da imagem. TCGdex serve a imagem sem extensão —
  /// é preciso completar com qualidade + formato (ex: "/low.png",
  /// "/high.webp"). Usamos baixa qualidade aqui porque é só pra conferência
  /// visual na tela de revisão, não precisa de imagem grande.
  String? get thumbnailUrl => imageBaseUrl == null ? null : '$imageBaseUrl/low.webp';

  factory TcgCard.fromTcgdexSetCardJson(
    Map<String, dynamic> json, {
    required String setId,
    required String setName,
  }) {
    return TcgCard(
      id: json['id'] as String,
      setId: setId,
      setName: setName,
      name: json['name'] as String? ?? '',
      localId: json['localId']?.toString() ?? '',
      imageBaseUrl: json['image'] as String?,
      dexIds: (json['dexId'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [],
    );
  }

  /// Texto usado como base pro matching do scanner (nome + número), sempre
  /// em minúsculo pra comparação case-insensitive.
  String get matchKey => '${name.toLowerCase()} $localId';
}
