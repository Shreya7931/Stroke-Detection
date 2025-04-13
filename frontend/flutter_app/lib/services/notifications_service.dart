import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationService {
  static const String apiUrl = 'YOUR_BACKEND_API_URL';

  static Future<void> sendNotification(String message, List<String> contacts) async {
    for (var contact in contacts) {
      try {
        final response = await http.post(
          Uri.parse('$apiUrl/sendNotification'),
          headers: <String, String>{'Content-Type': 'application/json'},
          body: jsonEncode({
            'contact': contact,
            'message': message,
          }),
        );
        if (response.statusCode == 200) {
          print('Notification sent successfully to $contact');
        } else {
          print('Failed to send notification to $contact');
        }
      } catch (e) {
        print('Error sending notification: $e');
      }
    }
  }
}
