import 'dart:io';

class AIModel {
  final String id;
  final String displayName;

  final bool supportsVision;
  final bool supportsWebSearch;
  final bool supportsImageGen;

  AIModel({
    required this.id,
    required this.displayName,
    this.supportsVision = false,
    this.supportsWebSearch = false,
    this.supportsImageGen = false,
  });
}

abstract class AIService {
  String get providerName;
  String get brandAsset;

  List<AIModel> get availableModels;
  AIModel get currentModel;
  void setModel(AIModel model);

  Future<String> sendMessage(
      String prompt, {
        required List<Map<String, dynamic>> history,
        File? attachment,
        bool isDeepResearch = false,
      });


  Future<String> generateImage(String prompt);
}