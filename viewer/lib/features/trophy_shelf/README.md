# Feature: Trophy Shelf (Estante de troféus)

Visão gamificada da galeria: prateleiras, slots, troféus com estados (bloqueado/ouro com glow) e modal de detalhes.

- **Página:** `presentation/trophy_shelf_page.dart` — carrega via `GET /trophies/user/{user_id}`, trata loading/erro/403.
- **Layout:** `Padding` + `Column` de `ShelfRow` (não usar `Positioned` como filho de `LayoutBuilder`).
- **Documentação completa:** [docs/TROPHY_SHELF.md](../../../../docs/TROPHY_SHELF.md) na raiz do projeto.

Acesso: Galeria de troféus → ícone da AppBar "Ver como estante".
