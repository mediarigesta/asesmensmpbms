@echo off
echo ========================================
echo   BM-Exam Pro - Flutter Web Build
echo ========================================
echo.

echo [1/5] Building Flutter Web...
call flutter build web --dart-define=FLUTTER_WEB_USE_SKIA=false
if %errorlevel% neq 0 (
    echo BUILD GAGAL! Cek error di atas.
    pause
    exit /b 1
)

echo.
echo [2/5] Patching flutter_bootstrap.js (ganti canvaskit ke html renderer)...
powershell -Command ^
  "$f = 'build\web\flutter_bootstrap.js';" ^
  "$c = Get-Content $f -Raw;" ^
  "$c = $c -replace '\"builds\":\[.*?\]', '\"builds\":[{\"compileTarget\":\"dart2js\",\"renderer\":\"html\",\"mainJsPath\":\"main.dart.js\"}]';" ^
  "$c = $c -replace '_flutter\.loader\.load\(\{[\s\S]*?\}\);', '_flutter.loader.load({ config: { renderer: \"html\" } });';" ^
  "Set-Content $f $c -NoNewline;"

echo.
echo [3/5] Patching main.dart.js (hapus CanvasKit dan Firebase dari gstatic.com)...
powershell -Command ^
  "$f = 'build\web\main.dart.js';" ^
  "Write-Host 'Membaca main.dart.js... (harap tunggu)';" ^
  "$c = Get-Content $f -Raw;" ^
  "$c = $c -replace 'https://www\.gstatic\.com/flutter-canvaskit/[a-f0-9]+/', 'canvaskit/';" ^
  "$c = $c -replace 'https://www\.gstatic\.com/flutter-canvaskit/[a-f0-9]+', 'canvaskit';" ^
  "$c = $c -replace 'https://www\.gstatic\.com/firebasejs/[0-9.]+/', './firebase/';" ^
  "$c = $c -replace 'https://www\.gstatic\.com/firebasejs/[0-9.]+', './firebase';" ^
  "Set-Content $f $c -NoNewline;" ^
  "Write-Host 'main.dart.js berhasil di-patch!';"

echo.
echo [4/5] Download Firebase lokal (butuh internet sekali)...
if not exist "build\web\firebase" mkdir "build\web\firebase"

powershell -Command ^
  "$v = '11.9.1';" ^
  "$base = 'https://www.gstatic.com/firebasejs/' + $v + '/';" ^
  "$files = @('firebase-app.js','firebase-firestore.js','firebase-app-compat.js','firebase-firestore-compat.js');" ^
  "foreach ($file in $files) {" ^
  "  $out = 'build\web\firebase\' + $file;" ^
  "  if (!(Test-Path $out)) {" ^
  "    Write-Host ('Downloading ' + $file + '...');" ^
  "    try { Invoke-WebRequest -Uri ($base + $file) -OutFile $out -TimeoutSec 30; Write-Host 'OK'; }" ^
  "    catch { Write-Host ('GAGAL: ' + $file + ' - skip'); }" ^
  "  } else { Write-Host ($file + ' sudah ada, skip.'); }" ^
  "}"

echo.
echo [5/5] Selesai!
echo.
echo Untuk menjalankan:
echo   cd build\web
echo   python server.py
echo.
echo Lalu buka http://localhost:8080 di browser.
echo.
pause
