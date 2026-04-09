// lib/models/chat_models.dart
import 'package:uuid/uuid.dart';

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});

  Map<String, dynamic> toJson() => {
    'text': text,
    'isUser': isUser,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    text: json['text'],
    isUser: json['isUser'],
  );
}

class ChatSession {
  final String id;
  String title;
  List<ChatMessage> messages; // Must be a mutable list
  bool isPinned;
  final DateTime createdAt;

  ChatSession({
    String? id,
    required this.title,
    List<ChatMessage>? messages, // 1. Remove the const [] from here
    this.isPinned = false,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        messages = messages ?? []; // 2. Initialize it as a growable list here!

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'messages': messages.map((m) => m.toJson()).toList(),
    'isPinned': isPinned,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'],
      title: json['title'],
      isPinned: json['isPinned'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      messages: (json['messages'] as List).map((m) => ChatMessage.fromJson(m)).toList(),
    );
  }
}