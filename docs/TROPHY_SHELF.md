# Estante de troféus (Trophy Shelf)

Visão gamificada da galeria de troféus e medalhas: estante 3D onde os itens aparecem sobre prateleiras, com estados visuais (bloqueado, ouro com glow) e modal de detalhes.

---

## Acesso

- **Galeria em lista:** menu do aluno → atalho "Galeria de troféus" (ou via lista de usuários no admin: "Ver galeria").
- **Estante:** na tela da Galeria de troféus, toque no ícone da AppBar (**Ver como estante**) para abrir a `TrophyShelfPage`.

A estante usa os mesmos dados da API que a galeria em lista (`GET /trophies/user/{user_id}`). Se a galeria estiver privada, retorna 403 e a mensagem "Esta galeria está privada."

---

## Arquitetura (viewer)

```
viewer/lib/
├── features/
│   └── trophy_shelf/
│       ├── domain/
│       │   └── shelf_trophy.dart      # Entidade de apresentação (posição + estado na estante)
│       ├── presentation/
│       │   ├── trophy_shelf_page.dart # Página: loading, erro, lista vazia, layout
│       │   └── widgets/
│       │       ├── shelf_background.dart   # Fundo (gradiente ou asset da estante)
│       │       ├── shelf_row.dart           # Uma prateleira horizontal de slots
│       │       ├── trophy_slot.dart        # Slot (vazio ou com troféu), toque, acessibilidade
│       │       ├── trophy_item.dart        # Ícone do troféu, opacidade, glow ouro, animações
│       │       ├── trophy_shelf_layout.dart # Stack (fundo + prateleiras)
│       │       └── trophy_detail_modal.dart # Bottom sheet com detalhes ao toque
│       └── utils/
│           └── shelf_layout_config.dart # Slots por linha, linhas, tamanhos (phone/tablet)
├── models/
│   └── trophy.dart                    # TrophyWithEarned (DTO da API), inalterado
└── screens/student/
    └── trophy_gallery_screen.dart    # Galeria em lista + botão "Ver como estante"
```

---

## Widgets principais

| Widget | Responsabilidade |
|--------|------------------|
| **TrophyShelfPage** | Carrega troféus via API (ou usa lista passada). Trata loading, erro (403 = galeria privada), lista vazia. Orquestra layout e modal. |
| **TrophyShelfLayout** | Stack: `ShelfBackground` + área de prateleiras (Padding + Column de ShelfRow). **Importante:** não usar `Positioned` como filho de `LayoutBuilder` — só como filho direto de `Stack`; aqui o conteúdo é posicionado com `Padding(top: topOffset)`. |
| **ShelfBackground** | Fundo em gradiente (ou asset opcional). Sem asset, usa gradiente escuro. |
| **ShelfRow** | Uma linha de slots (Row com N TrophySlot). Recebe troféus daquela fila e config. |
| **TrophySlot** | Área clicável (mín. 48 dp), feedback de toque (scale 0.98), Semantics para leitores de tela. Vazio ou com TrophyItem. |
| **TrophyItem** | Ícone por tier (ouro/prata/bronze/bloqueado), opacidade reduzida se bloqueado, glow para ouro. Animações: desbloqueio (scale/opacity), pulsação contínua para ouro. |
| **TrophyDetailModal** | Bottom sheet: nome, técnica, tier, datas, progresso (gold/silver/bronze). Botão Fechar; acessível. |

---

## Modelo de apresentação

- **TrophyWithEarned** (em `models/trophy.dart`): DTO da API; não alterado.
- **ShelfTrophy** (em `features/trophy_shelf/domain/shelf_trophy.dart`):
  - Referência a `TrophyWithEarned`, `shelfRowIndex`, `slotIndex`, `isUnlocked`, `isGold`.
  - Mapeamento: `ShelfTrophy.fromTrophies(trophies, slotsPerRow, rowCount)` — ordenação por `end_date` desc, depois `name`; preenche slots por linha/linha.

---

## Layout e responsividade

- **ShelfLayoutConfig:** `fromWidth(width)` retorna config por breakpoint (ex.: &lt; 600 px = phone, ≥ 600 = tablet): slots por linha, número de linhas, tamanho do slot, padding, espaçamento.
- Prateleiras: `Padding(top: topOffset)` + `Column` com `SizedBox` por linha contendo `ShelfRow`. Cada linha usa `Row` com slots de tamanho fixo (config.slotSize).

---

## API e estados

| Situação | Comportamento |
|----------|----------------|
| Própria galeria | Lista completa (conquistados + em andamento). |
| Galeria de outro, visível | Apenas itens com `earned_tier != null` (só conquistados). |
| Galeria de outro, privada | 403 → mensagem "Esta galeria está privada." |
| Lista vazia | Mensagem "Nenhum troféu nesta galeria." |

Endpoint: `GET /trophies/user/{user_id}` (mesmo da galeria em lista). Cada item inclui `unlocked`, `min_reward_level_to_unlock` (0 = sem requisito de nível) e `min_graduation_to_unlock`; a API calcula `unlocked` a partir de `users.reward_level` e da faixa do aluno.

---

## Acessibilidade

- **TrophySlot:** Semantics com label do tipo "{nome}, {ouro/prata/bronze/bloqueado}. Toque para ver detalhes"; área de toque mínima 48 dp.
- **TrophyDetailModal:** Semantics no container e no botão "Fechar detalhes do troféu".

---

## Riscos técnicos evitados

1. **Positioned fora do Stack:** `Positioned` só pode ser filho direto de `Stack`. No layout, o conteúdo das prateleiras é posicionado com `Padding`, não com `Positioned` retornado pelo `LayoutBuilder`.
2. **Asset da estante:** opcional; sem asset usa gradiente. Para usar imagem, defina `ShelfBackground(imageAssetPath: 'assets/images/shelf_background.png')` e inclua o arquivo em `pubspec.yaml` (assets já declarados para `assets/images/`).

---

## Ordem de implementação (referência)

1. Assets e ShelfLayoutConfig  
2. ShelfTrophy e mapeamento  
3. Widgets básicos (ShelfBackground, ShelfRow, TrophySlot, TrophyItem)  
4. TrophyShelfPage + TrophyShelfLayout  
5. TrophyDetailModal e toque  
6. Estados visuais (opacidade bloqueado, glow ouro)  
7. Integração API (getTrophiesForUser, loading/erro/403)  
8. Animações (desbloqueio, pulsação, feedback toque)  
9. Navegação (botão "Ver como estante" na galeria)  
10. Polish (acessibilidade, ajustes)
