"""Seed de academia de DEMONSTRAÇÃO/TESTES (Octogrip).

Cria uma academia completa e isolada, com tudo que o modelo permite:
alunos (várias faixas/níveis/streaks), professor(es), gerente, técnicas/posições,
slots e kits semanais, missões, troféus automáticos (com conquistas por aluno),
medalhas manuais e de campeonato, execuções confirmadas, conclusões de missão,
presença, metas coletivas, parceiros, vídeos, marketplace e notificações.

Tudo fica sob o slug `demo-octogrip` e o domínio de e-mail `@demo.octogrip.com.br`,
para ser fácil de identificar e remover.

Uso (em produção, dentro do container da API):

    docker compose exec api python /app/scripts/seed_demo_academy.py
    docker compose exec api python /app/scripts/seed_demo_academy.py --reset

Sem flags: se a academia demo já existir, não faz nada (idempotente).
Com --reset: apaga a academia demo (e todos os dados ligados) e recria do zero.

Senha de todos os usuários demo: Demo@1234
"""

from __future__ import annotations

import argparse
import asyncio
import random
import sys
import unicodedata
from datetime import UTC, datetime, timedelta
from uuid import UUID

from sqlalchemy import delete, select

from app.core.leveling import compute_level_from_total_points
from app.core.security import hash_password_sync
from app.database import AsyncSessionLocal
from app.models import (
    Academy,
    AcademyChampionshipEvent,
    AcademyMarketplaceItem,
    AcademyTrophyAward,
    AcademyTrophyTemplate,
    AttendanceRecord,
    AttendanceSession,
    CollectiveGoal,
    Lesson,
    Mission,
    MissionUsage,
    Notification,
    Partner,
    Professor,
    Technique,
    TechniqueExecution,
    TrainingVideo,
    Trophy,
    User,
    UserLoginDay,
    UserTrophyEarned,
    WeeklyKitItem,
    WeeklyTechniqueKit,
)

# --------------------------------------------------------------------------- #
# Constantes da academia demo
# --------------------------------------------------------------------------- #
DEMO_SLUG = "demo-octogrip"
DEMO_NAME = "Academia Octogrip — Demonstração"
DEMO_EMAIL_DOMAIN = "demo.octogrip.com.br"
DEMO_PASSWORD = "Demo@1234"
N_STUDENTS = 25
RANDOM_SEED = 20260617

now = datetime.now(UTC)
today = now.date()

GRADUATIONS = ["white", "blue", "purple", "brown", "black"]

# Faixas dos 25 alunos (distribuição realista: muitos brancos, poucos pretos)
STUDENT_BELTS = (
    ["white"] * 10
    + ["blue"] * 7
    + ["purple"] * 4
    + ["brown"] * 3
    + ["black"] * 1
)

STUDENT_NAMES = [
    "Lucas Almeida", "Mariana Costa", "Rafael Souza", "Beatriz Lima", "Gabriel Rocha",
    "Juliana Martins", "Felipe Carvalho", "Camila Ferreira", "Bruno Oliveira", "Larissa Gomes",
    "Thiago Ribeiro", "Amanda Barbosa", "Diego Nunes", "Patrícia Araújo", "Vinícius Pinto",
    "Fernanda Dias", "Rodrigo Teixeira", "Aline Cardoso", "Marcelo Castro", "Carolina Moraes",
    "Eduardo Ramos", "Tatiane Freitas", "Gustavo Mendes", "Priscila Lopes", "André Correia",
]

TECHNIQUES = [
    ("Mata-Leão", 10),
    ("Armlock da Guarda Fechada", 10),
    ("Triângulo", 15),
    ("Kimura", 10),
    ("Omoplata", 15),
    ("Americana", 10),
    ("Raspagem de Tesoura", 10),
    ("Raspagem de Gancho", 10),
    ("Passagem de Guarda em Pé", 15),
    ("Escape da Montada", 10),
    ("Pegada nas Costas", 15),
    ("Berimbolo", 20),
]


