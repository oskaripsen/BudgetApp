import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatService {
  static const String _baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://your-budget-api-956e1b31bfce.herokuapp.com'  // Remove /chat
  );

  static Future<String> getChatResponse(String message, Map<DateTime, List<Map<String, dynamic>>> notes) async {
    try {
      final payload = {
        'message': message,
        'notes': notes.map((key, value) => MapEntry(key.toIso8601String(), value)),
      };
      
      print('Sending request to $_baseUrl/chat');  // Debug print
      print('Payload: ${jsonEncode(payload)}');  // Debug print

      final response = await http.post(
        Uri.parse('$_baseUrl/chat'),  // Add /chat here
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      print('Response status: ${response.statusCode}');  // Debug print
      print('Response body: ${response.body}');  // Debug print

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'];
      } else {
        return 'Server error (${response.statusCode}): ${response.body}';
      }
    } catch (e, stackTrace) {
      print('Error: $e');  // Debug print
      print('Stack trace: $stackTrace');  // Debug print
      return 'Error connecting to server: $e';
    }
  }

  static Future<void> saveBudgetEntry(Map<String, dynamic> entry) async {
    try {
      await http.post(
        Uri.parse(_baseUrl.replaceAll('/chat', '/budget')),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(entry),
      );
    } catch (e) {
      print('Error saving entry: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> loadBudgetEntries() async {
    try {
      final response = await http.get(
        Uri.parse(_baseUrl.replaceAll('/chat', '/budget')),
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      print('Error loading entries: $e');
    }
    return [];
  }
}