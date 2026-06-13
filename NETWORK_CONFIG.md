# 🌐 إعدادات الشبكة والربط - FarahDent

## ✅ الإعدادات الحالية (محدّثة)

### Backend (الخادم)
- 📍 **الموقع**: `C:\Users\ENG\Desktop\cases_photo\backend`
- 🌐 **المنفذ**: `5030`
- 🔗 **العناوين**:
  - `http://localhost:5030` ✅
  - `http://127.0.0.1:5030` ✅
  - `http://192.168.0.104:5030` ✅ (IP جهازك)
- 💾 **قاعدة البيانات**: `mongodb://localhost:27017/cases_photo`
- 🔐 **CORS**: مفتوح لجميع الأصول `["*"]`

### Frontend (التطبيق)
- 📍 **الموقع**: `C:\Users\ENG\Desktop\cases_photo\frontend`
- 🔗 **API URL**: `http://192.168.0.104:5030`
- 📱 **الأجهزة المدعومة**:
  - Android Emulator
  - iOS Simulator
  - أجهزة حقيقية على نفس الشبكة

---

## 🔄 حالات الاستخدام المختلفة

### 1️⃣ التشغيل على Android Emulator

**عدّل في:** `frontend/lib/core/constants/api_constants.dart`

```dart
static const String baseUrl = 'http://10.0.2.2:5030';
```

📝 **ملاحظة**: `10.0.2.2` هو عنوان خاص يشير إلى `localhost` للكمبيوتر من داخل الإيميوليتر

---

### 2️⃣ التشغيل على جهاز Android/iOS حقيقي

**عدّل في:** `frontend/lib/core/constants/api_constants.dart`

```dart
static const String baseUrl = 'http://192.168.0.104:5030';
```

⚠️ **شروط مهمة:**
- الكمبيوتر والجهاز على **نفس الشبكة Wi-Fi**
- تأكد أن Firewall لا يحجب المنفذ 5030
- Backend يجب أن يشتغل على `--host 0.0.0.0` (وليس `127.0.0.1`)

---

### 3️⃣ التشغيل على iOS Simulator

**عدّل في:** `frontend/lib/core/constants/api_constants.dart`

```dart
static const String baseUrl = 'http://localhost:5030';
// أو
static const String baseUrl = 'http://127.0.0.1:5030';
```

---

## 🚀 أوامر التشغيل السريعة

### تشغيل Backend

```powershell
# انتقل لمجلد Backend
cd C:\Users\ENG\Desktop\cases_photo\backend

# شغّل الخادم
python -m uvicorn app.main:app --host 0.0.0.0 --port 5030 --reload
```

**أو بـ Background Job:**

```powershell
Start-Job -Name "farahdent-api" -ScriptBlock {
  Set-Location 'C:\Users\ENG\Desktop\cases_photo\backend'
  python -m uvicorn app.main:app --host 0.0.0.0 --port 5030 --reload
}
```

### تشغيل Frontend

```powershell
# انتقل لمجلد Frontend
cd C:\Users\ENG\Desktop\cases_photo\frontend

# شغّل التطبيق
flutter run

# أو اختر جهاز محدد
flutter run -d <device-id>
```

---

## 🧪 اختبار الاتصال

### 1. اختبر Backend محلياً

```powershell
Invoke-WebRequest -Uri "http://localhost:5030/health" -UseBasicParsing
```

**النتيجة المتوقعة:**
```json
{"ok": true}
```

### 2. اختبر Backend عبر الشبكة

```powershell
Invoke-WebRequest -Uri "http://192.168.0.104:5030/" -UseBasicParsing
```

**النتيجة المتوقعة:**
```json
{"service": "FarahDent Backend", "version": "1.0.0"}
```

### 3. اختبر من الجهاز/الإيميوليتر

افتح المتصفح في الجهاز وادخل:
```
http://192.168.0.104:5030
```

يجب أن ترى:
```json
{"service": "FarahDent Backend", "version": "1.0.0"}
```

---

## 🛠️ حل المشاكل

### ❌ خطأ: "Failed to connect"

**الأسباب المحتملة:**

1. **Backend غير مشغّل**
   ```powershell
   Get-Job  # تحقق من الـ jobs
   Receive-Job -Name "farahdent-api" -Keep  # اعرض السجلات
   ```

2. **IP خاطئ في Frontend**
   - تحقق من IP جهازك: `ipconfig`
   - عدّل `api_constants.dart`

3. **Firewall يحجب المنفذ**
   ```powershell
   # السماح للمنفذ 5030
   New-NetFirewallRule -DisplayName "FarahDent API" -Direction Inbound -LocalPort 5030 -Protocol TCP -Action Allow
   ```

4. **الجهاز والكمبيوتر على شبكات مختلفة**
   - تأكد أن كلاهما على نفس Wi-Fi

---

### ❌ خطأ: "CORS error"

**الحل:** CORS مفتوح بالفعل في Backend (`ALLOWED_ORIGINS=["*"]`)

إذا استمرت المشكلة:
```python
# في backend/app/main.py
allow_origins=["*"],  # ✅ موجود
```

---

### ❌ خطأ: "Invalid token"

**الحل:**
1. سجل خروج من التطبيق
2. سجل دخول مرة أخرى
3. تأكد أن `JWT_SECRET` نفسه في Frontend و Backend

---

## 📊 ملخص الربط

| من | إلى | العنوان | الحالة |
|----|-----|---------|--------|
| Frontend (Emulator) | Backend | `http://10.0.2.2:5030` | ✅ |
| Frontend (Real Device) | Backend | `http://192.168.0.104:5030` | ✅ |
| Frontend (iOS Sim) | Backend | `http://localhost:5030` | ✅ |
| Browser | Backend | `http://localhost:5030` | ✅ |
| Network | Backend | `http://192.168.0.104:5030` | ✅ |

---

## 🔐 معلومات الأمان

- JWT Token مدته: **10 دقائق** (حسب `.env`)
- تخزين آمن: `flutter_secure_storage`
- HTTPS: غير مفعّل (للتطوير فقط)

⚠️ **للإنتاج**: يجب استخدام HTTPS وإغلاق CORS على نطاقات محددة

---

## 📱 معلومات إضافية

### معرفة IP جهازك

**Windows:**
```powershell
ipconfig | Select-String "IPv4"
```

**Mac/Linux:**
```bash
ifconfig | grep "inet "
# أو
ip addr show
```

### معرفة الأجهزة المتصلة بـ Flutter

```powershell
flutter devices
```

**مثال النتيجة:**
```
Chrome (web) • chrome
Windows (desktop) • windows
Pixel 5 API 33 (emulator) • emulator-5554
```

---

**تم التحديث:** 11 نوفمبر 2025
**الحالة:** ✅ Backend يعمل | Frontend محدّث | جاهز للتشغيل
