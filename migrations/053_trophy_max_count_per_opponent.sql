-- Limite opcional: quantas execuções confirmadas contam por adversário no período do troféu.
-- NULL = comportamento legado (ouro/prata: todas as execuções; bronze: faixas brancas distintas).
ALTER TABLE trophies ADD COLUMN IF NOT EXISTS max_count_per_opponent INTEGER NULL;

COMMENT ON COLUMN trophies.max_count_per_opponent IS
  'Máximo de execuções que contam por opponent_id no período; NULL = regras legadas de contagem.';
