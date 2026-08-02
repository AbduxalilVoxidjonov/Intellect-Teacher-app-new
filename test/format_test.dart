// Formatlash / rang yordamchilari uchun unit-testlar.
//
// Nishonlar:
//   lib/utils/format.dart
//   lib/theme/app_theme.dart (sof funksiyalar: balanceColor, buildMaterialTheme, konstantalar)
//
// `// BUG-Fn:` izohli testlar HOZIRGI (noto'g'ri) xatti-harakatni QOTIRIB QO'YADI —
// ular yashil bo'lishi kerak. Har birining ortidan `skip:` bilan "to'g'ri shartnoma"
// testi keladi; bug tuzatilganda `skip` olib tashlanadi va pin testi yangilanadi.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher/theme/app_theme.dart';
import 'package:teacher/utils/format.dart';

// Manbadagi aniq HEX qiymatlar — palitra o'zgarsa test yiqiladi.
const _emerald500 = Color(0xFF10B981);
const _emerald600 = Color(0xFF059669);
const _emerald700 = Color(0xFF047857);
const _emerald800 = Color(0xFF065F46);
const _emerald900 = Color(0xFF064E3B);

const _emerald50 = Color(0xFFECFDF5);
const _emerald100 = Color(0xFFD1FAE5);
const _emerald200 = Color(0xFFA7F3D0);
const _emerald400 = Color(0xFF34D399);

const _subjPalette = <Color>[
  Color(0xFF2563EB),
  Color(0xFF7C3AED),
  Color(0xFF0D9488),
  Color(0xFFDB2777),
  Color(0xFFEA580C),
  Color(0xFFB45309),
  Color(0xFF16A34A),
  Color(0xFF0891B2),
  Color(0xFF4F46E5),
  Color(0xFF65A30D),
];
const _subjFallback = Color(0xFF64708A);

const _minusSign = '−'; // U+2212 MINUS SIGN (ASCII '-' EMAS!)
const _space = ' '; // U+0020 SPACE (NBSP emas!)

