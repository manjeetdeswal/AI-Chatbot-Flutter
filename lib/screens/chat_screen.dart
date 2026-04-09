// lib/screens/chat_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/chat_provider.dart';
import '../services/ai_service.dart';
import '../models/chat_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  File? _attachedFile;
  bool _isImage = false;

  bool _isImageGenerationMode = false;
  final TextEditingController _textController = TextEditingController();
  bool _isDeepResearchActive = false;






  void _triggerImageGeneration() {
    setState(() {
      _isImageGenerationMode = true;
    });
  }




  void _toggleDeepResearch() {
    setState(() {
      _isDeepResearchActive = !_isDeepResearchActive;
    });

    // Optional: Show a little snackbar to confirm
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isDeepResearchActive ? 'Deep Research Enabled' : 'Deep Research Disabled'),
        duration: const Duration(seconds: 2),
      ),
    );
  }








  @override
  void initState() {
    super.initState();
    _initSpeech(); // Initialize mic on startup
  }

  // --- NEW: Speech to Text Logic ---
  void _initSpeech() async {
    await _speech.initialize();
  }

  void _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (result) {
          setState(() {
            _controller.text = result.recognizedWords; // Type as you speak!
          });
        });
      }
    }
  }

  // --- NEW: Image & File Pickers ---
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _attachedFile = File(image.path);
        _isImage = true;
      });
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() {
        _attachedFile = File(result.files.single.path!);
        _isImage = false;
      });
    }
  }

  void _removeAttachment() {
    setState(() {
      _attachedFile = null;
    });
  }
  void _cancelImageMode() {
    setState(() {
      _isImageGenerationMode = false;
      _controller.clear(); // Changed to use your main _controller
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend(ChatProvider provider) {
    // 1. Capture the current state before resetting the UI
    final String textToSend = _controller.text.trim();
    final File? fileToSend = _attachedFile;

    // 2. Only proceed if there is actually something to send
    if (textToSend.isNotEmpty || fileToSend != null) {

      if (_isImageGenerationMode) {
        // --- IMAGE GENERATION ROUTE ---

        // Safety check: Don't allow empty image prompts
        if (textToSend.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please describe the image you want to create.', style: TextStyle(color: Colors.white))),
          );
          return;
        }

        print("Generating image for prompt: $textToSend");
        // Call the provider to generate the image
        provider.generateImage(textToSend);

        _cancelImageMode(); // Resets UI and clears text

      } else {
        // --- NORMAL CHAT ROUTE ---

        print("Sending normal message. Deep Research: $_isDeepResearchActive");
        // Pass the text, the file (if any), and the deep research flag
        provider.sendUserMessage(
          textToSend,
          attachment: fileToSend,
          isDeepResearch: _isDeepResearchActive,
        );

        _controller.clear();

        // Turn off Deep Research after sending so it only applies to this one prompt
        if (_isDeepResearchActive) {
          setState(() {
            _isDeepResearchActive = false;
          });
        }
      }

      // 3. Clean up the UI
      _removeAttachment();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final isHome = chatProvider.pageState == ChatPageState.home;

    // Perplexity-style Dark Theme palette
    const bgDark = Color(0xFF191A1E);
    const bgCard = Color(0xFF202125);
    const accentTeal = Color(0xFF00C7B1);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bgDark,
      drawer: _buildSidebar(chatProvider, bgCard, accentTeal),
        appBar: AppBar(
          backgroundColor: bgDark,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.menu, color: Colors.white70),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          title: Text(
            isHome ? '' : (chatProvider.activeSession?.title ?? 'New Thread'),
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          centerTitle: true,
          actions: [

            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white70),
              onPressed: () => _showSettingsDialog(context),
            ),

            IconButton(
              icon: const Icon(Icons.add_comment, color: Colors.white70),
              onPressed: () => chatProvider.startNewChat(),
            ),
          ],
        ),
      body: Column(
        children: [
          Expanded(
            child: isHome
                ? _buildHomeView(chatProvider, bgCard, accentTeal)
                : _buildChatView(chatProvider),
          ),
          _buildInputArea(chatProvider, bgCard, accentTeal),
        ],
      ),
    );
  }









  // --- 1. SIDEBAR (DRAWER) ---
  Widget _buildSidebar(ChatProvider provider, Color bgCard, Color accentTeal) {
    final pinnedSessions = provider.sessions.where((s) => s.isPinned).toList();
    final recentSessions = provider.sessions.where((s) => !s.isPinned).toList();

    return Drawer(
      backgroundColor: bgCard,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Chat History", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ),

            // Pinned Chats Section
            if (pinnedSessions.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text("PINNED", style: TextStyle(color: Colors.white54, fontSize: 12)),
              ),
              ...pinnedSessions.map((session) => _buildSessionTile(session, provider, accentTeal)),
            ],

            // Recent Chats Section
            if (recentSessions.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text("RECENT", style: TextStyle(color: Colors.white54, fontSize: 12)),
              ),
              Expanded(
                child: ListView(
                  children: recentSessions.map((session) => _buildSessionTile(session, provider, accentTeal)).toList(),
                ),
              ),
            ] else
              const Expanded(child: Center(child: Text("No recent chats", style: TextStyle(color: Colors.white38)))),

            // Import / Export Footer
            const Divider(color: Colors.white10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.upload_file, color: Colors.white70, size: 18),
                  label: const Text("Import", style: TextStyle(color: Colors.white70)),
                  onPressed: () {
                    Navigator.pop(context);
                    provider.importChats();
                  },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.ios_share, color: Colors.white70, size: 18),
                  label: const Text("Export", style: TextStyle(color: Colors.white70)),
                  onPressed: () => provider.exportChats(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionTile(ChatSession session, ChatProvider provider, Color accentTeal) {
    final isActive = provider.activeSession?.id == session.id;
    return ListTile(
      selected: isActive,
      selectedTileColor: accentTeal.withOpacity(0.1),
      title: Text(session.title, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: isActive ? accentTeal : Colors.white)),
      onTap: () {
        provider.loadSession(session);
        Navigator.pop(context); // Close drawer
      },
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Colors.white54, size: 20),
        color: const Color(0xFF2A2B30),
        onSelected: (value) {
          if (value == 'pin') provider.togglePin(session);
          if (value == 'delete') provider.deleteSession(session);
        },
        itemBuilder: (context) => [
          PopupMenuItem(value: 'pin', child: Text(session.isPinned ? "Unpin Chat" : "Pin Chat", style: const TextStyle(color: Colors.white))),
          const PopupMenuItem(value: 'delete', child: Text("Delete Chat", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
  }

  // --- 2. HOME VIEW ---
  Widget _buildHomeView(ChatProvider provider, Color bgCard, Color accent) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'What do you want to know?',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w300),
            ),
            const SizedBox(height: 12),
            Text(
              'Currently using ${provider.currentService.currentModel.displayName}',
              style: const TextStyle(color: Colors.white60, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // --- 3. CHAT VIEW ---
  Widget _buildChatView(ChatProvider provider) {
    _scrollToBottom();
    final messages = provider.activeSession?.messages ?? [];

    return ListView.builder(
      controller: _scrollController,
      itemCount: messages.length,
      padding: const EdgeInsets.all(16.0),
      itemBuilder: (context, index) {
        return MessageBubble(message: messages[index]);
      },
    );
  }

  // --- 4. INPUT AREA & TOOLS ---
  Widget _buildInputArea(ChatProvider provider, Color bgCard, Color accentTeal) {
    final currentModel = provider.currentService.currentModel;
    final bool isTyping = _controller.text.isNotEmpty || _attachedFile != null;

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Container(
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _isListening ? Colors.redAccent : Colors.white10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // NEW: Attachment Preview Area
            if (_attachedFile != null)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 16, right: 16),
                child: Stack(
                  children: [
                    Container(
                      height: 80,
                      width: 80,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(12),
                        image: _isImage
                            ? DecorationImage(image: FileImage(_attachedFile!), fit: BoxFit.cover)
                            : null,
                      ),
                      child: !_isImage ? const Icon(Icons.insert_drive_file, color: Colors.white54) : null,
                    ),
                    Positioned(
                      top: -10,
                      right: -10,
                      child: IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.white70, size: 20),
                        onPressed: _removeAttachment,
                      ),
                    )
                  ],
                ),
              ),

            // Text Input Field
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
              child: Row(
                children: [
                  // Show a brush icon if in image mode
                  if (_isImageGenerationMode)
                    const Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: Icon(Icons.brush, color: Colors.blueAccent),
                    ),

                  // The actual text field
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 5,
                      minLines: 1,
                      onChanged: (text) => setState(() {}),
                      decoration: InputDecoration(
                        // Dynamic hint text and color based on mode
                        hintText: _isImageGenerationMode
                            ? 'Describe the image to create...'
                            : (_isListening ? 'Listening...' : 'Ask anything...'),
                        hintStyle: TextStyle(
                          color: _isImageGenerationMode
                              ? Colors.blueAccent
                              : (_isListening ? Colors.redAccent : Colors.white38),
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  // Show an X to cancel image mode
                  if (_isImageGenerationMode)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                      onPressed: _cancelImageMode,
                    ),
                ],
              ),
            ),

            // Toolbar
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.white70),
                    onPressed: () => _showToolsMenu(context, currentModel),
                  ),
                  InkWell(
                    onTap: () => _showModelPickerSheet(context, provider, accentTeal),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Text(currentModel.displayName, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(width: 4),
                          const Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 14),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),

                  // Dynamic Send / Mic Button
                  if (provider.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white60)),
                    )
                  else if (isTyping)
                    Container(
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_upward, color: Colors.black, size: 20),
                        onPressed: () => _handleSend(provider),
                      ),
                    )
                  else
                    IconButton(
                      icon: Icon(_isListening ? Icons.mic_off : Icons.mic,
                          color: _isListening ? Colors.redAccent : Colors.white70),
                      onPressed: _toggleListening, // Trigger Speech to text
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showToolsMenu(BuildContext context, AIModel currentModel) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF202125),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("Tools & Attachments", style: TextStyle(color: Colors.white54, fontSize: 12)),
              ),



              // --- IMAGE UPLOAD ---
              ListTile(
                leading: const Icon(Icons.image, color: Colors.white),
                title: const Text('Upload Image', style: TextStyle(color: Colors.white)),
                enabled: currentModel.supportsVision,
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),

              // --- DOCUMENT UPLOAD ---
              ListTile(
                leading: const Icon(Icons.attach_file, color: Colors.white),
                title: const Text('Upload Document', style: TextStyle(color: Colors.white)),
                enabled: currentModel.supportsVision,
                onTap: () {
                  Navigator.pop(context);
                  _pickFile();
                },
              ),

              // --- DEEP RESEARCH ---
              ListTile(
                // UI Feedback: Change icon color if the flag is currently active
                leading: Icon(Icons.travel_explore, color: _isDeepResearchActive ? Colors.blueAccent : Colors.white),
                title: const Text('Deep Research', style: TextStyle(color: Colors.white)),
                enabled: currentModel.supportsWebSearch,
                subtitle: currentModel.supportsWebSearch
                    ? Text(_isDeepResearchActive ? 'Active for next prompt' : 'Enable extended web search',
                    style: const TextStyle(color: Colors.white70, fontSize: 12))
                    : const Text('Not supported by this model', style: TextStyle(color: Colors.white38, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _toggleDeepResearch();
                },
              ),

              // --- CREATE IMAGE ---
              ListTile(
                leading: const Icon(Icons.brush, color: Colors.white),
                title: const Text('Create Image', style: TextStyle(color: Colors.white)),
                enabled: currentModel.supportsImageGen,
                subtitle: currentModel.supportsImageGen
                    ? const Text('Generate an image from text', style: TextStyle(color: Colors.white70, fontSize: 12))
                    : const Text('Not supported by this model', style: TextStyle(color: Colors.white38, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _triggerImageGeneration();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showModelPickerSheet(BuildContext context, ChatProvider provider, Color accentTeal) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF191A1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: provider.availableServices.length,
          itemBuilder: (context, serviceIndex) {
            final service = provider.availableServices[serviceIndex];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: Text(
                    service.providerName.toUpperCase(),
                    style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                ...service.availableModels.map((model) {
                  final isSelected = provider.currentService == service && service.currentModel == model;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(model.displayName, style: const TextStyle(color: Colors.white)),
                    trailing: isSelected ? Icon(Icons.check_circle, color: accentTeal) : null,
                    onTap: () {
                      service.setModel(model);
                      provider.switchModel(service);
                      Navigator.pop(context);
                    },
                  );
                }),
                const Divider(color: Colors.white10),
              ],
            );
          },
        );
      },
    );
  }
}

