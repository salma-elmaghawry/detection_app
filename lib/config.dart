// lib/config.dart
import 'package:/uuid.dart';
class AppConfig {
  // ثقة الموديلين
  static const double cartonConf = 0.5;
  static const double defectConf = 0.25;

  // توسعة البوكس قبل قصّه لموديل العيوب
  static const double expandRatio = 0.05;

  // عدد الفريمات المسموح بيها قبل ما نعتبر الـ QR اختفى
  static const int maxDisappear = 12;

  // API config (نفس اللي في config.py)
  static const String apiUrl =
      'https://chainly.azurewebsites.net/api/ProductionLines/sessions';
  static const int productionLineId = 1;
  static const int companyId = 90;

  // Session ID زي Python (uuid4)
  static final String sessionId = const Uuid().v4();
}
