// lib/services/openai_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'ai_service.dart';

class OpenAIService implements AIService {
  final String apiKey;
  late AIModel _currentModel;

  OpenAIService(this.apiKey) {
    _currentModel = availableModels.first;
  }

  @override
  String get providerName => 'OpenAI';
  @override
  String get brandAsset => 'assets/openai_logo.png';

  @override
  List<AIModel> get availableModels => [
    AIModel(
      id: 'gpt-5.4',
      displayName: 'GPT-5.4 (Flagship)',
      supportsVision: true,
      supportsWebSearch: true,
      supportsImageGen: true,
    ),
    AIModel(
      id: 'gpt-5.4-mini',
      displayName: 'GPT-5.4 Mini (Fast)',
      supportsVision: true,
      supportsWebSearch: true,
    ),
    AIModel(
      id: 'o4-mini',
      displayName: 'o4 Mini (Reasoning)',
      supportsVision: false,
    ),
  ];

  @override
  AIModel get currentModel => _currentModel;

  @override
  void setModel(AIModel model) => _currentModel = model;

  @override
  Future<String> sendMessage(String prompt, {required List<Map<String, dynamic>> history, File? attachment, bool isDeepResearch = false}) async {
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    var messages = history.map((m) => {"role": m['role'], "content": m['content']}).toList();

    // 1. Deep Research Logic
    if (isDeepResearch) {
      messages.insert(0, {
        "role": "system",
        "content": "DEEP RESEARCH MODE ACTIVE: You must provide an exhaustive, step-by-step analysis of the user's query. Consider edge cases, historical context, and break down complex topics into highly detailed sub-sections."
      });
    }

    // 2. Attachment Logic (Base64)
    if (attachment != null && _currentModel.supportsVision) {
      final bytes = await attachment.readAsBytes();
      final base64Image = base64Encode(bytes);

      String mimeType = 'image/jpeg';
      if (attachment.path.toLowerCase().endsWith('.png')) mimeType = 'image/png';
      if (attachment.path.toLowerCase().endsWith('.webp')) mimeType = 'image/webp';
      if (attachment.path.toLowerCase().endsWith('.gif')) mimeType = 'image/gif';

      messages.add({
        "role": "user",
        "content": [
          {"type": "text", "text": prompt},
          {"type": "image_url", "image_url": {"url": "data:$mimeType;base64,$base64Image"}}
        ]
      });
    } else {
      messages.add({"role": "user", "content": prompt});
    }

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $apiKey'},
        body: jsonEncode({'model': _currentModel.id, 'messages': messages}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        return "OpenAI Error: ${response.statusCode} - ${response.body}";
      }
    } catch (e) {
      return "Error connecting to OpenAI: $e";
    }
  }

  @override
  Future<String> generateImage(String prompt) {
    // TODO: implement generateImage
    throw UnimplementedError();
  }
}