import '../models/tcg_card.dart';

/// Resultado de uma tentativa de matching: ou achou uma carta com confiança
/// suficiente, ou não achou nenhuma boa o bastante.
class MatchResult {
  final TcgCard? card;
  final double score; // 0.0 a 1.0, quanto maior mais confiante

  const MatchResult({this.card, required this.score});

  bool get isConfident => card != null;
}

/// Casa o texto bruto reconhecido pelo OCR contra a lista de cartas do set
/// selecionado. Fica restrito a um set por vez de propósito — é o que
/// reduz drasticamente o espaço de busca e evita falso-positivo (ver plano
/// do MVP: "pré-filtro de set é a maior alavanca de precisão").
class CardMatcher {
  CardMatcher({this.confidenceThreshold = 0.55});

  /// Abaixo disso, o resultado vira pendência em vez de match automático.
  final double confidenceThreshold;

  MatchResult match(String recognizedText, List<TcgCard> candidates) {
    if (candidates.isEmpty) return const MatchResult(score: 0);

    final normalizedInput = _normalize(recognizedText);
    if (normalizedInput.isEmpty) return const MatchResult(score: 0);

    TcgCard? best;
    double bestScore = 0;

    for (final card in candidates) {
      final score = _scoreCard(normalizedInput, card);
      if (score > bestScore) {
        bestScore = score;
        best = card;
      }
    }

    if (best != null && bestScore >= confidenceThreshold) {
      return MatchResult(card: best, score: bestScore);
    }
    return MatchResult(score: bestScore);
  }

  double _scoreCard(String normalizedInput, TcgCard card) {
    final normalizedName = _normalize(card.name);
    if (normalizedName.isEmpty) return 0;

    // Sinal 1: o nome da carta aparece (quase) inteiro no texto reconhecido.
    final nameContained = normalizedInput.contains(normalizedName);
    final nameSimilarity = nameContained
        ? 1.0
        : _bestSubstringSimilarity(normalizedInput, normalizedName);

    // Sinal 2: o número da carta (local id) aparece no texto reconhecido.
    // Isso é o desempate mais forte quando várias cartas têm nomes
    // parecidos (ex: "Charizard" normal vs "Charizard ex").
    final numberFound = card.localId.isNotEmpty &&
        RegExp(r'(?<!\d)' + RegExp.escape(card.localId) + r'(?!\d)').hasMatch(normalizedInput);

    var score = nameSimilarity * 0.7;
    if (numberFound) score += 0.3;
    return score.clamp(0.0, 1.0);
  }

  /// Similaridade aproximada por distância de Levenshtein normalizada,
  /// comparando a substring mais parecida do texto de entrada com o nome
  /// da carta (o texto do OCR costuma ter ruído em volta do nome — outras
  /// linhas da carta, "Basic", HP, etc.).
  double _bestSubstringSimilarity(String input, String target) {
    if (target.isEmpty) return 0;
    final words = input.split(RegExp(r'\s+'));
    double best = 0;
    // Testa janelas de tamanho parecido ao número de palavras do nome alvo.
    final targetWordCount = target.split(' ').length;
    for (var i = 0; i < words.length; i++) {
      final window = words.skip(i).take(targetWordCount).join(' ');
      if (window.isEmpty) continue;
      final similarity = _normalizedLevenshteinSimilarity(window, target);
      if (similarity > best) best = similarity;
    }
    return best;
  }

  double _normalizedLevenshteinSimilarity(String a, String b) {
    final distance = _levenshtein(a, b);
    final maxLen = a.length > b.length ? a.length : b.length;
    if (maxLen == 0) return 1;
    return 1 - (distance / maxLen);
  }

  int _levenshtein(String a, String b) {
    final la = a.length;
    final lb = b.length;
    if (la == 0) return lb;
    if (lb == 0) return la;
    var prev = List<int>.generate(lb + 1, (i) => i);
    var curr = List<int>.filled(lb + 1, 0);
    for (var i = 1; i <= la; i++) {
      curr[0] = i;
      for (var j = 1; j <= lb; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = [
          curr[j - 1] + 1,
          prev[j] + 1,
          prev[j - 1] + cost,
        ].reduce((v, e) => v < e ? v : e);
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[lb];
  }

  String _normalize(String input) {
    // Remove acentos e caracteres especiais, mantém números e espaços.
    // Cobre português, inglês e caracteres comuns em nomes de Pokémon.
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}0-9\s]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
