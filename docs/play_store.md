# Play Store — ficha, Data safety e classificação

Material pronto para colar na Play Console ao criar o app **OctoGrip** (`br.com.octogrip.app`).
App criado em 2026-10-23: conta de desenvolvedor `6569729074761733260`, app `4972069362261756446`.
Imagens prontas para upload em `docs/play_store_assets/` (ícone 512×512 e destaque 1024×500).
Baseado no código e em `docs/legal/` em 2026-10-22. Itens marcados com **DECIDIR** dependem de você.

## Antes de enviar (pendências que a revisão da Google pode pegar)

- [ ] **Política de Privacidade, seção 9 (Menores de idade)** ainda tem o texto provisório
      «Preencher conforme a realidade da academia.», visível em produção. Precisa do texto definitivo.
- [ ] **Política de Privacidade não cita** as fotos e comentários do feed da academia (OctoPhotos) nem o
      Sentry (relatórios de falha do app). O formulário Data safety abaixo declara os dois; a política
      precisa dizer o mesmo. Recomendado passar pela revisão jurídica já pendente.
- [x] Exclusão de conta apaga também fotos, comentários e curtidas do feed (com os arquivos de imagem).
- [ ] Publicar a API com a página `/legal/account-deletion/view` (vai no próximo deploy do `main`).

## Links pedidos pela Play Console

| Campo | Valor |
| --- | --- |
| Política de Privacidade | `https://api.octogrip.com.br/legal/privacy/view` |
| Exclusão de conta (Data safety) | `https://api.octogrip.com.br/legal/account-deletion/view` |
| E-mail de contato | `privacidade@octogrip.com.br` (ou o de suporte que preferir) |
| Site | `https://octogrip.com.br` |

## Ficha da loja

**Nome do app** (até 30 caracteres)

```
OctoGrip
```

**Descrição curta** (até 80 caracteres)

```
Missões, técnicas e presença da sua academia de jiu-jitsu, tudo num só app.
```

**Descrição completa** (até 4000 caracteres)

```
O OctoGrip é o app da sua academia de jiu-jitsu. Ele organiza o que treinar na semana, registra
sua presença e mostra a sua evolução no tatame.

PARA O ALUNO
• Missões da semana: o professor escolhe as técnicas da turma e você acompanha o que já praticou.
• Biblioteca de técnicas com vídeos, para revisar antes e depois do treino.
• Vídeo do dia com uma técnica para estudar.
• Pontos, níveis e sequência de treinos para acompanhar a sua constância.
• Estante de troféus com as conquistas da academia e dos campeonatos.
• Presença por QR Code ou por reconhecimento facial (opcional) na entrada do treino.
• Confirmação de presença antes da aula.
• Feed de fotos da academia, com curtidas e comentários.
• Avisos da academia e lembretes por notificação.

PARA O PROFESSOR E O GESTOR
• Montagem das turmas e das técnicas da semana.
• Chamada por QR Code, reconhecimento facial ou lista.
• Relatórios de presença, pontualidade e conclusão de missões.
• Alerta dos alunos que estão há dias sem treinar.
• Troféus e premiações de campeonatos.

PRIVACIDADE
O reconhecimento facial é sempre opcional: quem não quiser usa o QR Code e continua com todas as
outras funções. Você pode baixar seus dados ou excluir sua conta a qualquer momento, em
Central → Privacidade e meus dados.

O OctoGrip é usado por academias parceiras. Para entrar, você precisa do cadastro feito pela sua
academia.
```

**Categoria:** Esportes. (Alternativa: Saúde e fitness.)
**Tags sugeridas:** Artes marciais, Treino, Esportes.
**Anúncios:** o app **não** contém anúncios.

**Recursos gráficos**

| Recurso | Situação |
| --- | --- |
| Ícone 512×512 | Usar `viewer/web/icons/Icon-512.png` (já no tamanho exigido) |
| Imagem de destaque 1024×500 | **Falta criar** (logo sobre o fundo `#262433`) |
| Capturas de tela do celular (mín. 2) | **Falta tirar** no app Android rodando (início, missões, troféus, presença) |
| Ícone do app no celular | Gerado a partir do ícone web, com ícone adaptativo (Android 8+) |

## Acesso ao app (para a revisão da Google)

O app exige login. Em *Política do app → Acesso ao app*, escolha "Todas ou algumas funções estão
restritas" e informe uma conta de aluno da **academia de demonstração** (`@demo.octogrip.com.br`)
com e-mail e senha. Você mesmo digita a senha no formulário. Instruções para o revisor:

