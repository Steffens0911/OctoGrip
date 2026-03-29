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
| [docs/TROPHY_SHELF.md](TROPHY_SHELF.md) | Estante de troféus gamificada: arquitetura, widgets, API, layout, acessibilidade |
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

---

## Análise e Qualidade

| Documento | Descrição |
|-----------|-----------|
| [AVALIACAO_ENTERPRISE.md](AVALIACAO_ENTERPRISE.md) | Avaliação segundo padrões enterprise: Segurança, Escalabilidade, Manutenibilidade, Performance, Clareza (0–10) |
| [ANALISE_COMPLETA_PROJETO.md](ANALISE_COMPLETA_PROJETO.md) | Análise detalhada: problemas críticos, médios, melhorias e pontos positivos |
| [CHECKLIST_MELHORIAS_APPBABY.md](CHECKLIST_MELHORIAS_APPBABY.md) | Checklist operacional de melhorias por prioridade, com status, responsável, prazo e evidência |
| [AVALIACAO_GAMIFICACAO_APPBABY.md](AVALIACAO_GAMIFICACAO_APPBABY.md) | Avaliação da gamificação do app com base em loops, validações e riscos éticos |
| [RESUMO_EXECUTIVO.md](RESUMO_EXECUTIVO.md) | Resumo visual rápido do status do projeto (score 8.0/10) |
| [CHECKLIST_DEPLOY.md](CHECKLIST_DEPLOY.md) | Checklist prático para usar antes do deploy em produção |
| [BOAS_PRATICAS.md](BOAS_PRATICAS.md) | Análise de padrões do framework, tipagem e linter/formatter |
| [FORMATACAO.md](FORMATACAO.md) | Guia de uso do Ruff para formatação e lint |
| [SECURITY.md](SECURITY.md) | Políticas de segurança e práticas recomendadas |

## Segurança Ofensiva

| Documento | Descrição |
|-----------|-----------|
| [AUDITORIA_SEGURANCA_OFENSIVA.md](AUDITORIA_SEGURANCA_OFENSIVA.md) | Auditoria completa simulando ataque: vulnerabilidades encontradas, vetores de ataque testados |
| [RESUMO_AUDITORIA_OFENSIVA.md](RESUMO_AUDITORIA_OFENSIVA.md) | Resumo executivo da auditoria ofensiva (score 7.5/10) |
| [CORRECOES_SEGURANCA_OFENSIVA.md](CORRECOES_SEGURANCA_OFENSIVA.md) | Guia prático com código para corrigir vulnerabilidades encontradas |
