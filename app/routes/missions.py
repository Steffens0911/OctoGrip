"""CRUD de missões para painel do professor (T-01)."""
from uuid import UUID

from fastapi import APIRouter, Depends
from fastapi.responses import HTMLResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ForbiddenError, MissionNotFoundError
from app.core.role_deps import require_admin_or_academy_access, require_read_access, require_write_access, verify_academy_access
from app.database import get_db
from app.models import User
from app.schemas.mission import MissionCreate, MissionRead, MissionUpdate
from app.services.mission_crud_service import (
    create_mission,
    delete_mission,
    get_mission,
    list_missions,
    update_mission,
)

router = APIRouter()


@router.get("", response_model=list[MissionRead])
async def missions_list(
    academy_id: UUID | None = None,
    limit: int = 100,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_read_access),
):
    """Lista missões (opcionalmente por academia)."""
    if current_user.role != "administrador" and academy_id:
        verify_academy_access(current_user, str(academy_id))
    elif current_user.role != "administrador":
        academy_id = current_user.academy_id
    return await list_missions(db, academy_id=academy_id, limit=limit)


@router.get("/panel", response_class=HTMLResponse)
async def missions_panel(current_user: User = Depends(require_write_access)):
    """T-01: Painel simples web para criar missão em 10s."""
    from app.core.security import generate_csrf_token

    csrf_token = generate_csrf_token(current_user.id)
    return _PANEL_HTML.replace("CSRF_TOKEN_PLACEHOLDER", csrf_token)


@router.get("/{mission_id}", response_model=MissionRead)
async def missions_get(
    mission_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_read_access),
):
    """Retorna uma missão por ID."""
    mission = await get_mission(db, mission_id)
    if not mission:
        raise MissionNotFoundError()
    if current_user.role != "administrador" and mission.academy_id:
        verify_academy_access(current_user, str(mission.academy_id))
    return mission


