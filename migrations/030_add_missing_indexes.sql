-- Migration 030: Adicionar índices faltantes para otimização de queries
-- Índices em foreign keys e campos frequentemente consultados

-- TrainingFeedback: adicionar índices em user_id e position_id
CREATE INDEX IF NOT EXISTS idx_training_feedback_user_id ON training_feedback(user_id);
CREATE INDEX IF NOT EXISTS idx_training_feedback_position_id ON training_feedback(position_id);

-- LessonProgress: adicionar índice em lesson_id (user_id já tem índice composto)
-- Nota: PostgreSQL cria índice automaticamente para unique constraints, mas vamos criar explícito para garantir
CREATE INDEX IF NOT EXISTS idx_lesson_progress_lesson_id ON lesson_progress(lesson_id);

-- MissionUsage: adicionar índice em usage_type (usado em métricas para filtrar before_training/after_training)
CREATE INDEX IF NOT EXISTS idx_mission_usage_usage_type ON mission_usages(usage_type);

-- Nota: TechniqueExecution.lesson_id já tem índice criado na migração 019 (ix_technique_executions_lesson_id)
-- Nota: TechniqueExecution.usage_type não precisa de índice (não há queries filtrando por este campo)
