# Tarjimon — iPhone uchun tarjimon klaviatura

Istalgan ilovada (Telegram, WhatsApp, Instagram, SMS…) o'zbekcha yozasiz, tilni tanlaysiz,
**«Tarjima»** ni bosasiz — tarjima to'g'ridan-to'g'ri xabar maydoniga tushadi.
Tarjimani Google'ning **Gemini** sun'iy intellekti qiladi: u gapning ma'nosini tushunadi,
imlo xatolari, `o'`/`g'` siz yozilgan so'zlar, shevadagi so'zlarni ham to'g'ri o'giradi.

```
┌──────────────────────────────────────────┐
│ 🇷🇺 Rus  🇬🇧 Ingliz  🇹🇷 Turk  🇰🇷 Koreys … ⚙︎ │  ← til tanlash
│ ertaga soat 10 da kelaman, kechikmayman▏ │  ← siz yozgan matn
│ [📋 → 🇺🇿]  [   Tarjima → 🇷🇺 Rus     ]   │
│  q w e r t y u i o p                     │
│  a s d f g h j k l ʻ                     │
│  ⇧ z x c v b n m ⌫                       │
│  123 🌐 , [ bo'sh joy ] . ⏎              │
└──────────────────────────────────────────┘
```

## Imkoniyatlar

- **O'zbekcha → istalgan til.** Rus, ingliz, turk, koreys, qozoq, nemis, arab, xitoy, yapon, fransuz.
- **Ikki usulda yozish mumkin:**
  1. Tarjimon klaviaturasida yozasiz — matn klaviatura oynasida turadi, xabarga faqat tarjima tushadi.
  2. Odatdagi klaviaturada (avtotuzatish bilan) o'zbekcha yozasiz, 🌐 bilan Tarjimon'ga o'tib,
     **«Tarjima»** ni bosasiz — maydondagi o'zbekcha matn tarjimaga almashtiriladi.
- **Suhbatdoshni tushunish:** uning xabarini bosib turib «Nusxalash» qiling, **📋 → 🇺🇿** ni bosing —
  o'zbekcha tarjimasi klaviatura oynasida chiqadi.
- Tarjimadan keyin oynada nima yuborilgani va asl matn ko'rinib turadi — tekshirib olishingiz mumkin.

## Nima kerak

| | |
|---|---|
| **Mac kompyuter** + **Xcode** (App Store'dan bepul) | iPhone ilovasini faqat Mac orqali o'rnatish mumkin. O'zingizda bo'lmasa, tanish dasturchi yoki Mac'i bor do'stingiz 15 daqiqada o'rnatib beradi. |
| **Apple ID** | Bepul Apple ID yetadi, lekin ilova **7 kunda** bir marta o'chib qoladi va Mac'dan qayta o'rnatish kerak bo'ladi. Apple Developer hisobi ($99/yil) bilan bir yil ishlaydi. |
| **Gemini API kaliti** | Bepul: <https://aistudio.google.com/apikey>. Kundalik suhbat uchun bepul limit yetadi. |

## O'rnatish (Mac'da)

1. Xcode'ni App Store'dan o'rnating va bir marta ochib qo'ying.
2. Terminal'da [Homebrew](https://brew.sh) bo'lmasa o'rnating, so'ng XcodeGen'ni o'rnating:

   ```bash
   brew install xcodegen
   ```

3. Shu papkaga o'ting va loyihani yarating:

   ```bash
   cd tarjimon-klaviatura
   ```

   ```bash
   xcodegen
   ```

   ```bash
   open Tarjimon.xcodeproj
   ```

4. `project.yml` dagi `BUNDLE_PREFIX: uz.tarjimon.ilova` qatorini o'zingizga xos nomga o'zgartiring
   (masalan `uz.alisher.tarjimon`), keyin 3-qadamdagi `xcodegen` ni qayta ishga tushiring.
   Bepul Apple ID'da bu nom boshqa birov bilan bir xil bo'lsa, Xcode xato beradi.
5. Xcode'da chapda **Tarjimon** loyihasini bosing → **Signing & Capabilities**.
   **Tarjimon** va **TarjimonKeyboard** — ikkala target'da ham **Team** ga Apple ID'ingizni tanlang
   (Xcode → Settings → Accounts orqali Apple ID qo'shiladi).
6. iPhone'ni kabel bilan ulang. iPhone'da: **Sozlamalar → Maxfiylik va xavfsizlik → Dasturchi rejimi** ni yoqing
   (telefon qayta yonadi).
7. Xcode'ning yuqorisida qurilma sifatida iPhone'ingizni tanlab, ▶︎ (Run) ni bosing.
8. Birinchi marta iPhone'da: **Sozlamalar → Umumiy → VPN va qurilmani boshqarish** → Apple ID'ingiz → **Ishonish**.

## iPhone'da sozlash

1. **Sozlamalar → Umumiy → Klaviatura → Klaviaturalar → Yangi klaviatura qo'shish → Tarjimon**.
2. Ro'yxatda **Tarjimon** ni bosing → **«To'liq ruxsat»** (Allow Full Access) ni yoqing.
   Bu internetga chiqish va nusxadan o'qish uchun kerak. Klaviatura siz yozganlarni faqat
   tarjima uchun Google Gemini'ga yuboradi, boshqa joyga hech narsa yubormaydi va saqlamaydi.
3. Safari'da <https://aistudio.google.com/apikey> → Google hisobingiz bilan kiring →
   **Create API key** → kalitni **Copy** qiling.
4. Istalgan ilovada yozish maydonini bosing, 🌐 ni bosib turib **Tarjimon** ni tanlang,
   **⚙︎** → **«📋 Kalitni saqlash»**. Kalit telefonning xavfsiz xotirasiga (Keychain) yoziladi
   va nusxadan o'chiriladi.

## Bilish kerak bo'lgan narsalar

- **Maxfiylik:** Gemini'ning bepul tarifida Google yuborilgan matnlardan o'z xizmatini yaxshilash uchun
  foydalanishi mumkin. Klaviatura orqali parol, karta raqami va shunga o'xshash maxfiy narsalarni
  tarjima qilmang. (Parol maydonlarida iOS baribir o'zining klaviaturasini chiqaradi.)
- Ba'zi ilovalar (masalan, bank ilovalari) begona klaviaturalarni taqiqlaydi — u yerda Tarjimon chiqmaydi.
- 2-usulda (maydondagi matnni tarjima qilish) iOS klaviaturaga faqat kursordan oldingi matnni beradi;
  juda uzun matnda hammasi kelmasligi mumkin. Kursor matn oxirida tursin.
- Klaviatura lotin alifbosida. Kirillcha yozsangiz ham tarjima ishlaydi (odatdagi klaviaturada yozib, 2-usul bilan).
- `Keyboard/GeminiTranslator.swift` da `Language.all` ro'yxatiga yangi til qo'shish mumkin;
  `models` da Gemini modeli ko'rsatilgan (`gemini-flash-latest` — har doim eng yangi tezkor model).

## Fayllar

| Fayl | Vazifasi |
|---|---|
| `project.yml` | Xcode loyihasi tavsifi (XcodeGen uchun) |
| `App/TarjimonApp.swift` | Asosiy ilova: sozlash bo'yicha ko'rsatma va sinash maydoni |
| `Keyboard/KeyboardViewController.swift` | Klaviaturaning o'zi: tugmalar, til tanlash, tarjima tugmalari |
| `Keyboard/GeminiTranslator.swift` | Gemini API bilan ishlash, tillar ro'yxati, kalitni Keychain'da saqlash |
