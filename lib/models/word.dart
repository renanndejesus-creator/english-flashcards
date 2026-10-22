/// Uma palavra do vocabulário, em ordem de frequência (rank 1 = mais usada).
class Word {
  const Word({
    required this.rank,
    required this.english,
    required this.partOfSpeech,
    required this.portuguese,
    required this.exampleEnglish,
    required this.examplePortuguese,
  });

  final int rank;
  final String english;
  final String partOfSpeech;
  final String portuguese;

  /// Frase de exemplo em inglês usando a palavra, e sua tradução.
  final String exampleEnglish;
  final String examplePortuguese;

  /// Chave usada para salvar o progresso.
  String get id => english.toLowerCase();

  /// Nome dos arquivos de áudio (igual ao `slug` de tool/generate_audio.py).
  String get audioSlug => id
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');

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

  /// Lê uma linha no formato `palavra|classe|tradução|exemplo|tradução do exemplo`.
  static Word parse(String line, int rank) {
    final parts = line.split('|');
    if (parts.length != 5) {
      throw FormatException('Linha inválida na lista de palavras: $line');
    }
    return Word(
      rank: rank,
      english: parts[0].trim(),
      partOfSpeech: parts[1].trim(),
      portuguese: parts[2].trim(),
      exampleEnglish: parts[3].trim(),
      examplePortuguese: parts[4].trim(),
    );
  }
}
