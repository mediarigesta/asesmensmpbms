@echo off
echo ================================
echo   Budi Mulia Exam - GitHub Pull
echo ================================
echo.
git config --global user.name "mediarigesta"
git config --global user.email "anselmusgestawan@gmail.com"
git branch --set-upstream-to=origin/master master >nul 2>&1
echo [1/3] Menyimpan perubahan lokal sementara...
git stash
echo.
echo [2/3] Mengambil update terbaru dari GitHub...
git pull origin master --allow-unrelated-histories
if %errorlevel% neq 0 (
    echo ERROR: Pull gagal!
    git stash pop 2>nul
    pause
    exit /b 1
)
echo.
echo [3/3] Mengembalikan perubahan lokal...
git stash pop 2>nul
echo.
echo ================================
echo   Berhasil update dari GitHub!
echo ================================
pause
