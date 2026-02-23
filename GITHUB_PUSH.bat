@echo off
echo ================================
echo   Budi Mulia Exam - GitHub Push
echo ================================
echo.

git config --global user.name "mediarigesta"
git config --global user.email "anselmusgestawan@gmail.com"

echo Masukkan pesan commit:
set /p COMMIT_MSG=">> "

if "%COMMIT_MSG%"=="" (
    set COMMIT_MSG=Update project
)

echo.
echo [1/3] Menambahkan semua perubahan...
git add .

echo [2/3] Commit: %COMMIT_MSG%
git commit -m "%COMMIT_MSG%"
if %errorlevel% neq 0 (
    echo.
    echo INFO: Tidak ada perubahan untuk di-commit.
    pause
    exit /b 0
)

echo.
echo [3/3] Push ke GitHub...
git push
if %errorlevel% neq 0 (
    echo.
    echo ERROR: Push gagal! Cek koneksi internet atau login GitHub.
    pause
    exit /b 1
)

echo.
echo ================================
echo   Berhasil push ke GitHub!
echo ================================
pause
