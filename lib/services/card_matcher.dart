import '../models/tcg_card.dart';

/// O que o scanner deve mostrar pra este frame:
///   - `choices` vazio  → nada plausível, segue escaneando sem perguntar
///   - `choices` com 1   → carta clara: card "É esta?" (1 toque pra confirmar)
///   - `choices` com 2–3 → dúvida: seletor pro usuário escolher
///
/// Nada entra na sessão sem o usuário tocar.
class MatchResult {
  final List<TcgCard> choices;
  final double score; // score do líder (diagnóstico / limiares)

  const MatchResult({this.choices = const [], required this.score});
}

/// Casa o texto bruto do OCR contra as cartas do set escolhido.
///
/// **Número de coletor é o sinal primário** — é o que separa a carta comum
/// da full art / alt art do mesmo Pokémon (mesmo nome, número diferente),
/// e continua legível quando o nome estilizado da full art não sai no OCR.
/// O denominador ("/132") é conferido contra o total do set.
class CardMatcher {
  CardMatcher({this.confidenceThreshold = 0.55});

  /// Score mínimo do líder pra ele ser tratado como "carta clara" (1 toque)
  /// em vez de virar uma escolha entre candidatos.
  final double confidenceThreshold;

  /// Abaixo disso não pergunta nada (leu lixo / pedaço fraco de nome).
  static const double _showMinScore = 0.40;

  /// Score mínimo pra uma carta aparecer como opção no seletor.
  static const double _candidateMinScore = 0.34;

  /// Janela em torno do líder — só cartas "realmente prováveis" entram.
  static const double _candidateSpread = 0.16;

  /// 2º lugar precisa estar tão atrás pra colapsar num "É esta?" só.
  static const double _clearMargin = 0.18;

  MatchResult match(String recognizedText, List<TcgCard> candidates) {
    if (candidates.isEmpty) return const MatchResult(score: 0);

    final input = _normalize(recognizedText);
    if (input.isEmpty) return const MatchResult(score: 0);
    final parsed = _parseCollectorNumber(recognizedText);

    final scored = candidates
        .map((c) => (card: c, score: _scoreCard(input, parsed, c)))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final best = scored.first;

    // 1) MESMO NOME empatado (comum vs full art) e o número não decidiu →
    //    força a escolha entre essas versões (prioridade sobre "líder claro").
    final sameName = scored
        .where((s) =>
            _norm(s.card.name) == _norm(best.card.name) &&
            (best.score - s.score) < 0.15)
        .map((s) => s.card)
        .toList();
    if (best.score >= _candidateMinScore &&
        sameName.length > 1 &&
        !_numberDecides(parsed, sameName)) {
      return MatchResult(choices: sameName.take(3).toList(), score: best.score);
    }

    // 2) nada plausível → não pergunta
    if (best.score < _showMinScore) return MatchResult(score: best.score);

    // 3) cartas realmente prováveis: perto do líder, score decente, no máx. 3
    final near = scored
        .where((s) =>
            s.score >= _candidateMinScore &&
            best.score - s.score <= _candidateSpread)
        .take(3)
        .map((s) => s.card)
        .toList();

    // 4) líder claro → confirmar 1; senão → escolher entre os prováveis
    final clearLeader = near.length == 1 ||
        (best.score >= confidenceThreshold &&
            scored.length > 1 &&
            best.score - scored[1].score >= _clearMargin);
    return MatchResult(
      choices: clearLeader ? [best.card] : near,
      score: best.score,
    );
  }

