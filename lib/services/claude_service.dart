// lib/services/claude_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'ai_service.dart';

class ClaudeService implements AIService {
  final String apiKey;
  late AIModel _currentModel;

  ClaudeService(this.apiKey) {
    _currentModel = availableModels.first;
  }

  @override
  String get providerName => 'Anthropic';

  @override
  String get brandAsset => 'assets/claude_logo.png';

  @override
  List<AIModel> get availableModels => [
    AIModel(
      id: 'claude-sonnet-4-6',
      displayName: 'Claude Sonnet 4.6',
      supportsVision: true,
      supportsWebSearch: true, // Anthropic added native web search tools in 4.6
    ),
    AIModel(
      id: 'claude-opus-4-6',
      displayName: 'Claude Opus 4.6',
      supportsVision: true,
    ),
    AIModel(
      id: 'claude-haiku-4-5',
      displayName: 'Claude Haiku 4.5',
      supportsVision: true,
    ),
  ];

  @override
  AIModel get currentModel => _currentModel;

  @override
  void setModel(AIModel model) => _currentModel = model;

  @override
  Future<String> sendMessage(String prompt, {required List<Map<String, dynamic>> history, File? attachment, bool isDeepResearch = false}) async {
    final url = Uri.parse('https://api.anthropic.com/v1/messages');

    var messages = history.map((m) => {"role": m['role'], "content": m['content']}).toList();

    // 1. Attachment Logic (Anthropic Source Object)
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
          {
            "type": "image",
            "source": {"type": "base64", "media_type": mimeType, "data": base64Image}
          },
          {"type": "text", "text": prompt}
        ]
      });
    } else {
      messages.add({"role": "user", "content": prompt});
    }

    // 2. Deep Research Logic
    String? systemPrompt;
    if (isDeepResearch) {
      systemPrompt = "DEEP RESEARCH MODE ACTIVE: You must provide an exhaustive, step-by-step analysis of the user's query. Consider edge cases, historical context, and break down complex topics into highly detailed sub-sections.";
    }

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'x-api-key': apiKey, 'anthropic-version': '2023-06-01'},
        body: jsonEncode({
          'model': _currentModel.id,
          'messages': messages,
          'max_tokens': 4096,
          if (systemPrompt != null) 'system': systemPrompt, // Claude takes system prompts at the root level
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['content'][0]['text'];
      } else {
        return "Claude Error: ${response.statusCode} - ${response.body}";
      }
    } catch (e) {
      return "Error connecting to Claude: $e";
    }
  }

  @override
  Future<String> generateImage(String prompt) {
    // TODO: implement generateImage
    throw UnimplementedError();
  }
}