"""Painel de administração — CRUDs: academias, usuários, lições, técnicas, posições, missões."""
from fastapi import APIRouter
from fastapi.responses import HTMLResponse

router = APIRouter()


@router.get("", response_class=HTMLResponse)
def admin_panel():
    """Página única do painel admin com todos os CRUDs."""
    return _ADMIN_HTML


_ADMIN_HTML = """<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Administração — AppBaby</title>
  <style>
    * { box-sizing: border-box; }
    body { font-family: system-ui, -apple-system, sans-serif; margin: 0; background: #f5f5f5; color: #333; }
    .layout { display: flex; min-height: 100vh; }
    .sidebar { width: 220px; background: #1a1a2e; color: #eee; padding: 20px 0; flex-shrink: 0; }
    .sidebar h2 { font-size: 0.9rem; padding: 0 20px 12px; margin: 0; color: #58CC02; border-bottom: 1px solid #333; }
    .sidebar a { display: block; padding: 10px 20px; color: #ccc; text-decoration: none; }
    .sidebar a:hover, .sidebar a.active { background: #252540; color: #58CC02; }
    .main { flex: 1; padding: 24px; overflow: auto; }
    .panel { display: none; }
    .panel.active { display: block; }
    .toolbar { display: flex; align-items: center; justify-content: space-between; margin-bottom: 16px; flex-wrap: wrap; gap: 12px; }
    .toolbar h1 { margin: 0; font-size: 1.35rem; }
    .btn { padding: 10px 18px; border: none; border-radius: 8px; cursor: pointer; font-size: 0.95rem; font-weight: 500; }
    .btn-primary { background: #58CC02; color: #fff; }
    .btn-primary:hover { background: #46A302; }
    .btn-secondary { background: #e0e0e0; color: #333; }
    .btn-danger { background: #e53935; color: #fff; }
    .btn-sm { padding: 6px 12px; font-size: 0.85rem; }
    table { width: 100%; border-collapse: collapse; background: #fff; border-radius: 8px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,0.08); }
    th, td { padding: 12px 16px; text-align: left; border-bottom: 1px solid #eee; }
    th { background: #f8f8f8; font-weight: 600; color: #555; }
    tr:hover { background: #fafafa; }
    .actions { white-space: nowrap; }
    .actions button { margin-right: 8px; }
    .form-card { background: #fff; padding: 24px; border-radius: 8px; margin-bottom: 24px; box-shadow: 0 1px 3px rgba(0,0,0,0.08); max-width: 560px; }
    .form-card h3 { margin: 0 0 16px; font-size: 1.1rem; }
    .form-row { margin-bottom: 14px; }
    .form-row label { display: block; margin-bottom: 4px; font-weight: 500; color: #555; font-size: 0.9rem; }
    .form-row input, .form-row select, .form-row textarea { width: 100%; padding: 10px; border: 1px solid #ddd; border-radius: 6px; font-size: 1rem; }
    .form-row textarea { min-height: 80px; resize: vertical; }
    .msg { margin-top: 12px; padding: 12px; border-radius: 8px; }
    .msg.ok { background: #e8f5e9; color: #2e7d32; }
    .msg.err { background: #ffebee; color: #c62828; }
    .hidden { display: none !important; }
  </style>
</head>
<body>
  <div class="layout">
    <nav class="sidebar">
      <h2>Administração</h2>
      <a href="#" data-panel="academies" class="active">Academias</a>
      <a href="#" data-panel="users">Usuários</a>
      <a href="#" data-panel="lessons">Lições</a>
      <a href="#" data-panel="techniques">Técnicas</a>
      <a href="#" data-panel="positions">Posições</a>
      <a href="#" data-panel="missions">Missões</a>
    </nav>
    <main class="main">
      <div id="panel-academies" class="panel active">
        <div class="toolbar"><h1>Academias</h1><button class="btn btn-primary" data-action="new-academy">Nova academia</button></div>
        <div id="form-academy" class="form-card hidden"><h3 id="form-academy-title">Nova academia</h3><form id="f-academy"><input type="hidden" name="id"><div class="form-row"><label>Nome</label><input name="name" required></div><div class="form-row"><label>Missão do dia (técnica)</label><select name="weekly_technique_id"><option value="">— Nenhuma —</option></select></div><button type="submit" class="btn btn-primary">Salvar</button></form><div id="msg-academy" class="msg hidden"></div></div>
        <table><thead><tr><th>Nome</th><th>Missão do dia</th><th>Ações</th></tr></thead><tbody id="tbl-academies"></tbody></table>
      </div>
      <div id="panel-users" class="panel">
        <div class="toolbar"><h1>Usuários</h1><button class="btn btn-primary" data-action="new-user">Novo usuário</button></div>
        <div id="form-user" class="form-card hidden"><h3 id="form-user-title">Novo usuário</h3><form id="f-user"><input type="hidden" name="id"><div class="form-row"><label>E-mail</label><input type="email" name="email" required></div><div class="form-row"><label>Nome</label><input name="name"></div><div class="form-row"><label>Academia</label><select name="academy_id"><option value="">— Nenhuma —</option></select></div><button type="submit" class="btn btn-primary">Salvar</button></form><div id="msg-user" class="msg hidden"></div></div>
        <table><thead><tr><th>E-mail</th><th>Nome</th><th>Academia</th><th>Ações</th></tr></thead><tbody id="tbl-users"></tbody></table>
      </div>
      <div id="panel-lessons" class="panel">
        <div class="toolbar"><h1>Lições</h1><button class="btn btn-primary" data-action="new-lesson">Nova lição</button></div>
        <div id="form-lesson" class="form-card hidden"><h3 id="form-lesson-title">Nova lição</h3><form id="f-lesson"><input type="hidden" name="id"><div class="form-row"><label>Técnica</label><select name="technique_id" required></select></div><div class="form-row"><label>Título</label><input name="title" required></div><div class="form-row"><label>Link do YouTube</label><input name="video_url" type="url" placeholder="https://www.youtube.com/..."></div><div class="form-row"><label>Conteúdo</label><textarea name="content"></textarea></div><div class="form-row"><label>Ordem</label><input name="order_index" type="number" value="0"></div><button type="submit" class="btn btn-primary">Salvar</button></form><div id="msg-lesson" class="msg hidden"></div></div>
        <table><thead><tr><th>Título</th><th>Técnica</th><th>Ordem</th><th>Ações</th></tr></thead><tbody id="tbl-lessons"></tbody></table>
      </div>
      <div id="panel-techniques" class="panel">
        <div class="toolbar"><h1>Técnicas</h1><button class="btn btn-primary" data-action="new-technique">Nova técnica</button></div>
        <div id="form-technique" class="form-card hidden"><h3 id="form-technique-title">Nova técnica</h3><form id="f-technique"><input type="hidden" name="id"><div class="form-row"><label>Nome</label><input name="name" required></div><div class="form-row"><label>Link do YouTube</label><input name="video_url" type="url" placeholder="https://www.youtube.com/..."></div><div class="form-row"><label>De posição</label><select name="from_position_id" required></select></div><div class="form-row"><label>Para posição</label><select name="to_position_id" required></select></div><div class="form-row"><label>Descrição</label><textarea name="description"></textarea></div><button type="submit" class="btn btn-primary">Salvar</button></form><div id="msg-technique" class="msg hidden"></div></div>
        <table><thead><tr><th>Nome</th><th>De → Para</th><th>Ações</th></tr></thead><tbody id="tbl-techniques"></tbody></table>
      </div>
      <div id="panel-positions" class="panel">
        <div class="toolbar"><h1>Posições</h1><button class="btn btn-primary" data-action="new-position">Nova posição</button></div>
        <div id="form-position" class="form-card hidden"><h3 id="form-position-title">Nova posição</h3><form id="f-position"><input type="hidden" name="id"><div class="form-row"><label>Nome</label><input name="name" required></div><div class="form-row"><label>Descrição</label><textarea name="description"></textarea></div><button type="submit" class="btn btn-primary">Salvar</button></form><div id="msg-position" class="msg hidden"></div></div>
        <table><thead><tr><th>Nome</th><th>Descrição</th><th>Ações</th></tr></thead><tbody id="tbl-positions"></tbody></table>
      </div>
      <div id="panel-missions" class="panel">
        <div class="toolbar"><h1>Missões</h1><button class="btn btn-primary" data-action="new-mission">Nova missão</button></div>
        <div id="form-mission" class="form-card hidden"><h3 id="form-mission-title">Nova missão</h3><form id="f-mission"><input type="hidden" name="id"><div class="form-row"><label>Técnica</label><select name="technique_id" required></select></div><div class="form-row"><label>Início</label><input name="start_date" type="date" required></div><div class="form-row"><label>Fim</label><input name="end_date" type="date" required></div><div class="form-row"><label>Nível</label><select name="level"><option value="beginner">Iniciante</option><option value="intermediate">Intermediário</option></select></div><div class="form-row"><label>Tema</label><input name="theme"></div><div class="form-row"><label>Academia</label><select name="academy_id"><option value="">Global</option></select></div><button type="submit" class="btn btn-primary">Salvar</button></form><div id="msg-mission" class="msg hidden"></div></div>
        <table><thead><tr><th>Técnica</th><th>Início</th><th>Fim</th><th>Nível</th><th>Tema</th><th>Ações</th></tr></thead><tbody id="tbl-missions"></tbody></table>
      </div>
    </main>
  </div>
  <script>
(function() {
  const API = '';
  function $(id) { return document.getElementById(id); }
  function sel(q) { return document.querySelector(q); }
  function all(q) { return document.querySelectorAll(q); }

  function showMsg(msgId, text, ok) { const el = $(msgId); el.textContent = text; el.className = 'msg ' + (ok ? 'ok' : 'err'); el.classList.remove('hidden'); }
  function hideMsg(msgId) { $(msgId).classList.add('hidden'); }

  async function get(path) { const r = await fetch(API + path); return r.ok ? r.json() : Promise.reject(await r.json().catch(() => ({}))); }
  async function post(path, body) { const r = await fetch(API + path, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }); const data = await r.json().catch(() => ({})); if (!r.ok) throw data; return data; }
  async function patch(path, body) { const r = await fetch(API + path, { method: 'PATCH', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }); const data = await r.json().catch(() => ({})); if (!r.ok) throw data; return data; }
  async function put(path, body) { const r = await fetch(API + path, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }); const data = await r.json().catch(() => ({})); if (!r.ok) throw data; return data; }
  async function del(path) { const r = await fetch(API + path, { method: 'DELETE' }); if (!r.ok) throw await r.json().catch(() => ({})); }

  all('.sidebar a[data-panel]').forEach(a => { a.addEventListener('click', e => { e.preventDefault(); all('.sidebar a').forEach(x => x.classList.remove('active')); a.classList.add('active'); all('.panel').forEach(p => p.classList.remove('active')); $('panel-' + a.dataset.panel).classList.add('active'); loadPanel(a.dataset.panel); }); });

  function loadPanel(name) {
    if (name === 'academies') loadAcademies();
    else if (name === 'users') loadUsers();
    else if (name === 'lessons') loadLessons();
    else if (name === 'techniques') loadTechniques();
    else if (name === 'positions') loadPositions();
    else if (name === 'missions') loadMissions();
  }

  async function loadAcademies() {
    const list = await get('/academies');
    const tbody = $('tbl-academies');
    tbody.innerHTML = list.map(a => '<tr><td>' + escapeHtml(a.name) + '</td><td>' + escapeHtml(a.weekly_technique_name || a.weekly_theme || '') + '</td><td class="actions"><button class="btn btn-secondary btn-sm" data-edit-academy="' + a.id + '">Editar</button><button class="btn btn-danger btn-sm" data-delete-academy="' + a.id + '">Excluir</button></td></tr>').join('');
    tbody.querySelectorAll('[data-edit-academy]').forEach(b => b.addEventListener('click', () => editAcademy(b.dataset.editAcademy)));
    tbody.querySelectorAll('[data-delete-academy]').forEach(b => b.addEventListener('click', () => deleteAcademy(b.dataset.deleteAcademy)));
  }
  async function showAcademyForm(editId) {
    const form = $('form-academy'); form.classList.remove('hidden'); $('form-academy-title').textContent = editId ? 'Editar academia' : 'Nova academia';
    const techniques = await get('/techniques');
    const selTc = $('f-academy').querySelector('select[name="weekly_technique_id"]');
    selTc.innerHTML = '<option value="">— Nenhuma —</option>' + techniques.map(t => '<option value="' + t.id + '">' + escapeHtml(t.name) + '</option>').join('');
    sel('#f-academy input[name="id"]').value = editId || ''; sel('#f-academy input[name="name"]').value = ''; selTc.value = '';
    if (editId) get('/academies/' + editId).then(a => { sel('#f-academy input[name="name"]').value = a.name; selTc.value = a.weekly_technique_id || ''; }).catch(() => {});
  }
  document.querySelector('[data-action="new-academy"]').addEventListener('click', () => showAcademyForm(null));
  document.getElementById('f-academy').addEventListener('submit', async e => { e.preventDefault(); const fd = new FormData(e.target); const id = fd.get('id'); hideMsg('msg-academy'); try { if (id) { await patch('/academies/' + id, { name: fd.get('name'), weekly_technique_id: fd.get('weekly_technique_id') || null }); showMsg('msg-academy', 'Academia atualizada. Missão do dia definida.', true); } else { await post('/academies', { name: fd.get('name') }); showMsg('msg-academy', 'Academia criada.', true); $('form-academy').classList.add('hidden'); loadAcademies(); } } catch (err) { showMsg('msg-academy', err.detail || err.message || 'Erro', false); } });
  async function editAcademy(id) { showAcademyForm(id); }
  async function deleteAcademy(id) { if (!confirm('Excluir esta academia?')) return; try { await del('/academies/' + id); $('form-academy').classList.add('hidden'); loadAcademies(); } catch (e) { alert(e.detail || 'Erro'); } }

  async function loadUsers() {
    const [list, academies] = await Promise.all([get('/users'), get('/academies')]);
    const selAc = $('f-user').querySelector('select[name="academy_id"]');
    selAc.innerHTML = '<option value="">— Nenhuma —</option>' + academies.map(a => '<option value="' + a.id + '">' + escapeHtml(a.name) + '</option>').join('');
    const tbody = $('tbl-users');
    tbody.innerHTML = list.map(u => '<tr><td>' + escapeHtml(u.email) + '</td><td>' + escapeHtml(u.name || '') + '</td><td>' + (u.academy_id ? '—' : '—') + '</td><td class="actions"><button class="btn btn-secondary btn-sm" data-edit-user="' + u.id + '">Editar</button><button class="btn btn-danger btn-sm" data-delete-user="' + u.id + '">Excluir</button></td></tr>').join('');
    list.forEach((u, i) => { const row = tbody.rows[i]; const ac = academies.find(a => a.id === u.academy_id); row.cells[2].textContent = ac ? ac.name : '—'; });
    tbody.querySelectorAll('[data-edit-user]').forEach(b => b.addEventListener('click', () => editUser(b.dataset.editUser)));
    tbody.querySelectorAll('[data-delete-user]').forEach(b => b.addEventListener('click', () => deleteUser(b.dataset.deleteUser)));
  }
  function showUserForm(editId) {
    const form = $('form-user'); form.classList.remove('hidden'); $('form-user-title').textContent = editId ? 'Editar usuário' : 'Novo usuário';
    sel('#f-user input[name="id"]').value = editId || ''; sel('#f-user input[name="email"]').value = ''; sel('#f-user input[name="name"]').value = ''; sel('#f-user input[name="email"]').disabled = !!editId;
    if (editId) get('/users/' + editId).then(u => { sel('#f-user input[name="email"]').value = u.email; sel('#f-user input[name="name"]').value = u.name || ''; sel('#f-user select[name="academy_id"]').value = u.academy_id || ''; }).catch(() => {});
  }
  document.querySelector('[data-action="new-user"]').addEventListener('click', () => showUserForm(null));
  document.getElementById('f-user').addEventListener('submit', async e => { e.preventDefault(); const fd = new FormData(e.target); const id = fd.get('id'); hideMsg('msg-user'); try { if (id) { await patch('/users/' + id, { name: fd.get('name') || null, academy_id: fd.get('academy_id') || null }); showMsg('msg-user', 'Usuário atualizado.', true); } else { await post('/users', { email: fd.get('email'), name: fd.get('name') || null, academy_id: fd.get('academy_id') || null }); showMsg('msg-user', 'Usuário criado.', true); $('form-user').classList.add('hidden'); loadUsers(); } } catch (err) { showMsg('msg-user', (Array.isArray(err.detail) ? err.detail.map(x => x.msg).join(' ') : err.detail) || err.message || 'Erro', false); } });
  async function editUser(id) { showUserForm(id); }
  async function deleteUser(id) { if (!confirm('Excluir este usuário?')) return; try { await del('/users/' + id); $('form-user').classList.add('hidden'); loadUsers(); } catch (e) { alert(e.detail || 'Erro'); } }

  async function loadLessons() {
    const [list, techniques, positions] = await Promise.all([get('/lessons'), get('/techniques'), get('/positions')]);
    const selTc = $('f-lesson').querySelector('select[name="technique_id"]'); selTc.innerHTML = techniques.map(t => '<option value="' + t.id + '">' + escapeHtml(t.name) + '</option>').join('');
    const tbody = $('tbl-lessons');
    const techDisplay = (t, l) => { if (l.technique_name && l.position_name) return escapeHtml(l.technique_name) + ' ' + escapeHtml(l.position_name); if (!t) return ''; const fromP = positions.find(x => x.id === t.from_position_id); const toP = positions.find(x => x.id === t.to_position_id); const fromN = fromP ? fromP.name : ''; const toN = toP ? toP.name : ''; const posStr = fromN && toN ? ' da posição ' + fromN + ' → para posição ' + toN : ''; return escapeHtml(t.name) + posStr; };
    tbody.innerHTML = list.map(l => { const t = techniques.find(x => x.id === l.technique_id); return '<tr><td>' + escapeHtml(l.title) + '</td><td>' + techDisplay(t, l) + '</td><td>' + l.order_index + '</td><td class="actions"><button class="btn btn-secondary btn-sm" data-edit-lesson="' + l.id + '">Editar</button><button class="btn btn-danger btn-sm" data-delete-lesson="' + l.id + '">Excluir</button></td></tr>'; }).join('');
    tbody.querySelectorAll('[data-edit-lesson]').forEach(b => b.addEventListener('click', () => editLesson(b.dataset.editLesson)));
    tbody.querySelectorAll('[data-delete-lesson]').forEach(b => b.addEventListener('click', () => deleteLesson(b.dataset.deleteLesson)));
  }
  function showLessonForm(editId) {
    const form = $('form-lesson'); form.classList.remove('hidden'); $('form-lesson-title').textContent = editId ? 'Editar lição' : 'Nova lição';
    sel('#f-lesson input[name="id"]').value = editId || ''; sel('#f-lesson input[name="title"]').value = ''; sel('#f-lesson input[name="video_url"]').value = ''; sel('#f-lesson textarea[name="content"]').value = ''; sel('#f-lesson input[name="order_index"]').value = '0';
    if (editId) get('/lessons/' + editId).then(l => { sel('#f-lesson select[name="technique_id"]').value = l.technique_id; sel('#f-lesson input[name="title"]').value = l.title; sel('#f-lesson input[name="video_url"]').value = l.video_url || ''; sel('#f-lesson textarea[name="content"]').value = l.content || ''; sel('#f-lesson input[name="order_index"]').value = l.order_index; }).catch(() => {});
  }
  document.querySelector('[data-action="new-lesson"]').addEventListener('click', () => showLessonForm(null));
  document.getElementById('f-lesson').addEventListener('submit', async e => { e.preventDefault(); const fd = new FormData(e.target); const id = fd.get('id'); hideMsg('msg-lesson'); const body = { technique_id: fd.get('technique_id'), title: fd.get('title'), video_url: fd.get('video_url') || null, content: fd.get('content') || null, order_index: parseInt(fd.get('order_index'), 10) }; try { if (id) { await put('/lessons/' + id, body); showMsg('msg-lesson', 'Lição atualizada.', true); } else { await post('/lessons', body); showMsg('msg-lesson', 'Lição criada.', true); $('form-lesson').classList.add('hidden'); loadLessons(); } } catch (err) { showMsg('msg-lesson', (Array.isArray(err.detail) ? err.detail.map(x => x.msg).join(' ') : err.detail) || err.message || 'Erro', false); } });
  async function editLesson(id) { showLessonForm(id); }
  async function deleteLesson(id) { if (!confirm('Excluir esta lição?')) return; try { await del('/lessons/' + id); $('form-lesson').classList.add('hidden'); loadLessons(); } catch (e) { alert(e.detail || 'Erro'); } }

  async function loadTechniques() {
    const [list, positions] = await Promise.all([get('/techniques'), get('/positions')]);
    const fromSel = $('f-technique').querySelector('select[name="from_position_id"]'); const toSel = $('f-technique').querySelector('select[name="to_position_id"]');
    const opts = positions.map(p => '<option value="' + p.id + '">' + escapeHtml(p.name) + '</option>').join(''); fromSel.innerHTML = '<option value="">—</option>' + opts; toSel.innerHTML = '<option value="">—</option>' + opts;
    const tbody = $('tbl-techniques');
    tbody.innerHTML = list.map(t => { const fromP = positions.find(x => x.id === t.from_position_id); const toP = positions.find(x => x.id === t.to_position_id); const fromN = fromP ? fromP.name : ''; const toN = toP ? toP.name : ''; const posStr = fromN && toN ? 'da posição ' + fromN + ' → para posição ' + toN : fromN + ' → ' + toN; return '<tr><td>' + escapeHtml(t.name) + '</td><td>' + posStr + '</td><td class="actions"><button class="btn btn-secondary btn-sm" data-edit-technique="' + t.id + '">Editar</button><button class="btn btn-danger btn-sm" data-delete-technique="' + t.id + '">Excluir</button></td></tr>'; }).join('');
    tbody.querySelectorAll('[data-edit-technique]').forEach(b => b.addEventListener('click', () => editTechnique(b.dataset.editTechnique)));
    tbody.querySelectorAll('[data-delete-technique]').forEach(b => b.addEventListener('click', () => deleteTechnique(b.dataset.deleteTechnique)));
  }
  function showTechniqueForm(editId) {
    const form = $('form-technique'); form.classList.remove('hidden'); $('form-technique-title').textContent = editId ? 'Editar técnica' : 'Nova técnica';
    sel('#f-technique input[name="id"]').value = editId || ''; sel('#f-technique input[name="name"]').value = ''; sel('#f-technique input[name="video_url"]').value = ''; sel('#f-technique textarea[name="description"]').value = '';
    if (editId) get('/techniques/' + editId).then(t => { sel('#f-technique input[name="name"]').value = t.name; sel('#f-technique input[name="video_url"]').value = t.video_url || ''; sel('#f-technique textarea[name="description"]').value = t.description || ''; sel('#f-technique select[name="from_position_id"]').value = t.from_position_id; sel('#f-technique select[name="to_position_id"]').value = t.to_position_id; }).catch(() => {});
  }
  document.querySelector('[data-action="new-technique"]').addEventListener('click', () => showTechniqueForm(null));
  document.getElementById('f-technique').addEventListener('submit', async e => { e.preventDefault(); const fd = new FormData(e.target); const id = fd.get('id'); hideMsg('msg-technique'); const body = { name: fd.get('name'), video_url: fd.get('video_url') || null, description: fd.get('description') || null, from_position_id: fd.get('from_position_id'), to_position_id: fd.get('to_position_id') }; try { if (id) { await put('/techniques/' + id, body); showMsg('msg-technique', 'Técnica atualizada.', true); } else { await post('/techniques', body); showMsg('msg-technique', 'Técnica criada.', true); $('form-technique').classList.add('hidden'); loadTechniques(); } } catch (err) { showMsg('msg-technique', (Array.isArray(err.detail) ? err.detail.map(x => x.msg).join(' ') : err.detail) || err.message || 'Erro', false); } });
  async function editTechnique(id) { showTechniqueForm(id); }
  async function deleteTechnique(id) { if (!confirm('Excluir esta técnica?')) return; try { await del('/techniques/' + id); $('form-technique').classList.add('hidden'); loadTechniques(); } catch (e) { alert(e.detail || 'Erro'); } }

  async function loadPositions() {
    const list = await get('/positions');
    const tbody = $('tbl-positions');
    tbody.innerHTML = list.map(p => '<tr><td>' + escapeHtml(p.name) + '</td><td>' + escapeHtml((p.description || '').slice(0, 60)) + (p.description && p.description.length > 60 ? '…' : '') + '</td><td class="actions"><button class="btn btn-secondary btn-sm" data-edit-position="' + p.id + '">Editar</button><button class="btn btn-danger btn-sm" data-delete-position="' + p.id + '">Excluir</button></td></tr>').join('');
    tbody.querySelectorAll('[data-edit-position]').forEach(b => b.addEventListener('click', () => editPosition(b.dataset.editPosition)));
    tbody.querySelectorAll('[data-delete-position]').forEach(b => b.addEventListener('click', () => deletePosition(b.dataset.deletePosition)));
  }
  function showPositionForm(editId) {
    const form = $('form-position'); form.classList.remove('hidden'); $('form-position-title').textContent = editId ? 'Editar posição' : 'Nova posição';
    sel('#f-position input[name="id"]').value = editId || ''; sel('#f-position input[name="name"]').value = ''; sel('#f-position textarea[name="description"]').value = '';
    if (editId) get('/positions/' + editId).then(p => { sel('#f-position input[name="name"]').value = p.name; sel('#f-position textarea[name="description"]').value = p.description || ''; }).catch(() => {});
  }
  document.querySelector('[data-action="new-position"]').addEventListener('click', () => showPositionForm(null));
  document.getElementById('f-position').addEventListener('submit', async e => { e.preventDefault(); const fd = new FormData(e.target); const id = fd.get('id'); hideMsg('msg-position'); const body = { name: fd.get('name'), description: fd.get('description') || null }; try { if (id) { await put('/positions/' + id, body); showMsg('msg-position', 'Posição atualizada.', true); } else { await post('/positions', body); showMsg('msg-position', 'Posição criada.', true); $('form-position').classList.add('hidden'); loadPositions(); } } catch (err) { showMsg('msg-position', (Array.isArray(err.detail) ? err.detail.map(x => x.msg).join(' ') : err.detail) || err.message || 'Erro', false); } });
  async function editPosition(id) { showPositionForm(id); }
  async function deletePosition(id) { if (!confirm('Excluir esta posição?')) return; try { await del('/positions/' + id); $('form-position').classList.add('hidden'); loadPositions(); } catch (e) { alert(e.detail || 'Erro'); } }

  async function loadMissions() {
    const [list, techniques, academies, positions] = await Promise.all([get('/missions'), get('/techniques'), get('/academies'), get('/positions')]);
    const selTc = $('f-mission').querySelector('select[name="technique_id"]'); selTc.innerHTML = techniques.map(t => '<option value="' + t.id + '">' + escapeHtml(t.name) + '</option>').join('');
    const selAc = $('f-mission').querySelector('select[name="academy_id"]'); selAc.innerHTML = '<option value="">Global</option>' + academies.map(a => '<option value="' + a.id + '">' + escapeHtml(a.name) + '</option>').join('');
    const tbody = $('tbl-missions');
    const techDisplay = (t) => { if (!t) return ''; const fromP = positions.find(x => x.id === t.from_position_id); const toP = positions.find(x => x.id === t.to_position_id); const fromN = fromP ? fromP.name : ''; const toN = toP ? toP.name : ''; const posStr = fromN && toN ? ' da posição ' + fromN + ' → para posição ' + toN : ''; return escapeHtml(t.name) + posStr; };
    tbody.innerHTML = list.map(m => { const t = techniques.find(x => x.id === m.technique_id); return '<tr><td>' + (t ? techDisplay(t) : (m.technique_id || '')) + '</td><td>' + m.start_date + '</td><td>' + m.end_date + '</td><td>' + m.level + '</td><td>' + escapeHtml(m.theme || '') + '</td><td class="actions"><button class="btn btn-secondary btn-sm" data-edit-mission="' + m.id + '">Editar</button><button class="btn btn-danger btn-sm" data-delete-mission="' + m.id + '">Excluir</button></td></tr>'; }).join('');
    tbody.querySelectorAll('[data-edit-mission]').forEach(b => b.addEventListener('click', () => editMission(b.dataset.editMission)));
    tbody.querySelectorAll('[data-delete-mission]').forEach(b => b.addEventListener('click', () => deleteMission(b.dataset.deleteMission)));
  }
  function showMissionForm(editId) {
    const form = $('form-mission'); form.classList.remove('hidden'); $('form-mission-title').textContent = editId ? 'Editar missão' : 'Nova missão';
    sel('#f-mission input[name="id"]').value = editId || ''; const today = new Date().toISOString().slice(0, 10); const end = new Date(); end.setDate(end.getDate() + 6); sel('#f-mission input[name="start_date"]').value = today; sel('#f-mission input[name="end_date"]').value = end.toISOString().slice(0, 10); sel('#f-mission input[name="theme"]').value = ''; sel('#f-mission select[name="academy_id"]').value = '';
    if (editId) get('/missions/' + editId).then(m => { sel('#f-mission select[name="technique_id"]').value = m.technique_id || ''; sel('#f-mission input[name="start_date"]').value = m.start_date; sel('#f-mission input[name="end_date"]').value = m.end_date; sel('#f-mission select[name="level"]').value = m.level; sel('#f-mission input[name="theme"]').value = m.theme || ''; sel('#f-mission select[name="academy_id"]').value = m.academy_id || ''; }).catch(() => {});
  }
  document.querySelector('[data-action="new-mission"]').addEventListener('click', () => showMissionForm(null));
  document.getElementById('f-mission').addEventListener('submit', async e => { e.preventDefault(); const fd = new FormData(e.target); const id = fd.get('id'); hideMsg('msg-mission'); const body = { technique_id: fd.get('technique_id'), start_date: fd.get('start_date'), end_date: fd.get('end_date'), level: fd.get('level'), theme: fd.get('theme') || null, academy_id: fd.get('academy_id') || null }; try { if (id) { await patch('/missions/' + id, body); showMsg('msg-mission', 'Missão atualizada.', true); } else { await post('/missions', body); showMsg('msg-mission', 'Missão criada.', true); $('form-mission').classList.add('hidden'); loadMissions(); } } catch (err) { showMsg('msg-mission', (Array.isArray(err.detail) ? err.detail.map(x => x.msg).join(' ') : err.detail) || err.message || 'Erro', false); } });
  async function editMission(id) { showMissionForm(id); }
  async function deleteMission(id) { if (!confirm('Excluir esta missão?')) return; try { await del('/missions/' + id); $('form-mission').classList.add('hidden'); loadMissions(); } catch (e) { alert(e.detail || 'Erro'); } }

  function escapeHtml(s) { if (s == null) return ''; const div = document.createElement('div'); div.textContent = s; return div.innerHTML; }

  loadAcademies();
})();
  </script>
</body>
</html>
"""
