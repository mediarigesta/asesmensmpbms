@echo off
echo ================================
echo   Budi Mulia Exam - GitHub Pull
echo ================================
echo.

git config --global user.name "mediarigesta"
git config --global user.email "anselmusgestawan@gmail.com"

echo [1/3] Menyimpan perubahan lokal sementara...
git stash
if %errorlevel% neq 0 (
    echo INFO: Tidak ada perubahan lokal untuk disimpan.
)

echo.
echo [2/3] Mengambil update terbaru dari GitHub...
git pull
if %errorlevel% neq 0 (
    echo.
    echo ERROR: Pull gagal! Cek koneksi internet.
    echo Mengembalikan perubahan lokal...
    git stash pop
    pause
    exit /b 1
)

echo.
echo [3/3] Mengembalikan perubahan lokal...
git stash pop
if %errorlevel% neq 0 (
    echo INFO: Tidak ada perubahan lokal untuk dikembalikan.
)

echo.
echo ================================
echo   Berhasil update dari GitHub!
echo ================================
pause
