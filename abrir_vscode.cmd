@echo off
setlocal
where code >nul 2>nul
if not errorlevel 1 (
    call code "%~dp0pizzaplex.code-workspace"
    exit /b
)
if exist "%LOCALAPPDATA%\Programs\Microsoft VS Code\bin\code.cmd" (
    call "%LOCALAPPDATA%\Programs\Microsoft VS Code\bin\code.cmd" "%~dp0pizzaplex.code-workspace"
    exit /b
)
if exist "%ProgramFiles%\Microsoft VS Code\bin\code.cmd" (
    call "%ProgramFiles%\Microsoft VS Code\bin\code.cmd" "%~dp0pizzaplex.code-workspace"
    exit /b
)
echo Abra esta pasta pelo VS Code em Arquivo ^> Abrir Pasta.
pause
