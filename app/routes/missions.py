"""CRUD de missões para painel do professor (T-01)."""
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import HTMLResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.schemas.mission import MissionCreate, MissionRead, MissionUpdate
from app.services.mission_crud_service import create_mission, delete_mission, get_mission, list_missions, update_mission

router = APIRouter()


@router.get("", response_model=list[MissionRead])
async def missions_list(academy_id: UUID | None = None, limit: int = 100, db: AsyncSession = Depends(get_db)):
    return await list_missions(db, academy_id=academy_id, limit=limit)


@router.get("/panel", response_class=HTMLResponse)
def missions_panel():
    """T-01: Painel simples web para criar missão em 10s."""
    return _PANEL_HTML


@router.get("/{mission_id}", response_model=MissionRead)
async def missions_get(mission_id: UUID, db: AsyncSession = Depends(get_db)):
    mission = await get_mission(db, mission_id)
    if not mission:
        raise HTTPException(status_code=404, detail="Missão não encontrada.")
    return mission


@router.post("", response_model=MissionRead, status_code=201)
async def missions_create(body: MissionCreate, db: AsyncSession = Depends(get_db)):
    return await create_mission(
        db, technique_id=body.technique_id, start_date=body.start_date, end_date=body.end_date,
        level=body.level, theme=body.theme, academy_id=body.academy_id, lesson_id=body.lesson_id, multiplier=body.multiplier,
    )


@router.patch("/{mission_id}", response_model=MissionRead)
async def missions_update(mission_id: UUID, body: MissionUpdate, db: AsyncSession = Depends(get_db)):
    payload = body.model_dump(exclude_unset=True)
    academy_id = payload.pop("academy_id", None)
    set_academy_none = "academy_id" in body.model_dump(exclude_unset=True) and body.academy_id is None
    mission = await update_mission(
        db, mission_id, _set_academy_id_none=set_academy_none,
        academy_id=academy_id if not set_academy_none else None, **payload,
    )
    if not mission:
        raise HTTPException(status_code=404, detail="Missão não encontrada.")
    return mission


@router.delete("/{mission_id}", status_code=204)
async def missions_delete(mission_id: UUID, db: AsyncSession = Depends(get_db)):
    if not await delete_mission(db, mission_id):
        raise HTTPException(status_code=404, detail="Missão não encontrada.")
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
    <select name="level"><option value="beginner">Iniciante</option><option value="intermediate">Intermediário</option></select>
    <label>Tema (opcional)</label>
    <input type="text" name="theme" placeholder="Ex: Passagem de guarda" maxlength="128">
    <label>Academia (opcional)</label>
    <select name="academy_id"><option value="">Global</option></select>
    <button type="submit">Criar missão</button>
  </form>
  <div id="msg"></div>
  <script>
    const API = window.location.origin;
    const $ = (id) => document.getElementById(id);
    const sel = (q) => document.querySelector(q);
    async function loadTechniques() { const r = await fetch(API + '/techniques'); const t = await r.json(); sel('select[name="technique_id"]').innerHTML = t.map(x => '<option value="' + x.id + '">' + x.name + '</option>').join(''); }
    async function loadAcademies() { const r = await fetch(API + '/academies'); const l = await r.json(); sel('select[name="academy_id"]').innerHTML = '<option value="">Global</option>' + l.map(a => '<option value="' + a.id + '">' + a.name + '</option>').join(''); }
    function setDefaultDates() { const today = new Date().toISOString().slice(0, 10); const end = new Date(); end.setDate(end.getDate() + 6); sel('input[name="start_date"]').value = today; sel('input[name="end_date"]').value = end.toISOString().slice(0, 10); }
    loadTechniques().catch(() => sel('select[name="technique_id"]').innerHTML = '<option value="">Erro</option>');
    loadAcademies().catch(() => {});
    setDefaultDates();
    sel('#f').onsubmit = async (e) => { e.preventDefault(); const fd = new FormData(e.target); const body = { technique_id: fd.get('technique_id'), start_date: fd.get('start_date'), end_date: fd.get('end_date'), level: fd.get('level'), theme: fd.get('theme') || null, academy_id: fd.get('academy_id') || null }; $('msg').className = ''; $('msg').textContent = 'Criando...'; try { const r = await fetch(API + '/missions', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }); const data = await r.json().catch(() => ({})); if (r.ok) { $('msg').className = 'msg ok'; $('msg').textContent = 'Missão criada: ' + (data.id || 'OK'); } else { $('msg').className = 'msg err'; $('msg').textContent = data.detail || r.statusText || 'Erro'; } } catch (err) { $('msg').className = 'msg err'; $('msg').textContent = err.message || 'Erro de rede'; } };
  </script>
</body>
</html>
"""
