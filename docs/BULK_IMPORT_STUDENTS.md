# Importação em lote de alunos (Excel)

Este documento descreve como uma academia pode cadastrar **alunos em lote** via upload de uma planilha **Excel `.xlsx`**.

## Endpoint

- **Método**: `POST`
- **URL**: `/academies/{academy_id}/students/bulk-import`
- **Autenticação**: Bearer token (JWT)
- **Permissão**: `administrador`, `gerente_academia` ou `professor`
- **Multipart**: campo `file` (arquivo `.xlsx`)

## Regras

- **Escopo de academia**: o `academy_id` vem da URL e o backend valida acesso do usuário à academia.
- **Sempre cria aluno**: o backend força `role = "aluno"` e ignora qualquer tentativa de mandar role pela planilha.
- **E-mail único global**: se o e-mail já existir na tabela `users`, a linha é **pulada** (`skipped`).
- **Validação por linha**: erros em uma linha **não** abortam o lote; a resposta lista erros por linha.
- **Tamanho máximo**: 10 MB.

## Formato da planilha

- **Primeira aba** (worksheet 0).
- **Cabeçalho obrigatório** (colunas):
  - `E-MAIL`
  - `NOME`
  - `SENHA`
  - `GRADUAÇÃO`

O parser normaliza nomes (case, espaços, hífens e acentos), então variações como `EMAIL`, `E-mail`, `GRADUACAO` também funcionam.

### Valores aceitos para GRADUAÇÃO

O backend usa as mesmas graduações já existentes no sistema:

- `white`, `blue`, `purple`, `brown`, `black`

Por conveniência, ele também aceita PT-BR e converte automaticamente:

- `branca` → `white`
- `azul` → `blue`
- `roxa`/`roxo` → `purple`
- `marrom` → `brown`
- `preta`/`preto` → `black`

## Resposta

O endpoint retorna JSON com:

- `summary`: contadores do processamento
- `results`: lista por linha (criado, pulado, vazio, ou erro)

Exemplo (resumo):

```json
{
  "ok": true,
  "academy_id": "f0c2c1a5-7cc4-4bd0-9c25-30d20db8f85f",
  "summary": { "total_rows": 12, "created": 9, "skipped": 2, "failed": 1 },
  "results": [
    { "row_number": 2, "ok": true, "action": "created", "id": "..." },
    { "row_number": 3, "ok": true, "action": "skipped", "reason": "email_already_exists" },
    { "row_number": 4, "ok": false, "action": "create", "errors": [ { "field": "graduation", "code": "invalid", "message": "..." } ] }
  ]
}
```

## Frontend (Viewer)

Na tela **Usuários** (`viewer/lib/screens/admin/user_list_screen.dart`) existe a ação **“Importar alunos (Excel)”** que:

- abre o seletor de arquivo e restringe para `.xlsx`
- faz upload para `/academies/{academyId}/students/bulk-import`
- mostra um resumo do resultado
- recarrega a lista de usuários

