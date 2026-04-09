import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../services/ai_service.dart';
import '../models/chat_models.dart';

enum ChatPageState { home, chatting }

class ChatProvider extends ChangeNotifier {
  List<ChatSession> _sessions = [];
  List<ChatSession> get sessions => _sessions;

  ChatSession? _activeSession;
  ChatSession? get activeSession => _activeSession;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  ChatPageState get pageState => _activeSession == null || _activeSession!.messages.isEmpty
      ? ChatPageState.home
      : ChatPageState.chatting;

  final List<AIService> availableServices;
  late AIService _currentService;
  AIService get currentService => _currentService;

  ChatProvider(this.availableServices) {
    _currentService = availableServices.first; // Default fallback
    _initializeApp(); // Run our async initializers
  }

  Future<void> _initializeApp() async {
    await _loadSelectedModel();
    await _loadSessions();
  }

  // 2. UPDATED SWITCH MODEL
  void switchModel(AIService newService) {
    _currentService = newService;
    _saveSelectedModel(); // Save it whenever it changes!
    notifyListeners();
  }

  Future<void> _saveSelectedModel() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_provider', _currentService.providerName);
    await prefs.setString('saved_model_id', _currentService.currentModel.id);
  }

  Future<void> _loadSelectedModel() async {
    final prefs = await SharedPreferences.getInstance();
    final savedProvider = prefs.getString('saved_provider');
    final savedModelId = prefs.getString('saved_model_id');

    if (savedProvider != null && savedModelId != null) {
      try {
        // 1. Find the matching provider (e.g., "Google" or "OpenAI")
        final targetService = availableServices.firstWhere(
              (s) => s.providerName == savedProvider,
        );

        // 2. Find the exact model inside that provider (e.g., "gemini-3.1-pro-preview")
        final targetModel = targetService.availableModels.firstWhere(
              (m) => m.id == savedModelId,
        );

        // 3. Set them as active
        targetService.setModel(targetModel);
        _currentService = targetService;
        notifyListeners();
      } catch (e) {
        // If the saved model was removed or updated in the code, it gracefully falls back
        debugPrint("Could not restore saved model: $e");
      }
    }
  }

  // --- SESSION MANAGEMENT ---
  void startNewChat() {
    // Create the session, but DO NOT add it to the _sessions list or save it yet!
    _activeSession = ChatSession(title: "New Chat");
    notifyListeners();
  }

  void loadSession(ChatSession session) {
    _activeSession = session;
    notifyListeners();
  }

  void togglePin(ChatSession session) {
    session.isPinned = !session.isPinned;
    _saveSessions();
    notifyListeners();
  }

  void deleteSession(ChatSession session) {
    _sessions.remove(session);
    if (_activeSession == session) _activeSession = null;
    _saveSessions();
    notifyListeners();
  }

  // --- SENDING MESSAGES (UPDATED FOR ATTACHMENTS & RESEARCH) ---
  Future<void> sendUserMessage(
      String text, {
        File? attachment,
        bool isDeepResearch = false,
      }) async {
    // If there is no text AND no attachment, do nothing
    if (text.trim().isEmpty && attachment == null) return;

    // Safety check just in case
    if (_activeSession == null) startNewChat();

    // Check if this is the very first message of the session
    bool isFirstMessage = _activeSession!.messages.isEmpty;

    if (isFirstMessage) {
      // Auto-generate title. If text is empty (user just sent an image), use a fallback.
      String titleText = text.trim().isNotEmpty ? text : "Attachment uploaded";
      _activeSession!.title = titleText.length > 25 ? "${titleText.substring(0, 25)}..." : titleText;
      // NOW we officially add it to the history list
      _sessions.insert(0, _activeSession!);
    }

    // Determine what to show in the UI for the user's message bubble
    String uiText = text;
    if (attachment != null) {
      // Just adding a little visual indicator that a file was sent alongside the text
      uiText = text.isEmpty ? "[Attachment: ${attachment.path.split('/').last}]"
          : "$text\n\n[Attachment: ${attachment.path.split('/').last}]";
    }

    _activeSession!.messages.add(ChatMessage(text: uiText, isUser: true));
    _isLoading = true;
    notifyListeners();

    final history = _activeSession!.messages.map((m) => {
      "role": m.isUser ? "user" : "assistant",
      "content": m.text
    }).toList();

    try {
      // IMPORTANT: You will need to update your AIService's sendMessage method
      // to accept these new parameters so it can actually process them!
      final responseText = await _currentService.sendMessage(
        text,
        history: history,
        attachment: attachment,
        isDeepResearch: isDeepResearch,
      );

      _activeSession!.messages.add(ChatMessage(text: responseText, isUser: false));
    } catch (e) {
      _activeSession!.messages.add(ChatMessage(text: "Error: $e", isUser: false));
    }

    _isLoading = false;
    _saveSessions(); // Save to database after the AI replies
    notifyListeners();
  }

  // --- IMAGE GENERATION (NEW) ---
  Future<void> generateImage(String prompt) async {
    if (prompt.trim().isEmpty) return;

    if (_activeSession == null) startNewChat();
    bool isFirstMessage = _activeSession!.messages.isEmpty;

    if (isFirstMessage) {
      _activeSession!.title = "Image: ${prompt.length > 20 ? prompt.substring(0, 20) : prompt}...";
      _sessions.insert(0, _activeSession!);
    }

    _activeSession!.messages.add(ChatMessage(text: prompt, isUser: true));
    _isLoading = true;
    notifyListeners();

    try {
      // IMPORTANT: You will need to add a generateImage method to your AIService class
      final imageUrlOrMarkdown = await _currentService.generateImage(prompt);

      _activeSession!.messages.add(ChatMessage(text: imageUrlOrMarkdown, isUser: false));
    } catch (e) {
      _activeSession!.messages.add(ChatMessage(text: "Error generating image: $e", isUser: false));
    }

    _isLoading = false;
    _saveSessions();
    notifyListeners();
  }

  // --- LOCAL STORAGE ---
  Future<void> _saveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(_sessions.map((s) => s.toJson()).toList());
    await prefs.setString('chat_history', encodedData);
  }

  Future<void> _loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encodedData = prefs.getString('chat_history');
    if (encodedData != null) {
      final List decodedData = jsonDecode(encodedData);

      _sessions = decodedData
          .map((json) => ChatSession.fromJson(json))
      // Clean up old bugs: Filter out any saved sessions that have 0 messages
          .where((session) => session.messages.isNotEmpty)
          .toList();

      notifyListeners();
    }
  }

  // --- IMPORT / EXPORT ---
  Future<void> exportChats() async {
    final String encodedData = jsonEncode(_sessions.map((s) => s.toJson()).toList());
    await Share.share(encodedData, subject: 'My AI Chat History Backup');
  }

  Future<void> importChats() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      String jsonString = await file.readAsString();
      try {
        final List decodedData = jsonDecode(jsonString);
        final newSessions = decodedData.map((json) => ChatSession.fromJson(json)).toList();
        _sessions.addAll(newSessions);
        _saveSessions();
        notifyListeners();
      } catch (e) {
        debugPrint("Error importing chats: $e");
      }
    }
  }
}