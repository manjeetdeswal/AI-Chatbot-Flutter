import 'dart:convert';
import 'dart:io'; // ADDED
import 'package:http/http.dart' as http;
import 'ai_service.dart';

class GrokService implements AIService {
  final String apiKey;
  late AIModel _currentModel;

  GrokService(this.apiKey) {
    _currentModel = availableModels.first;
  }

  @override
  String get providerName => 'xAI';

  @override
  String get brandAsset => 'assets/grok_logo.png';

  @override
  List<AIModel> get availableModels => [
    AIModel(id: 'grok-4.20-non-reasoning', displayName: 'Grok 4.20', supportsVision: true, supportsWebSearch: true),
    AIModel(id: 'grok-3', displayName: 'Grok 3 (Flagship)', supportsVision: true, supportsWebSearch: true),
    AIModel(id: 'grok-3-mini', displayName: 'Grok 3 Mini', supportsVision: true, supportsWebSearch: true),
  ];

  @override
  AIModel get currentModel => _currentModel;

  @override
  void setModel(AIModel model) => _currentModel = model;

  @override
  Future<String> sendMessage(String prompt, {required List<Map<String, dynamic>> history, File? attachment, bool isDeepResearch = false}) async {
    final url = Uri.parse('https://api.x.ai/v1/chat/completions');

    var messages = history.map((m) => {"role": m['role'], "content": m['content']}).toList();

    // 1. Deep Research Logic
    if (isDeepResearch) {
      messages.insert(0, {
        "role": "system",
        "content": "You are in Deep Research Mode. Search your knowledge base exhaustively and provide a highly detailed, multi-faceted analysis of the prompt."
      });
    }

    // 2. Attachment Logic
    if (attachment != null && _currentModel.supportsVision) {
      final bytes = await attachment.readAsBytes();
      final base64Image = base64Encode(bytes);

      String mimeType = 'image/jpeg';
      if (attachment.path.toLowerCase().endsWith('.png')) mimeType = 'image/png';
      if (attachment.path.toLowerCase().endsWith('.webp')) mimeType = 'image/webp';

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
        return "Grok Error: ${response.statusCode} - ${response.body}";
      }
    } catch (e) {
      return "Error connecting to Grok: $e";
    }
  }

  @override
  Future<String> generateImage(String prompt) async {
    return "Grok image generation not yet implemented.";
  }
}