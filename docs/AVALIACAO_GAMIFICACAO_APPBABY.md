# Avaliacao de Gamificacao do AppBaby

Data: 2026-03-23
Base de referencia: skill `gamification-loops` (`patterns`, `sharp_edges`, `validations`)

## Escopo avaliado

- Home do aluno (`viewer/lib/screens/student/student_home_screen.dart`)
- Header e barra de progresso (`viewer/lib/widgets/header_widget.dart`)
- Log de pontuacao (`viewer/lib/screens/student/points_log_screen.dart`)
- Estante de trofeus (`viewer/lib/features/trophy_shelf/presentation/trophy_shelf_page.dart`)
- Modelo de nivel/XP (`viewer/lib/core/leveling.dart`)

## Diagnostico executivo

O AppBaby ja possui uma base de gamificacao funcional e relativamente saudavel:
missao semanal, progresso de XP/level, recompensa diaria por video, meta coletiva e trofeus/medalhas.

Pelo criterio da skill, o risco atual nao e de "dark pattern agressivo", mas sim de
**engajamento cair por falta de loop completo** (trigger -> action -> reward -> investment)
e por falta de mecanismos de motivacao social/progresso de medio prazo mais claros.

## Pontos fortes (alinhados a `patterns.md`)

1. **Loop de acao + recompensa presente**
   - O aluno executa missoes/acoes e recebe pontos/XP.
   - Evidencias: `_loadMissionWeekWith`, `_loadUserPointsWith`, `HeaderWidget`.

2. **Progresso visivel**
   - Barra de XP, nivel e meta coletiva com `LinearProgressIndicator`.
   - Evidencias: `HeaderWidget` e `_buildCollectiveGoalCard`.

3. **Camada social leve e saudavel**
   - Galeria de colegas e meta coletiva; nao depende de ranking absoluto unico.
   - Isso reduz risco de desmotivacao do "bottom 90%".

4. **Sem penalidade agressiva de desligamento**
   - Nao foi identificado streak punitivo nem perda dura por ausencia.
   - Alinhado com validacao de "off-ramp" da skill.

## Riscos e lacunas (por severidade)

### Medio - "reward-only tendency" (validacao `reward-only-motivation`)

- O sistema comunica fortemente XP/pontos, mas com pouca explicacao de valor intrinseco
  (dominio tecnico, consistencia, melhoria real).
- Sintoma: usuario pode focar no numero e nao no aprendizado.
- Onde aparece:
  - Badge `+ XP Completar tarefa!` no header.
  - Log de pontuacao majoritariamente transacional (entrada de pontos).

### Medio - risco de "metric gaming" (sharp edge `metric-gaming`)

- Sem evidencias no cliente de quality gates visiveis no feedback de recompensa.
- Se o backend premiar quantidade de acoes sem qualidade, vira comportamento de "farm".
- Onde observar:
  - Fluxo de confirmacoes e historico de pontos sem score de qualidade/impacto.

### Medio - falta de milestones de medio/longo prazo (validacao `no-completion`)

- Ha progresso de curto prazo (missao/XP), mas poucos marcos narrativos de ciclo maior
  (ex.: "trilha completa", "dominio da tecnica X", "3 semanas consistentes").
- Impacto: sensacao de esteira infinita apos fase inicial.

### Baixo - competencia social pode evoluir melhor

- Hoje ha social por galeria/meta coletiva, mas nao ha mecanismo de comparacao por coorte,
  personal best ou ligas temporais (alternativas recomendadas pela skill).

## Resultado das validacoes da skill

- `no-off-ramp`: **OK** (nao ha punicao forte de pausa detectada no app avaliado)
- `reward-only-motivation`: **Atencao** (comunicao mais extrinseca que intrinseca)
- `demotivating-leaderboard`: **OK parcial** (nao ha leaderboard agressivo)
- `gameable-rewards`: **Atencao** (depende de gates de qualidade no backend/fluxo)
- `excessive-notifications`: **Nao avaliado no cliente** (sem base suficiente neste recorte)
- `no-completion`: **Atencao** (faltam marcos de ciclo mais longo)

## Recomendacoes praticas (priorizadas)

1. **Conectar recompensa a dominio (alta prioridade)**
   - Em cada ganho de XP, mostrar "o que melhorou" (tecnica, consistencia, precisao).
   - Ex.: no `PointsLogScreen`, adicionar tag de "competencia evoluida".

2. **Criar milestones de jornada (alta prioridade)**
   - Marcos semanais/mensais com fim claro e celebracao (nao apenas XP continuo).
   - Ex.: "Semana de base completa", "Ciclo tecnico concluido".

3. **Adicionar anti-gaming visivel (media prioridade)**
   - Tornar claro para o usuario que qualidade pesa mais que volume.
   - Ex.: feedback "confirmacao validada com qualidade" no log/confirmacoes.

4. **Evoluir social para modelo saudavel (media prioridade)**
   - Introduzir personal best e coortes em vez de ranking geral fixo.
   - Preserva motivacao da maioria.

5. **Documentar principio etico de gamificacao (media prioridade)**
   - Regra de produto: sem punicao por pausa, sem FOMO abusivo, com saidas claras.

## Plano sugerido em 3 fases

### Fase 1 (rapida, baixo risco)
- Melhorar textos de UI para valor intrinseco (nao so pontos)
- Enriquecer `PointsLogScreen` com contexto do ganho
- Inserir micro-celebracoes de milestones simples

### Fase 2 (impacto medio)
- Trilhas semanais/mensais com conclusao clara
- Badges por consistencia e qualidade, nao apenas quantidade

### Fase 3 (impacto alto)
- Coortes e personal best
- Eventos temporais opt-in e colaborativos (academia/time)

## Metricas para acompanhar (sem incentivar dark pattern)

- Retencao 7d e 30d por coorte
- % usuarios que completam milestone semanal
- Distribuicao de progresso (evitar concentracao extrema no topo)
- Qualidade media de execucoes confirmadas
- Sinal de bem-estar: queda de abandono por frustracao/ansiedade

## Conclusao

AppBaby tem base solida de gamificacao e boa direcao etica inicial.
O maior ganho agora e evoluir de "pontuar atividade" para "mostrar progresso real de dominio",
com milestones claros e mecanismos anti-gaming transparentes.
