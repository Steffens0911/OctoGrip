# Documentação — JJB (App Baby)

Índice da documentação do projeto.

---

## Visão geral

| Documento | Descrição |
|-----------|-----------|
| [README.md](../README.md) | Início rápido, execução, endpoints resumidos |
| [FUNCIONALIDADES.md](../FUNCIONALIDADES.md) | Funcionalidades implementadas (backend + app) |
| [docs/BACKLOG.md](BACKLOG.md) | Roadmap e backlog técnico |

---

## API e backend

| Documento | Descrição |
|-----------|-----------|
| [docs/API.md](API.md) | Referência completa da API REST |
| [docs/ACADEMIAS.md](ACADEMIAS.md) | API de academias, 3 missões semanais, missão por academia |
| [docs/ARCHITECTURE.md](ARCHITECTURE.md) | Arquitetura do backend (routes, services, models) |
| [docs/MIGRATIONS.md](MIGRATIONS.md) | Migrações SQL do banco de dados |

---

## Frontend (Viewer)

| Documento | Descrição |
|-----------|-----------|
| [docs/VIEWER.md](VIEWER.md) | App Flutter: telas, modelos, serviços, navegação |
| [docs/ANDROID_APK_LOCAL.md](ANDROID_APK_LOCAL.md) | Configurações para APK no celular e teste local (IP, cleartext, firewall) |
| [viewer/README.md](../viewer/README.md) | Como rodar o viewer, URL da API |

---

## Fluxos principais

| Fluxo | Onde está documentado |
|-------|------------------------|
| 3 missões semanais | [ACADEMIAS.md](ACADEMIAS.md) — seção "Três missões semanais" |
| Conclusão de missão (antes/depois do treino) | [API.md](API.md) — POST /mission_complete; [VIEWER.md](VIEWER.md) — LessonViewScreen |
| Missão do dia por academia | [ACADEMIAS.md](ACADEMIAS.md) — seção "Missão do dia por academia" |
| Área do professor | [VIEWER.md](VIEWER.md) — Telas do professor; [FUNCIONALIDADES.md](../FUNCIONALIDADES.md) |