// --- 5. CUSTOM MESSAGE BUBBLE (WITH HTML PREVIEW) ---


class MessageBubble extends StatefulWidget {
  final ChatMessage message;
  const MessageBubble({super.key, required this.message});

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _showPreview = false;

  // Safely check for the html fence without triggering markdown bugs
  bool get _hasHtmlBlock {
    final String fence = '`' * 3;
    return widget.message.text.contains('${fence}html');
  }

  // Safely extract HTML code from inside the markdown block
  String _extractHtml(String text) {
    // Construct the regex dynamically to avoid breaking the markdown parser
    final String fence = '`' * 3;
    final regex = RegExp('$fence' + r'html\n(.*?)\n' + '$fence', dotAll: true);

    final match = regex.firstMatch(text);
    return match?.group(1) ?? text;
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.message;
    const userMsgColor = Color(0xFF2A2B30);

    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        padding: const EdgeInsets.all(12.0),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          color: msg.isUser ? userMsgColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HTML Toggle Button
            if (!msg.isUser && _hasHtmlBlock)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: Icon(_showPreview ? Icons.code : Icons.preview, color: Colors.amber, size: 16),
                  label: Text(
                      _showPreview ? "View Code" : "Preview HTML",
                      style: const TextStyle(color: Colors.amber)
                  ),
                  onPressed: () => setState(() => _showPreview = !_showPreview),
                ),
              ),

            // Message Content
            if (_showPreview && !msg.isUser)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(8),
                child: Html(data: _extractHtml(msg.text)),
              )
            else if (msg.isUser)
              Text(msg.text, style: const TextStyle(color: Colors.white))
            else
              MarkdownBody(
                data: msg.text,
                selectable: true,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
                  code: const TextStyle(backgroundColor: Colors.black26, color: Colors.amberAccent),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

void _showSettingsDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const SettingsDialog(),
  );
}

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final TextEditingController _geminiController = TextEditingController();
  final TextEditingController _openAiController = TextEditingController();
  final TextEditingController _claudeController = TextEditingController();
  final TextEditingController _deepSeekController = TextEditingController();
  final TextEditingController _grokController = TextEditingController();
  final TextEditingController _kimiController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _geminiController.text = prefs.getString('api_key_gemini') ?? '';
      _openAiController.text = prefs.getString('api_key_openai') ?? '';
      _claudeController.text = prefs.getString('api_key_claude') ?? '';
      _deepSeekController.text = prefs.getString('api_key_deepseek') ?? '';
      _grokController.text = prefs.getString('api_key_grok') ?? '';
      _kimiController.text = prefs.getString('api_key_kimi') ?? '';

      _isLoading = false;
    });
  }

  Future<void> _saveKeys() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_key_gemini', _geminiController.text.trim());
    await prefs.setString('api_key_openai', _openAiController.text.trim());
    await prefs.setString('api_key_claude', _claudeController.text.trim());
    await prefs.setString('api_key_grok', _grokController.text.trim());
    await prefs.setString('api_key_kimi', _kimiController.text.trim());
    await prefs.setString('api_key_deepseek', _deepSeekController.text.trim());

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API Keys saved! Please restart the app to apply them.')),
      );
    }
  }

  Future<void> _launchGitHub() async {
    // Make sure to replace YOUR_USERNAME with your actual GitHub username!
    final Uri url = Uri.parse('https://github.com/manjeetdeswal?tab=repositories');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  void dispose() {
    _geminiController.dispose();
    _openAiController.dispose();
    _claudeController.dispose();
    _deepSeekController.dispose();

    _grokController.dispose();
    _kimiController.dispose();
    super.dispose();
  }

  Widget _buildKeyInput(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        obscureText: true, // Hides the key for security
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          filled: true,
          fillColor: Colors.black26,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Dialog(
      backgroundColor: const Color(0xFF202125),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "API Configurations",
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),


              _buildKeyInput("Google Gemini API Key", _geminiController),
              _buildKeyInput("OpenAI API Key", _openAiController),
              _buildKeyInput("Anthropic (Claude) API Key", _claudeController),
              _buildKeyInput("xAI (Grok) API Key", _grokController),
              _buildKeyInput("Moonshot (Kimi) API Key", _kimiController),
              _buildKeyInput("DeepSeek API Key", _deepSeekController),

              const SizedBox(height: 8),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C7B1),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _saveKeys,
                child: const Text("Save Keys", style: TextStyle(fontWeight: FontWeight.bold)),
              ),

              const SizedBox(height: 16),
              const Divider(color: Colors.white10),
              const SizedBox(height: 8),


              TextButton.icon(
                icon: const Icon(Icons.code, color: Colors.white70),
                label: const Text("Support / Developer GitHub", style: TextStyle(color: Colors.white70)),
                onPressed: _launchGitHub,
              ),

              TextButton(
                child: const Text("Cancel", style: TextStyle(color: Colors.white38)),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
        ),
      ),
    );
  }
}