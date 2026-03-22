# Módulo Troféus (Clean Architecture)

Espelha o padrão de **[`docs/CRUD_PADRAO_FLUTTER.md`](../../../../docs/CRUD_PADRAO_FLUTTER.md)** e do módulo `features/techniques/`.

- Lista por academia: sync API + Hive, busca com debounce, paginação client-side.
- **Criar/editar**: [`TrophyFormScreen`](../../screens/admin/trophy_form_screen.dart) — nível mínimo para desbloquear (`min_reward_level_to_unlock`, 0 = livre), faixa mínima opcional; ao editar período/técnica/meta/tipo, confirmação de aviso (impacto nas conquistas).
- **Excluir**: soft delete no servidor; diálogo explica exclusão lógica.
- **API**: `PATCH /trophies/{id}`, `DELETE /trophies/{id}`; listagem ignora `deleted_at` preenchido.
