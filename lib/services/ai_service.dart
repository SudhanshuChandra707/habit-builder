import 'dart:convert';
import 'dart:io';

class AIService {
  static const String baseUrl = 'https://api.experientiallabs.ai/v1';
  static const String modelId = 'gpt-6-astra';

  // The key is never stored in source. Supply it from the environment or at
  // build time: flutter run --dart-define=EXPLABS_API_KEY=...
  static String get apiKey =>
      Platform.environment['EXPLABS_API_KEY'] ??
      const String.fromEnvironment('EXPLABS_API_KEY');

  /// Send a prompt to gpt-6-astra through Experiential Labs gateway
  static Future<Map<String, dynamic>> completePrompt(String userPrompt) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$baseUrl/chat/completions');
      final request = await client.postUrl(uri);

      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Authorization', 'Bearer $apiKey');

      final body = jsonEncode({
        'model': modelId,
        'messages': [
          {
            'role': 'system',
            'content': 'You are a helpful productivity and task assistant.'
          },
          {'role': 'user', 'content': userPrompt}
        ],
        'temperature': 0.7,
      });

      request.add(utf8.encode(body));
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      final data = jsonDecode(responseBody) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final content = data['choices'][0]['message']['content'] as String;
        final usage = data['usage'] as Map<String, dynamic>? ?? {};
        return {
          'success': true,
          'content': content,
          'usage': usage,
        };
      } else {
        return {
          'success': false,
          'error': data['error']?['message'] ?? 'HTTP ${response.statusCode}',
          'raw': data,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    } finally {
      client.close();
    }
  }
}
