/// Ilova sozlamalari. API bazasi shu yerda — dev uchun o'zgartiring.
///
/// Prod: https://crm.intellectschool.uz/api
/// Android emulyator lokal server: http://10.0.2.2:PORT/api
/// iOS simulyator lokal server:    http://localhost:PORT/api
/// Dev uchun FAYLNI TAHRIRLAMANG — build vaqtida bering:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api \
///               --dart-define=FILE_BASE_URL=http://10.0.2.2:5000
/// Shunda lokal manzil tasodifan commit'ga tushib, prod build'ga ketmaydi.
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://crm.intellectschool.uz/api',
);

/// Fayl/rasm manzillari nisbiy ("/uploads/..") kelsa shu bazaga ulanadi.
const String kFileBaseUrl = String.fromEnvironment(
  'FILE_BASE_URL',
  defaultValue: 'https://crm.intellectschool.uz',
);

const String kAppVersion = 'v1.0.0';
