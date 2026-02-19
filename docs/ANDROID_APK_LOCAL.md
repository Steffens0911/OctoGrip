# App Android (APK) — Teste local no celular

Configurações que permitem instalar o APK no celular e conectar na API rodando no PC (mesma rede Wi‑Fi). Use este documento para alterações futuras (trocar IP, produção, etc.).

---

## Resumo do que está configurado

| Objetivo | Onde | O quê |
|----------|------|--------|
| URL da API no app (Android) | `viewer/lib/config_stub.dart` | IP do PC + porta 8000 (ex.: `http://192.168.0.14:8000`) |
| Permissões de rede | `viewer/android/app/src/main/AndroidManifest.xml` | `INTERNET`, `ACCESS_NETWORK_STATE` |
| Permitir HTTP (cleartext) | `AndroidManifest.xml` | `usesCleartextTraffic="true"` + `networkSecurityConfig` |
| Política de rede | `viewer/android/app/src/main/res/xml/network_security_config.xml` | `base-config cleartextTrafficPermitted="true"` |
| Firewall Windows | `scripts/liberar_porta_8000_firewall.bat` | Regra para permitir entrada TCP na porta 8000 |

---

## 1. URL da API no app (Android)

**Arquivo:** [viewer/lib/config_stub.dart](../viewer/lib/config_stub.dart)

```dart
String getApiBaseUrl() => 'http://192.168.0.14:8000';
```

- **Alterar o IP:** use o IPv4 do seu PC na rede Wi‑Fi. No PowerShell: `ipconfig` e veja "Endereço IPv4" do adaptador Wi‑Fi.
- **Emulador Android:** pode usar `http://10.0.2.2:8000` (10.0.2.2 = localhost do host no emulador).
- **Produção:** troque para a URL pública da API (HTTPS); depois pode remover ou restringir cleartext no Android (ver seção 4).

---

## 2. Permissões no AndroidManifest

**Arquivo:** [viewer/android/app/src/main/AndroidManifest.xml](../viewer/android/app/src/main/AndroidManifest.xml)

Dentro de `<manifest>`, antes de `<application>`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

Necessárias para o app abrir conexões de rede e verificar estado da rede.

---

## 3. Cleartext e Network Security Config no manifest

**Arquivo:** [viewer/android/app/src/main/AndroidManifest.xml](../viewer/android/app/src/main/AndroidManifest.xml)

Na tag `<application>`:

```xml
android:usesCleartextTraffic="true"
android:networkSecurityConfig="@xml/network_security_config"
```

- **usesCleartextTraffic="true":** permite HTTP (não só HTTPS). Obrigatório para API local em `http://`.
- **networkSecurityConfig:** aponta para o XML que define a política (seção 4).

---

## 4. Network Security Config (XML)

**Arquivo:** [viewer/android/app/src/main/res/xml/network_security_config.xml](../viewer/android/app/src/main/res/xml/network_security_config.xml)

Conteúdo atual (permite cleartext para qualquer destino — adequado para teste local):

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="true">
        <trust-anchors>
            <certificates src="system" />
            <certificates src="user" />
        </trust-anchors>
    </base-config>
</network-security-config>
```

- **Para produção com HTTPS:** pode remover este arquivo e o `networkSecurityConfig` do manifest, e deixar ou remover `usesCleartextTraffic` (default false).
- **Restringir só a IPs locais:** troque por um `domain-config` com `cleartextTrafficPermitted="true"` e `<domain>192.168.0.14</domain>` (e outros IPs necessários).

---

## 5. Firewall Windows (porta 8000)

**Arquivo:** [scripts/liberar_porta_8000_firewall.bat](../scripts/liberar_porta_8000_firewall.bat)

Execute **como Administrador** (clique direito → Executar como administrador) para permitir que o celular acesse a API no PC:

```batch
netsh advfirewall firewall add rule name="AppBaby API (porta 8000)" dir=in action=allow protocol=TCP localport=8000
```

Só é necessário uma vez por máquina (ou até remover a regra manualmente depois).

---

## 6. Rodar a API para o celular acessar

A API precisa escutar em todas as interfaces, não só em localhost:

```bash
cd "c:\...\AppBaby"
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

O `--host 0.0.0.0` é essencial para aceitar conexões do celular na rede.

---

## 7. Gerar o APK

```bash
cd "c:\...\AppBaby\viewer"
C:\flutter\bin\flutter.bat build apk
```

APK gerado em: `viewer\build\app\outputs\flutter-apk\app-release.apk`.

---

## Checklist rápido para testar no celular

1. PC e celular na **mesma rede Wi‑Fi**.
2. **IP do PC** em `config_stub.dart` correto (`ipconfig`).
3. **API** rodando com `--host 0.0.0.0 --port 8000`.
4. **Firewall:** executar `scripts/liberar_porta_8000_firewall.bat` como administrador (uma vez).
5. **Instalar** o `app-release.apk` no celular.
6. (Opcional) No navegador do celular, abrir `http://<IP_DO_PC>:8000` para confirmar que a rede está ok.

---

## Referência rápida de arquivos

| Arquivo | Função |
|---------|--------|
| `viewer/lib/config_stub.dart` | URL da API para Android (e outras plataformas não-web) |
| `viewer/lib/config_web.dart` | URL da API para Flutter web (usa `index.html`) |
| `viewer/android/app/src/main/AndroidManifest.xml` | Permissões, cleartext, networkSecurityConfig |
| `viewer/android/app/src/main/res/xml/network_security_config.xml` | Política de cleartext/HTTPS |
| `scripts/liberar_porta_8000_firewall.bat` | Regra de firewall para porta 8000 |
