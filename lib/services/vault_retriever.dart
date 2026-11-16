import 'dart:math' as math;

import 'vault_service.dart';

/// One vault note (or chunk) selected for chat context.
class VaultHit {
  const VaultHit({
    required this.path,
    required this.snippet,
    required this.score,
  });

  final String path;
  final String snippet;
  final double score;
}

/// Lightweight local retrieval: keyword / TF-IDF-lite over path + body.
/// No embedding model / vector DB — keeps PC load low for MVP.
class VaultRetriever {
  const VaultRetriever({
    this.topK = 6,
    this.maxSnippetChars = 1400,
    this.maxFilesToScan = 400,
    this.maxFileBytes = 80 * 1024,
  });

  final int topK;
  final int maxSnippetChars;
  final int maxFilesToScan;
  final int maxFileBytes;

  static final _tokenRe = RegExp(r'[a-zа-яё0-9]+', caseSensitive: false);
  static const _stop = {
    'и',
    'в',
    'во',
    'не',
    'на',
    'я',
    'что',
    'это',
    'как',
    'а',
    'то',
    'все',
    'она',
    'так',
    'его',
    'но',
    'да',
    'ты',
    'к',
    'у',
    'же',
    'вы',
    'за',
    'бы',
    'по',
    'только',
    'ее',
    'мне',
    'было',
    'вот',
    'от',
    'меня',
    'еще',
    'ещё',
    'о',
    'из',
    'ему',
    'теперь',
    'когда',
    'даже',
    'ну',
    'вдруг',
    'ли',
    'если',
    'уже',
    'или',
    'ни',
    'быть',
    'был',
    'него',
    'до',
    'вас',
    'нибудь',
    'опять',
    'уж',
    'вам',
    'ведь',
    'там',
    'потом',
    'себя',
    'ничего',
    'ей',
    'может',
    'они',
    'тут',
    'где',
    'есть',
    'надо',
    'ней',
    'для',
    'мы',
    'тебя',
    'их',
    'чем',
    'была',
    'сам',
    'чтоб',
    'без',
    'будто',
    'чего',
    'раз',
    'тоже',
    'себе',
    'под',
    'будет',
    'ж',
    'тогда',
    'кто',
    'этот',
    'того',
    'потому',
    'этого',
    'какой',
    'совсем',
    'ним',
    'здесь',
    'этом',
    'один',
    'почти',
    'мой',
    'тем',
    'чтобы',
    'нее',
    'сейчас',
    'были',
    'куда',
    'зачем',
    'сказать',
    'the',
    'a',
    'an',
    'and',
    'or',
    'of',
    'to',
    'in',
    'on',
    'for',
    'is',
    'are',
    'was',
    'be',
    'with',
    'as',
    'by',
    'at',
    'from',
    'it',
    'this',
    'that',
    'i',
    'you',
    'my',
    'me',
    'we',
    'our',
    'your',
    'have',
    'has',
    'do',
    'does',
    'did',
    'not',
    'but',
    'if',
    'so',
    'what',
    'which',
    'who',
    'how',
    'when',
    'where',
    'why',
    'about',
    'into',
    'md',
  };

  /// Tokenize query/body for RU+EN keyword matching.
  static List<String> tokenize(String text) {
    final out = <String>[];
    for (final m in _tokenRe.allMatches(text.toLowerCase())) {
      final t = m.group(0)!;
      if (t.length < 2) continue;
      if (_stop.contains(t)) continue;
      out.add(t);
    }
    return out;
  }

  /// Soft stem: strip common RU endings for length≥4 so «физике»≈«физик».
  static String softStem(String token) {
    if (token.length < 5) return token;
    const endings = [
      'иями',
      'ями',
      'ами',
      'ией',
      'ием',
      'ом',
      'ем',
      'ой',
      'ей',
      'ию',
      'ью',
      'ия',
      'ья',
      'ие',
      'ые',
      'ий',
      'ый',
      'ая',
      'ое',
      'ых',
      'их',
      'ам',
      'ям',
      'ах',
      'ях',
      'ов',
      'ев',
      'ью',
      'ью',
      'у',
      'ю',
      'а',
      'я',
      'е',
      'и',
      'ы',
      'о',
      's',
      'ed',
      'ing',
    ];
    for (final e in endings) {
      if (token.length - e.length >= 4 && token.endsWith(e)) {
        return token.substring(0, token.length - e.length);
      }
    }
    return token;
  }