  double _scoreCard(String input, _ParsedNumber? parsed, TcgCard card) {
    double s = 0;

    // ---- número de coletor ----
    final want = _digits(card.localId);
    if (parsed != null && want.isNotEmpty) {
      final pn = _digits(parsed.number);
      if (pn == want) {
        s += 0.55; // numerador bate exato
        if (parsed.denominator != null &&
            card.printedTotal > 0 &&
            _digits(parsed.denominator!) == card.printedTotal.toString()) {
          s += 0.20; // + denominador confere = quase certeza
        }
      } else if (_oneDigitOff(pn, want)) {
        s += 0.34; // OCR provavelmente errou 1 dígito — perde pra qualquer exato
      }
    } else {
      // sem fração lida: o número impresso zero-pad (ex. "080") aparece cru?
      final raw = card.localId.replaceAll(RegExp(r'\D'), '');
      if (raw.length >= 3 &&
          RegExp('(?<![0-9])$raw(?![0-9])').hasMatch(input)) {
        s += 0.30;
      }
    }

    // ---- nome ----
    final name = _norm(card.name);
    if (name.isNotEmpty) {
      if (input.contains(name)) {
        s += 0.60; // nome único inteiro no texto já confirma
      } else {
        final sim = _bestSubstringSimilarity(input, name);
        s += (sim >= 0.72 ? 0.55 : 0.60) * sim;
      }
    }

    return s.clamp(0.0, 1.0);
  }

  /// O número lido resolve o empate entre as candidatas de mesmo nome?
  bool _numberDecides(_ParsedNumber? parsed, List<TcgCard> tied) {
    if (parsed == null) return false;
    final pn = _digits(parsed.number);
    return tied.where((c) => _digits(c.localId) == pn).length == 1;
  }

  // ---- número: parsing + comparação tolerante a OCR ----

  /// "145/132", "145 / 132", "145 132", ou um número solto no fim.
  _ParsedNumber? _parseCollectorNumber(String raw) {
    // trocas comuns de OCR só no contexto de dígitos
    final t = raw
        .replaceAll(RegExp(r'[oO]'), '0')
        .replaceAll(RegExp(r'[lI]'), '1')
        .replaceAll('／', '/');

    // Só a fração "N/M" (ou "N M" colados) — sinal confiável. Um número solto
    // não dá: dano de ataque / HP são "60", "120" e virariam falso-positivo.
    var m = RegExp(r'(\d{1,3})\s*/\s*(\d{1,3})').firstMatch(t);
    m ??= RegExp(r'\b(\d{2,3})\s+(\d{2,3})\b').firstMatch(t);
    if (m != null) {
      return _ParsedNumber(number: m.group(1)!, denominator: m.group(2));
    }
    return null;
  }

  String _digits(String s) {
    final d = s.replaceAll(RegExp(r'\D'), '');
    return d.isEmpty ? '' : int.parse(d).toString(); // tira zeros à esquerda
  }

  /// Mesma quantidade de dígitos e exatamente 1 diferente (OCR flubou 1).
  bool _oneDigitOff(String a, String b) {
    if (a.isEmpty || b.isEmpty || a.length != b.length || a.length < 2) {
      return false;
    }
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) diff++;
    }
    return diff == 1;
  }

  // ---- nome ----

  double _bestSubstringSimilarity(String input, String target) {
    if (target.isEmpty) return 0;
    final words = input.split(RegExp(r'\s+'));
    final targetWordCount = target.split(' ').length;
    double best = 0;
    for (var i = 0; i < words.length; i++) {
      final window = words.skip(i).take(targetWordCount).join(' ');
      if (window.isEmpty) continue;
      final sim = _levSimilarity(window, target);
      if (sim > best) best = sim;
    }
    return best;
  }

  double _levSimilarity(String a, String b) {
    final d = _levenshtein(a, b);
    final maxLen = a.length > b.length ? a.length : b.length;
    return maxLen == 0 ? 1 : 1 - (d / maxLen);
  }

  int _levenshtein(String a, String b) {
    final la = a.length, lb = b.length;
    if (la == 0) return lb;
    if (lb == 0) return la;
    var prev = List<int>.generate(lb + 1, (i) => i);
    var curr = List<int>.filled(lb + 1, 0);
    for (var i = 1; i <= la; i++) {
      curr[0] = i;
      for (var j = 1; j <= lb; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = [curr[j - 1] + 1, prev[j] + 1, prev[j - 1] + cost]
            .reduce((v, e) => v < e ? v : e);
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[lb];
  }

  String _norm(String s) => _normalize(s);

  String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}0-9\s]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _ParsedNumber {
  final String number;
  final String? denominator;
  const _ParsedNumber({required this.number, this.denominator});
}
