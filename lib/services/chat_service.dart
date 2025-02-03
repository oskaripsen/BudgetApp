import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatService {
  static const String _baseUrl = 'https://your-budget-api-956e1b31bfce.herokuapp.com'; // Ensure no trailing slash

  static Future<String> getChatResponse(String message, Map<DateTime, List<Map<String, dynamic>>> notes) async {
    try {
      final payload = {
        'message': message,
        'notes': notes.map((key, value) => MapEntry(key.toIso8601String(), value)),
      };
      
      print('Sending request to $_baseUrl/chat'); // Debug print
      print('Payload: ${jsonEncode(payload)}'); // Debug print

      final response = await http.post(
        Uri.parse('$_baseUrl/chat'), // Corrected to match backend routes
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      print('Response status: ${response.statusCode}'); // Debug print
      print('Response body: ${response.body}'); // Debug print

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'];
      } else {
        return 'Server error (${response.statusCode}): ${response.body}';
      }
    } catch (e, stackTrace) {
      print('Error: $e'); // Debug print
      print('Stack trace: $stackTrace'); // Debug print
      return 'Error connecting to server: $e';
    }
  }

  static Future<void> saveBudgetEntry(Map<String, dynamic> entry) async {
    try {
      final payload = entry;
      
      print('Saving entry with payload: ${jsonEncode(payload)}'); // Debug print
      
      final response = await http.post(
        Uri.parse('$_baseUrl/budget'), // Corrected to match backend routes
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      print('Save response status: ${response.statusCode}'); // Debug print
      print('Save response body: ${response.body}'); // Debug print

      if (response.statusCode != 200) {
        throw Exception('Failed to save entry: ${response.body}');
      }
    } catch (e) {
      print('Error saving entry: $e');
      rethrow;
    }
  }

  static Future<void> updateBudgetEntry(Map<String, dynamic> entry) async {
    try {
      final payload = entry;
      
      print('Updating entry with payload: ${jsonEncode(payload)}'); // Debug print
      
      final response = await http.put(
        Uri.parse('$_baseUrl/budget'), // Corrected to match backend routes
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      print('Update response status: ${response.statusCode}'); // Debug print
      print('Update response body: ${response.body}'); // Debug print

      if (response.statusCode != 200) {
        throw Exception('Failed to update entry: ${response.body}');
      }
    } catch (e) {
      print('Error updating entry: $e');
      rethrow;
    }
  }

  static Future<void> deleteBudgetEntry(Map<String, dynamic> entry) async {
    try {
      final url = Uri.parse('$_baseUrl/budget');

      print('Attempting to delete entry at: $url');
      print('Entry data: ${jsonEncode(entry)}');

      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json', // Ensure the backend processes JSON
        },
        body: jsonEncode({
          'date': entry['date'],
          'title': entry['title'],
          'amount': entry['amount'],
        }),
      );

      print('Delete response status: ${response.statusCode}');
      print('Delete response body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Failed to delete entry: ${response.body}');
      }
    } catch (e) {
      print('Error deleting entry: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> loadBudgetEntries() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/budget'), // Corrected to match backend routes
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
