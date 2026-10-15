import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main() async {
  print('Testing Gemini 3.8 Flash Neural TTS...');
  final apiKey = Platform.environment['GEMINI_API_KEY'] ?? '';
  final url = Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash-tts:generateContent?key=$apiKey',
  );

  final body = jsonEncode({
    'contents': [
      {
        'parts': [
          {'text': 'नमस्ते दोस्तों, SyncDub Cinema में आपका स्वागत है!'}
        ]
      }
    ],
    'generationConfig': {
      'responseModalities': ['AUDIO'],
      'speechConfig': {
        'voiceConfig': {
          'prebuiltVoiceConfig': {
            'voiceName': 'Puck'
          }
        }
      }
    }
  });

  final res = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: body,
  );

  print('Status: ${res.statusCode}');
  if (res.statusCode == 200) {
    final data = jsonDecode(res.body);
    final part = data['candidates'][0]['content']['parts'][0];
    final mime = part['inlineData']['mimeType'];
    final b64 = part['inlineData']['data'] as String;
    final bytes = base64Decode(b64);
    print('SUCCESS! Mime: $mime, Decoded Audio bytes: ${bytes.length}');
    final outFile = File('test_gemini_out.wav');
    await outFile.writeAsBytes(bytes);
    print('Saved to ${outFile.path}');
  } else {
    print('Failed: ${res.body}');
  }
}
