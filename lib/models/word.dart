/// Uma palavra do vocabulário, em ordem de frequência (rank 1 = mais usada).
class Word {
  const Word({
    required this.rank,
    required this.english,
    required this.partOfSpeech,
    required this.portuguese,
  });

  final int rank;
  final String english;
  final String partOfSpeech;
  final String portuguese;

  /// Chave usada para salvar o progresso.
  String get id => english.toLowerCase();

  /// Nível de 1 a 15, com 100 palavras cada.
  int get level => (rank - 1) ~/ wordsPerLevel + 1;

  static const wordsPerLevel = 100;

  static const _partOfSpeechLabels = {
    'n': 'substantivo',
    'v': 'verbo',
    'adj': 'adjetivo',
    'adv': 'advérbio',
    'prep': 'preposição',
    'pron': 'pronome',
    'conj': 'conjunção',
    'det': 'determinante',
    'num': 'numeral',
    'int': 'interjeição',
  };

  String get partOfSpeechLabel =>
      _partOfSpeechLabels[partOfSpeech] ?? partOfSpeech;

  /// Lê uma linha no formato `palavra|classe|tradução`.
  static Word parse(String line, int rank) {
    final parts = line.split('|');
    if (parts.length != 3) {
      throw FormatException('Linha inválida na lista de palavras: $line');
    }
    return Word(
      rank: rank,
      english: parts[0].trim(),
      partOfSpeech: parts[1].trim(),
      portuguese: parts[2].trim(),
    );
  }
}
