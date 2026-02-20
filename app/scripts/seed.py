"""
Seed expandido com dados iniciais para testar a API (S-04: 10+ lições; PF-01: missão por nível).
Popula BD para que ranking, dificuldades, relatório semanal e listas não fiquem em branco.
Roda automaticamente no startup da API (Docker). Também: docker compose exec api python -m app.scripts.seed
"""
import logging
import sys
from datetime import date, datetime, timedelta, timezone

logger = logging.getLogger(__name__)

from app.core.security import hash_password
from app.database import SessionLocal
from app.models import (
    Academy,
    Lesson,
    LessonProgress,
    Mission,
    Position,
    Technique,
    TrainingFeedback,
    User,
)


def run_seed():
    db = SessionLocal()
    try:
        # Garante que aluno@jjb.com exista com senha (para login JWT em Docker).
        from app.services.user_service import get_user_by_email
        aluno = get_user_by_email(db, "aluno@jjb.com")
        if aluno:
            if not aluno.password_hash:
                aluno.password_hash = hash_password("senha123")
                db.commit()
                db.refresh(aluno)
                logger.info("Senha definida para aluno@jjb.com (login: senha123)")
        else:
            # Cria aluno@jjb.com se não existir (DB pode ter outros usuários de outro seed)
            first_academy = db.query(Academy).first()
            aluno = User(
                email="aluno@jjb.com",
                name="Aluno Teste",
                academy_id=first_academy.id if first_academy else None,
                password_hash=hash_password("senha123"),
            )
            db.add(aluno)
            db.commit()
            db.refresh(aluno)
            logger.info("Criado aluno@jjb.com (login: senha123)")

        if db.query(User).first():
            return  # Seed já aplicado; evita reimprimir mensagens em startup automático

        # A-03: tema semanal já definido para o professor ver
        academy = Academy(
            name="Academia Teste",
            slug="academia-teste",
            weekly_theme="Passagem de guarda",
        )
        db.add(academy)
        db.flush()

        # Segunda academia para lista não ficar vazia
        academy2 = Academy(
            name="Academia Norte",
            slug="academia-norte",
            weekly_theme="Controle de costas",
        )
        db.add(academy2)
        db.flush()

        # Vários usuários na primeira academia (para ranking com múltiplos nomes)
        # Senha padrão para login (JWT): aluno@jjb.com / senha123
        user = User(
            email="aluno@jjb.com",
            name="Aluno Teste",
            academy_id=academy.id,
            password_hash=hash_password("senha123"),
        )
        db.add(user)
        db.flush()
        user2 = User(
            email="maria@jjb.com",
            name="Maria Silva",
            academy_id=academy.id,
        )
        db.add(user2)
        db.flush()
        user3 = User(
            email="pedro@jjb.com",
            name="Pedro Santos",
            academy_id=academy.id,
        )
        db.add(user3)
        db.flush()
        user_norte = User(
            email="norte@jjb.com",
            name="Atleta Norte",
            academy_id=academy2.id,
        )
        db.add(user_norte)
        db.flush()

        # Posições (iniciante)
        positions = [
            Position(name="Guarda fechada", slug="guarda-fechada", description="Guarda com pernas fechadas no tronco."),
            Position(name="Side control", slug="side-control", description="Controle lateral no chão."),
            Position(name="Montada", slug="montada", description="Montada sobre o adversário."),
            Position(name="Costas", slug="costas", description="Controle pelas costas."),
            Position(name="Meia guarda", slug="meia-guarda", description="Uma perna por dentro, outra por fora."),
        ]
        for p in positions:
            db.add(p)
        db.flush()
        pos_guarda, pos_side, pos_montada, pos_costas, pos_meia = positions

        # Técnicas (transições iniciante)
        techniques_data = [
            ("Passagem de guarda básica", "passagem-guarda-basica", "Passagem da guarda para side control.", pos_guarda.id, pos_side.id),
            ("Abertura de guarda", "abertura-guarda", "Como abrir a guarda fechada.", pos_guarda.id, pos_side.id),
            ("Passagem para montada", "passagem-para-montada", "Da side para a montada.", pos_side.id, pos_montada.id),
            ("Escape da side (ponte)", "escape-side-ponte", "Escape da side com ponte.", pos_side.id, pos_guarda.id),
            ("Montada: controle e ataque", "montada-controle-ataque", "Manter montada e atacar.", pos_montada.id, pos_montada.id),
            ("Escape da montada (upa)", "escape-montada-upa", "Escape básico da montada (upa).", pos_montada.id, pos_guarda.id),
            ("Pegada de costas", "pegada-costas", "Como chegar às costas a partir da montada.", pos_montada.id, pos_costas.id),
            ("Controle de costas", "controle-costas", "Manter e finalizar pelas costas.", pos_costas.id, pos_costas.id),
            ("Passagem da meia guarda", "passagem-meia-guarda", "Passar da meia guarda.", pos_meia.id, pos_side.id),
            ("Recuperar guarda da meia", "recuperar-guarda-meia", "Sair da meia e recuperar guarda.", pos_meia.id, pos_guarda.id),
        ]
        techniques = []
        for name, slug, desc, from_id, to_id in techniques_data:
            t = Technique(
                name=name,
                slug=slug,
                description=desc,
                from_position_id=from_id,
                to_position_id=to_id,
            )
            db.add(t)
            techniques.append(t)
        db.flush()

        # 12 lições para iniciante (order_index 0..11)
        lessons_data = [
            ("Abertura de guarda e passagem", "abertura-guarda-passagem", "Controle de ombros, abertura e passagem para side.", 0, techniques[0].id),
            ("Passagem de guarda: base e postura", "passagem-guarda-base-postura", "Base e postura na passagem de guarda.", 1, techniques[0].id),
            ("Passagem de guarda: quebrando a guarda", "passagem-guarda-quebrando", "Como quebrar a guarda fechada.", 2, techniques[1].id),
            ("Side control: estabilidade", "side-control-estabilidade", "Posição estável na side control.", 3, techniques[2].id),
            ("Da side para a montada", "side-para-montada", "Transição side control → montada.", 4, techniques[2].id),
            ("Escape da side com ponte", "escape-side-ponte-aula", "Técnica de ponte para escapar da side.", 5, techniques[3].id),
            ("Montada: posição e controle", "montada-posicao-controle", "Como manter a montada com segurança.", 6, techniques[4].id),
            ("Escape da montada (upa)", "escape-montada-upa-aula", "Escape básico da montada.", 7, techniques[5].id),
            ("Pegada de costas pela montada", "pegada-costas-aula", "Chegando às costas a partir da montada.", 8, techniques[6].id),
            ("Controle de costas: gancho e mão", "controle-costas-gancho", "Ganchos e controle pelas costas.", 9, techniques[7].id),
            ("Meia guarda: passagem básica", "meia-guarda-passagem-aula", "Passagem básica da meia guarda.", 10, techniques[8].id),
            ("Recuperar guarda da meia", "recuperar-guarda-meia-aula", "Saindo da meia e recuperando a guarda.", 11, techniques[9].id),
        ]
        lessons = []
        for i, (title, slug, content, order, tech_id) in enumerate(lessons_data):
            # Algumas lições com video_url para não ficar em branco no app
            video_url = f"https://example.com/videos/{slug}" if i < 4 else None
            lesson = Lesson(
                title=title,
                slug=slug,
                video_url=video_url,
                content=content,
                order_index=order,
                technique_id=tech_id,
            )
            db.add(lesson)
            lessons.append(lesson)
        db.flush()

        # Missões por nível (PF-01): esta semana, beginner/intermediate = técnica da lição 0/1
        today = date.today()
        week_end = today + timedelta(days=6)
        mission_beginner = Mission(
            technique_id=lessons[0].technique_id,
            start_date=today,
            end_date=week_end,
            is_active=True,
            level="beginner",
            theme="Passagem de guarda",
        )
        mission_intermediate = Mission(
            technique_id=lessons[1].technique_id,
            start_date=today,
            end_date=week_end,
            is_active=True,
            level="intermediate",
            theme="Base e postura",
        )
        db.add_all([mission_beginner, mission_intermediate])
        db.flush()

        # A-02: missão por academia (override)
        mission_academy = Mission(
            technique_id=lessons[2].technique_id,
            start_date=today,
            end_date=week_end,
            is_active=True,
            level="beginner",
            theme="Quebrando a guarda",
            academy_id=academy.id,
        )
        db.add(mission_academy)
        mission_academy2 = Mission(
            technique_id=lessons[3].technique_id,
            start_date=today,
            end_date=week_end,
            is_active=True,
            level="beginner",
            theme="Side control",
            academy_id=academy2.id,
        )
        db.add(mission_academy2)
        db.flush()

        # LessonProgress: conclusões para ranking e relatório semanal não ficarem vazios
        # Semana atual (para relatório semanal) e últimos dias (para ranking 30 dias)
        now = datetime.now(timezone.utc)
        base_week = now - timedelta(days=now.weekday())  # início da semana (segunda)
        progress_data = [
            (user.id, lessons[0].id, base_week + timedelta(days=1)),   # Aluno Teste, lição 0
            (user.id, lessons[1].id, base_week + timedelta(days=2)),
            (user.id, lessons[2].id, base_week + timedelta(days=3)),
            (user2.id, lessons[0].id, base_week + timedelta(days=1)),     # Maria, lição 0
            (user2.id, lessons[1].id, base_week + timedelta(days=2)),
            (user2.id, lessons[2].id, base_week + timedelta(days=3)),
            (user2.id, lessons[3].id, base_week + timedelta(days=4)),   # Maria mais uma
            (user3.id, lessons[0].id, base_week + timedelta(days=2)),    # Pedro
            (user3.id, lessons[1].id, base_week + timedelta(days=3)),
            (user_norte.id, lessons[3].id, base_week + timedelta(days=1)),  # Atleta Norte
        ]
        for uid, lid, completed_at in progress_data:
            lp = LessonProgress(
                user_id=uid,
                lesson_id=lid,
                completed_at=completed_at,
            )
            db.add(lp)
        db.flush()

        # TrainingFeedback: dificuldades reportadas (T-02) para a tela não ficar vazia
        feedback_data = [
            (user.id, pos_guarda.id, "Dificuldade para manter a base."),
            (user.id, pos_side.id, None),
            (user2.id, pos_guarda.id, "Abertura da guarda difícil."),
            (user2.id, pos_guarda.id, "Repetir mais vezes."),  # mesma posição, 2 reportes
            (user3.id, pos_montada.id, "Escape complicado."),
            (user_norte.id, pos_costas.id, None),
        ]
        for uid, pid, note in feedback_data:
            tf = TrainingFeedback(
                user_id=uid,
                position_id=pid,
                difficulty_level=1,
                note=note,
            )
            db.add(tf)
        db.flush()

        db.commit()

        print("Seed expandido aplicado com sucesso.")
        print()
        print("Resumo:")
        print(f"  Academias:  2 ({academy.name}, {academy2.name})")
        print(f"  Usuários:   4 (3 em Academia Teste, 1 em Academia Norte)")
        print(f"  Posições:   {len(positions)}")
        print(f"  Técnicas:   {len(techniques)}")
        print(f"  Lições:     {len(lessons)} (4 com video_url)")
        print(f"  Missões:    4 (2 globais + 2 por academia)")
        print(f"  Conclusões (LessonProgress): {len(progress_data)}")
        print(f"  Dificuldades (TrainingFeedback): {len(feedback_data)}")
        print()
        print("IDs para usar no /docs:")
        print(f"  user_id:      {user.id}")
        print(f"  lesson_id:    {lessons[0].id} (primeira lição)")
        print(f"  mission_id:   {mission_beginner.id} (missão do dia, GET /mission_today)")
        print()
        print("Login (JWT):")
        print("  POST /auth/login  body: {\"email\": \"aluno@jjb.com\", \"password\": \"senha123\"}")
        print("  Use o access_token no header: Authorization: Bearer <token>")
        print()
        print("Endpoints para testar:")
        print("  GET  /mission_today")
        print("  POST /mission_complete (body: mission_id, usage_type; requer Authorization)")
        print("  GET  /lessons")
        print("  GET  /academies, /academies/{id}/ranking, /difficulties, /report/weekly")
        print("  POST /lesson_complete   (body: lesson_id; requer Authorization)")
        print("  POST /training_feedback (body: position_id, observation?; requer Authorization)")
    except Exception as e:
        db.rollback()
        print(f"Erro no seed: {e}", file=sys.stderr)
        raise
    finally:
        db.close()


if __name__ == "__main__":
    run_seed()
