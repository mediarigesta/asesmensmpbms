@echo off
chcp 65001 >nul
echo ===========================================
echo   BM-Exam - Build APK
echo ===========================================
echo.

echo [1/2] Building APK Release...
call flutter build apk --release
if %errorlevel% neq 0 (
    echo.
    echo [!] Build APK gagal!
    pause
    exit /b 1
)

echo.
echo [2/2] Membuka folder APK...
explorer build\app\outputs\flutter-apk\

echo.
echo ===========================================
echo   Build APK berhasil!
echo   File: build\app\outputs\flutter-apk\app-release.apk
echo ===========================================
pause
