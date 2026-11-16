# Wi-Fi diagnostika (Windows noutbuk)

`wifi-diag.ps1` 5 ta bosqichni bajaradi: OLDIN o'lchov, tahlil, ruxsat bilan tuzatish, KEYIN o'lchov va OLDIN/KEYIN jadvali.
Barcha natijalar `natijalar\` papkasiga yoziladi.

## Ishga tushirish

1. Papkani noutbukka yuklab oling (yoki `wifi-diag.ps1` faylining o'zini).
2. **PowerShell'ni "Administrator sifatida" oching**, papkaga o'ting.
3. Hammasi ketma-ket (taxminan 30 daqiqa):

```powershell
powershell -ExecutionPolicy Bypass -File .\wifi-diag.ps1
```

Yoki bosqichma-bosqich:

| Buyruq | Nima qiladi | Admin kerakmi |
|---|---|---|
| `-Step Before` | 12 daqiqa davomida routergacha va 8.8.8.8 gacha ping (soniyasiga 1 ta) | yo'q |
| `-Step Analyze` | sabablarni topadi: tirband kanal, 2.4 GHz, eski drayver, quvvat tejash, rouming, afzal chastota, paketlarni birlashtirish | yo'q |
| `-Step Fix` | avval zaxira oladi, so'ng har bir o'zgarishdan oldin nima va nega o'zgarishini aytib, ruxsat so'raydi | **ha** |
| `-Step After` | `Before` bilan bir xil test | yo'q |
| `-Step Compare` | OLDIN / KEYIN jadvali (ekranga va `taqqoslash_*.md` fayliga) | yo'q |
| `-Step Restore` | `zaxira_*.json` dan hamma sozlamani eski holatiga qaytaradi | **ha** |

Qo'shimcha parametrlar: `-Minutes 15`, `-Target 1.1.1.1`, `-SpikeMs 30`.

## Nimalar o'lchanadi

Router va 8.8.8.8 uchun alohida:
- yo'qotish %;
- oddiy ping (mediana);
- o'rtacha, min va eng yomon (max) ping;
- P99 va eng yomon 1% pinglarning o'rtachasi;
- jitter (ketma-ket pinglar farqining o'rtachasi);
- 30 ms dan oshgan pinglar soni, "sakrashlar" (mediana + 30 ms dan yuqori) va keskin o'zgarishlar (ketma-ket farq 30 ms dan katta).

Wi-Fi bo'yicha:
- ulanish tezligi;
- chastota (2.4/5/6 GHz), kanal, signal (% va dBm), standart;
- drayver versiyasi, sanasi va provayderi;
- quvvat manbai;
- test davomidagi rouming (BSSID almashishi), har 15 soniyada yozib boriladi.

Routergacha ping yomon bo'lsa, muammo Wi-Fi'da. Router yaxshi-yu, faqat 8.8.8.8 yomon bo'lsa, muammo provayderda yoki routerning internet (WAN) tomonida.

## Tuzatish bosqichida nimalar o'zgarishi mumkin (har biri alohida so'raladi)

- Adapterning "quvvat tejash uchun o'chirishga ruxsat" sozlamasi o'chiriladi.
- Quvvat rejasida simsiz adapter "Maksimal unumdorlik"ka o'tkaziladi (zaryadkada ham, batareyada ham).
- Afzal chastota 5 GHz qilinadi.
- Rouming agressivligi pasaytiriladi: bitta router bo'lsa eng past, mesh bo'lsa o'rta-past.
- Paketlarni birlashtirish (Packet Coalescing), MIMO va U-APSD quvvat tejash o'chiriladi.
- 2.4 GHz da qolinsa, kanal kengligi 20 MHz qilinadi.
- Iloji bo'lsa, 5 GHz tarmoqqa ulanadi.
- Drayver **faqat Windows Update orqali** qidiriladi va o'rnatiladi. Intel adapterlar uchun Intel sayti, boshqalari uchun noutbuk ishlab chiqaruvchisi sahifasi ko'rsatiladi.

Har qanday o'zgarishdan oldin quyidagilar saqlanadi:
- `natijalar\zaxira_*.json` (adapterning barcha sozlamalari, quvvat sozlamalari);
- `natijalar\drayver_zaxira_*` (joriy drayverning nusxasi, `pnputil /export-driver` bilan);
- xohlasangiz, Windows tiklash nuqtasi ham yaratiladi.

Router kanalini noutbukdan o'zgartirib bo'lmaydi. Skript eng bo'sh kanallarni tavsiya qiladi, ularni router sozlamalarida qo'lda o'rnatasiz.

## Eslatmalar

- Windows 11 24H2 da `netsh wlan` buyruqlari uchun **Joylashuv (Location)** ruxsati kerak: Sozlamalar > Maxfiylik > Joylashuv > "Ish stoli ilovalariga ruxsat berish".
- OLDIN va KEYIN testlarini bir xil joyda, bir xil quvvat manbaida (zaryadka yoki batareya) va katta yuklab olishlarsiz o'tkazing.