void main() {
  // ---------------------------------------------------------------------------
  group('gradeColor', () {
    test('1–5 baholari uchun emerald 500→900', () {
      expect(gradeColor(1), _emerald500);
      expect(gradeColor(2), _emerald600);
      expect(gradeColor(3), _emerald700);
      expect(gradeColor(4), _emerald800);
      expect(gradeColor(5), _emerald900);
    });

    test('chegaralar: 0 pastdan, 6 yuqoridan qirqiladi', () {
      expect(gradeColor(0), _emerald500);
      expect(gradeColor(6), _emerald900);
      expect(gradeColor(100), _emerald900);
    });

    test('manfiy qiymatlar eng och rangga tushadi', () {
      expect(gradeColor(-1), _emerald500);
      expect(gradeColor(-99.7), _emerald500);
    });

    test('.round() semantikasi: 1.4→1, 1.5→2, 4.6→5', () {
      expect(gradeColor(1.4), _emerald500, reason: '1.4.round() == 1');
      expect(gradeColor(1.5), _emerald600, reason: '1.5.round() == 2 (yarmi yuqoriga)');
      expect(gradeColor(4.6), _emerald900, reason: '4.6.round() == 5');
      expect(gradeColor(2.5), _emerald700, reason: '2.5.round() == 3');
      expect(gradeColor(0.5), _emerald500, reason: '0.5.round() == 1');
      expect(gradeColor(5.4), _emerald900);
    });

    test('-2.5 nolga qarab emas, noldan uzoqqa yaxlitlanadi (barcha holda qirqiladi)', () {
      expect(gradeColor(-2.5), _emerald500);
    });

    test('int va double bir xil natija beradi', () {
      expect(gradeColor(3), gradeColor(3.0));
      expect(gradeColor(3), gradeColor(2.9));
    });
  });

  // ---------------------------------------------------------------------------
  group('gradeCellBg', () {
    test('1–5 baholari uchun emerald 50→600', () {
      expect(gradeCellBg(1), _emerald50);
      expect(gradeCellBg(2), _emerald100);
      expect(gradeCellBg(3), _emerald200);
      expect(gradeCellBg(4), _emerald400);
      expect(gradeCellBg(5), _emerald600);
    });

    test('chegaralar 0 va 6', () {
      expect(gradeCellBg(0), _emerald50);
      expect(gradeCellBg(6), _emerald600);
    });

    test('manfiy va kasr qiymatlar', () {
      expect(gradeCellBg(-3), _emerald50);
      expect(gradeCellBg(1.4), _emerald50);
      expect(gradeCellBg(1.5), _emerald100);
      expect(gradeCellBg(4.6), _emerald600);
    });

    test('3 baho SARIQ emas — svetofor regressiyasi qaytmasin', () {
      final bg = gradeCellBg(3);
      expect(bg, _emerald200);
      expect(bg, isNot(const Color(0xFFF59E0B)));
      expect(bg, isNot(const Color(0xFFEF4444)));
    });
  });

  // ---------------------------------------------------------------------------
  group('gradeCellFg', () {
    test('1–3 uchun to\'q emerald matn', () {
      expect(gradeCellFg(1), _emerald600);
      expect(gradeCellFg(2), _emerald700);
      expect(gradeCellFg(3), _emerald800);
    });

    test('4–5 (to\'q fon) uchun OQ matn', () {
      expect(gradeCellFg(4), Colors.white);
      expect(gradeCellFg(5), Colors.white);
      expect(gradeCellFg(4), const Color(0xFFFFFFFF));
    });

    test('chegaralar 0 va 6', () {
      expect(gradeCellFg(0), _emerald600);
      expect(gradeCellFg(6), Colors.white);
      expect(gradeCellFg(-5), _emerald600);
    });

    test('.round() semantikasi', () {
      expect(gradeCellFg(1.4), _emerald600);
      expect(gradeCellFg(1.5), _emerald700);
      expect(gradeCellFg(3.5), Colors.white, reason: '3.5.round() == 4');
      expect(gradeCellFg(4.6), Colors.white);
    });

    test('bg va fg juftligi doim mos pog\'onadan olinadi', () {
      for (final g in [0, 1, 2, 3, 4, 5, 6]) {
        expect(gradeCellBg(g), isA<Color>());
        expect(gradeCellFg(g), isA<Color>());
      }
    });
  });

  // ---------------------------------------------------------------------------
  group('BUG-F1 (TUZATILDI) — _gradeStep NaN/Infinity ni qirqadi', () {
    // BUG-F1: lib/utils/format.dart — `g.round()` NaN/Infinity uchun
    // UnsupportedError tashlardi (build ichida → qizil ekran). Endi qirqiladi.
    // Eski "pin" testlar (throwsUnsupportedError) o'chirildi.
    test('BUG-F1 shartnoma: NaN/Infinity qirqilishi va rang qaytishi kerak', () {
      expect(gradeColor(double.nan), _emerald500);
      expect(gradeColor(double.infinity), _emerald900);
      expect(gradeColor(double.negativeInfinity), _emerald500);
      expect(gradeCellBg(double.infinity), _emerald600);
      expect(gradeCellBg(double.nan), _emerald50);
      expect(gradeCellFg(double.nan), _emerald600);
    });

    test('BUG-F1: hech qanday istisno otilmaydi', () {
      for (final v in [double.nan, double.infinity, double.negativeInfinity]) {
        expect(() => gradeColor(v), returnsNormally);
        expect(() => gradeCellBg(v), returnsNormally);
        expect(() => gradeCellFg(v), returnsNormally);
      }
      expect(gradeCellFg(double.infinity), Colors.white);
    });
  });

  // ---------------------------------------------------------------------------
  group('subjectColor', () {
    test('bo\'sh satr → zaxira (fallback) rang', () {
      expect(subjectColor(''), _subjFallback);
      expect(subjectColor(''), const Color(0xFF64708A));
      expect(_subjPalette.contains(subjectColor('')), isFalse,
          reason: 'zaxira rang palitradan tashqarida');
    });

    test('determinizm: bir xil kalit → bir xil rang (ikki marta chaqirib)', () {
      final a1 = subjectColor('Matematika');
      final a2 = subjectColor('Matematika');
      expect(a1, a2);
      expect(subjectColor('Fizika'), subjectColor('Fizika'));
      expect(subjectColor(''), subjectColor(''));
    });

    test('natija doim 10 ta rangli palitra ichidan', () {
      const keys = [
        'Matematika', 'Fizika', 'Ingliz tili', 'Ona tili', 'Kimyo',
        'Biologiya', 'Tarix', 'Geografiya', 'Informatika', 'Adabiyot',
        'a', 'b', 'c', '1', '  ', 'Fizika ',
      ];
      for (final k in keys) {
        expect(_subjPalette, contains(subjectColor(k)), reason: 'kalit: "$k"');
      }
    });

    test('aniq kalitlar aniq palitra indekslariga tushadi', () {
      expect(subjectColor('Tarix'), _subjPalette[0]);
      expect(subjectColor('Kimyo'), _subjPalette[1]);
      expect(subjectColor('Matematika'), _subjPalette[2]);
      expect(subjectColor('Adabiyot'), _subjPalette[3]);
      expect(subjectColor('Ingliz tili'), _subjPalette[5]);
      expect(subjectColor('Fizika'), _subjPalette[6]);
      expect(subjectColor('Biologiya'), _subjPalette[7]);
      expect(subjectColor('Ona tili'), _subjPalette[8]);
      expect(subjectColor('Informatika'), _subjPalette[9]);
    });

    test('turli kalitlar kamida bir nechta turli rang beradi', () {
      final got = <Color>{
        for (final k in [
          'Matematika', 'Fizika', 'Ingliz tili', 'Ona tili', 'Kimyo',
          'Biologiya', 'Tarix', 'Informatika', 'Adabiyot',
        ])
          subjectColor(k),
      };
      expect(got.length, greaterThanOrEqualTo(5));
    });

    test('registr farqi boshqa rang beradi (hash xom kod birliklaridan)', () {
      expect(subjectColor('Fizika'), isNot(subjectColor('fizika')));
    });

    test('kirill nomi ishlaydi va palitradan chiqmaydi', () {
      final c = subjectColor('Математика');
      expect(_subjPalette, contains(c));
      expect(c, _subjPalette[3]);
      expect(subjectColor('Математика'), subjectColor('Математика'));
    });

    test('o\'zbek-lotin apostrofli nom', () {
      final c = subjectColor('O\'zbek tili');
      expect(_subjPalette, contains(c));
      expect(c, _subjPalette[2]);
    });

    test('juda uzun nom (500 belgi) — toshib ketmaydi', () {
      final long = 'x' * 500;
      final c = subjectColor(long);
      expect(_subjPalette, contains(c));
      expect(c, _subjPalette[4]);
      expect(subjectColor(long), c);
      expect(subjectColor('y' * 5000), isA<Color>());
    });

    test('bitta belgili kalitlar', () {
      expect(subjectColor('A'), _subjPalette[5]);
      expect(subjectColor('B'), _subjPalette[6]);
    });
  });

  // ---------------------------------------------------------------------------
  group('initials', () {
    test('oddiy "Ali Valiyev" → "AV"', () {
      expect(initials('Ali Valiyev'), 'AV');
    });

    test('uch va undan ortiq so\'z → faqat birinchi ikkitasi', () {
      expect(initials('Ali Valiyev Akmalovich'), 'AV');
      expect(initials('a b c d e'), 'AB');
    });

    test('bitta so\'z → bitta harf', () {
      expect(initials('Ali'), 'A');
      expect(initials('Valiyev'), 'V');
    });

    test('bitta belgili ism', () {
      expect(initials('A'), 'A');
      expect(initials('a'), 'A');
    });

    test('bosh/oxirgi va ichki ko\'p probellar tozalanadi', () {
      expect(initials('  Ali Valiyev  '), 'AV');
      expect(initials('Ali    Valiyev'), 'AV');
      expect(initials('\tAli\n\nValiyev\t'), 'AV');
      expect(initials('   Ali   '), 'A');
    });

    test('bo\'sh va faqat probelli satr → "?"', () {
      expect(initials(''), '?');
      expect(initials('   '), '?');
      expect(initials('\t\n '), '?');
    });

    test('kichik harflar katta harfga aylantiriladi', () {
      expect(initials('ali valiyev'), 'AV');
      expect(initials('aLi vAliyev'), 'AV');
    });

    test('kirill va o\'zbek-lotin ismlari', () {
      expect(initials('Абдулла Каримов'), 'АК');
      expect(initials('G\'ayrat Sobirov'), 'GS');
      expect(initials('Shohruh O\'ktamov'), 'SO');
    });

    test('natija uzunligi hech qachon 2 dan oshmaydi (BMP nomlar uchun)', () {
      for (final n in ['Ali Valiyev', 'a b c', 'Ali', 'X']) {
        expect(initials(n).length, lessThanOrEqualTo(2), reason: n);
      }
    });
  });

  group('BUG-F7 (TUZATILDI) — initials runes bilan ishlaydi', () {
    // BUG-F7: `w[0]` UTF-16 kod BIRLIGINI olardi → surrogat juftlik (emoji)
    // buzilar va avatarda "tofu" chiqardi. Eski pin testlar o'chirildi.
    test('BUG-F7 shartnoma: emoji butun qoladi, tinish belgilari tashlanadi', () {
      expect(initials('🎓 Ali'), 'A');
      expect(initials('- -'), '?');
      expect(initials('.'), '?');
    });

    test('BUG-F7: natijada yolg\'iz surrogat qolmaydi', () {
      final r = initials('🎓 Ali');
      expect(r.codeUnits, [0x41]);
      expect(r.runes.length, 1);
    });

    test('BUG-F7: harfsiz bo\'lak o\'tkazib yuboriladi, keyingisi olinadi', () {
      expect(initials('🎓 Ali Valiyev'), 'AV');
      expect(initials('- Ali'), 'A');
      expect(initials('123 Ali Valiyev'), 'AV');
    });
  });

  // ---------------------------------------------------------------------------
  group('fmtMoney', () {
    test('kichik sonlar ajratkichsiz', () {
      expect(fmtMoney(0), '0');
      expect(fmtMoney(1), '1');
      expect(fmtMoney(12), '12');
      expect(fmtMoney(999), '999');
    });

    test('minglar ajratkichi qo\'shiladi', () {
      expect(fmtMoney(1000), '1 000');
      expect(fmtMoney(999999), '999 999');
      expect(fmtMoney(1000000), '1 000 000');
      expect(fmtMoney(12500000), '12 500 000');
      expect(fmtMoney(850000), '850 000');
    });

    test('ajratkich AYNAN oddiy probel U+0020 (NBSP/thin space emas)', () {
      final s = fmtMoney(1000);
      expect(s, '1${_space}000');
      expect(s.codeUnitAt(1), 0x0020);
      expect(s.contains(' '), isFalse, reason: 'NBSP bo\'lmasin');
      expect(s.contains(' '), isFalse, reason: 'narrow NBSP bo\'lmasin');
      final big = fmtMoney(12500000);
      expect(big.codeUnits.where((c) => c == 0x20).length, 2);
    });

    test('manfiy son U+2212 MINUS SIGN bilan (ASCII defis EMAS)', () {
      expect(fmtMoney(-1), '${_minusSign}1');
      expect(fmtMoney(-1000), '${_minusSign}1 000');
      expect(fmtMoney(-12500000), '${_minusSign}12 500 000');
      final s = fmtMoney(-1000);
      expect(s.codeUnitAt(0), 0x2212);
      expect(s.codeUnitAt(0), isNot(0x2D), reason: 'ASCII "-" bo\'lmasligi kerak');
      expect(s.startsWith('-'), isFalse);
    });

    test('withSign: musbat → "+", nol → belgisiz, manfiy → "−"', () {
      expect(fmtMoney(500, withSign: true), '+500');
      expect(fmtMoney(1000000, withSign: true), '+1 000 000');
      expect(fmtMoney(0, withSign: true), '0', reason: 'nol uchun "+" qo\'yilmaydi');
      expect(fmtMoney(-500, withSign: true), '${_minusSign}500');
      expect(fmtMoney(0, withSign: true).codeUnitAt(0), 0x30);
    });

    test('withSign: false (default) musbat oldida belgi yo\'q', () {
      expect(fmtMoney(500), '500');
      expect(fmtMoney(500, withSign: false), '500');
    });

    test('kasr qiymatlar yaxlitlanadi (yarmi noldan uzoqqa)', () {
      expect(fmtMoney(0.4), '0');
      expect(fmtMoney(0.5), '1');
      expect(fmtMoney(1.49), '1');
      expect(fmtMoney(1.5), '2');
      expect(fmtMoney(999.5), '1 000');
      expect(fmtMoney(999999.6), '1 000 000');
      expect(fmtMoney(-1.5), '${_minusSign}2', reason: 'abs() dan keyin yaxlitlanadi');
      expect(fmtMoney(-1.4), '${_minusSign}1');
    });

    test('int va double bir xil chiqadi', () {
      expect(fmtMoney(1000), fmtMoney(1000.0));
      expect(fmtMoney(-1000), fmtMoney(-1000.0));
    });

    test('juda katta son', () {
      expect(fmtMoney(1234567890), '1 234 567 890');
    });
  });

  group('BUG-F2 (TUZATILDI) — fmtMoney NaN/Infinity da yiqilmaydi', () {
    // BUG-F2: `val.abs().round()` UnsupportedError tashlardi. Eski pin testlar
    // o'chirildi. Shartnoma testidagi kutilgan qiymat '0' emas — TIRE:
    // yaroqsiz/noma'lum summa "0 so'm" bo'lib ko'rinmasligi kerak (o'qituvchiga
    // "qarz yo'q" degan YOLG'ON ma'lumot beradi).
    test('BUG-F2 shartnoma: NaN/Infinity uchun xavfsiz zaxira qiymat qaytadi', () {
      expect(() => fmtMoney(double.nan), returnsNormally);
      expect(() => fmtMoney(double.infinity), returnsNormally);
      expect(() => fmtMoney(double.negativeInfinity), returnsNormally);
      expect(fmtMoney(double.nan), kNoValueDash);
      expect(fmtMoney(double.infinity), kNoValueDash);
      expect(fmtMoney(double.negativeInfinity), kNoValueDash);
      expect(fmtMoney(double.nan, withSign: true), kNoValueDash);
    });

    test('BUG-F2: zaxira qiymat "0" EMAS (yolg\'on summa ko\'rsatilmasin)', () {
      expect(fmtMoney(double.nan), isNot('0'));
      expect(kNoValueDash, '—');
    });
  });

  group('BUG-F3 (TUZATILDI) — fmtMoney "−0" bermaydi', () {
    // BUG-F3: belgi yaxlitlashdan OLDIN hisoblanardi → -0.4 → "−0".
    // Eski pin testlar o'chirildi.
    test('BUG-F3 shartnoma: nolga yaxlitlangan qiymat belgisiz "0"', () {
      expect(fmtMoney(-0.4), '0');
      expect(fmtMoney(-0.0001), '0');
      expect(fmtMoney(-0.49), '0');
      expect(fmtMoney(-0.4, withSign: true), '0');
      expect(fmtMoney(0.4), '0');
    });

    test('BUG-F3: nolga yaxlitlanmagan manfiy son belgisini saqlaydi', () {
      expect(fmtMoney(-0.5), '${_minusSign}1');
      expect(fmtMoney(-1), '${_minusSign}1');
      expect(fmtMoney(-0.4).codeUnits, [0x30]);
    });
  });

  // ---------------------------------------------------------------------------
  group('fmtDate', () {
    test('oddiy ISO sana → "12 Mart"', () {
      expect(fmtDate('2026-03-12'), '12 Mart');
      expect(fmtDate('2026-01-01'), '1 Yanvar');
      expect(fmtDate('2026-12-31'), '31 Dekabr');
    });

    test('kun oldida nol qo\'yilmaydi', () {
      expect(fmtDate('2026-03-05'), '5 Mart');
      expect(fmtDate('2026-03-05'), isNot('05 Mart'));
    });

    test('weekday: true → o\'zbekcha hafta kuni qo\'shiladi', () {
      // 2026-03-12 haqiqatda PAYSHANBA (2026-01-01 — payshanba, +70 kun).
      expect(DateTime(2026, 3, 12).weekday, DateTime.thursday);
      expect(fmtDate('2026-03-12', weekday: true), '12 Mart, Payshanba');
    });

    test('weekday: barcha 7 kun to\'g\'ri nomlanadi (2026-03-09 … 2026-03-15)', () {
      const expected = {
        '2026-03-09': 'Dushanba',
        '2026-03-10': 'Seshanba',
        '2026-03-11': 'Chorshanba',
        '2026-03-12': 'Payshanba',
        '2026-03-13': 'Juma',
        '2026-03-14': 'Shanba',
        '2026-03-15': 'Yakshanba',
      };
      expected.forEach((iso, name) {
        final d = DateTime.parse(iso);
        expect(weekdaysUz[(d.weekday + 6) % 7], name, reason: iso);
        expect(fmtDate(iso, weekday: true), endsWith(', $name'), reason: iso);
      });
    });

    test('weekday: false (default) — hafta kuni qo\'shilmaydi', () {
      expect(fmtDate('2026-03-12'), '12 Mart');
      expect(fmtDate('2026-03-12', weekday: false), '12 Mart');
      expect(fmtDate('2026-03-12').contains(','), isFalse);
    });

    test('to\'liq ISO datetime ham qabul qilinadi', () {
      expect(fmtDate('2026-03-12T14:35:00'), '12 Mart');
      expect(fmtDate('2026-03-12T14:35:00.123456'), '12 Mart');
      expect(fmtDate('2026-03-12T14:35:00', weekday: true), '12 Mart, Payshanba');
    });

    test('null → bo\'sh satr', () {
      expect(fmtDate(null), '');
      expect(fmtDate(null, weekday: true), '');
    });

    test('bo\'sh satr → bo\'sh satr', () {
      expect(fmtDate(''), '');
    });

    // BUG-F9 (TUZATILDI): `_parse` null qaytarganda fmtDate XOM (trim qilinmagan)
    // satrni qaytarardi — fmtTime bilan nomuvofiq edi. Eski pin o'chirildi.
    test('BUG-F9 shartnoma: faqat probelli kirish bo\'sh satr bo\'ladi', () {
      expect(fmtDate('   '), '');
      expect(fmtDate(' \t '), '');
      expect(fmtDate('   '), fmtTime('   '), reason: 'fmtDate va fmtTime izchil');
    });

    test('BUG-F9: yaroqsiz satrning atrofidagi probellar ham tozalanadi', () {
      expect(fmtDate('  abc  '), 'abc');
      expect(fmtDate('abc'), 'abc');
    });

    test('buzuq satr xom holida qaytariladi', () {
      expect(fmtDate('abc'), 'abc');
      expect(fmtDate('not-a-date'), 'not-a-date');
      expect(fmtDate('2026/03/12'), '2026/03/12');
      expect(fmtDate('12.03.2026'), '12.03.2026');
    });

    test('10 belgidan qisqa (bir xonali oy/kun) sana ham parse qilinmaydi', () {
      // '2026-3-5' → '2026-3-5T00:00:00' — DateTime.tryParse ikki xonali oy talab qiladi.
      expect(fmtDate('2026-3-5'), '2026-3-5');
      expect(fmtDate('2026-03'), '2026-03');
      expect(fmtDate('2026'), '2026');
    });

    test('atrofdagi probellar tozalanadi', () {
      expect(fmtDate('  2026-03-12  '), '12 Mart');
    });

    test('kabisa yili 29-fevral', () {
      expect(fmtDate('2024-02-29'), '29 Fevral');
    });
  });

  group('BUG-F6 — fmtDate diapazondan tashqari sanalarni jimgina "aylantiradi"', () {
    // BUG-F6: lib/utils/format.dart:91 — `_parse` DateTime.tryParse ga tayanadi,
    // u 13-oy / 31-fevralni xato deb hisoblamay, keyingi oyga o'tkazib yuboradi.
    test('BUG-F6 pin: fmtDate("2026-13-05") → "5 Yanvar" (2027 yilga o\'tib ketdi)', () {
      expect(fmtDate('2026-13-05'), '5 Yanvar');
    });
    test('BUG-F6 pin: fmtDate("2026-02-31") → "3 Mart"', () {
      expect(fmtDate('2026-02-31'), '3 Mart');
    });
    test('BUG-F6 pin: 00-oy va 00-kun ham aylanadi', () {
      expect(fmtDate('2026-00-10'), '10 Dekabr', reason: '0-oy → oldingi yil dekabri');
      expect(fmtDate('2026-03-00'), '28 Fevral', reason: '0-kun → oldingi oy oxiri');
    });
    test('BUG-F6 pin: 2025-02-29 (kabisa emas) → 1 Mart', () {
      expect(fmtDate('2025-02-29'), '1 Mart');
    });

    test(
      'BUG-F6 shartnoma: yaroqsiz sana xom satr sifatida qaytishi kerak',
      () {
        expect(fmtDate('2026-13-05'), '2026-13-05');
        expect(fmtDate('2026-02-31'), '2026-02-31');
        expect(fmtDate('2026-00-10'), '2026-00-10');
        expect(fmtDate('2025-02-29'), '2025-02-29');
      },
      skip: 'BUG-F6 — hozircha noto\'g\'ri ishlaydi',
    );
  });

  group('BUG-F8 — fmtDate hech qachon yilni ko\'rsatmaydi', () {
    // BUG-F8: lib/utils/format.dart:99 — chiqishda faqat kun va oy bor,
    // shu sababli boshqa yildagi sana joriy yildagidan farqlanmaydi.
    test('BUG-F8 pin: 2020 va 2026 yillardagi bir xil kun — bir xil matn', () {
      expect(fmtDate('2020-03-12'), fmtDate('2026-03-12'));
      expect(fmtDate('2020-03-12'), '12 Mart');
      expect(fmtDate('1999-03-12'), '12 Mart');
    });
    test('BUG-F8 pin: weekday: true bo\'lsa ham yil yo\'q (hatto kun nomi farq qilsa ham)', () {
      expect(fmtDate('2020-03-12', weekday: true), '12 Mart, Payshanba');
      expect(fmtDate('2021-03-12', weekday: true), '12 Mart, Juma');
      expect(fmtDate('2021-03-12', weekday: true).contains('2021'), isFalse);
    });
    test('BUG-F8 pin: chiqishda hech qanday 4 xonali yil yo\'q', () {
      expect(RegExp(r'\d{4}').hasMatch(fmtDate('2026-03-12', weekday: true)), isFalse);
    });

    test(
      'BUG-F8 shartnoma: boshqa yildagi sana ajratib ko\'rsatilishi kerak',
      () {
        expect(fmtDate('2020-03-12'), isNot(fmtDate('2026-03-12')));
        expect(fmtDate('2020-03-12'), contains('2020'));
      },
      skip: 'BUG-F8 — hozircha noto\'g\'ri ishlaydi',
    );
  });

  // ---------------------------------------------------------------------------
  group('fmtMonth', () {
    test('"2026-03" → "Mart 2026"', () {
      expect(fmtMonth('2026-03'), 'Mart 2026');
    });

    test('01–12 oylarining barchasi', () {
      const expected = [
        'Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun',
        'Iyul', 'Avgust', 'Sentabr', 'Oktabr', 'Noyabr', 'Dekabr',
      ];
      for (var m = 1; m <= 12; m++) {
        final ym = '2026-${m.toString().padLeft(2, '0')}';
        expect(fmtMonth(ym), '${expected[m - 1]} 2026', reason: ym);
      }
    });

    test('to\'liq sana berilsa ham oy+yil qaytadi (7 belgidan keyingisi e\'tiborsiz)', () {
      expect(fmtMonth('2026-03-12'), 'Mart 2026');
      expect(fmtMonth('2026-03-12T10:00:00'), 'Mart 2026');
    });

    test('boshqa yillar', () {
      expect(fmtMonth('1999-12'), 'Dekabr 1999');
      expect(fmtMonth('2030-01'), 'Yanvar 2030');
    });

    test('null → bo\'sh satr', () {
      expect(fmtMonth(null), '');
    });

    test('juda qisqa satr xom holida qaytadi', () {
      expect(fmtMonth('2026-3'), '2026-3');
      expect(fmtMonth('2026'), '2026');
      expect(fmtMonth(''), '');
      expect(fmtMonth('ab'), 'ab');
    });
  });

  group('BUG-F4 (TUZATILDI) — fmtMonth yaroqsiz oyda xom satr qaytaradi', () {
    // BUG-F4: zaxira shoxida `ym` TO'LIQ satr sifatida ishlatilib, ustiga yana
    // ' ' + ym.substring(0,4) qo'shilardi ("2026-13 2026"). Pinlar o'chirildi.
    test('BUG-F4 shartnoma: yaroqsiz oy → xom satr qaytadi', () {
      expect(fmtMonth('2026-13'), '2026-13');
      expect(fmtMonth('2026-00'), '2026-00');
      expect(fmtMonth('abcdefg'), 'abcdefg');
      expect(fmtMonth('2026-xx'), '2026-xx');
      expect(fmtMonth('2026-99'), '2026-99');
    });

    test('BUG-F4: chiqishda yil ikki marta takrorlanmaydi', () {
      expect(fmtMonth('2026-13').split(' ').length, 1);
      expect(fmtMonth('2026-13'), isNot(contains(' 2026')));
      // To'g'ri oy esa avvalgidek ishlaydi:
      expect(fmtMonth('2026-12'), 'Dekabr 2026');
    });
  });

  // ---------------------------------------------------------------------------
  group('fmtTime', () {
    test('ISO datetime → "HH:mm"', () {
      expect(fmtTime('2026-03-12T14:35:00'), '14:35');
      expect(fmtTime('2026-03-12T00:00:00'), '00:00');
      expect(fmtTime('2026-03-12T23:59:59'), '23:59');
    });

    test('bir xonali soat/daqiqa nol bilan to\'ldiriladi', () {
      expect(fmtTime('2026-03-12T09:05:00'), '09:05');
      expect(fmtTime('2026-03-12T01:02:03'), '01:02');
      expect(fmtTime('2026-03-12T09:05:00').length, 5);
    });

    test('faqat sana berilsa "00:00"', () {
      expect(fmtTime('2026-03-12'), '00:00');
    });

    test('null / bo\'sh / probelli → bo\'sh satr', () {
      expect(fmtTime(null), '');
      expect(fmtTime(''), '');
      expect(fmtTime('   '), '');
    });

    test('buzuq satr → bo\'sh satr (xom satr EMAS)', () {
      expect(fmtTime('abc'), '');
      expect(fmtTime('14:35'), '');
      expect(fmtTime('2026/03/12 14:35'), '');
    });

    test('sekund/millisekundlar tashlanadi', () {
      expect(fmtTime('2026-03-12T14:35:59.999'), '14:35');
    });
  });

  group('BUG-F5 — _parse .toLocal() ni chaqirmaydi (UTC ko\'rsatiladi)', () {
    // BUG-F5: lib/utils/format.dart:91 — `DateTime.tryParse` "Z"/offsetli satr uchun
    // UTC DateTime qaytaradi, u `.toLocal()` qilinmaydi. Natijada foydalanuvchi
    // mahalliy vaqt o'rniga UTC ni ko'radi.
    const isoZ = '2026-03-12T09:00:00Z';
    const isoLateZ = '2026-03-12T23:30:00Z';

    test('BUG-F5 pin: fmtTime("...09:00:00Z") har qanday mintaqada "09:00" (UTC)', () {
      expect(fmtTime(isoZ), '09:00');
      expect(DateTime.parse(isoZ).isUtc, isTrue);
    });

    test('BUG-F5 pin: chiqish mahalliy vaqtga MOS EMAS (offset != 0 bo\'lganda)', () {
      final local = DateTime.parse(isoZ).toLocal();
      final localStr = '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
      if (DateTime.now().timeZoneOffset != Duration.zero) {
        expect(fmtTime(isoZ), isNot(localStr),
            reason: 'UTC CI bo\'lmagan mashinada mahalliy vaqt farq qilishi kerak edi');
      }
      // UTC mashinada ham pin barqaror:
      expect(fmtTime(isoZ), '09:00');
    });

    test('BUG-F5 pin: fmtDate kech kechqurungi UTC belgisida ham UTC kunini beradi', () {
      expect(fmtDate(isoLateZ), '12 Mart');
      final local = DateTime.parse(isoLateZ).toLocal();
      final localStr = '${local.day} ${monthsUz[local.month - 1]}';
      if (DateTime.now().timeZoneOffset != Duration.zero && local.day != 12) {
        expect(fmtDate(isoLateZ), isNot(localStr),
            reason: 'mahalliy kun 12-martdan farq qilsa, chiqish ham farq qilishi kerak edi');
      }
    });

    test('BUG-F5 pin: aniq offsetli satr ham konvertatsiya qilinmaydi', () {
      // "+05:00" berilgan → mahalliy mintaqadan qat\'i nazar UTC ga keltirilib ko'rsatiladi.
      expect(fmtTime('2026-03-12T14:00:00+05:00'), '09:00');
      expect(fmtTime('2026-03-12T14:00:00+05:00'), fmtTime(isoZ));
    });

    test(
      'BUG-F5 shartnoma: UTC belgili vaqt mahalliy vaqtga o\'girilishi kerak',
      () {
        final local = DateTime.parse(isoZ).toLocal();
        final localStr = '${local.hour.toString().padLeft(2, '0')}:'
            '${local.minute.toString().padLeft(2, '0')}';
        expect(fmtTime(isoZ), localStr);

        final localD = DateTime.parse(isoLateZ).toLocal();
        expect(fmtDate(isoLateZ), '${localD.day} ${monthsUz[localD.month - 1]}');
      },
      skip: 'BUG-F5 — hozircha noto\'g\'ri ishlaydi',
    );
  });

  // ---------------------------------------------------------------------------
  group('monthsUz / weekdaysUz', () {
    test('monthsUz — 12 ta, birinchi "Yanvar", oxirgi "Dekabr"', () {
      expect(monthsUz.length, 12);
      expect(monthsUz.first, 'Yanvar');
      expect(monthsUz.last, 'Dekabr');
      expect(monthsUz, contains('Mart'));
      expect(monthsUz.toSet().length, 12, reason: 'takrorlanmasin');
    });

    test('weekdaysUz — 7 ta, birinchi "Dushanba", oxirgi "Yakshanba"', () {
      expect(weekdaysUz.length, 7);
      expect(weekdaysUz.first, 'Dushanba');
      expect(weekdaysUz.last, 'Yakshanba');
      expect(weekdaysUz.toSet().length, 7, reason: 'takrorlanmasin');
    });

    test('getter har chaqiruvda bir xil ro\'yxatni beradi', () {
      expect(monthsUz, monthsUz);
      expect(weekdaysUz, weekdaysUz);
    });

    test('monthsUz fmtMonth/fmtDate bilan izchil', () {
      for (var m = 1; m <= 12; m++) {
        final mm = m.toString().padLeft(2, '0');
        expect(fmtMonth('2026-$mm'), '${monthsUz[m - 1]} 2026');
        expect(fmtDate('2026-$mm-15'), '15 ${monthsUz[m - 1]}');
      }
    });
  });

  // ---------------------------------------------------------------------------
  group('app_theme — balanceColor', () {
    const light = AppColors.light;
    const dark = AppColors.dark;

    test('2+ oylik qarz → fuchsia, balansdan qat\'i nazar', () {
      expect(balanceColor(light, -100000, 2), kHeavyDebtColor);
      expect(balanceColor(light, 0, 2), kHeavyDebtColor);
      expect(balanceColor(light, 500000, 2), kHeavyDebtColor);
      expect(balanceColor(light, 500000, 5), kHeavyDebtColor);
      expect(balanceColor(dark, -1, 3), kHeavyDebtColor);
    });

    test('fuchsia qiymati aynan Tailwind fuchsia-600 (0xFFC026D3)', () {
      expect(kHeavyDebtColor, const Color(0xFFC026D3));
      expect(balanceColor(light, -1, 2), const Color(0xFFC026D3));
    });

    test('1 oylik qarz og\'ir hisoblanmaydi — oddiy qoidaga tushadi', () {
      expect(balanceColor(light, -1, 1), light.red);
      expect(balanceColor(light, 100, 1), light.green);
      expect(balanceColor(light, -1, 1), isNot(kHeavyDebtColor));
    });

    test('manfiy balans → qizil, aks holda yashil', () {
      expect(balanceColor(light, -0.01, 0), light.red);
      expect(balanceColor(light, -1000000, 0), light.red);
      expect(balanceColor(light, 0, 0), light.green, reason: 'nol qarz emas');
      expect(balanceColor(light, 0.01, 0), light.green);
      expect(balanceColor(light, 850000, 0), light.green);
    });

    test('mavzuga bog\'liq: light va dark turli qizil/yashil beradi', () {
      expect(balanceColor(light, -1, 0), const Color(0xFFEF4444));
      expect(balanceColor(dark, -1, 0), const Color(0xFFF87171));
      expect(balanceColor(light, 1, 0), const Color(0xFF16A34A));
      expect(balanceColor(dark, 1, 0), const Color(0xFF22C55E));
      expect(balanceColor(light, -1, 0), isNot(balanceColor(dark, -1, 0)));
    });

    test('manfiy debtMonths (yaroqsiz kirish) og\'ir qarz emas', () {
      expect(balanceColor(light, -1, -1), light.red);
      expect(balanceColor(light, 1, -5), light.green);
    });

    test('kHeavyDebtMonths chegarasi 2', () {
      expect(kHeavyDebtMonths, 2);
      expect(balanceColor(light, 0, kHeavyDebtMonths - 1), light.green);
      expect(balanceColor(light, 0, kHeavyDebtMonths), kHeavyDebtColor);
    });

    test('sof funksiya — takroriy chaqiruv bir xil natija', () {
      expect(balanceColor(light, -5, 0), balanceColor(light, -5, 0));
      expect(balanceColor(dark, 5, 9), balanceColor(dark, 5, 9));
    });
  });

  group('app_theme — konstantalar va palitra', () {
    test('brend rangi va shrift', () {
      expect(kBrandNavy, const Color(0xFF020066));
      expect(AppColors.light.accentD, kBrandNavy);
      expect(kTeacherFontFamily, 'Times New Roman');
      expect(kTeacherFontFallback, ['serif', 'Georgia']);
    });

    test('light/dark mavzular isDark bayrog\'i bilan farqlanadi', () {
      expect(AppColors.light.isDark, isFalse);
      expect(AppColors.dark.isDark, isTrue);
      expect(AppColors.light.bg, isNot(AppColors.dark.bg));
      expect(AppColors.light.text, isNot(AppColors.dark.text));
    });

    test('AppSizes qiymatlari', () {
      expect(AppSizes.card, 18);
      expect(AppSizes.cardLg, 20);
      expect(AppSizes.chip, 8);
      expect(AppSizes.btn, 14);
      expect(AppSizes.pad, 16);
    });

    test('har bir mavzuda bitta soya bor', () {
      expect(AppColors.light.shadow, hasLength(1));
      expect(AppColors.dark.shadow, hasLength(1));
      expect(AppColors.dark.shadow.first.blurRadius, 24);
    });
  });

  group('app_theme — buildMaterialTheme (widget pump talab qilmaydi)', () {
    test('light mavzu ranglari AppColors dan ko\'chiriladi', () {
      const c = AppColors.light;
      final t = buildMaterialTheme(c);
      expect(t.scaffoldBackgroundColor, c.bg);
      expect(t.primaryColor, c.accent);
      expect(t.colorScheme.primary, c.accent);
      expect(t.colorScheme.surface, c.surface);
      expect(t.colorScheme.error, c.red);
      expect(t.dividerColor, c.border);
      expect(t.brightness, Brightness.light);
    });

    test('dark mavzu Brightness.dark bo\'ladi', () {
      const c = AppColors.dark;
      final t = buildMaterialTheme(c);
      expect(t.brightness, Brightness.dark);
      expect(t.scaffoldBackgroundColor, c.bg);
      expect(t.colorScheme.primary, c.accent);
    });

    test('matn mavzusiga serif shrift qo\'llanadi', () {
      final t = buildMaterialTheme(AppColors.light);
      expect(t.textTheme.bodyMedium?.fontFamily, kTeacherFontFamily);
      expect(t.textTheme.bodyMedium?.color, AppColors.light.text);
      expect(t.textTheme.bodyMedium?.fontFamilyFallback, kTeacherFontFallback);
    });
  });

  group('app_theme — AppTheme.of konteksitsiz zaxira', () {
    test('updateShouldNotify palitra o\'zgarganda true (BUG-U4 TUZATILDI)', () {
      const child = SizedBox.shrink();
      const a = AppTheme(colors: AppColors.light, child: child);
      const b = AppTheme(colors: AppColors.dark, child: child);
      expect(b.updateShouldNotify(a), isTrue);
      expect(a.updateShouldNotify(a), isFalse);
      expect(a.updateShouldNotify(b), isTrue);

      // Bir xil `isDark`, lekin boshqa ranglar — ilgari xabar berilmasdi.
      const variant = AppTheme(
        colors: AppColors(
          accent: Color(0xFFFF0000),
          accentD: Color(0xFF020066),
          accentSoft: Color(0xFFE8E8F6),
          bg: Color(0xFFFBFCFC),
          surface: Color(0xFFFFFFFF),
          surface2: Color(0xFFF4F6F5),
          surface3: Color(0xFFF0F3F2),
          text: Color(0xFF0F1A17),
          muted: Color(0xFF5A6360),
          faint: Color(0xFF94A09B),
          border: Color(0xFFE7ECEB),
          borderStrong: Color(0xFFD7DEDC),
          green: Color(0xFF16A34A),
          greenSoft: Color(0xFFE7F6EC),
          red: Color(0xFFEF4444),
          redSoft: Color(0xFFFDEAEA),
          amber: Color(0xFFF59E0B),
          amberSoft: Color(0xFFFDF2E1),
          shadow: [BoxShadow(color: Color(0x0F0F1A17), blurRadius: 18, offset: Offset(0, 6))],
          isDark: false,
        ),
        child: child,
      );
      expect(variant.colors.isDark, AppColors.light.isDark);
      expect(variant.updateShouldNotify(a), isTrue,
          reason: 'faqat accent farq qilsa ham dependentlar qayta qurilishi kerak');
    });

    test('AppColors == barcha ranglarni solishtiradi', () {
      expect(AppColors.light, AppColors.light);
      expect(AppColors.light == AppColors.dark, isFalse);
      expect(AppColors.light.hashCode, AppColors.light.hashCode);
    });

    testWidgets('AppTheme yo\'q bo\'lsa AppColors.light qaytadi', (tester) async {
      late AppColors seen;
      await tester.pumpWidget(Builder(builder: (ctx) {
        seen = AppTheme.of(ctx);
        return const SizedBox.shrink();
      }));
      expect(seen.isDark, isFalse);
      expect(seen, same(AppColors.light));
    });
  });
}
