# 👕 Ertaga nima kiyaman?

Ertangi ob-havoga qarab, **o'zingizdagi kiyimlardan** libos tanlab beradigan veb-dastur.

## Qanday ishlaydi
1. **Garderob** bo'limida kiyimlaringiz rasmini yuklaysiz (bir nechtasini birdan).
   Dastur rasmdan asosiy rangni avtomatik aniqlaydi, fayl nomidan turini taxmin qiladi
   (`jeans.jpg` → shim, `boots.jpg` → poyabzal). Har bir kiyimni bosib turi, issiqligi (1–5),
   uslubi va suv o'tkazmasligini to'g'rilang.
2. **Sozlamalar**da shaharni kiriting yoki "📍 Joriy joyim"ni bosing (standart — Toshkent).
3. **Ertangi libos** bo'limi ertangi prognozni (Open-Meteo, kalit talab qilinmaydi) oladi va:
   - ertalabki, kunduzgi va "sezilish" haroratidan, shamoldan samarali haroratni hisoblaydi;
   - har bir qavat (ust, past, kurtka, poyabzal, bosh kiyim, sharf) uchun kerakli issiqlikni aniqlaydi;
   - yomg'ir/qorda suv o'tkazmaydigan kurtka va poyabzalni afzal ko'radi;
   - ranglarni uyg'unlashtiradi (neytral ranglar + ko'pi bilan bitta yorqin aksent);
   - yaqinda kiyilgan narsalarni navbatga suradi ("✅ Shuni kiyaman" bosilganda belgilanadi);
   - tadbir turiga (kundalik / rasmiy / sport) mos uslubni tanlaydi.
   "🔄 Boshqa variant" — yangi kombinatsiya.

Rasmlar faqat brauzeringizda (IndexedDB) saqlanadi, serverga yuborilmaydi.
Boshqa qurilmaga o'tkazish uchun Sozlamalar → Eksport/Import.

## Ishga tushirish
`kiyim/index.html` faylini brauzerda oching — boshqa hech narsa kerak emas.
Telefonda qulay foydalanish uchun GitHub Pages orqali joylash mumkin.
