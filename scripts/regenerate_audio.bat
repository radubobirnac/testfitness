@echo off
echo 🎖️ REGENERATING DRILL INSTRUCTOR AUDIO
echo.

REM Check if .env file exists
if not exist ".env" (
    echo ❌ .env file not found!
    echo Please create .env file with your OPENAI_API_KEY
    echo See .env.example for format
    pause
    exit /b 1
)

REM Read OpenAI API key from .env file
for /f "tokens=2 delims==" %%a in ('findstr "OPENAI_API_KEY" .env') do set OPENAI_API_KEY=%%a

if "%OPENAI_API_KEY%"=="" (
    echo ❌ OPENAI_API_KEY not found in .env file!
    echo Please add your OpenAI API key to .env file
    pause
    exit /b 1
)

echo 🗑️ Cleaning old audio files...
if exist "assets\audio\workout\timing" rmdir /s /q "assets\audio\workout\timing"
if exist "assets\audio\workout\combinations" rmdir /s /q "assets\audio\workout\combinations"
if exist "assets\audio\workout\motivation" rmdir /s /q "assets\audio\workout\motivation"

echo 🎯 Generating fresh drill instructor audio...
python scripts/generate_countdown_audio.py "%OPENAI_API_KEY%"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ✅ SUCCESS! Fresh drill instructor audio generated!
    echo 🥊 Your boxing app is ready to DOMINATE!
) else (
    echo.
    echo ❌ Error occurred during audio generation
    echo Please check your API key and internet connection
)

echo.
pause
