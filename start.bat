@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set API_PORT=18765
set JAR_PATH=%~dp0target\git-manager-1.0.0.jar

:: Verifica se o JAR existe
if not exist "%JAR_PATH%" (
    echo JAR nao encontrado. Compilando...
    cd /d "%~dp0"
    call mvn package -q -DskipTests
)

:: Verifica se o Java esta instalado
java -version >nul 2>&1
if errorlevel 1 (
    echo Erro: Java 17+ nao encontrado. Instale o JDK 17.
    pause
    exit /b 1
)

:: Mata processos antigos na mesma porta
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :%API_PORT%') do (
    taskkill /F /PID %%a >nul 2>&1
)

echo =========================================
echo    Git Manager - Flutter + Java
echo =========================================
echo.

echo Iniciando backend Java na porta %API_PORT%...
start /b javaw -cp "%JAR_PATH%" com.gitmanager.ApiMain > "%TEMP%\git-manager-api.log" 2>&1

echo Aguardando servidor...
:wait_loop
timeout /t 1 /nobreak >nul
curl -s http://localhost:%API_PORT%/api/health >nul 2>&1
if errorlevel 1 goto wait_loop

echo Backend pronto!
echo.

:: Encontra o executavel Flutter Windows
set FLUTTER_EXE=%~dp0git_manager_ui\build\windows\x64\runner\Release\git_manager_ui.exe
if not exist "%FLUTTER_EXE%" (
    set FLUTTER_EXE=%~dp0git_manager_ui\build\windows\x64\runner\Debug\git_manager_ui.exe
)

if exist "%FLUTTER_EXE%" (
    echo Iniciando Flutter Windows...
    start /b "" "%FLUTTER_EXE%"
    echo.
    echo Git Manager esta rodando!
    echo.
    pause
    :: Encerra o Java ao fechar
    for /f "tokens=5" %%a in ('netstat -ano ^| findstr :%API_PORT%') do (
        taskkill /F /PID %%a >nul 2>&1
    )
) else (
    echo.
    echo Executavel Flutter nao encontrado.
    echo Compile primeiro com: flutter build windows --release
    echo.
    pause
)
