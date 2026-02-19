@echo off
REM Execute como Administrador: clique direito -> Executar como administrador
REM Libera a porta 8000 para o celular conectar na API na rede local.
netsh advfirewall firewall add rule name="AppBaby API (porta 8000)" dir=in action=allow protocol=TCP localport=8000
echo.
echo Regra adicionada. Se a API estiver rodando com --host 0.0.0.0, o celular deve conectar.
pause
