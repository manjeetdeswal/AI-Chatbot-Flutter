// lib/services/gemini_service.dart
import 'dart:io';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'ai_service.dart';

class GeminiService implements AIService {
  final String apiKey;
  late AIModel _currentModel;

  GeminiService(this.apiKey) {
    _currentModel = availableModels.first;
  }

  @override
  String get providerName => 'Google';

  @override
  String get brandAsset => 'assets/gemini_logo.png';

  @override
  List<AIModel> get availableModels => [
    AIModel(
      id: 'gemini-3.1-pro-preview',
      displayName: 'Gemini 3.1 Pro',
      supportsVision: true,
      supportsWebSearch: true,
    ),
    AIModel(
      id: 'gemini-3.1-flash-lite-preview',
      displayName: 'Gemini 3.1 Flash Lite',
      supportsVision: true,
    ),
    AIModel(
      id: 'gemini-3-flash-preview',
      displayName: 'Gemini 3 Flash',
      supportsVision: true,
    ),
  ];

  @override
  AIModel get currentModel => _currentModel;

  @override
  void setModel(AIModel model) => _currentModel = model;

  @override
  Future<String> sendMessage(String prompt, {required List<Map<String, dynamic>> history, File? attachment, bool isDeepResearch = false}) async {
    // 1. Implement Native Google Search if Deep Research is active
    List<Tool>? tools;


    final modelInfo = GenerativeModel(
      model: _currentModel.id,
      apiKey: apiKey,
      tools: tools,
    );

    try {
      List<Content> geminiHistory = history.map((msg) {
        final role = msg['role'] == 'user' ? 'user' : 'model';
        return Content(role, [TextPart(msg['content'].toString())]);
      }).toList();

      // 2. Implement Attachment Logic
      List<Part> currentMessageParts = [];

      if (attachment != null) {
        final bytes = await attachment.readAsBytes();

        // Dynamic Mime-Type detection
        String mimeType = 'image/jpeg';
        final path = attachment.path.toLowerCase();
        if (path.endsWith('.png')) mimeType = 'image/png';
        if (path.endsWith('.webp')) mimeType = 'image/webp';
        if (path.endsWith('.heic')) mimeType = 'image/heic';
        if (path.endsWith('.pdf'))
          mimeType = 'application/pdf'; // Gemini uniquely supports PDFs
        if (path.endsWith('.mp4')) mimeType = 'video/mp4';

        currentMessageParts.add(DataPart(mimeType, bytes));
      }

      currentMessageParts.add(TextPart(prompt));
      geminiHistory.add(Content('user', currentMessageParts));

      final response = await modelInfo.generateContent(geminiHistory);
      return response.text ?? "No response generated.";
    } catch (e) {
      return "Gemini Error: $e";
    }
  }

  @override
  Future<String> generateImage(String prompt) {
    // TODO: implement generateImage
    throw UnimplementedError();
  }
}