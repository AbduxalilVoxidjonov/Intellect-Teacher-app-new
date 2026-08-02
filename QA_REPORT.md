# QA hisoboti — Intellect Teacher (Flutter)

**Sana:** 2026-08-01 (audit) / 2026-08-02 (tuzatish) · **Flutter:** 3.44.8 · **Dart:** 3.12.2
**Qamrov:** `lib/` dagi 31 ta faylning hammasi (12 967 qator) auditdan o'tkazildi.

## HOLAT — 2026-08-02

Quyidagi hisobotdagi kamchiliklarning **deyarli hammasi tuzatildi**.

| Tekshiruv | Natija |
|---|---|
| `flutter analyze` | ✅ No issues found |
| `flutter test --no-test-assets` | ✅ **767 o'tdi / 6 skip** |
| `flutter build apk --debug` | ✅ APK qurildi |

- **P0 (8 ta) — hammasi tuzatildi.**
- **P1 (18 ta) — hammasi tuzatildi.**
- **P2 / UI-kit / modellar / formatlash — hammasi tuzatildi**, quyidagi ro'yxatdan tashqari.
- Qolgan **6 ta skip** — ataylab ochiq qoldirilgan, backend tasdig'ini talab qiladi:
  1. `format.dart:91` — `_parse` `.toLocal()` chaqirmaydi (server UTC yuboradimi?)
  2. `format.dart:91` — chegaradan chiqqan sana komponentlari jimgina siljiydi
  3. `format.dart:99` — `fmtDate` yilni ko'rsatmaydi
  4. `models.dart:292,382` — `toJson` aniq `null` yuboradi (backend uni "tozala" deb tushunishi mumkin)
  5. `models.dart` — `grade: 0` haqiqiy bahomi yoki "tozalangan" belgisimi
  6. `group_tests_panel.dart:805` — onlayn test yarim tundan o'ta olmaydi
- Backend tasdig'i kerak bo'lgan, testsiz qolgan boshqa punktlar: hafta kuni
  konvensiyasi (`group_detail_screen.dart:397`), bitta maydonni tozalash
  (`:1320`), `frozenAt` semantikasi, onlayn test vaqt mintaqasi, topshiriq
  muddatining offset'siz yuborilishi.

### Tuzatish paytida topilgan QO'SHIMCHA kamchiliklar (hisobotda yo'q edi, tuzatildi)

- `group_rating_tab.dart` — `Row(crossAxisAlignment: stretch)` cheksiz balandlikdagi
  `Column` ichida → `BoxConstraints forces an infinite height`. Ya'ni guruh ichidagi
  **«Reyting» tabi umuman chizilmayotgan bo'lishi mumkin**. Haqiqiy qurilmada tasdiqlang.
- `models.dart` `_i` — int64 dan oshgan satr maksimal `int` ga "yopishib" qolardi.
- `api_client.dart` — `errorMessage` tuzatilgach login'dagi tanasiz 401 noto'g'ri
  matn bera boshlagan edi (regressiya, darhol tuzatildi).

---

**Testlar:** 0 → **767 test** (6 tasi `skip`), 9 ta test fayli.

---

## 1. Testlarni ishga tushirish

Flutter SDK standart bo'lmagan yo'lda, shuning uchun:

```bash
export FLUTTER_ROOT="/Users/me/iCloud Drive (Archive)/Documents/sdk/flutter"
export PATH="$FLUTTER_ROOT/bin:$PATH"
cd "/Users/me/iCloud Drive (Archive)/Documents/git/Intellect-Teacher-app-new"
flutter test --no-test-assets
```

`--no-test-assets` **shart**: loyiha yo'lida qavs bor (`iCloud Drive (Archive)`) va bu
`flutter_tools`'ning native-asset bosqichida `parseOtoolArchitectureSections` funksiyasini
yiqitadi. Loyihani qavssiz yo'lga ko'chirsangiz bayroq kerak bo'lmaydi.

### Test fayllari

