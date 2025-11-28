// lib/services/api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;


class ApiClient {
  final Uri _uri = Uri.parse(AppConfig.apiUrl);

  Future<bool> sendProductToApi({
    required String productId,
    required int maxDefects,
    required String finalStatus,
  }) async {
    final payload = {
      "product_id": productId,
      "session_id": AppConfig.sessionId,
      "status": finalStatus,
      "max_defects": maxDefects,
      "timestamp": DateTime.now().toIso8601String(),
      "productionline_id": AppConfig.productionLineId,
      "companyId": AppConfig.companyId,
    };

    try {
      final resp = await http.post(
        _uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        // debugPrint('[API] OK $productId -> $finalStatus');
        return true;
      } else {
        // debugPrint('[API] Error ${resp.statusCode} for $productId: ${resp.body}');
        return false;
      }
    } catch (e) {
      // debugPrint('[API] Connection error for $productId: $e');
      return false;
    }
  }
}