def slugify(value: str) -> str:
    norm = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode("ascii")
    out = "".join(c if c.isalnum() else "-" for c in norm.lower())
    while "--" in out:
        out = out.replace("--", "-")
    return out.strip("-")


def email_for(name: str) -> str:
    base = slugify(name).replace("-", ".")
    return f"{base}@{DEMO_EMAIL_DOMAIN}"


# --------------------------------------------------------------------------- #
# Reset
# --------------------------------------------------------------------------- #
async def wipe_demo(db, academy_id: UUID) -> None:
    """Remove, em ordem segura de FKs, tudo ligado à academia demo."""
    user_ids_subq = select(User.id).where(User.academy_id == academy_id).scalar_subquery()
    session_ids_subq = (
        select(AttendanceSession.id).where(AttendanceSession.academy_id == academy_id).scalar_subquery()
    )

    # Filhos por usuário
    await db.execute(delete(UserTrophyEarned).where(UserTrophyEarned.user_id.in_(user_ids_subq)))
    await db.execute(delete(AcademyTrophyAward).where(AcademyTrophyAward.user_id.in_(user_ids_subq)))
    await db.execute(delete(TechniqueExecution).where(TechniqueExecution.user_id.in_(user_ids_subq)))
    await db.execute(delete(MissionUsage).where(MissionUsage.user_id.in_(user_ids_subq)))
    await db.execute(delete(Notification).where(Notification.user_id.in_(user_ids_subq)))
    await db.execute(delete(UserLoginDay).where(UserLoginDay.user_id.in_(user_ids_subq)))

    # Presença
    await db.execute(delete(AttendanceRecord).where(AttendanceRecord.session_id.in_(session_ids_subq)))
    await db.execute(delete(AttendanceSession).where(AttendanceSession.academy_id == academy_id))

    # Por academia (ordem: missões e itens de kit antes de técnicas/kits por causa de FKs RESTRICT)
    await db.execute(delete(AcademyChampionshipEvent).where(AcademyChampionshipEvent.academy_id == academy_id))
    await db.execute(delete(AcademyTrophyTemplate).where(AcademyTrophyTemplate.academy_id == academy_id))
    await db.execute(delete(Mission).where(Mission.academy_id == academy_id))
    kit_ids_subq = (
        select(WeeklyTechniqueKit.id).where(WeeklyTechniqueKit.academy_id == academy_id).scalar_subquery()
    )
    await db.execute(delete(WeeklyKitItem).where(WeeklyKitItem.kit_id.in_(kit_ids_subq)))
    await db.execute(delete(WeeklyTechniqueKit).where(WeeklyTechniqueKit.academy_id == academy_id))
    await db.execute(delete(CollectiveGoal).where(CollectiveGoal.academy_id == academy_id))
    await db.execute(delete(Trophy).where(Trophy.academy_id == academy_id))
    await db.execute(delete(Lesson).where(Lesson.academy_id == academy_id))
    await db.execute(delete(TrainingVideo).where(TrainingVideo.academy_id == academy_id))
    await db.execute(delete(AcademyMarketplaceItem).where(AcademyMarketplaceItem.academy_id == academy_id))
    await db.execute(delete(Partner).where(Partner.academy_id == academy_id))

    # Limpa ponteiros da academia para técnicas/lição antes de apagar técnicas
    await db.execute(
        Academy.__table__.update()
        .where(Academy.id == academy_id)
        .values(
            weekly_technique_id=None,
            weekly_technique_2_id=None,
            weekly_technique_3_id=None,
            visible_lesson_id=None,
        )
    )
    await db.execute(delete(Technique).where(Technique.academy_id == academy_id))

    # Usuários, professores e a academia
    await db.execute(delete(User).where(User.academy_id == academy_id))
    await db.execute(delete(Professor).where(Professor.academy_id == academy_id))
    await db.execute(delete(Academy).where(Academy.id == academy_id))
    await db.commit()


