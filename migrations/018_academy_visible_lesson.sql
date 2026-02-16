-- Lição visível para o aluno (professor define qual lição aparece em destaque na academia).
ALTER TABLE academies ADD COLUMN IF NOT EXISTS visible_lesson_id UUID NULL REFERENCES lessons(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS ix_academies_visible_lesson_id ON academies(visible_lesson_id);
COMMENT ON COLUMN academies.visible_lesson_id IS 'Lição em destaque visível para os alunos da academia; usado em GET /lessons?academy_id=...';
