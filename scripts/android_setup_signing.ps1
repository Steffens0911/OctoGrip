<#
.SYNOPSIS
  Gera a chave de upload do app Android e cadastra os secrets do build-mobile.yml no GitHub.

.DESCRIPTION
  Rode você mesmo, num terminal PowerShell (não pelo Claude): a senha é digitada aqui e
  vai direto para o keytool e para o GitHub, sem aparecer na tela nem em arquivo.

  1. Instala (se faltar) o Java (keytool) e o GitHub CLI (gh) via winget.
  2. Gera octogrip-upload.jks FORA do repositório (padrão: %USERPROFILE%\octogrip-android-keys).
  3. Cadastra no environment "secrets" do repositório:
     ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD
     e API_BASE_URL (só se ainda não existir).

  Depois: guarde o .jks e a senha no gerenciador de senhas. Ver docs/android_release.md.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\android_setup_signing.ps1
#>
param(
    [string]$OutDir = (Join-Path $env:USERPROFILE "octogrip-android-keys"),
    [string]$Repo = "Steffens0911/OctoGrip",
    [string]$GitHubEnvironment = "secrets",
    [string]$ApiBaseUrl = "https://api.octogrip.com.br",
    [string]$KeyAlias = "upload"
)

$ErrorActionPreference = "Stop"

function Write-Step([string]$text) { Write-Host "`n==> $text" -ForegroundColor Cyan }

function Confirm-Yes([string]$question) {
    $answer = Read-Host "$question (s/n)"
    return $answer -match '^(s|sim|y|yes)$'
}

function Find-Keytool {
    $cmd = Get-Command keytool -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $candidates = @()
    if ($env:JAVA_HOME) { $candidates += Join-Path $env:JAVA_HOME "bin\keytool.exe" }
    $candidates += "$env:ProgramFiles\Android\Android Studio\jbr\bin\keytool.exe"
    $candidates += Get-ChildItem "$env:ProgramFiles\Microsoft\jdk-*\bin\keytool.exe" -ErrorAction SilentlyContinue | ForEach-Object FullName
    $candidates += Get-ChildItem "$env:ProgramFiles\Java\*\bin\keytool.exe" -ErrorAction SilentlyContinue | ForEach-Object FullName
    $candidates += Get-ChildItem "$env:ProgramFiles\Eclipse Adoptium\*\bin\keytool.exe" -ErrorAction SilentlyContinue | ForEach-Object FullName
    return $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}

function Find-Gh {
    $cmd = Get-Command gh -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $path = "$env:ProgramFiles\GitHub CLI\gh.exe"
    if (Test-Path $path) { return $path }
    return $null
}

function Read-NewPassword {
    while ($true) {
        $first = Read-Host "Senha da chave (mínimo 8 caracteres; não aparece na tela)" -AsSecureString
        $second = Read-Host "Repita a senha" -AsSecureString
        $a = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($first))
        $b = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($second))
        if ($a -ne $b) { Write-Host "As senhas não conferem. Tente de novo." -ForegroundColor Yellow; continue }
        if ($a.Length -lt 8) { Write-Host "Use pelo menos 8 caracteres." -ForegroundColor Yellow; continue }
        return $a
    }
}

function Set-GhSecret([string]$gh, [string]$name, [string]$value) {
    # --body em vez de stdin: o pipe do PowerShell acrescenta quebra de linha ao valor,
    # o que mudaria a senha. Os comandos internos do script não vão para o histórico do terminal.
    & $gh secret set $name --repo $Repo --env $GitHubEnvironment --body $value
    if ($LASTEXITCODE -ne 0) { throw "Falha ao cadastrar o secret $name." }
    Write-Host "  secret $name cadastrado"
}

# --- 1. Ferramentas -----------------------------------------------------------------
Write-Step "Conferindo Java (keytool) e GitHub CLI (gh)"

$keytool = Find-Keytool
if (-not $keytool) {
    if (-not (Confirm-Yes "keytool não encontrado. Instalar o Microsoft OpenJDK 17 via winget?")) { throw "keytool é necessário." }
    winget install --id Microsoft.OpenJDK.17 -e --accept-source-agreements
    $keytool = Find-Keytool
    if (-not $keytool) { throw "Instalação concluída, mas o keytool não foi encontrado. Abra um novo terminal e rode de novo." }
}
Write-Host "  keytool: $keytool"

