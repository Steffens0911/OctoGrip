"""Reenfileira geração de embedding facial para todos os alunos com avatar_url.

Útil após mudanças no pipeline de embedding (ex.: adição de normalização L2).
Os jobs são processados pelos workers Celery já em execução.

Uso:
    docker compose exec api python -m app.scripts.regenerate_embeddings
    docker compose exec api python -m app.scripts.regenerate_embeddings --academy-id <uuid>
    docker compose exec api python -m app.scripts.regenerate_embeddings --dry-run
"""

import argparse
import logging
import sys
from uuid import UUID

from sqlalchemy import select

from app.database import SyncSessionLocal
from app.models import StudentFaceEmbedding, User

logger = logging.getLogger(__name__)


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Regenera embeddings faciais dos alunos.")
    parser.add_argument(
        "--academy-id",
        type=str,
        default=None,
        help="UUID da academia (opcional). Se omitido, processa todas as academias.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Apenas lista os alunos sem enfileirar os jobs.",
    )
    return parser.parse_args()


def run_regenerate(academy_id: UUID | None = None, dry_run: bool = False) -> None:
    from app.tasks.face_recognition_tasks import generate_student_embedding

    with SyncSessionLocal() as db:
        query = (
            select(User.id, User.email, User.name, User.academy_id)
            .where(User.role == "aluno", User.avatar_url.is_not(None))
        )
        if academy_id:
            query = query.where(User.academy_id == academy_id)

        rows = db.execute(query).all()

        if not rows:
            print("Nenhum aluno com avatar_url encontrado.")
            return

        existing_ids = set(
            db.execute(
                select(StudentFaceEmbedding.student_id).where(
                    StudentFaceEmbedding.student_id.in_([r[0] for r in rows])
                )
            ).scalars().all()
        )

    total = len(rows)
    with_embedding = sum(1 for r in rows if r[0] in existing_ids)
    without_embedding = total - with_embedding

    print(f"\nAlunos com avatar_url: {total}")
    print(f"  Com embedding existente : {with_embedding}")
    print(f"  Sem embedding           : {without_embedding}")

    if dry_run:
        print("\n[dry-run] Nenhum job enfileirado.")
        for row in rows:
            status = "com embedding" if row[0] in existing_ids else "sem embedding"
            print(f"  {row[1]} ({row[2] or 'sem nome'}) [{status}]")
        return

    print(f"\nEnfileirando {total} job(s)...")
    enqueued = 0
    for row in rows:
        try:
            generate_student_embedding.delay(str(row[0]))
            enqueued += 1
        except Exception as exc:
            print(f"  ERRO ao enfileirar {row[1]}: {exc}", file=sys.stderr)

    print(f"Jobs enfileirados: {enqueued}/{total}")
    print("Acompanhe o progresso nos logs do celery-worker.")


if __name__ == "__main__":
    logging.basicConfig(level=logging.WARNING)
    args = _parse_args()
    aid = UUID(args.academy_id) if args.academy_id else None
    run_regenerate(academy_id=aid, dry_run=args.dry_run)
