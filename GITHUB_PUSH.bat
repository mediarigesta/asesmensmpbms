@echo off
echo ===========================================
echo   Budi Mulia Exam - GitHub RE-UPLOAD (NEW)
echo ===========================================
echo.

:: 1. Hapus file lock jika ada (mencegah error fatal sebelumnya)
if exist ".git\index.lock" (
    echo [!] Membersihkan file lock yang tersangkut...
    del /f ".git\index.lock"
)

:: 2. Konfigurasi User
git config --global user.name "mediarigesta"
git config --global user.email "anselmusgestawan@gmail.com"

:: 3. Masukkan Pesan Commit
echo Masukkan pesan commit untuk isi baru:
set /p COMMIT_MSG=">> "

if "%COMMIT_MSG%"=="" (
    set COMMIT_MSG="Re-upload: Initial clean version"
)

echo.
echo [1/3] Menambahkan file baru ke index...
git add .

echo [2/3] Membuat commit baru...
git commit -m "%COMMIT_MSG%"

echo.
echo [3/3] Melakukan Force Push ke GitHub...
echo PERINGATAN: Ini akan menghapus file lama di GitHub dan menggantinya dengan yang baru!
echo.
:: Perintah Force Push untuk menimpa history lama
git push origin main --force

if %errorlevel% neq 0 (
    echo.
    echo [!] Gagal push. Jika branch Anda bukan 'main', coba ganti 'main' menjadi 'master' di file .bat ini.
    pause
    exit /b 1
)

echo.
echo ===========================================
echo   PROSES BERHASIL! GitHub kini sudah diperbarui.
echo ===========================================
pause