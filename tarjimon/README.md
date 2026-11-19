# 🇺🇿 Tarjimon — tarjima qiluvchi iPhone klaviaturasi

O'zbekcha yozasiz, **Tarjima** tugmasini bosasiz va chatga tayyor 🇷🇺 ruscha yoki 🇬🇧 inglizcha matn tushadi.
Ilova Telegram, WhatsApp, Instagram va boshqa ilovalarda ishlaydi. Tarjimani bepul Google Gemini sun'iy intellekti qiladi.

## Klaviatura tugmalari

| Tugma | Vazifasi |
|---|---|
| 🇷🇺 RU / 🇬🇧 EN | Qaysi tilga tarjima qilish |
| 😊 Do'stona / 🎩 Rasmiy | Muloqot uslubi («ты» yoki «Вы») |
| **🇷🇺 Tarjima** | Yozganingizni tarjima qilib, chatga qo'yadi |
| 🇺🇿↵ | Tarjimasiz, o'zbekcha yuboradi |
| ✏️⇄ | Chat maydonidagi matnni tarjimaga almashtiradi (oddiy klaviaturada yozib, keyin shu tugmani bossangiz bo'ladi) |
| 📋→🇺🇿 | Nusxa olingan ruscha/inglizcha xabarni o'zbekchaga tarjima qilib ko'rsatadi |

---

## 1-qadam: bepul Gemini kalitini olish (telefonda ham bo'ladi)

1. https://aistudio.google.com/apikey saytiga Google akkauntingiz bilan kiring.
2. **Create API key** tugmasini bosing.
3. `AIza...` bilan boshlanadigan kalitni nusxa oling va saqlab qo'ying.

> ⚠️ Kalitni hech kimga bermang.

## 2-qadam: Mac'da Xcode o'rnatish

1. Mac'da **App Store** → **Xcode** (bepul) → o'rnatish. Hajmi katta, bir necha soat ketishi mumkin.
2. Xcode'ni bir marta ochib, so'ralgan qo'shimcha komponentlarni o'rnating (iOS platformasi).

## 3-qadam: loyihani yuklab olish

1. GitHub'da shu repo'ni oching va `claude/sleepy-fermat-3c6e5c` branch'ini tanlang.
2. **Code → Download ZIP** ni bosing va arxivni oching.
3. `tarjimon/Tarjimon.xcodeproj` faylini ikki marta bosing, u Xcode'da ochiladi.

## 4-qadam: Apple ID bilan imzolash (bepul)

1. Xcode → **Settings → Accounts** → **+** → **Apple ID**: o'zingizning Apple ID'ingiz bilan kiring.
2. Chapdagi ro'yxatda ko'k **Tarjimon** loyihasini bosing.
3. **TARGETS → Tarjimon** → **Signing & Capabilities** → **Team** maydonidan ismingizni tanlang ("Personal Team").
4. Xuddi shunday **TARGETS → TarjimonKeyboard** uchun ham Team'ni tanlang.

## 5-qadam: iPhone'ga o'rnatish

1. iPhone'ni Mac'ga kabel bilan ulang. Telefonda **"Trust"** (Ishonish) ni bosing.
2. iPhone'da **Developer Mode**'ni yoqing: Settings → Privacy & Security → Developer Mode → yoqing. Telefon qayta yonadi.
3. Xcode'ning tepasidagi qurilmalar ro'yxatidan **iPhone'ingizni** tanlang.
4. ▶ (**Run**) tugmasini bosing.
5. Birinchi marta ishga tushirishda iPhone'da: Settings → General → **VPN & Device Management** → Apple ID'ingiz → **Trust**.

## 6-qadam: sozlash

1. iPhone'da **Tarjimon** ilovasini oching va Gemini kalitini joylang.
2. **Sozlamalarni ochish** → **Keyboards** → **Tarjimon** ni yoqing → **Allow Full Access** ni yoqing.
   Full Access internetga chiqish uchun kerak. Klaviatura yozganlaringizni faqat tarjima uchun Google Gemini'ga yuboradi.
3. Ilovaning **"Sinab ko'rish"** bo'limida tarjimani tekshirib ko'ring.
4. Har qanday chatda 🌐 tugmasini bosing yoki bosib turing va **Tarjimon**ni tanlang.

---

## ⏰ Har 7 kunda yangilash

Bepul Apple ID bilan o'rnatilgan ilova 7 kundan keyin ochilmay qoladi. Bu Apple'ning qoidasi.
Yangilash uchun telefonni yana Mac'ga ulab, Xcode'da ▶ **Run** ni bosish kifoya. Sozlamalar va kalit saqlanib qoladi.

## Muammolar

- **"Failed to register bundle identifier" / "not available"**: loyiha → **Build Settings** → qidiruvga `BUNDLE_PREFIX` deb yozing va qiymatni o'zgartiring, masalan `uz.tarjimon.ismingiz2026`.
- **App Groups xatosi**: Signing & Capabilities → **App Groups** bo'limida guruh yonidagi 🔄 (refresh) tugmasini bosing. Har ikki target uchun ham Team tanlanganini tekshiring.
- **Ilova kalitni ko'rmayapti**: klaviaturadagi **📋 Joylash** tugmasidan foydalaning. Kalitni nusxa olib, shu tugmani bosing.
- **"Full Access ni yoqing"**: Settings → General → Keyboard → Keyboards → Tarjimon → Allow Full Access.
- **"User location is not supported"**: Gemini sizning hududingizda ishlamayapti. Menga yozing, boshqa tarjima xizmatini ulab beraman.
- **Xcode iPhone'ni ko'rmayapti**: Xcode iPhone'dagi iOS versiyasini qo'llashi kerak. Xcode'ni eng so'nggi versiyaga yangilang.
