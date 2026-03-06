@echo off
echo ================================
echo   Budi Mulia Exam - Web Update
echo ================================
echo.

echo [1/2] Building Flutter Web...
call flutter build web --release
if %errorlevel% neq 0 (
    echo.
    echo ERROR: Flutter build gagal!
    pause
    exit /b 1
)

echo.
echo [2/2] Deploying ke Firebase...
:: Sesuaikan target hosting dengan Project ID yang ada di gambar (bm-exam)
call firebase deploy --project bm-exam --only hosting
if %errorlevel% neq 0 (
    echo.
    echo ERROR: Deploy gagal!
    pause
    exit /b 1
)

echo.
echo ================================
echo   Deploy berhasil!
echo   https://bm-exam.web.app
echo ================================
pause