```
Entre com o e-mail e a senha informados. A conta é de um aluno da academia de demonstração.
O reconhecimento facial é opcional e pode ser ignorado; a presença também funciona por QR Code.
```

## Data safety (Segurança dos dados)

**Visão geral**

| Pergunta | Resposta |
| --- | --- |
| O app coleta ou compartilha dados do usuário? | Sim |
| Os dados são criptografados em trânsito? | Sim (HTTPS) |
| O usuário pode pedir a exclusão dos dados? | Sim (no app e pelo link de exclusão) |
| Compartilha dados com terceiros? | Não. Firebase (notificações) e Sentry (falhas) são prestadores de serviço que processam em nosso nome, o que a Google não conta como compartilhamento |
| Foi feita revisão de segurança independente? | Não |

**Dados coletados**

| Categoria → tipo | Coletado | Obrigatório? | Finalidade |
| --- | --- | --- | --- |
| Informações pessoais → Nome | Sim | Obrigatório | Funcionalidade do app; Gerenciamento da conta |
| Informações pessoais → Endereço de e-mail | Sim | Obrigatório | Funcionalidade do app; Gerenciamento da conta |
| Informações pessoais → IDs do usuário | Sim | Obrigatório | Funcionalidade do app; Gerenciamento da conta |
| Fotos e vídeos → Fotos | Sim | Opcional | Funcionalidade do app (foto de perfil, feed da academia e foto facial para presença) |
| Atividade no app → Interações no app | Sim | Obrigatório | Funcionalidade do app (missões, pontos, presença, troféus) |
| Atividade no app → Outro conteúdo gerado pelo usuário | Sim | Opcional | Funcionalidade do app (comentários no feed) |
| Informações e desempenho do app → Registros de falhas | Sim | Obrigatório | Análise; Funcionalidade do app (Sentry, só se `SENTRY_DSN_APP` estiver configurado) |
| Informações e desempenho do app → Diagnóstico | Sim | Obrigatório | Análise (versão do app e plataforma) |
| IDs do dispositivo ou outros → ID do dispositivo | Sim | Opcional | Funcionalidade do app (token de notificação FCM) |

Não coletados: localização, contatos, informações financeiras, saúde e fitness (o app não lê dados
de saúde do aparelho), mensagens (e-mail/SMS), áudio, arquivos, agenda, histórico de navegação.

**Dado biométrico:** a Play Console não tem um tipo "biometria". A foto facial entra em *Fotos* e o
reconhecimento facial deve ser descrito na Política de Privacidade (já está, no Aviso de Biometria).
Na revisão, a Google pode pedir detalhes: a resposta é que o uso é opcional, depende de consentimento
específico e serve só para registrar presença.

## Classificação de conteúdo (questionário IARC)

| Pergunta | Resposta |
| --- | --- |
| Categoria do app | Referência, notícias ou educação (não é jogo) |
| Violência | Não. Vídeos de técnicas de arte marcial em contexto esportivo e educativo, sem violência gráfica |
| Medo, sexualidade, linguagem imprópria, drogas, jogos de azar | Não |
| Usuários podem interagir ou trocar conteúdo? | **Sim** (feed de fotos e comentários entre alunos da mesma academia) |
| Compartilha localização do usuário? | Não |
| Compras digitais? | Não |

Resultado esperado: classificação livre ou 10+, com o aviso "Interação de usuários".

## Público-alvo e conteúdo

**DECIDIR: faixa etária do público-alvo.** Isso muda as exigências da Google:

- **Se nenhum usuário tiver menos de 13 anos:** marque 13–15, 16–17 e 18+. O app segue as regras gerais.
- **Se academias tiverem turmas infantis usando o app (menores de 13):** marque também as faixas abaixo
  de 13. Aí vale a **Política para Famílias** da Google: revisão mais rígida, restrição a SDKs (o
  Firebase Messaging é aceito; o Sentry precisa ser avaliado) e consentimento do responsável legal,
  que a LGPD (art. 14) também já exige.

Declarar uma faixa que não corresponde ao uso real pode levar à remoção do app. Se houver menores de
13 usando, a opção mais simples é eles não terem login próprio: o professor registra a presença.

**Outras declarações**

| Pergunta | Resposta |
| --- | --- |
| App de notícias? | Não |
| App de rastreamento de contatos (COVID)? | Não |
| App governamental? | Não |
| Recursos financeiros? | Não (o marketplace só abre o WhatsApp da academia; não há pagamento no app) |
| App de saúde? | Sim: **Atividade e condicionamento físicos** (acompanha treinos). Sem recursos médicos |
| Usa ID de publicidade? | Não |
