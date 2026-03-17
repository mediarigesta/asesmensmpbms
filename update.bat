@echo off
chcp 65001 >nul
echo ===========================================
echo   BM-Exam - Update Website (Firebase)
echo ===========================================
echo.

echo [1/2] Building Flutter Web...
call flutter build web --release
if %errorlevel% neq 0 (
    echo.
    echo [!] Flutter build web gagal!
    pause
    exit /b 1
)

echo.
echo [2/2] Deploying ke Firebase Hosting...
call firebase deploy --project bm-exam --only hosting
if %errorlevel% neq 0 (
    echo.
    echo [!] Deploy ke Firebase gagal!
    pause
    exit /b 1
)

echo.
echo ===========================================
echo   Website berhasil di-update!
echo   https://bm-exam.web.app
echo ===========================================
pause