  Future<List<VaultHit>> retrieve({
    required VaultService vault,
    required List<String> files,
    required String query,
  }) async {
    final qTokens = tokenize(query);
    if (qTokens.isEmpty || files.isEmpty) return const [];

    final qStems = qTokens.map(softStem).toSet();
    final scanned = files.take(maxFilesToScan).toList();

    // Document frequency for IDF.
    final df = <String, int>{};
    final docs = <_Doc>[];

    for (final path in scanned) {
      String body;
      try {
        body = await vault.readNote(path);
      } catch (_) {
        continue;
      }
      if (body.length > maxFileBytes) {
        body = body.substring(0, maxFileBytes);
      }
      final pathTokens = tokenize(path.replaceAll(RegExp(r'[\\/_.-]'), ' '));
      final bodyTokens = tokenize(body);
      final all = [...pathTokens, ...bodyTokens];
      final tf = <String, int>{};
      for (final t in all) {
        final s = softStem(t);
        tf[s] = (tf[s] ?? 0) + 1;
      }
      // Path/title boost: count path tokens twice more.
      for (final t in pathTokens) {
        final s = softStem(t);
        tf[s] = (tf[s] ?? 0) + 3;
      }
      for (final s in tf.keys) {
        df[s] = (df[s] ?? 0) + 1;
      }
      docs.add(_Doc(path: path, body: body, tf: tf));
    }

    if (docs.isEmpty) return const [];
    final n = docs.length;
    final scored = <VaultHit>[];

    for (final doc in docs) {
      var score = 0.0;
      var matched = 0;
      for (final qs in qStems) {
        final tf = doc.tf[qs] ?? _fuzzyTf(doc.tf, qs);
        if (tf <= 0) continue;
        matched++;
        final idf = math.log((n + 1) / ((df[qs] ?? _fuzzyDf(df, qs)) + 1)) + 1;
        score += (1 + math.log(tf)) * idf;
      }
      if (matched == 0) continue;
      // Prefer covering more query terms.
      score *= (1 + matched / qStems.length);
      scored.add(
        VaultHit(
          path: doc.path,
          snippet: _snippet(doc.body, qStems),
          score: score,
        ),
      );
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(topK).toList();
  }

  static int _fuzzyTf(Map<String, int> tf, String stem) {
    if (stem.length < 4) return 0;
    var best = 0;
    for (final e in tf.entries) {
      if (e.key.startsWith(stem) || stem.startsWith(e.key)) {
        best = math.max(best, e.value);
      }
    }
    return best;
  }

  static int _fuzzyDf(Map<String, int> df, String stem) {
    if (stem.length < 4) return 0;
    var best = 0;
    for (final e in df.entries) {
      if (e.key.startsWith(stem) || stem.startsWith(e.key)) {
        best = math.max(best, e.value);
      }
    }
    return best;
  }

  String _snippet(String body, Set<String> qStems) {
    final clean = body.replaceAll('\r\n', '\n').trim();
    if (clean.length <= maxSnippetChars) return clean;

    // Prefer a window around the first query hit.
    final lower = clean.toLowerCase();
    var bestIdx = 0;
    for (final s in qStems) {
      if (s.length < 3) continue;
      final i = lower.indexOf(s);
      if (i >= 0) {
        bestIdx = i;
        break;
      }
    }
    final start = math.max(0, bestIdx - maxSnippetChars ~/ 4);
    var end = math.min(clean.length, start + maxSnippetChars);
    var slice = clean.substring(start, end);
    if (start > 0) slice = '…$slice';
    if (end < clean.length) slice = '$slice…';
    return slice;
  }

  /// Format hits for the system prompt.
  static String formatForPrompt(List<VaultHit> hits) {
    final buf = StringBuffer();
    buf.writeln('## Выдержки из vault (RAG-lite)');
    buf.writeln(
      'Ниже — релевантные фрагменты заметок, которые приложение нашло по запросу.',
    );
    buf.writeln(
      'Отвечай, ОПИРАЯСЬ на эти выдержки. Суммируй и анализируй сам.',
    );
    buf.writeln(
      'ЗАПРЕЩЕНО говорить пользователю «открой файл», «посмотри в папке», '
      '«прочитай заметку сам» — ты уже получил текст.',
    );
    buf.writeln(
      'Если выдержек нет или они не по теме — честно скажи, что в vault '
      'по этому вопросу ничего (достаточного) не найдено.',
    );
    buf.writeln('Упоминай пути источников в ответе, когда опираешься на них.');
    if (hits.isEmpty) {
      buf.writeln();
      buf.writeln('(Релевантных заметок не найдено.)');
      return buf.toString();
    }
    for (var i = 0; i < hits.length; i++) {
      final h = hits[i];
      buf.writeln();
      buf.writeln('### [${i + 1}] `${h.path}`');
      buf.writeln(h.snippet);
    }
    return buf.toString();
  }
}

class _Doc {
  _Doc({required this.path, required this.body, required this.tf});

  final String path;
  final String body;
  final Map<String, int> tf;
}
