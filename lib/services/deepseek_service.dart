import 'dart:convert';
import 'dart:io'; // ADDED
import 'package:http/http.dart' as http;
import 'ai_service.dart';

class DeepSeekService implements AIService {
  final String apiKey;
  late AIModel _currentModel;

  DeepSeekService(this.apiKey) {
    _currentModel = availableModels.first;
  }

  @override
  String get providerName => 'DeepSeek';

  @override
  String get brandAsset => 'assets/deepseek_logo.png';

  @override
  List<AIModel> get availableModels => [
    AIModel(id: 'deepseek-chat', displayName: 'DeepSeek Chat (V3)', supportsVision: false, supportsWebSearch: false, supportsImageGen: false),
    AIModel(id: 'deepseek-reasoner', displayName: 'DeepSeek Reasoner (R1)', supportsVision: false),
  ];

  @override
  AIModel get currentModel => _currentModel;

  @override
  void setModel(AIModel model) => _currentModel = model;

  @override
  Future<String> sendMessage(String prompt, {required List<Map<String, dynamic>> history, File? attachment, bool isDeepResearch = false}) async {
    final url = Uri.parse('https://api.deepseek.com/chat/completions');

    var messages = history.map((m) => {"role": m['role'], "content": m['content']}).toList();

    // 1. Deep Research Logic
    if (isDeepResearch) {
      messages.insert(0, {
        "role": "system",
        "content": "You are in Deep Research Mode. Provide a comprehensive, in-depth analysis of the prompt. Consider edge cases and break down complex topics into highly detailed sub-sections."
      });
    }

    // 2. Handle Text (Ignore attachment since DeepSeek doesn't support Vision yet)
    String finalPrompt = prompt;
    if (attachment != null) {
      finalPrompt = "[Note: User attached a file, but DeepSeek models currently do not support vision/files. Please respond to the text.]\n\n$prompt";
    }

    messages.add({"role": "user", "content": finalPrompt});

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
        return "DeepSeek Error: ${response.statusCode} - ${response.body}";
      }
    } catch (e) {
      return "Error connecting to DeepSeek: $e";
    }
  }

  @override
  Future<String> generateImage(String prompt) async {
    return "DeepSeek does not support image generation.";
  }
}