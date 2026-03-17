@echo off
chcp 65001 >nul
echo ===========================================
echo   BM-Exam - GitHub Push
echo ===========================================
echo.

:: Hapus file lock jika ada
if exist ".git\index.lock" (
    echo [!] Membersihkan file lock...
    del /f ".git\index.lock"
    echo.
)

:: Konfigurasi User
git config --global user.name "mediarigesta"
git config --global user.email "anselmusgestawan@gmail.com"

:: Masukkan Pesan Commit
echo Masukkan pesan commit:
set /p COMMIT_MSG=">> "
if "%COMMIT_MSG%"=="" (
    set COMMIT_MSG=Update project
)
echo.

:: Step 1 - Add
echo [1/3] Menambahkan semua file ke index...
git add .
if %errorlevel% neq 0 (
    echo [!] Gagal git add.
    pause
    exit /b 1
)

:: Step 2 - Commit
echo [2/3] Membuat commit...
git commit -m "%COMMIT_MSG%"
if %errorlevel% neq 0 (
    echo [!] Tidak ada perubahan untuk di-commit.
    pause
    exit /b 1
)

:: Step 3 - Push (coba master dulu, lalu main)
echo.
echo [3/3] Push ke GitHub...
git push origin master
if %errorlevel% equ 0 goto :SUCCESS

echo [!] Gagal push ke 'master', mencoba 'main'...
git push origin main
if %errorlevel% equ 0 goto :SUCCESS

echo.
echo [!] Gagal push. Kemungkinan penyebab:
echo     - Belum login GitHub / token expired
echo     - Tidak ada koneksi internet
echo.
pause
exit /b 1

:SUCCESS
echo.
echo ===========================================
echo   BERHASIL! GitHub sudah diperbarui.
echo ===========================================
pause
