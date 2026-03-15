"""Limpa todo o banco de dados de uso (academias, posições, técnicas, lições,
missões, execuções, feedbacks etc.) e mantém apenas o usuário admin@jjb.com.

Pode ser executado via:

    docker compose exec api python -m app.scripts.cleanup_keep_admin

ou, com o ambiente configurado localmente:

    python -m app.scripts.cleanup_keep_admin
"""

import sys
import logging

from app.core.security import hash_password_sync
from app.database import SessionLocal
from app.models import (
    Academy,
    CollectiveGoal,
    Lesson,
    LessonProgress,
    Mission,
    MissionUsage,
    Position,
    Professor,
    Technique,
    TechniqueExecution,
    TrainingFeedback,
    Trophy,
    User,
)


logger = logging.getLogger(__name__)

ADMIN_EMAIL = "admin@jjb.com"


def cleanup_db_keep_admin() -> None:
    """Remove todos os dados e mantém apenas o usuário admin@jjb.com."""
    db = SessionLocal()
    try:
        # Garante que o admin exista
        admin = (
            db.query(User)
            .filter(User.email.ilike(ADMIN_EMAIL))
            .first()
        )

        if not admin:
            logger.info("Usuário admin@jjb.com não encontrado; criando novo admin (senha: saas).")
            admin = User(
                email=ADMIN_EMAIL,
                name="Administrador",
                role="administrador",
                gallery_visible=True,
                password_hash=hash_password_sync("saas"),
            )
            db.add(admin)
            db.flush()
        else:
            # Garante role de administrador e senha "saas"
            if admin.role != "administrador":
                admin.role = "administrador"
            if not admin.password_hash:
                admin.password_hash = hash_password_sync("saas")
                logger.info("Senha definida para admin@jjb.com (login: saas)")

        # Apaga tabelas dependentes primeiro (ordem importante para FKs).
        # Tabelas que referenciam usuários, técnicas, lições etc.
        for model in (
            TechniqueExecution,
            MissionUsage,
            LessonProgress,
            TrainingFeedback,
            CollectiveGoal,
            Trophy,
            Mission,
            Lesson,
            Technique,
            Position,
            Professor,
            Academy,
        ):
            deleted = db.query(model).delete(synchronize_session=False)
            logger.info("Removidos %s registros de %s", deleted, model.__tablename__)

        # Remove todos os usuários exceto o admin
        deleted_users = (
            db.query(User)
                .filter(User.id != admin.id)
                .delete(synchronize_session=False)
        )
        logger.info("Removidos %s usuários (mantido apenas %s).", deleted_users, ADMIN_EMAIL)

        db.commit()
        print("Banco de dados limpo com sucesso. Mantido apenas o usuário admin@jjb.com.")
    except Exception as exc:
        db.rollback()
        logger.exception("Falha ao limpar o banco de dados: %s", exc)
        print(f"Erro ao limpar o banco de dados: {exc}", file=sys.stderr)
        raise
    finally:
        db.close()


if __name__ == "__main__":
    cleanup_db_keep_admin()