# --------------------------------------------------------------------------- #
# Seed
# --------------------------------------------------------------------------- #
async def seed(db) -> None:
    rng = random.Random(RANDOM_SEED)
    pwd = hash_password_sync(DEMO_PASSWORD)

    # 1) Academia (com features premium ligadas) ---------------------------- #
    academy = Academy(
        name=DEMO_NAME,
        slug=DEMO_SLUG,
        logo_url="https://placehold.co/200x200/png?text=Octogrip",
        schedule_image_url="https://placehold.co/800x1000/png?text=Quadro+de+Horarios",
        weekly_multiplier_1=10,
        weekly_multiplier_2=15,
        weekly_multiplier_3=20,
        show_trophies=True,
        show_partners=True,
        show_schedule=True,
        show_global_supporters=True,
        login_notice_title="Bem-vindo ao Octogrip!",
        login_notice_body="Esta é a academia de demonstração. Explore missões, troféus e o ranking semanal.",
        login_notice_active=True,
        face_recognition_enabled=True,
        qr_attendance_enabled=True,
        octophotos_enabled=True,
        user_photos_quota=30,
    )
    db.add(academy)
    await db.flush()

    # 2) Técnicas / posições ------------------------------------------------ #
    techniques: list[Technique] = []
    for name, pts in TECHNIQUES:
        t = Technique(
            academy_id=academy.id,
            name=name,
            slug=slugify(name),
            description=f"Técnica de demonstração: {name}.",
            video_url="https://www.youtube.com/watch?v=dQw4w9WgXcQ",
            base_points=pts,
        )
        db.add(t)
        techniques.append(t)
    await db.flush()

    # 3) Lições (algumas técnicas) ----------------------------------------- #
    lessons: list[Lesson] = []
    for i, t in enumerate(techniques[:4]):
        lesson = Lesson(
            academy_id=academy.id,
            title=f"Como aplicar: {t.name}",
            slug=slugify(f"licao-{t.name}"),
            video_url="https://www.youtube.com/watch?v=dQw4w9WgXcQ",
            content=f"Passo a passo da técnica {t.name}.",
            order_index=i,
            base_points=10,
            technique_id=t.id,
        )
        db.add(lesson)
        lessons.append(lesson)
    await db.flush()

    # Slots semanais + lição em destaque na academia
    academy.weekly_technique_id = techniques[0].id
    academy.weekly_technique_2_id = techniques[1].id
    academy.weekly_technique_3_id = techniques[2].id
    academy.visible_lesson_id = lessons[0].id

    # 4) Kits semanais (turmas) + itens ------------------------------------ #
    kits: list[WeeklyTechniqueKit] = []
    kit_specs = [
        ("Turma Iniciante", techniques[0:3]),
        ("Turma Avançada", techniques[3:6]),
    ]
    for sort_order, (label, kit_techs) in enumerate(kit_specs):
        kit = WeeklyTechniqueKit(academy_id=academy.id, label=label, sort_order=sort_order)
        db.add(kit)
        await db.flush()
        for order_index, t in enumerate(kit_techs):
            db.add(
                WeeklyKitItem(
                    kit_id=kit.id,
                    order_index=order_index,
                    technique_id=t.id,
                    multiplier=10 + order_index * 5,
                )
            )
        kits.append(kit)
    await db.flush()

    # 5) Missões (slots legados por nível + missões de kit) ---------------- #
    missions: list[Mission] = []
    levels = ["beginner", "intermediate", "advanced"]
    for slot_index in range(3):
        for level in levels[: slot_index + 1]:
            m = Mission(
                technique_id=techniques[slot_index].id,
                slot_index=slot_index,
                start_date=today - timedelta(days=2),
                end_date=today + timedelta(days=5),
                is_active=True,
                level=level,
                theme="Semana de finalizações",
                academy_id=academy.id,
                multiplier=getattr(academy, f"weekly_multiplier_{slot_index + 1}"),
            )
            db.add(m)
            missions.append(m)
    # Missões de kit
    for kit, (_, kit_techs) in zip(kits, kit_specs, strict=True):
        for slot_index, t in enumerate(kit_techs):
            m = Mission(
                technique_id=t.id,
                slot_index=slot_index,
                start_date=today - timedelta(days=2),
                end_date=today + timedelta(days=5),
                is_active=True,
                level="beginner",
                academy_id=academy.id,
                weekly_kit_id=kit.id,
                multiplier=10 + slot_index * 5,
            )
            db.add(m)
            missions.append(m)
    await db.flush()

    # 6) Staff: gerente + professores -------------------------------------- #
    manager = User(
        email=email_for("Sergio Gestor"),
        password_hash=pwd,
        name="Sérgio Gestor",
        role="gerente_academia",
        graduation="black",
        academy_id=academy.id,
        last_login_at=now - timedelta(hours=3),
    )
    db.add(manager)

    prof_users: list[User] = []
    for pname in ["Professor Faixa-Preta", "Professora Coral"]:
        pu = User(
            email=email_for(pname),
            password_hash=pwd,
            name=pname,
            role="professor",
            graduation="black",
            academy_id=academy.id,
            last_login_at=now - timedelta(hours=rng.randint(1, 12)),
        )
        db.add(pu)
        prof_users.append(pu)
    await db.flush()

    # Registros na tabela professors (área do professor)
    for pu in prof_users:
        db.add(Professor(name=pu.name, email=pu.email, academy_id=academy.id))
    await db.flush()

    main_prof = prof_users[0]

    # 7) Alunos ------------------------------------------------------------- #
    students: list[User] = []
    for i in range(N_STUDENTS):
        name = STUDENT_NAMES[i]
        belt = STUDENT_BELTS[i]
        frozen = i in (7, 18)  # dois alunos congelados (ex.: mensalidade)
        s = User(
            email=email_for(name),
            password_hash=pwd,
            name=name,
            role="aluno",
            graduation=belt,
            academy_id=academy.id,
            gallery_visible=True,
            account_frozen=frozen,
            account_freeze_reason="Mensalidade em aberto" if frozen else None,
            avatar_url=f"https://i.pravatar.cc/150?u={slugify(name)}",
            last_login_at=now - timedelta(days=rng.randint(0, 6), hours=rng.randint(0, 23)),
        )
        db.add(s)
        students.append(s)
    await db.flush()

    # 8) Streak: dias de login consecutivos (varia por aluno) -------------- #
    for i, s in enumerate(students):
        streak_len = [0, 1, 2, 3, 5, 7, 10, 14][i % 8]
        # Alguns logaram ontem mas não hoje (streak em risco), outros hoje.
        end_offset = 0 if i % 3 != 0 else 1
        for d in range(streak_len):
            db.add(UserLoginDay(user_id=s.id, login_day=today - timedelta(days=end_offset + d)))
    await db.flush()

    # 9) Atividade: conclusões de missão + execuções confirmadas ----------- #
    # Gera atividade nesta semana para alimentar pontos, níveis e ranking semanal.
    legacy_missions = [m for m in missions if m.weekly_kit_id is None]
    student_total_points: dict[UUID, int] = {}

    for rank_idx, s in enumerate(students):
        # Alunos no topo da lista têm mais atividade (ranking semanal claro).
        intensity = max(1, (N_STUDENTS - rank_idx))
        total = 0

        # Conclusões de missão (MissionUsage)
        n_missions = min(6, 1 + intensity // 4)
        for _ in range(n_missions):
            m = rng.choice(legacy_missions)
            completed = now - timedelta(days=rng.randint(0, 6), hours=rng.randint(0, 23))
            pts = m.multiplier
            db.add(
                MissionUsage(
                    user_id=s.id,
                    mission_id=m.id,
                    opened_at=completed - timedelta(minutes=20),
                    completed_at=completed,
                    usage_type="after_training",
                    points_awarded=pts,
                )
            )
            total += pts

        # Execuções confirmadas (contra colegas), com mission_id → contam pontos
        n_exec = min(8, intensity // 3)
        for _ in range(n_exec):
            opponent = rng.choice([o for o in students if o.id != s.id])
            m = rng.choice(legacy_missions)
            confirmed = now - timedelta(days=rng.randint(0, 6), hours=rng.randint(0, 23))
            pts = rng.choice([10, 15, 20])
            # CHECK chk_execution_source: apenas uma fonte (mission_id) preenchida.
            db.add(
                TechniqueExecution(
                    user_id=s.id,
                    mission_id=m.id,
                    opponent_id=opponent.id,
                    usage_type="after_training",
                    status="confirmed",
                    outcome="success",
                    points_awarded=pts,
                    confirmed_at=confirmed,
                    confirmed_by=main_prof.id,
                )
            )
            total += pts

        # Algumas execuções pendentes de confirmação (não pontuam ainda)
        if rng.random() < 0.4:
            opponent = rng.choice([o for o in students if o.id != s.id])
            db.add(
                TechniqueExecution(
                    user_id=s.id,
                    mission_id=rng.choice(legacy_missions).id,
                    opponent_id=opponent.id,
                    usage_type="after_training",
                    status="pending_confirmation",
                )
            )

        student_total_points[s.id] = total

    await db.flush()

    # 10) Níveis (reward_level) coerentes com os pontos gerados ------------- #
    for s in students:
        level, level_points, _ = compute_level_from_total_points(student_total_points[s.id])
        s.reward_level = level
        s.reward_level_points = level_points
    await db.flush()

    # 11) Troféus automáticos + conquistas (alunos com troféus) ------------ #
    trophies: list[Trophy] = []
    trophy_specs = [
        ("Caçador de Costas", techniques[10], 15),  # Pegada nas Costas
        ("Mestre do Triângulo", techniques[2], 10),
        ("Rei da Raspagem", techniques[6], 12),
        ("Finalizador", techniques[0], 20),  # Mata-Leão
    ]
    for tname, tech, target in trophy_specs:
        tr = Trophy(
            academy_id=academy.id,
            technique_id=tech.id,
            name=tname,
            start_date=today.replace(day=1),
            end_date=today + timedelta(days=30),
            target_count=target,
            award_kind="trophy",
            min_reward_level_to_unlock=0,
            max_count_per_opponent=3,
        )
        db.add(tr)
        trophies.append(tr)
    await db.flush()

    # Conquistas: ~12 alunos ganham troféus com tiers variados
    tiers = ["gold", "silver", "bronze"]
    earners = students[:12]
    for i, s in enumerate(earners):
        # cada aluno conquista 1–2 troféus
        chosen = rng.sample(trophies, k=rng.randint(1, 2))
        for tr in chosen:
            db.add(
                UserTrophyEarned(
                    user_id=s.id,
                    trophy_id=tr.id,
                    tier=tiers[i % 3],
                    earned_at=now - timedelta(days=rng.randint(1, 20)),
                )
            )
    await db.flush()

    # 12) Medalhas manuais (templates, campeonato, concessões) ------------- #
    tpl_destaque = AcademyTrophyTemplate(
        academy_id=academy.id,
        name="Aluno Destaque do Mês",
        description="Reconhecimento ao aluno mais dedicado do mês.",
        icon="star",
        color="#FFD700",
        trophy_type="custom",
        created_by=main_prof.id,
    )
    tpl_disciplina = AcademyTrophyTemplate(
        academy_id=academy.id,
        name="Disciplina de Ferro",
        description="Presença impecável nos treinos.",
        icon="shield",
        color="#C0C0C0",
        trophy_type="custom",
        created_by=main_prof.id,
    )
    tpl_medalha = AcademyTrophyTemplate(
        academy_id=academy.id,
        name="Medalha de Campeonato",
        description="Medalha conquistada em campeonato externo.",
        icon="medal",
        color="#CD7F32",
        trophy_type="championship",
        created_by=main_prof.id,
    )
    db.add_all([tpl_destaque, tpl_disciplina, tpl_medalha])
    await db.flush()

    champ = AcademyChampionshipEvent(
        academy_id=academy.id,
        name="Copa Octogrip 2026",
        location="São Paulo - SP",
        event_date=today - timedelta(days=15),
        created_by=main_prof.id,
    )
    db.add(champ)
    await db.flush()

    # Concessões: alunos diferentes dos que pegaram troféu (para variar)
    medalists = students[12:20]
    for i, s in enumerate(medalists):
        if i % 2 == 0:
            # Medalha de campeonato
            db.add(
                AcademyTrophyAward(
                    template_id=tpl_medalha.id,
                    user_id=s.id,
                    awarded_by=main_prof.id,
                    championship_event_id=champ.id,
                    medal_type=["gold", "silver", "bronze", "participation"][i % 4],
                    note="Pódio na categoria adulto.",
                )
            )
        else:
            # Troféu manual (custom)
            tpl = rng.choice([tpl_destaque, tpl_disciplina])
            db.add(
                AcademyTrophyAward(
                    template_id=tpl.id,
                    user_id=s.id,
                    awarded_by=main_prof.id,
                    medal_type=rng.choice(["gold", "silver", "bronze"]),
                    note="Concedido pelo professor.",
                )
            )
    await db.flush()

    # 13) Metas coletivas --------------------------------------------------- #
    for tech, target in [(techniques[9], 100), (techniques[2], 50)]:
        db.add(
            CollectiveGoal(
                academy_id=academy.id,
                technique_id=tech.id,
                target_count=target,
                start_date=today - timedelta(days=today.weekday()),
                end_date=today - timedelta(days=today.weekday()) + timedelta(days=6),
            )
        )

    # 14) Parceiros --------------------------------------------------------- #
    partners_data = [
        ("Loja Tatame Forte", "Kimonos e acessórios.", "https://exemplo.com.br", True),
        ("Suplementos Pro", "Whey e creatina com desconto.", "https://exemplo.com.br", False),
        ("Fisio Esportiva", "Recuperação para atletas.", "https://exemplo.com.br", False),
    ]
    for pname, desc, url, highlight in partners_data:
        db.add(
            Partner(
                academy_id=academy.id,
                name=pname,
                description=desc,
                url=url,
                logo_url="https://placehold.co/120x120/png",
                button_label="Saiba mais",
                highlight_on_login=highlight,
            )
        )

    # 15) Vídeos de treinamento -------------------------------------------- #
    videos = [
        ("Aquecimento para o treino", "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
        ("Drills de passagem de guarda", "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
        ("Mobilidade de quadril", "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
    ]
    for order_index, (vtitle, vurl) in enumerate(videos):
        db.add(
            TrainingVideo(
                title=vtitle,
                youtube_url=vurl,
                points_per_day=10,
                is_active=True,
                order_index=order_index,
                academy_id=academy.id,
                created_by_id=main_prof.id,
            )
        )

    # 16) Marketplace ------------------------------------------------------- #
    items = [
        ("Kimono Octogrip A2", "Kimono trançado, branco, A2.", 35000, "5511999990001"),
        ("Faixa Roxa A3", "Faixa nova, lacrada.", 9000, "5511999990002"),
        ("Rashguard Manga Longa", "Rashguard preto, tamanho M.", 12000, "5511999990003"),
    ]
    for order_index, (ititle, idesc, price, phone) in enumerate(items):
        db.add(
            AcademyMarketplaceItem(
                academy_id=academy.id,
                title=ititle,
                description=idesc,
                price_cents=price,
                currency="BRL",
                image_url="https://placehold.co/400x400/png",
                whatsapp_phone=phone,
                sort_order=order_index,
                is_active=True,
                created_by_id=main_prof.id,
            )
        )
    await db.flush()

    # 17) Presença (sessões de chamada + registros) ------------------------ #
    for d in (1, 3):  # duas aulas recentes
        session = AttendanceSession(
            academy_id=academy.id,
            created_by_user_id=main_prof.id,
            status="closed",
            title=f"Treino {'Gi' if d == 1 else 'No-Gi'}",
            starts_at=now - timedelta(days=d, hours=2),
            ends_at=now - timedelta(days=d, hours=1),
            expires_at=now - timedelta(days=d, hours=1),
        )
        db.add(session)
        await db.flush()
        present = rng.sample(students, k=rng.randint(10, 16))
        for s in present:
            db.add(
                AttendanceRecord(
                    session_id=session.id,
                    user_id=s.id,
                    checked_in_at=session.starts_at + timedelta(minutes=rng.randint(0, 30)),
                    method="qr",
                    face_recognition=False,
                    added_manually=False,
                )
            )

    # 18) Notificações in-app ---------------------------------------------- #
    for s in students[:14]:
        db.add(
            Notification(
                user_id=s.id,
                type="level_up",
                title="Você subiu de nível! 🎉",
                body=f"Parabéns, {s.name.split()[0]}! Continue treinando para subir ainda mais.",
                read=rng.random() < 0.5,
            )
        )
        if rng.random() < 0.5:
            db.add(
                Notification(
                    user_id=s.id,
                    type="trophy_earned",
                    title="Novo troféu conquistado! 🏆",
                    body="Você desbloqueou um troféu da academia.",
                    read=False,
                )
            )

    await db.commit()

    # Resumo
    print("=" * 60)
    print(f"Academia demo criada: {DEMO_NAME}  (slug={DEMO_SLUG})")
    print(f"  academy_id .......... {academy.id}")
    print(f"  alunos .............. {len(students)}")
    print(f"  professores ......... {len(prof_users)} (+ gerente)")
    print(f"  técnicas/posições ... {len(techniques)}")
    print(f"  missões ............. {len(missions)}")
    print(f"  troféus automáticos . {len(trophies)} (com {len(earners)} alunos premiados)")
    print(f"  medalhas manuais .... {len(medalists)} alunos")
    print(f"  kits semanais ....... {len(kits)}")
    print(f"  senha de acesso ..... {DEMO_PASSWORD}")
    print(f"  login gerente ....... {manager.email}")
    print(f"  login professor ..... {main_prof.email}")
    print(f"  login aluno (ex.) ... {students[0].email}")
    print("=" * 60)


# --------------------------------------------------------------------------- #
async def main() -> int:
    parser = argparse.ArgumentParser(description="Seed da academia de demonstração Octogrip.")
    parser.add_argument(
        "--reset",
        action="store_true",
        help="Apaga a academia demo existente (e todos os dados ligados) e recria do zero.",
    )
    args = parser.parse_args()

    async with AsyncSessionLocal() as db:
        existing = (
            await db.execute(select(Academy).where(Academy.slug == DEMO_SLUG))
        ).scalar_one_or_none()

        if existing is not None:
            if not args.reset:
                print(
                    f"Academia demo '{DEMO_SLUG}' já existe (id={existing.id}). "
                    "Nada a fazer. Use --reset para apagar e recriar."
                )
                return 0
            print(f"--reset: apagando academia demo existente (id={existing.id})...")
            await wipe_demo(db, existing.id)
            print("Apagada. Recriando...")

        await seed(db)
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
