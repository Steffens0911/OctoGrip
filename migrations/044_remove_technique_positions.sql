-- Remove relacionamento de técnicas com posições (from_position_id / to_position_id)
-- Este script é tolerante: em bancos que nunca tiveram essas colunas, os ALTER TABLE
-- são ignorados graças ao IF EXISTS.
--
-- Não usar UPDATE ... SET coluna = NULL: em bancos legados essas colunas podem ser
-- NOT NULL, o que quebra a migração. DROP COLUMN remove a coluna e os FKs associados.

ALTER TABLE techniques DROP COLUMN IF EXISTS from_position_id;
ALTER TABLE techniques DROP COLUMN IF EXISTS to_position_id;