@router.post("", response_model=MissionRead, status_code=201)
async def missions_create(
    body: MissionCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    """T-01: Cria uma missão."""
    academy_id = body.academy_id
    if current_user.role != "administrador":
        if current_user.academy_id is None:
            raise ForbiddenError("Você precisa estar vinculado a uma academia para criar missões.")
        academy_id = current_user.academy_id
    elif academy_id:
        verify_academy_access(current_user, str(academy_id))
    mission = await create_mission(
        db,
        technique_id=body.technique_id,
        start_date=body.start_date,
        end_date=body.end_date,
        level=body.level,
        theme=body.theme,
        academy_id=academy_id,
        lesson_id=body.lesson_id,
        multiplier=body.multiplier,
    )
    return mission


@router.patch("/{mission_id}", response_model=MissionRead)
async def missions_update(
    mission_id: UUID,
    body: MissionUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    """Atualiza uma missão."""
    mission = await get_mission(db, mission_id)
    if not mission:
        raise MissionNotFoundError()
    if current_user.role != "administrador" and mission.academy_id:
        verify_academy_access(current_user, str(mission.academy_id))
    payload = body.model_dump(exclude_unset=True)
    academy_id = payload.pop("academy_id", None)
    set_academy_none = "academy_id" in body.model_dump(exclude_unset=True) and body.academy_id is None
    if current_user.role != "administrador":
        academy_id = None
        set_academy_none = False
    elif academy_id:
        verify_academy_access(current_user, str(academy_id))
    mission = await update_mission(
        db,
        mission_id,
        _set_academy_id_none=set_academy_none,
        academy_id=academy_id if not set_academy_none else None,
        **payload,
    )
    if not mission:
        raise MissionNotFoundError()
    return mission


@router.delete("/{mission_id}", status_code=204)
async def missions_delete(
    mission_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    """Remove uma missão."""
    if not await delete_mission(db, mission_id):
        raise MissionNotFoundError()
    return None


_PANEL_HTML = """<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Professor — Criar missão</title>
  <style>
    * { box-sizing: border-box; }
    body { font-family: system-ui, sans-serif; max-width: 480px; margin: 24px auto; padding: 0 16px; }
    h1 { font-size: 1.25rem; color: #333; }
    label { display: block; margin-top: 12px; font-weight: 500; color: #555; }
    input, select, button { width: 100%; padding: 10px; margin-top: 4px; font-size: 1rem; }
    button { background: #58CC02; color: #fff; border: none; border-radius: 8px; cursor: pointer; margin-top: 20px; }
    button:hover { background: #46A302; }
    .msg { margin-top: 16px; padding: 12px; border-radius: 8px; }
    .ok { background: #e8f5e9; color: #2e7d32; }
    .err { background: #ffebee; color: #c62828; }
  </style>
</head>
<body>
  <h1>Criar missão (10s)</h1>
  <form id="f">
    <label>Técnica</label>
    <select name="technique_id" required><option value="">Carregando...</option></select>
    <label>Início</label>
    <input type="date" name="start_date" required>
    <label>Fim</label>
    <input type="date" name="end_date" required>
    <label>Nível</label>
    <select name="level">
      <option value="beginner">Iniciante</option>
      <option value="intermediate">Intermediário</option>
    </select>
    <label>Tema (opcional)</label>
    <input type="text" name="theme" placeholder="Ex: Passagem de guarda" maxlength="128">
    <label>Academia (opcional)</label>
    <select name="academy_id"><option value="">Global</option></select>
    <button type="submit">Criar missão</button>
  </form>
  <div id="msg"></div>
  <script>
    const API = window.location.origin;
    let csrfToken = 'CSRF_TOKEN_PLACEHOLDER';
    const $ = (id) => document.getElementById(id);
    const sel = (q) => document.querySelector(q);

    function getHeaders() {
      const headers = { 'Content-Type': 'application/json' };
      if (csrfToken && csrfToken !== 'CSRF_TOKEN_PLACEHOLDER') {
        headers['X-CSRF-Token'] = csrfToken;
      }
      return headers;
    }

    function escapeHtml(s) {
      if (s == null) return '';
      const div = document.createElement('div');
      div.textContent = s;
      return div.innerHTML;
    }

    async function loadTechniques() {
      const r = await fetch(API + '/techniques');
      const techniques = await r.json();
      const select = sel('select[name="technique_id"]');
      select.innerHTML = techniques.map(t => '<option value="' + t.id + '">' + escapeHtml(t.name) + '</option>').join('');
    }
    async function loadAcademies() {
      const r = await fetch(API + '/academies');
      const list = await r.json();
      const select = sel('select[name="academy_id"]');
      select.innerHTML = '<option value="">Global</option>' + list.map(a => '<option value="' + a.id + '">' + escapeHtml(a.name) + '</option>').join('');
    }
    function setDefaultDates() {
      const today = new Date().toISOString().slice(0, 10);
      const end = new Date();
      end.setDate(end.getDate() + 6);
      sel('input[name="start_date"]').value = today;
      sel('input[name="end_date"]').value = end.toISOString().slice(0, 10);
    }

    loadTechniques().then(() => {}).catch(() => sel('select[name="technique_id"]').innerHTML = '<option value="">Erro ao carregar</option>');
    loadAcademies().then(() => {}).catch(() => {});
    setDefaultDates();

    sel('#f').onsubmit = async (e) => {
      e.preventDefault();
      const fd = new FormData(e.target);
      const body = {
        technique_id: fd.get('technique_id'),
        start_date: fd.get('start_date'),
        end_date: fd.get('end_date'),
        level: fd.get('level'),
        theme: fd.get('theme') || null,
        academy_id: fd.get('academy_id') || null
      };
      $('msg').className = '';
      $('msg').textContent = 'Criando...';
      try {
        const r = await fetch(API + '/missions', { method: 'POST', headers: getHeaders(), body: JSON.stringify(body) });
        const data = await r.json().catch(() => ({}));
        if (r.ok) {
          $('msg').className = 'msg ok';
          $('msg').textContent = 'Missão criada: ' + (data.id || 'OK');
        } else {
          $('msg').className = 'msg err';
          $('msg').textContent = data.detail || r.statusText || 'Erro';
        }
      } catch (err) {
        $('msg').className = 'msg err';
        $('msg').textContent = err.message || 'Erro de rede';
      }
    };
  </script>
</body>
</html>
"""
