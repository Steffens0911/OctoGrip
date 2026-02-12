"""
Seed expandido com dados iniciais para testar a API (S-04: 10+ lições; PF-01: missão por nível).
Rodar: python -m app.scripts.seed
Com Docker: docker compose exec api python -m app.scripts.seed
"""
import sys
from datetime import date, timedelta

from app.database import SessionLocal
from app.models import Lesson, Mission, Position, Technique, User


def run_seed():
    db = SessionLocal()
    try:
        if db.query(User).first():
            print("Seed já aplicado (existe usuário). Nada a fazer.")
            return

        user = User(
            email="aluno@jjb.com",
            name="Aluno Teste",
        )
        db.add(user)
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
        for title, slug, content, order, tech_id in lessons_data:
            lesson = Lesson(
                title=title,
                slug=slug,
                video_url=None,
                content=content,
                order_index=order,
                technique_id=tech_id,
            )
            db.add(lesson)
            lessons.append(lesson)
        db.flush()

        # Missões por nível (PF-01): esta semana, beginner = lição 0, intermediate = lição 1
        today = date.today()
        week_end = today + timedelta(days=6)
        mission_beginner = Mission(
            lesson_id=lessons[0].id,
            start_date=today,
            end_date=week_end,
            is_active=True,
            level="beginner",
        )
        mission_intermediate = Mission(
            lesson_id=lessons[1].id,
            start_date=today,
            end_date=week_end,
            is_active=True,
            level="intermediate",
        )
        db.add_all([mission_beginner, mission_intermediate])

        db.commit()

        print("Seed expandido aplicado com sucesso.")
        print()
        print("Resumo:")
        print(f"  Usuário:     {user.id}")
        print(f"  Posições:    {len(positions)}")
        print(f"  Técnicas:    {len(techniques)}")
        print(f"  Lições:      {len(lessons)}")
        print(f"  Missões:     2 (beginner + intermediate)")
        print()
        print("IDs para usar no /docs:")
        print(f"  user_id:      {user.id}")
        print(f"  lesson_id:    {lessons[0].id} (primeira lição)")
        print()
        print("Endpoints para testar:")
        print("  GET  /mission_today")
        print("  GET  /lessons")
        print("  POST /lesson_complete   (body: user_id, lesson_id)")
        print("  POST /training_feedback (body: user_id, position_id, observation?)")
    except Exception as e:
        db.rollback()
        print(f"Erro no seed: {e}", file=sys.stderr)
        raise
    finally:
        db.close()


if __name__ == "__main__":
    run_seed()
