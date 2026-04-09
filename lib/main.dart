// lib/main.dart
import 'package:ai_chatbot_flutter/services/openai_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Add this import!

import 'providers/chat_provider.dart';
import 'screens/chat_screen.dart';
import 'services/claude_service.dart';
import 'services/deepseek_service.dart';
import 'services/gemini_service.dart';
import 'services/grok_service.dart';
import 'services/kimi_service.dart';

Future<void> main() async {
  // Required when doing async operations before runApp
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (your default developer keys)
  await dotenv.load(fileName: ".env");

  // Load user settings (keys inputted via the app UI)
  final prefs = await SharedPreferences.getInstance();

  // Helper function to check SharedPreferences first, then fallback to .env
  String getKey(String prefsKey, String envKey) {
    final savedKey = prefs.getString(prefsKey);
    if (savedKey != null && savedKey.trim().isNotEmpty) {
      return savedKey.trim();
    }
    return dotenv.env[envKey] ?? '';
  }

  // Retrieve keys using the priority helper
  final geminiKey = getKey('api_key_gemini', 'GEMINI_API_KEY');
  final claudeKey = getKey('api_key_claude', 'CLAUDE_API_KEY');
  final grokKey = getKey('api_key_grok', 'GROK_API_KEY');
  final kimiKey = getKey('api_key_kimi', 'KIMI_API_KEY');
  final deepseekKey = getKey('api_key_deepseek', 'DEEPSEEK_API_KEY');
  final openAiKey = getKey('api_key_openai', 'OPENAI_API_KEY');


  runApp(
    ChangeNotifierProvider(
      create: (context) => ChatProvider([
        // Order here determines the default
        GeminiService(geminiKey),
        ClaudeService(claudeKey),
        GrokService(grokKey),
        KimiService(kimiKey),
        DeepSeekService(deepseekKey),
        OpenAIService(openAiKey)
      ]),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Perplexity Style AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFF00C7B1),
        scaffoldBackgroundColor: const Color(0xFF191A1E),
      ),
      home: const ChatScreen(),
    );
  }
}