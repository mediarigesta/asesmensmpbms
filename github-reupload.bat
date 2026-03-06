@echo off
chcp 65001 >nul
echo ===========================================
echo   Budi Mulia Exam - GitHub RE-UPLOAD (NEW)
echo ===========================================
echo.

:: -----------------------------------------------
:: PENGATURAN
:: -----------------------------------------------
set "PROJECT_PATH=%~dp0"
set "GIT_USERNAME=mediarigesta"
set "GIT_EMAIL=anselmusgestawan@gmail.com"
set "REMOTE_URL=https://github.com/mediarigesta/asesmensmpbms.git"
:: -----------------------------------------------

:: Pindah ke folder yang sama dengan file .bat ini
cd /d "%PROJECT_PATH%"
echo [i] Folder aktif: %PROJECT_PATH%
echo.

:: Cek apakah ini git repository
if not exist ".git" (
    echo [!] Folder ini bukan git repository!
    echo     Akan diinisialisasi otomatis dengan remote:
    echo     %REMOTE_URL%
    echo.
    git init
    git remote add origin "%REMOTE_URL%"
    echo [OK] Git berhasil diinisialisasi!
    echo.
)

:: Hapus file lock jika ada
if exist ".git\index.lock" (
    echo [!] Membersihkan file lock yang tersangkut...
    del /f ".git\index.lock"
    echo.
)

:: Konfigurasi User
git config --global user.name "%GIT_USERNAME%"
git config --global user.email "%GIT_EMAIL%"

:: Masukkan Pesan Commit
echo Masukkan pesan commit untuk isi baru:
set /p COMMIT_MSG=">> "
if "%COMMIT_MSG%"=="" (
    set COMMIT_MSG=Re-upload: Initial clean version
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
echo [2/3] Membuat commit baru...
git commit -m "%COMMIT_MSG%"
if %errorlevel% neq 0 (
    echo [!] Tidak ada perubahan untuk di-commit, atau terjadi error.
    pause
    exit /b 1
)

:: Step 3 - Force Push (langsung ke master karena repo pakai master)
echo.
echo [3/3] Melakukan Force Push ke GitHub (branch: master)...
echo PERINGATAN: Ini akan menimpa history lama di GitHub!
echo.
git push origin master --force
if %errorlevel% equ 0 (
    goto :SUCCESS
)

:: Jika master gagal, coba main
echo [!] Gagal push ke 'master', mencoba 'main'...
git push origin main --force
if %errorlevel% equ 0 (
    goto :SUCCESS
)

:: Kedua branch gagal
echo.
echo [!] Gagal push. Kemungkinan penyebab:
echo     - Belum login GitHub / token expired
echo     - Tidak ada koneksi internet
echo     - Remote URL salah
echo.
echo     Cek remote: git remote -v
pause
exit /b 1

:SUCCESS
echo.
echo ===========================================
echo   BERHASIL! GitHub sudah diperbarui.
echo ===========================================
echo.
pause