$gh = Find-Gh
if (-not $gh) {
    if (-not (Confirm-Yes "gh não encontrado. Instalar o GitHub CLI via winget?")) { throw "gh é necessário para cadastrar os secrets." }
    winget install --id GitHub.cli -e --accept-source-agreements
    $gh = Find-Gh
    if (-not $gh) { throw "Instalação concluída, mas o gh não foi encontrado. Abra um novo terminal e rode de novo." }
}
Write-Host "  gh: $gh"

# No Windows PowerShell 5.1, stderr de comando nativo com 2>$null vira erro fatal sob "Stop".
$ErrorActionPreference = "Continue"
& $gh auth status 2>$null | Out-Null
$ghLogged = ($LASTEXITCODE -eq 0)
$ErrorActionPreference = "Stop"
if (-not $ghLogged) {
    Write-Host "Faça login no GitHub com a conta dona do repositório $Repo." -ForegroundColor Yellow
    & $gh auth login --hostname github.com --web
    if ($LASTEXITCODE -ne 0) { throw "Login no GitHub não concluído." }
}

# --- 2. Chave de upload -------------------------------------------------------------
Write-Step "Gerando a chave de upload"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$OutDir = [IO.Path]::GetFullPath($OutDir)
if ($OutDir.StartsWith($repoRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "A chave não pode ficar dentro do repositório ($repoRoot). Use outro -OutDir."
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$keystore = Join-Path $OutDir "octogrip-upload.jks"

if (Test-Path $keystore) {
    Write-Host "Já existe $keystore." -ForegroundColor Yellow
    if (-not (Confirm-Yes "Usar essa chave existente (não gera outra)?")) { throw "Mova ou apague a chave existente antes de gerar outra." }
    $password = Read-Host "Senha da chave existente" -AsSecureString
    $password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
} else {
    $password = Read-NewPassword
    $env:OCTOGRIP_KS_PASS = $password
    try {
        # PKCS12: a senha da chave é a mesma do arquivo.
        & $keytool -genkeypair -v -keystore $keystore -storetype PKCS12 -keyalg RSA -keysize 2048 `
            -validity 10000 -alias $KeyAlias -dname "CN=Octogrip, O=Octogrip, L=Brasil, C=BR" `
            -storepass:env OCTOGRIP_KS_PASS -keypass:env OCTOGRIP_KS_PASS
        if ($LASTEXITCODE -ne 0) { throw "keytool falhou ao gerar a chave." }
    } finally {
        Remove-Item Env:\OCTOGRIP_KS_PASS -ErrorAction SilentlyContinue
    }
}

# Confere a senha antes de mandar qualquer coisa ao GitHub.
$env:OCTOGRIP_KS_PASS = $password
try {
    & $keytool -list -keystore $keystore -alias $KeyAlias -storepass:env OCTOGRIP_KS_PASS | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Senha incorreta ou alias '$KeyAlias' não encontrado em $keystore." }
} finally {
    Remove-Item Env:\OCTOGRIP_KS_PASS -ErrorAction SilentlyContinue
}

# --- 3. Secrets no GitHub -----------------------------------------------------------
Write-Step "Cadastrando secrets no environment '$GitHubEnvironment' de $Repo"

$base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($keystore))
Set-GhSecret $gh "ANDROID_KEYSTORE_BASE64" $base64
Set-GhSecret $gh "ANDROID_KEYSTORE_PASSWORD" $password
Set-GhSecret $gh "ANDROID_KEY_ALIAS" $KeyAlias
Set-GhSecret $gh "ANDROID_KEY_PASSWORD" $password
$password = $null

$ErrorActionPreference = "Continue"
$existing = & $gh secret list --repo $Repo --env $GitHubEnvironment 2>$null
$ErrorActionPreference = "Stop"
if ($existing -match '^API_BASE_URL\s') {
    Write-Host "  secret API_BASE_URL já existe (mantido)"
} else {
    Set-GhSecret $gh "API_BASE_URL" $ApiBaseUrl
}

# --- Fim ----------------------------------------------------------------------------
Write-Step "Pronto"
Write-Host @"
Chave gerada em: $keystore

AGORA, ANTES DE QUALQUER OUTRA COISA:
  1. Guarde o arquivo octogrip-upload.jks e a senha no seu gerenciador de senhas
     (e uma cópia offline). Sem eles você não publica novas versões.
  2. Nunca coloque o .jks no repositório.

Ainda faltam (docs/android_release.md):
  - GOOGLE_PLAY_SERVICE_ACCOUNT_JSON, depois de criar o app na Play Console.
  - SENTRY_DSN_APP (opcional).
"@ -ForegroundColor Green
