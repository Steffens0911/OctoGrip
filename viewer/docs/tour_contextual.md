# Tour Contextual — Como implementar em novas telas

Sistema de onboarding com spotlight que ilumina cada elemento da tela enquanto exibe um balão explicativo. Implementado no Campo de Treinamento (`StudentHomeScreen`).

---

## Arquitetura

```
lib/
  widgets/
    student/
      training_field_tour.dart   ← engine genérica do tour
  screens/
    student/
      student_home_screen.dart   ← usa o tour (modelo a seguir)
  widgets/
    header_widget.dart           ← botão ? de replay
```

---

## Como funciona

### 1. Cada elemento recebe uma `GlobalKey`

A GlobalKey permite localizar o widget na tela em tempo de execução (posição e tamanho).

```dart
// Declaradas no arquivo do tour, acessíveis por toda a tela
final tourKeyHeader   = GlobalKey(debugLabel: 'tour_header');
final tourKeyStreak   = GlobalKey(debugLabel: 'tour_streak');
```

**Regra:** não usar `const` — GlobalKey não é constante.

### 2. Cada widget-alvo recebe a chave via `KeyedSubtree`

Envolva o widget sem mudar seu layout:

```dart
KeyedSubtree(
  key: tourKeyHeader,
  child: HeaderWidget(...),
),
```

### 3. O tour é um `OverlayEntry` com `CustomPainter`

`showTrainingFieldTour(context)` insere um `OverlayEntry` no topo de tudo.
O `_SpotlightPainter` desenha a máscara escura com um recorte (even-odd) ao redor do elemento ativo.

```
Overlay
  └─ Stack
       ├─ CustomPaint(_SpotlightPainter)   ← máscara + borda colorida
       ├─ GestureDetector(onTap: _skip)    ← toque fora fecha (atrás do bubble)
       └─ Positioned(_Bubble)              ← balão de texto (na frente)
```

**Ordem importa:** o `GestureDetector` de fechar deve vir ANTES do bubble no Stack. Se vier depois, intercepta os cliques dos botões.

### 4. Para cada slide: scroll → posicionar → mostrar

```dart
Future<void> _focusStep(int index) async {
  // 1. Rola até o elemento
  await Scrollable.ensureVisible(
    step.key.currentContext!,
    duration: Duration(milliseconds: 380),
    alignment: 0.25,
  );
  await Future.delayed(Duration(milliseconds: 420)); // aguarda scroll

  // 2. Captura a posição real do elemento
  final box = key.currentContext!.findRenderObject() as RenderBox;
  final pos = box.localToGlobal(Offset.zero);
  _spotlightRect = Rect.fromLTWH(pos.dx, pos.dy, box.size.width, box.size.height);
}
```

### 5. Posicionamento do bubble

O bubble é colocado abaixo do spotlight se couber, senão acima. Clamping garante que nunca saia da tela:

```dart
final placeBelow = spaceBelow >= bubbleEstHeight + gap ||
                   spaceAbove < bubbleEstHeight + gap + 24;

double top = placeBelow
    ? spotlight.bottom + gap
    : spotlight.top - bubbleEstHeight - gap;

top = top.clamp(8.0, screenSize.height - bubbleEstHeight - 8.0);
```

### 6. Persistência do "já visto"

Flag no `SharedPreferences`, chave por `userId`:

```dart
Future<bool> trainingFieldTourDone(String userId) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('training_field_tour_v1_$userId') ?? false;
}
```

Para resetar durante desenvolvimento, remover a chave no console do browser:
```js
localStorage.removeItem('flutter.training_field_tour_v1_<userId>')
```

---

## Como implementar em uma nova tela

### Passo 1 — Criar o arquivo do tour

Copie `training_field_tour.dart` e adapte:

```dart
// my_screen_tour.dart

// Chaves dos elementos
final tourKeyFoo = GlobalKey(debugLabel: 'tour_foo');
final tourKeyBar = GlobalKey(debugLabel: 'tour_bar');

// Slides
final _steps = <_TourStep>[
  _TourStep(
    key: tourKeyFoo,
    color: Color(0xFF6C63FF),
    title: 'Título do slide',
    body: 'Descrição do que esse elemento faz.',
  ),
  // ...
];

// Prefixo único para não colidir com outros tours
const _prefKey = 'my_screen_tour_v1';
```

As classes `_TourOverlay`, `_SpotlightPainter`, `_Bubble`, `_Card`, `_Arrow`, `_ArrowPainter` são idênticas — copie sem alteração.

### Passo 2 — Adicionar `KeyedSubtree` nos widgets-alvo

```dart
KeyedSubtree(
  key: tourKeyFoo,
  child: MeuWidget(...),
),
```

Dicas:
- Envolva o container/card inteiro, não um widget interno
- Para blocos condicionais (`if ... else`), ponha o `KeyedSubtree` dentro do branch
- Para `Column` com label + widget, envolva os dois juntos

### Passo 3 — Disparar no primeiro acesso

```dart
@override
void initState() {
  super.initState();
  _load().then((_) => _maybeShowTour());
}

Future<void> _maybeShowTour() async {
  if (!mounted) return;
  final userId = AuthService().currentUser?.id;
  if (userId == null) return;
  final done = await myScreenTourDone(userId);
  if (!mounted || done) return;
  await markMyScreenTourDone(userId);
  if (!mounted) return;
  showMyScreenTour(context);
}
```

### Passo 4 — Botão de replay (opcional)

Adicione um `IconButton` de `help_outline_rounded` no header ou AppBar da tela:

```dart
IconButton(
  onPressed: () => showMyScreenTour(context),
  icon: const Icon(Icons.help_outline_rounded),
  tooltip: 'Como funciona',
),
```

---

## Paleta de cores usada no Campo de Treinamento

| Slide | Elemento | Cor |
|-------|----------|-----|
| 1 | Header / XP | `0xFF6C63FF` (roxo) |
| 2 | Streak | `0xFFFF5722` (laranja) |
| 3 | Sua Jornada | `0xFF00BCD4` (ciano) |
| 4 | Missões | `0xFF4CAF50` (verde) |
| 5 | Troféus | `0xFFFFC107` (amarelo) |
| 6 | Confirmações | `0xFF9C27B0` (roxo escuro) |

Sugestão: use cores que contrastem com o fundo da tela-alvo.

---

## Problemas conhecidos e soluções

| Problema | Causa | Solução |
|----------|-------|---------|
| Bubble some ao clicar Próximo | `GestureDetector` de fechar estava na frente do bubble no Stack | Colocar o GestureDetector ANTES do bubble nos filhos do Stack |
| `tutorial_coach_mark` não funciona | Pacote usa hit-test incompatível com Flutter web canvas | Usar a implementação custom com `OverlayEntry` + `CustomPainter` |
| Bubble fora da tela | Elemento no topo/fundo sem espaço suficiente | Lógica de `placeBelow` + `clamp` já resolve |
| Spotlight não aparece | `GlobalKey.currentContext` retornando null | Verificar que o widget está montado; aguardar o `_load()` terminar antes de chamar `showTour` |
| Elemento fora do scroll | `Scrollable.ensureVisible` não encontra o scrollable | Confirmar que o widget está dentro de um `SingleChildScrollView` com o mesmo contexto |
