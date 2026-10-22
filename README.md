# 🃏 Flashcards de Inglês: 1500 palavras

App web feito em **Flutter** para estudar as 1500 palavras mais usadas do inglês com flashcards e **repetição espaçada** (algoritmo SM-2, o mesmo princípio do Anki).

## Funcionalidades

- 1500 palavras em ordem de frequência, com tradução para o português e classe gramatical
- 15 níveis de 100 palavras
- Repetição espaçada: responda **Errei / Difícil / Bom / Fácil** e o app agenda a próxima revisão
- Pronúncia em inglês pela voz do navegador 🔊
- Direção dos cartões: Inglês → Português, Português → Inglês ou misturado
- Lista de palavras com busca e filtro por status (nova, aprendendo, revisando, dominada)
- Estatísticas: revisões do dia, palavras vistas, dominadas e dias seguidos
- Progresso salvo no navegador, com exportação/importação de backup (JSON)
- Tema claro/escuro (Material 3)
- Atalhos de teclado: `espaço` vira o cartão · `1`–`4` responde · `P` pronuncia

## Estrutura

```
assets/words.txt          # lista de palavras: palavra|classe|tradução (uma por linha)
lib/
  main.dart               # app, tema e navegação
  models/                 # Word e CardState
  services/srs.dart       # algoritmo de repetição espaçada
  services/browser.dart   # voz, download e upload (APIs do navegador)
  state/app_state.dart    # estado global e persistência
  screens/                # Início, Estudar, Palavras, Ajustes
  widgets/flip_card.dart  # cartão com animação de virar
test/                     # testes do SRS e da lista de palavras
.github/workflows/        # build e deploy automático no GitHub Pages
```

## Rodando localmente

Requer o [Flutter SDK](https://docs.flutter.dev/get-started/install).

```bash
flutter pub get
flutter run -d chrome        # desenvolvimento
flutter test                 # testes
flutter build web --release  # gera build/web
```

## Deploy

Cada push na branch `main` roda os testes, compila o app e publica no **GitHub Pages** pelo workflow em `.github/workflows/deploy.yml`.

## Editando as palavras

Edite `assets/words.txt`. Cada linha segue o formato `palavra|classe|tradução`, em que a classe é uma destas: `n`, `v`, `adj`, `adv`, `prep`, `pron`, `conj`, `det`, `num`, `int`. A ordem das linhas define a frequência e os níveis. Rode `flutter test` para validar a lista.
