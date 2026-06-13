# 🚀 سكربت تشغيل سريع على الإيميوليتر

Write-Host "🔵 بدء تشغيل تطبيق FarahDent على الإيميوليتر..." -ForegroundColor Cyan

# التحقق من Backend
Write-Host "`n📡 التحقق من Backend..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:5030/health" -UseBasicParsing -TimeoutSec 3
    if ($response.StatusCode -eq 200) {
        Write-Host "✅ Backend يعمل على المنفذ 5030" -ForegroundColor Green
    }
} catch {
    Write-Host "❌ Backend غير متصل! شغّل Backend أولاً" -ForegroundColor Red
    Write-Host "الأمر: Start-Job -Name 'farahdent-api' -ScriptBlock { Set-Location 'C:\Users\ENG\Desktop\cases_photo\backend'; python -m uvicorn app.main:app --host 0.0.0.0 --port 5030 --reload }" -ForegroundColor Yellow
    exit
}

# التحقق من الإيميوليتر
Write-Host "`n📱 التحقق من الإيميوليتر..." -ForegroundColor Yellow
$devices = flutter devices
if ($devices -match "emulator") {
    Write-Host "✅ إيميوليتر متصل" -ForegroundColor Green
} else {
    Write-Host "⚠️  لا يوجد إيميوليتر شغال. تشغيل Pixel 7..." -ForegroundColor Yellow
    flutter emulators --launch Pixel_7
    Write-Host "⏳ انتظار الإيميوليتر (30 ثانية)..." -ForegroundColor Cyan
    Start-Sleep -Seconds 30
}

# تشغيل التطبيق
Write-Host "`n🚀 تشغيل التطبيق..." -ForegroundColor Cyan
Write-Host "ℹ️  للإيقاف: اضغط Ctrl+C في النافذة" -ForegroundColor Gray
Write-Host "ℹ️  للـ Hot Reload: اضغط 'r' في النافذة" -ForegroundColor Gray
Write-Host "ℹ️  للـ Hot Restart: اضغط 'R' في النافذة" -ForegroundColor Gray
Write-Host "`n" -ForegroundColor Gray

flutter run -d emulator-5554

Write-Host "`n✅ تم إغلاق التطبيق" -ForegroundColor Green