| Fayl | Test | Skip | Nimani qoplaydi |
|---|---:|---:|---|
| `test/models_test.dart` | 243 | 17 | `models.dart` — 52 ta klass, barcha `fromJson`/`toJson` |
| `test/api_client_test.dart` | 126 | 8 | `ApiClient` + 34 ta `TeacherApi` endpoint (soxta Dio adapteri) |
| `test/session_test.dart` | 44 | 4 | `Session` — login/logout/persist/tema |
| `test/format_test.dart` | 115 | 9 | `format.dart` + `app_theme.dart` sof funksiyalari |
| `test/widgets/ui_widgets_test.dart` | 87 | 7 | `ui.dart`, `sub_scaffold.dart`, `AppTheme` |
| `test/widgets/screens_test.dart` | 32 | 7 | Jurnal, Baholash, Login, Testlar, Maosh ekranlari |
| `test/helpers/fake_api.dart` | — | — | Soxta `HttpClientAdapter` (yangi paket qo'shilmagan) |
| `test/widgets/screen_harness.dart` | — | — | Ekran testlari uchun harness |

### `skip` qilingan testlar nimani anglatadi

Har bir tasdiqlangan kamchilik uchun **ikkita** test yozilgan:

1. **Hozirgi xatti-harakatni qotiruvchi test** (o'tadi) — `// BUG-Xn:` izohi bilan.
   Kod o'zgarsa bu test yiqiladi va o'zgarish e'tibordan chetda qolmaydi.
2. **To'g'ri xatti-harakat shartnomasi** (`skip`) — kamchilik tuzatilgach `skip`ni olib
   tashlaysiz va test yashil bo'lishi kerak.

Ya'ni **52 ta skip = 52 ta hujjatlashtirilgan kamchilik shartnomasi**, e'tiborsizlik emas.

---

## 2. P0 — Relizni to'sadigan kamchiliklar

### P0-1 · Sessiya tugagach ilovaga QAYTA KIRIB BO'LMAYDI (cheksiz 401 sikli)
`lib/services/session.dart:80-94` + `lib/services/push.dart:229-234` + `lib/api/api_client.dart:49-56`

Zanjir:
1. Har qanday non-login 401 → `onUnauthorized()` → `logout()` (qorovulsiz, fire-and-forget).
2. `logout()` avval `await PushService.clear()` qiladi, `_token`ni **keyin** tozalaydi.
3. `clear()` da `ApiClient.token == null` tekshiruvi **yo'q** (`_sendToBackend`da bor) va
   `_lastToken` hech qachon `null` qilinmaydi → doim `DELETE /teacher/notifications/register`.
4. Bu paytda token allaqachon tozalangan → `Authorization` sarlavhasi yo'q → endpoint
   `[Authorize]` → **401** → 2-bandga qaytamiz.

`clear()` dagi `catch (_)` hamma narsani yutadi — logda hech nima ko'rinmaydi.

**Foydalanuvchi ko'radigan oqibat:** sikl ishlab turganda login **muvaffaqiyatli** bo'ladi,
lekin keyingi iteratsiyaning 401'i darhol yana `logout()` chaqiradi → o'qituvchi login
ekraniga qaytariladi va **ilovani majburan yopmaguncha kira olmaydi**.

**Tuzatish:**
```dart
// session.dart
void _onUnauthorized() { if (_token == null || _loggingOut) return; logout(); }
// push.dart clear()
if (ApiClient.token == null) { _lastToken = null; return; }
```
va `/notifications/register` yo'lini 401 interceptoridan chiqarib tashlash.

> Test: `session_test.dart` da `Session` darajasida qotirilgan (BUG-A8). To'liq sikl
> Firebase'siz takrorlanmaydi — `getToken()` `[core/no-app]` bilan yiqiladi.

---

### P0-2 · Login abadiy "yuklanmoqda" holatida qotib qoladi
`lib/services/session.dart:52`, `lib/screens/login_screen.dart:29-38`

`res.data as Map<String, dynamic>` — `TypeError` bu `Error`, `Exception` **emas**, shuning
uchun `:63` dagi `on Exception` uni tutmaydi. `_submit()` da `try/catch` yo'q → `_loading`
hech qachon `false` bo'lmaydi → spinner aylanaveradi, tugma o'lik, faqat ilovani yopish qoladi.

Qachon sodir bo'ladi (status 200 bo'lsa ham):
- bo'sh tana + JSON content-type → `null`
- 204 / content-type'siz bo'sh tana → `''`
- HTML sahifa (WAF, proxy, mehmonxona Wi-Fi captive portal) → `String`

**Tuzatish:** `final data = res.data; if (data is! Map) return "Server javobi noto'g'ri";`
va `on Exception` → `catch (_)`.

> Test: `session_test.dart`, BUG-A2 (3 variant) — `throwsA(isA<TypeError>())` bilan qotirilgan.

---

### P0-3 · Kelmagan o'quvchi jurnalda YASHIL ✓ bo'lib ko'rinadi
`lib/screens/group_detail_screen.dart:65-73`, `:768`, `:774-780`

`_loadReasons()` xatoni `catch (_) {}` bilan yutadi. `_reasons` bo'sh qolsa `_cell` sababni
`reasonById[...]` orqali qidiradi va topilmasa `reason == null` bo'ladi → "keldi" tarmog'i
ishga tushadi.

**Ikkita mustaqil trigger, ikkalasi ham real:**
1. `/teacher/meta` bir marta yiqiladi (401, tarmoq) — qayta urinish yo'q, indikator yo'q.
2. **Hech qanday xato kerak emas:** Sozlamalardan davomat sababi o'chirilsa, o'sha sabab
   ishlatilgan **barcha tarixiy yozuvlar** doimiy ravishda yashil ✓ ga aylanadi.

Bundan tashqari Davomat tabi `e?.reasonId != null` ni to'g'ridan-to'g'ri o'qiydi (`:960`),
ya'ni **bitta ekranning ikki tabi bir o'quvchi haqida qarama-qarshi ma'lumot beradi**.

**Tuzatish:** `_cell`da `entry.reasonId != null` bo'lsa qidiruv natijasidan qat'i nazar
"yo'q" deb hisoblash (`label = reason?.short ?? '?'`), va `_reasons` bo'sh bo'lsa banner ko'rsatish.

> Test: `screens_test.dart`, **BUG-S1 — ishlaydigan kod bilan tasdiqlangan.**
> Nazorat testi ko'rsatadiki, meta yuklanganda ayni fixture `K` kodini chizadi.

---

### P0-4 · Reyting jimgina noto'g'ri bo'ladi (baholash yiqilsa)
`lib/screens/group_detail_screen.dart:98-106`, `:122-143`

`_loadGrading` xatoni yutadi va `_grading = null` qiladi — **hech qanday xabar yo'q**.
Natijada "Jami" ustuni faqat jurnal baholarini ko'rsatadi va **qatorlar tartibi o'zgaradi** —
o'qituvchi ishonchli ko'rinadigan, ammo noto'g'ri reytingni ko'radi.

Ikkinchi nuqson: `_loadGrading` `_load`dan `await`siz chaqiriladi (`:87`) va so'rov tokeni
yo'q. "May" → "Iyun" chiplarini tez bosish May'ning baholash ma'lumotini Iyun jurnaliga
ulab qo'yadi. (`group_rating_tab.dart:124` da to'g'ri `_reqId` namunasi bor.)

**Tuzatish:** `int _reqId` tokeni; xatoda `_gradingFailed` bayrog'i va Jami ustunida `0` emas `—`.

> Test: `screens_test.dart`, **BUG-S2 — tasdiqlangan.** Yig'indi `11 → 6` ga tushadi va
> tartib Ali→Vali dan Vali→Ali ga aylanadi; `error_outline` ham, `SnackBar` ham yo'q.

---

### P0-5 · Bo'sh javob tanasi ~26 ta endpointni yiqitadi
`lib/api/teacher_api.dart`

dio 5.10 bo'sh tanani content-type'ga qarab `''` (String) yoki `null` qaytaradi. Faqat
`contracts():536` va `rating():432` to'g'ri himoyalangan (`is! List` / `is! Map`).

- **`data == null` qorovuli ishlamaydi** (real 204'da `''` keladi): `profile():34`,
  `meta():156`, `salary():257`.
- **Qorovulsiz `as List`** (7 ta): `myClasses:40`, `evalTypes:50`, `assignments:93`,
  `assignmentTypes:145`, `chatClasses:394`, `chat:403`, `groupTests:445`.
- **Qorovulsiz `as Map`** (19 ta): `evalBoard:65`, `createAssignment:101`,
  `assignmentResults:117`, `uploadFile:139`, `school:162`, `notifications:170`,
  `gradingBoard:217`, `groupJournal:268`, `rescheduleLesson:356`, `sendChat:414`,
  `lastMessages:421`, `testDetail:454`, `uploadTestFile:465`, `createTest:486`,
  `setTestScore:524` + yuqoridagi 3 ta.

Eng ehtimolli: bo'sh chat kanali ro'yxati, bo'sh topshiriqlar, bo'sh bildirishnomalar.

**Tuzatish:** `TeacherApi`ga `_asList(d)` / `_asMap(d)` yordamchilarini qo'shib, barcha
castlarni ular orqali o'tkazish.

> Test: `api_client_test.dart`, BUG-A4 (3 ta) va BUG-A5 (4 ta) — ikkala bo'sh-tana varianti
> (`''` va `null`) alohida qotirilgan.

---

### P0-6 · `GroupJournal.fromJson` `group` maydoni yo'q bo'lsa yiqiladi
`lib/models/models.dart:1042`

Butun fayldagi yagona xom cast: `j['group'] as Map`. `group` kelmasa yoki `null` bo'lsa
`TypeError` → guruh sahifasi umuman ochilmaydi, sababi esa umumiy xato bannerida ko'rinmaydi.
Qiziq tomoni: `GroupJournalInfo.fromJson({})` muvaffaqiyatli ishlaydi — hamma maydon
`_s`/`_i`/`_d` orqali o'tadi.

**Tuzatish:** `OnlineTest.parse` (`:1488`) dagi namunani takrorlash —
`j['group'] is Map ? Map<String,dynamic>.from(...) : const {}`.

> Test: `models_test.dart`, BUG-M1.

---

### P0-7 · Xavfsizlik: FCM token release build'da logga yoziladi
`lib/services/push.dart:219-221`

`debugPrint` release rejimida **o'chirilmaydi** (faqat `assert` tanasi va `kDebugMode`
qorovullari o'chadi — `:208` da to'g'ri ishlatilgan). Prod APK har login va har sovuq
ishga tushishda qurilmaning to'liq FCM tokenini logcat'ga yozadi. Logcat'ga kirish
huquqi bor har kim (ADB, MDM log yig'uvchi, crash-reporter) o'sha o'qituvchining
qurilmasiga ixtiyoriy push yubora oladi.

Qo'shimcha oqib chiqish: `:255` `${e.details}` — serverning xom javob tanasi.

**Yondosh muammolar:**
- JWT oddiy `SharedPreferences`da (`session.dart:9,73`) — `flutter_secure_storage` yo'q.
- `android/app/src/main/AndroidManifest.xml:18-21` da `android:allowBackup="false"` yo'q →
  standart `true` → token va foydalanuvchi obyekti Google Drive backup'ga yuklanadi va
  istalgan yangi qurilmaga tiklanadi.
- Token muddati (`exp`) hech qachon tekshirilmaydi; refresh token yo'q.

**Tuzatish:** 219-221 ni `kDebugMode` ichiga olish yoki o'chirish; `allowBackup="false"` +
`dataExtractionRules`; tokenni secure storage'ga ko'chirish; `init()` da `exp` ni dekod qilish.

---

### P0-8 · 5xx/timeout'da o'qituvchi inglizcha `DioException` matnini ko'radi
`lib/api/api_client.dart:40`

`validateStatus: (s) => s != null && s < 500` — 5xx `onResponse`ga umuman yetib bormaydi,
dio `DioException` otadi. `_check` / `ApiException` / `errorMessage` chetlab o'tiladi.

502'da o'zbek o'qituvchi SnackBar'da 4 qator ingliz matni va MDN havolasini ko'radi.
`e.toString()` ni to'g'ridan-to'g'ri chiqaradigan joylar: `group_tests_panel.dart:67,117,346,377,751,847`,
`group_detail_screen.dart:91,209,264`, `group_grading_section.dart:93,130,188`,
`tests_screen.dart:50`, `feedback_screen.dart:109`, `assignment_detail_screen.dart:230`,
`assignments_screen.dart:97,383`.

**Tuzatish:** `onError` interceptor qo'shib hamma narsani `ApiException`ga o'rash.

> Test: `api_client_test.dart`, BUG-A3.

---

## 3. P1 — Jiddiy (ma'lumot noto'g'ri yoki ilova yiqiladi)

| # | Fayl:qator | Muammo |
|---|---|---|
| P1-1 | `group_tests_panel.dart:356` | `firstWhere` `orElse`siz → `StateError`. `_ctrls`/`_nodes` hech qachon tozalanmaydi; o'quvchi ro'yxatdan chiqsa, uning `FocusNode` listeneri `_save`ni chaqiradi va **"Bad state: No element"** bilan yiqiladi. |
| P1-2 | `group_tests_panel.dart:654` | `_options = o.optionCount < 2 ? 4 : o.optionCount` — faqat pastdan cheklangan. `optionCount ≥ 7` bo'lsa `DropdownButton` assert'i ishlaydi va **tahrirlash oynasi umuman ochilmaydi**. `clamp(2, 6)` kerak. |
| P1-3 | `group_tests_panel.dart:354` | `_savingId != null` qorovuli **global**, o'quvchiga bog'liq emas. A o'quvchining bali saqlanayotganda B ning bali **jimgina yo'qoladi** va eski qiymat qaytarib yoziladi. |
| P1-4 | `group_detail_screen.dart:952-963` | Davomat foizi grid "keldi emas" deb chizadigan darslarni "keldi" deb sanaydi (`presentDefaultFrom` e'tiborga olinmaydi). ✅ **Test bilan tasdiqlangan (BUG-S3): grid `·`, Davomat `2/2 · 100%`.** |
| P1-5 | `group_detail_screen.dart:132-136` | "Jami" `memberStart`dan oldingi bahoni sanaydi, holbuki o'sha katak bo'sh va bosilmaydigan qilib chiziladi — o'qituvchi uni o'chira olmaydi. ✅ **Tasdiqlangan (BUG-S4).** |
| P1-6 | `group_detail_screen.dart:790-805` | `mastery` emoji davomat sababidan ustun turadi → kelmagan o'quvchi 🙋 bo'lib ko'rinadi. ✅ **Tasdiqlangan (BUG-S5).** |
| P1-7 | `messages_screen.dart:208,219-235` | 4 soniyalik `Timer.periodic` da in-flight qorovuli yo'q va `id` bo'yicha dedupe yo'q → sekin tarmoqda xabarlar **takrorlanib ketadi**. |
| P1-8 | `messages_screen.dart:208` + `shell.dart:110` | `IndexedStack` tabni dispose qilmaydi va `WidgetsBindingObserver` yo'q → chat polleri boshqa tabda ham, ilova fonda ham to'xtamaydi (soatiga ~900 so'rov). |
| P1-9 | `api_client.dart:76-88` | `errorMessage` `fallback`ni status switch'idan **oldin** tekshiradi → login'dagi tanasiz 429/403 "Login yoki parol noto'g'ri" bo'lib ko'rinadi va foydalanuvchi qayta-qayta urinib rate-limitni chuqurlashtiradi. ✅ Test: BUG-A1. |
| P1-10 | `session.dart:57-60` | Rol tekshiruvi **ochiq yiqiladi**: `role` yo'q bo'lsa istalgan CRM akkaunti o'qituvchi ilovasiga kiradi. ✅ Test: BUG-A6 (3 variant). |
| P1-11 | `assignment_detail_screen.dart:224` | `"8,5"` (vergulli kasr — o'zbek/rus klaviaturasi) → `null` → ball **jimgina saqlanmaydi**, lekin oyna yopiladi va "saqlandi" taassuroti qoladi. `maxScore` chegarasi ham, manfiy ham tekshirilmaydi. "Bajarmadi" holatida ham ball yuboriladi. |
| P1-12 | `assignments_screen.dart:374` | `double.tryParse(...) ?? 100` — `"abc"`, `"7,5"`, `"-10"`, `"0"` jimgina 100 ga aylanadi yoki qabul qilinadi. |
| P1-13 | `salary_screen.dart:28-37,67-73` | Tarmoq xatosi "Maosh ma'lumoti yo'q" deb ko'rsatiladi — puli bor o'qituvchiga "yo'q" deyiladi. `RefreshIndicator` ham yo'q. |
| P1-14 | `tests_screen.dart:47-52,61-65` | Xato holatida pull-to-refresh ham, qayta urinish tugmasi ham yo'q, `initState` bir marta ishlaydi, `IndexedStack` tabni saqlaydi → **ilovani qayta ishga tushirmaguncha tuzatib bo'lmaydi**. |
| P1-15 | `api_client.dart:52-56` → `main.dart:44` | Pushed sub-ekranda (Maosh, Shartnomalar) 401 bo'lsa `home` LoginScreen'ga o'tadi, lekin sub-ekran stack'ning tepasida qolaveradi — o'lik sessiyada ishlayotgandek ko'rinadi. |
| P1-16 | `group_rating_tab.dart:213-215` | Reyting muzlatilgan o'quvchilarni qo'shadi, Jurnal/Davomat esa chiqarib tashlaydi → bitta ekranda ikki xil o'quvchilar soni. |
| P1-17 | `group_rating_tab.dart:105-111,266` | Baholash yiqilsa butun reyting hech qanday belgisiz **0%** ga aylanadi. |
| P1-18 | `dashboard_screen.dart:297-306` | Joriy oy ledger'da bo'lmasa "Maosh" plitasi **butun davr yig'indisini** ko'rsatadi (24 mln vs 4 mln), yorliq esa o'zgarmaydi. |

---

## 4. P2 — O'rta (UX, ishonchlilik, ma'lumot yo'qolishi)

**Ma'lumot yo'qolishi / tasdiqsiz buzuvchi amallar**
- `group_detail_screen.dart:1295-1304` — "Tozalash" baho + davomat + uy vazifa + xulq +
  o'zlashtirishni bitta bosishda o'chiradi, tasdiq so'ralmaydi, "Saqlash" tugmasining ustida turadi.
- `group_detail_screen.dart:1521-1526` — "✗ Hammasi kelmadi" butun guruhni darhol yo'q deb
  belgilaydi; "✓ Hammasi keldi" dan atigi 10px pastda.
- `group_detail_screen.dart:1576-1581` — "Asl kuniga qaytarish" tasdiqsiz.
- `group_tests_panel.dart:827` — onlayn testni oflaynga o'tkazish PDF va javob kalitini
  ogohlantirishsiz tashlab yuboradi.
- `group_tests_panel.dart:333-341` — pull-to-refresh yozilgan lekin saqlanmagan ballarni o'chiradi.
- `messages_screen.dart:253` — yuborish javobi kelganda yangi yozilayotgan matn tozalanadi.

**Xatolarni yashirish**
- `group_detail_screen.dart:293-295` — bitta muvaffaqiyatsiz yangilash to'liq yuklangan
  jurnalni xato satri bilan almashtiradi (`group_grading_section.dart:96-99` da to'g'ri namunasi bor).
- `dashboard_screen.dart:74-92` — bildirishnomalar server xatosidan qat'i nazar "o'qildi" qilinadi.
- `rating_screen.dart:102-126` — `_loading` hech qachon `true` bo'lmaydi → qorovul ishlamaydi,
  parallel so'rovlar ketadi.

**Vaqt mintaqasi (barchasi backend tasdiqlashini talab qiladi)**
- `format.dart:91` — `_parse` `.toLocal()` chaqirmaydi → `fmtTime`/`fmtDate` UTC ko'rsatadi.
  `messages_screen.dart:390` esa `.toLocal()` ishlatadi → **bitta ekranda ikki xil sana**.
- `group_tests_panel.dart:669-675,816-817` — onlayn test oynasi mintaqasiz yoziladi va xom
  kesish bilan o'qiladi; server UTC'ga normallashtirsa oyna har tahrirda siljiydi.
- `assignments_screen.dart:362-364` — muddat `.toIso8601String()` bilan offset'siz yuboriladi.

**Boshqa**
- `group_tests_panel.dart:805` — onlayn test yarim tundan o'ta olmaydi (22:00–00:30 rad etiladi).
- `group_tests_panel.dart:683-685` — savollar soni 200 ga jimgina qisqartiriladi.
- `group_detail_screen.dart:244` — ommaviy davomat hali guruhga qo'shilmagan o'quvchilarga ham yoziladi.
- `group_detail_screen.dart:1320-1329` + `teacher_api.dart:292-296` — bitta maydonni
  (masalan bahoni) **tozalab bo'lmaydi**: `null` maydonlar so'rovdan olib tashlanadi.
- `group_detail_screen.dart:123` — `frozenAt` modelda bor, lekin `lib/` da **hech qayerda
  ishlatilmaydi** → oy o'rtasida muzlatilgan o'quvchining butun oyi yo'qoladi.
- `group_detail_screen.dart:397` — "Kunlar" qatorida hafta kuni konvensiyasi tekshirilmagan
  (0=Dushanba deb qabul qilingan). Tekshirish: Du+Cho guruhini oching — ustun sarlavhalari
  `Du, Cho` bo'lsa-yu info qatori `Ya, Se` desa, backend 0=Yakshanba ishlatadi.
- `contracts_screen.dart:48-58` — `launchUrl` natijasi e'tiborsiz qoldiriladi (jimgina hech
  nima bo'lmaydi); URL `Uri.resolve` bilan emas, satr qo'shish bilan yasaladi.
- `account_screen.dart:62-66` — parol o'zgartirish muvaffaqiyatli bo'lsa `_busy` hech qachon
  `false` bo'lmaydi → pop ishlamasa tugma abadiy o'chiq qoladi.
- `shell.dart:44-52,66-68` — tab tarixi desinxronlashadi.
- `dashboard_screen.dart:43-52` — 7 endpoint ketma-ket yuklanadi (`Future.wait` emas), ~2 s kutish.

---

## 5. Modellar va formatlash qatlamining kamchiliklari

Barchasi `models_test.dart` / `format_test.dart` da qotirilgan.

| Kod | Joy | Muammo |
|---|---|---|
| M2 | `models.dart:49` | `_list` ro'yxat ichida `null` element bo'lsa yiqiladi — bitta `null` butun javobni yo'q qiladi |
| M3 | `models.dart:48,55,60,65` | `{'days':'1,3,5'}`, `{'grades':[]}` kabi shakl mos kelmasa `TypeError` |
| M4 | `models.dart:9` | `_sn('')` → `''`, `null` emas → `dueDate != null` tekshiruvi o'tadi va UI **bo'sh** qoladi ("Muddat yo'q" o'rniga) |
| M5 | `models.dart:15,28` | `_i('4.0')` → **0** (baho yo'qoladi); `_d('1,5')` → **0.0** (qarzdor o'quvchi yashil ko'rinadi) |
| M6 | `models.dart:55,60` | `null` element `"null"` satriga / `0` ga aylanadi — UI'da so'zma-so'z "null" chiqadi |
| M7 | `models.dart:40` | `_b('1')` → `false` (faqat `'true'` ishlaydi) |
| M8 | `models.dart:44` | `_bn('')` → `false`, `null` emas |
| M9 | `models.dart:1284` | `modules: []` + to'ldirilgan `levels` → daraxt **bo'sh** chiqadi |
| M10 | `models.dart:1476-1485` | `optionCount` cheklanmaydi; `mode:'ONLINE'` → `isOnline == false`; `answerKey` uzunligi `questionCount` bilan solishtirilmaydi |
| M11 | `models.dart:292,382` | `toJson` ixtiyoriy maydonlar uchun doim aniq `null` yuboradi (`teacher_api.dart` esa hamma joyda `null`ni olib tashlaydi — nomuvofiqlik) |
| M12/M15 | `models.dart:28` | `_d('NaN')`/`_d('1e400')` → cheksiz/NaN → keyin `fmtMoney`/`gradeColor` da `UnsupportedError` |
| M13 | `models.dart:1489` | `OnlineTest.parse({1:'x'})` → `TypeError` → butun testlar ekrani yiqiladi |
| M14 | `models.dart:65` | `_intMap` String bo'lmagan kalitda yiqiladi |
| F1/F2 | `format.dart:18,77` | `gradeColor(NaN)`, `fmtMoney(NaN)` → `UnsupportedError` **build ichida** (qizil ekran) |
| F3 | `format.dart:84` | `fmtMoney(-0.4)` → `"−0"` ("Qoldi: −0") |
| F4 | `format.dart:108` | `fmtMonth('2026-13')` → `"2026-13 2026"` |
| F6 | `format.dart:91` | `fmtDate('2026-02-31')` → "3 Mart" (jimgina siljiydi, yil ko'rsatilmaydi) |
| F7 | `format.dart:71` | `initials('🎓 Ali')` surrogat juftlikni buzadi; `initials('- -')` → `"--"` |
| F9 | `format.dart:97` | `fmtDate('   ')` → `'   '` (trim qilinmaydi), `fmtTime('   ')` esa `''` — nomuvofiq |
| A9 | `session.dart:24-25` | `fullName`/`teacherId` getterlari serverdan raqamli qiymat kelsa **build paytida** `TypeError` beradi |

---

## 6. UI-kit kamchiliklari

| Kod | Joy | Muammo |
|---|---|---|
| U1 | `ui.dart:144-158` | `NaN.clamp(0,1)` → `1.0` → progress bar **100% to'la** ko'rinadi, xato o'rniga |
| U2 | `ui.dart:410-429` | `GradeBox` 1–5 uchun mo'ljallangan, lekin `assignment_detail_screen.dart:177` unga 0–100 ball beradi → 5 ham, 100 ham bir xil to'q yashil; `87.5` 30×30 katakka sig'may **jimgina kesiladi** (Flutter xato bermaydi) |
| U3 | `ui.dart:254-258` | `imageUrl` berilsa bosh harflar butunlay yo'qoladi; rasm yuklanmasa bo'sh doira qoladi (`DecorationImage`da `errorBuilder` yo'q) |
| U4 | `app_theme.dart:107` | `updateShouldNotify` faqat `isDark`ni solishtiradi → palitra almashsa dependentlar **umuman qayta qurilmaydi** |
| U5 | `ui.dart:394-401` | Ikonkali `SButton` tor joyda `RenderFlex overflowed by 216 pixels` beradi (`Flexible`/`overflow` yo'q) |
| NEW-1 | `ui.dart:267-317` | `EmptyState`/`Loader` balandligi cheklangan ota-widget ichida pastdan toshadi (scroll qilinmaydigan `Column` + 48px padding) |

---

## 7. O'lik kod / keraksiz og'irlik

- **`fl_chart` va `cached_network_image` hech qayerda import qilinmagan** — APK'da ortiqcha yuk.
  Dashboard/Maosh/Reytingda "grafik" yo'q; ular `LinearProgressIndicator` va qo'lda yozilgan
  `CustomPaint` halqa.
- **`assignments_screen.dart`, `assignment_detail_screen.dart`, `learning_screen.dart`
  umuman ishlatilmaydi** — `shell.dart:36-42` da 5 ta tab bor (Dashboard, Reyting, Testlar,
  Xabarlar, Profil), "Topshiriqlar" yo'q. Ulardagi kamchiliklar (P1-11, P1-12) hozircha
  foydalanuvchiga yetib bormaydi, lekin ekran qayta ulangunga qadar tuzatilishi kerak.
- `teacher_api.dart:133` `uploadFile` — chaqiruv joyi yo'q.
- `teacher_api.dart:104` `updateAssignment` hozirgi holida topshiriqning materiallari,
  savollari va `referenceText`ini **o'chirib yuboradi** (`MaterialInput`da `id` yo'q).
- `models.dart:965` `frozenAt` — modelda bor, ishlatilmaydi.

---

## 8. Tavsiya etilgan tuzatish tartibi

**1-bosqich (darhol, reliz oldidan):** P0-1, P0-2, P0-7.
Bu uchtasi mos ravishda ilovaga kirishni to'sadi, login'ni qotiradi va xavfsizlik
tokenini oshkor qiladi. Uchalasi ham ozgina o'zgarish talab qiladi.

**2-bosqich (ma'lumot ishonchliligi):** P0-3, P0-4, P1-4, P1-5, P1-6.
Bularning hammasi o'qituvchiga **noto'g'ri, ammo ishonchli ko'rinadigan** ma'lumot beradi —
davomat va reyting rasmiy hisobotlarga asos bo'lgani uchun bu eng qimmat toifadagi xatolar.
Har biri uchun tayyor test bor: tuzatgach mos `skip`ni olib tashlang.

**3-bosqich (barqarorlik):** P0-5, P0-6, P0-8, P1-1, P1-2, P1-3, M2, M3, M13.
Yiqilishlar va tushunarsiz xato matnlari.

**4-bosqich:** qolgan P1/P2 va UI-kit.

Har bir tuzatishdan keyin:
```bash
flutter test --no-test-assets
```
Tuzatilgan kamchilikning `skip:` bayrog'ini olib tashlang — o'sha test yashil bo'lishi kerak,
uning juftligi (hozirgi xatti-harakatni qotiruvchi test) esa **yiqilishi kerak** va uni
o'chirish yoki yangilash lozim. Shu ikkilik tuzatishning haqiqatan ishlaganini isbotlaydi.

---

## 9. Muhit haqida ogohlantirish

Loyiha va Flutter SDK ikkalasi ham **iCloud Drive** ichida turibdi va ikkalasining ham
`.git` papkasi qisman yo'q qilingan (`HEAD`, `config`, `refs` yo'qolgan) — iCloud fayllarni
"evict" qilgani uchun. SDK tiklandi, loyiha repositoriysi ham tiklanmoqda.

**Tavsiya:** loyihani ham, SDK'ni ham iCloud sinxronizatsiyasidan tashqaridagi papkaga
(masalan `~/dev/`) ko'chiring. Bu bir vaqtning o'zida `--no-test-assets` zaruriyatini ham
yo'qotadi (sabab — yo'ldagi qavslar).
