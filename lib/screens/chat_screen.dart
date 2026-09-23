import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_highlighter/flutter_highlighter.dart';
import 'package:flutter_highlighter/themes/atom-one-dark.dart';
import '../models/chat_message.dart';
import '../services/llama_service.dart';
import '../services/model_manager.dart';
import '../services/chat_storage.dart';
import '../services/theme_service.dart';
import 'settings_screen.dart';

class ChatScreen extends StatefulWidget {
  final LlamaService llamaService;
  final ModelManager modelManager;

  const ChatScreen({
    super.key,
    required this.llamaService,
    required this.modelManager,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatStorage _chatStorage = ChatStorage();
  final ThemeService _themeService = ThemeService();

  bool _isGenerating = false;
  bool _isSearching = false;
  String _searchQuery = "";
  String _currentStreamResponse = "";
  StreamSubscription<String>? _generationSubscription;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _loadHistory();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadHistory() async {
    final history = await _chatStorage.loadHistory();
    if (mounted) {
      setState(() {
        _messages.addAll(history);
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage({String? customText}) async {
    final text = (customText ?? _inputController.text).trim();
    if (text.isEmpty || _isGenerating) return;

    if (customText == null) {
      _inputController.clear();
    }

    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: MessageRole.user,
      content: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isGenerating = true;
      _currentStreamResponse = "";
    });
    _scrollToBottom();

    await _chatStorage.saveHistory(_messages);

    final historyBeforeCurrent = List<ChatMessage>.from(_messages.sublist(0, _messages.length - 1));

    _generationSubscription = widget.llamaService
        .generateResponse(
          text,
          historyBeforeCurrent,
          persona: _themeService.activePersona,
        )
        .listen(
      (token) {
        if (!mounted) return;
        setState(() {
          _currentStreamResponse += token;
        });
        _scrollToBottom();
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isGenerating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Generation error: $error")),
        );
      },
      onDone: () async {
        if (_currentStreamResponse.isNotEmpty) {
          final aiMessage = ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            role: MessageRole.assistant,
            content: _currentStreamResponse.trim(),
            timestamp: DateTime.now(),
          );
          if (!mounted) return;
          setState(() {
            _messages.add(aiMessage);
            _currentStreamResponse = "";
            _isGenerating = false;
          });
          await _chatStorage.saveHistory(_messages);
        } else {
          if (!mounted) return;
          setState(() {
            _isGenerating = false;
          });
        }
        _scrollToBottom();
      },
    );
  }

  Future<void> _stopGeneration() async {
    await widget.llamaService.stopGeneration();
    _generationSubscription?.cancel();
    if (_currentStreamResponse.isNotEmpty) {
      final aiMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: MessageRole.assistant,
        content: _currentStreamResponse.trim(),
        timestamp: DateTime.now(),
      );
      if (!mounted) return;
      setState(() {
        _messages.add(aiMessage);
        _currentStreamResponse = "";
        _isGenerating = false;
      });
      await _chatStorage.saveHistory(_messages);
    } else {
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
      });
    }
  }

  Future<void> _clearHistory() async {
    await _chatStorage.clearHistory();
    if (!mounted) return;
    setState(() {
      _messages.clear();
    });
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Copied to clipboard!"),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    _generationSubscription?.cancel();
    _inputController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = _themeService.activeTheme;
    final fontSize = _themeService.fontSize;

    final filteredMessages = _searchQuery.isEmpty
        ? _messages
        : _messages.where((m) => m.content.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarColor,
        elevation: 0,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: theme.textPrimary),
                decoration: InputDecoration(
                  hintText: "Search chat...",
                  hintStyle: TextStyle(color: theme.textSecondary),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              )
            : Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [theme.primaryColor, theme.accentColor],
                      ),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/awy_logo.png',
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "AWM",
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        "AI With Me • ${_themeService.activePersona}",
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded, color: theme.textPrimary),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = "";
                  _searchController.clear();
                }
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: theme.textPrimary),
            tooltip: "Settings",
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    modelManager: widget.modelManager,
                    llamaService: widget.llamaService,
                  ),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: theme.textPrimary),
            color: theme.cardColor,
            onSelected: (value) async {
              if (value == 'clear') {
                _clearHistory();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, color: theme.textPrimary, size: 20),
                    const SizedBox(width: 10),
                    Text("Clear Chat History", style: TextStyle(color: theme.textPrimary)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat Messages List or Empty State
          Expanded(
            child: _messages.isEmpty && !_isGenerating
                ? SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: theme.primaryColor.withValues(alpha: 0.3),
                                blurRadius: 30,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/awy_logo.png',
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "Ask AWM Anything",
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "100% Offline AI Assistant • Developed by Niranjan Kumar K",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 32),

                        // Quick Starter Action Chips
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildQuickChip("Who are you & who created AWM?", theme),
                            _buildQuickChip("Write a Python script for array sorting", theme),
                            _buildQuickChip("Explain Quantum Physics simply", theme),
                            _buildQuickChip("Top tips for productivity & focus", theme),
                          ],
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    itemCount: filteredMessages.length + (_isGenerating ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < filteredMessages.length) {
                        return _buildMessageBubble(filteredMessages[index], theme, fontSize);
                      } else {
                        return _buildStreamingBubble(theme, fontSize);
                      }
                    },
                  ),
          ),

          // Input Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.appBarColor,
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      style: TextStyle(color: theme.textPrimary, fontSize: fontSize),
                      maxLines: 4,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: "Type your message...",
                        hintStyle: TextStyle(color: theme.textSecondary),
                        filled: true,
                        fillColor: theme.cardColor,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (_isGenerating) ...[
                    IconButton(
                      onPressed: _stopGeneration,
                      icon: const Icon(Icons.stop_circle_rounded, color: Color(0xFFEF4444), size: 38),
                      tooltip: "Stop Generation",
                    ),
                  ] else ...[
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [theme.primaryColor, theme.accentColor],
                        ),
                      ),
                      child: IconButton(
                        onPressed: () => _sendMessage(),
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        tooltip: "Send Message",
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String label, AppThemeData theme) {
    return ActionChip(
      backgroundColor: theme.cardColor,
      side: BorderSide(color: theme.primaryColor.withValues(alpha: 0.3)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      label: Text(
        label,
        style: TextStyle(color: theme.textPrimary, fontSize: 13),
      ),
      onPressed: () => _sendMessage(customText: label),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, AppThemeData theme, double fontSize) {
    final isUser = msg.role == MessageRole.user;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.86,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: isUser
              ? LinearGradient(
                  colors: [theme.userBubbleGradientStart, theme.userBubbleGradientEnd],
                )
              : null,
          color: isUser ? null : theme.aiBubbleColor,
          border: isUser
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isUser)
              SelectableText(
                msg.content,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  height: 1.45,
                ),
              )
            else
              MarkdownBody(
                data: msg.content,
                selectable: true,
                styleSheet: _buildMarkdownStyleSheet(theme, fontSize, isUser),
                builders: {
                  'pre': CustomCodeBlockBuilder(theme, context),
                },
              ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Spacer(),
                InkWell(
                  onTap: () => _copyToClipboard(msg.content),
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.copy_rounded,
                          size: 13,
                          color: isUser ? Colors.white70 : theme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "Copy",
                          style: TextStyle(
                            fontSize: 11,
                            color: isUser ? Colors.white70 : theme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamingBubble(AppThemeData theme, double fontSize) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.86,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.aiBubbleColor,
          border: Border.all(color: theme.primaryColor.withValues(alpha: 0.3)),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_currentStreamResponse.isEmpty)
              Text(
                "AWM is thinking...",
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: fontSize,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              MarkdownBody(
                data: _currentStreamResponse,
                selectable: true,
                styleSheet: _buildMarkdownStyleSheet(theme, fontSize, false),
                builders: {
                  'pre': CustomCodeBlockBuilder(theme, context),
                },
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.primaryColor,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "Generating...",
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  MarkdownStyleSheet _buildMarkdownStyleSheet(AppThemeData theme, double fontSize, bool isUser) {
    final baseTextColor = isUser ? Colors.white : theme.textPrimary;
    return MarkdownStyleSheet(
      p: TextStyle(
        color: baseTextColor,
        fontSize: fontSize,
        height: 1.5,
      ),
      h1: TextStyle(
        color: isUser ? Colors.white : theme.primaryColor,
        fontSize: fontSize + 5,
        fontWeight: FontWeight.bold,
        height: 1.4,
      ),
      h2: TextStyle(
        color: isUser ? Colors.white : theme.accentColor,
        fontSize: fontSize + 3,
        fontWeight: FontWeight.bold,
        height: 1.35,
      ),
      h3: TextStyle(
        color: isUser ? Colors.white : theme.primaryColor,
        fontSize: fontSize + 2,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      h4: TextStyle(
        color: isUser ? Colors.white : theme.accentColor,
        fontSize: fontSize + 1,
        fontWeight: FontWeight.w600,
      ),
      strong: TextStyle(
        color: isUser ? Colors.white : theme.primaryColor,
        fontWeight: FontWeight.bold,
      ),
      em: TextStyle(
        color: baseTextColor.withValues(alpha: 0.9),
        fontStyle: FontStyle.italic,
      ),
      code: TextStyle(
        color: isUser ? Colors.white : theme.accentColor,
        backgroundColor: isUser
            ? Colors.white.withValues(alpha: 0.2)
            : theme.primaryColor.withValues(alpha: 0.15),
        fontFamily: 'monospace',
        fontSize: fontSize - 1,
      ),
      codeblockDecoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.3)),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      blockquote: TextStyle(
        color: theme.textSecondary,
        fontStyle: FontStyle.italic,
      ),
      blockquoteDecoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(4),
        border: Border(
          left: BorderSide(color: theme.primaryColor, width: 3),
        ),
      ),
      blockquotePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      listBullet: TextStyle(
        color: isUser ? Colors.white : theme.primaryColor,
        fontWeight: FontWeight.bold,
      ),
      a: TextStyle(
        color: theme.primaryColor,
        decoration: TextDecoration.underline,
      ),
    );
  }
}

class CustomCodeBlockBuilder extends MarkdownElementBuilder {
  final AppThemeData theme;
  final BuildContext context;
  CustomCodeBlockBuilder(this.theme, this.context);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    var language = '';
    if (element.attributes['class'] != null) {
      String lg = element.attributes['class'] as String;
      language = lg.replaceFirst('language-', '');
    }
    final String codeContent = element.textContent.trimRight();

    final customSyntaxTheme = Map<String, TextStyle>.from(atomOneDarkTheme);
    customSyntaxTheme['root'] = const TextStyle(
      backgroundColor: Colors.transparent,
      color: Color(0xFFABB2BF),
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF090D16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.primaryColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.terminal_rounded, size: 14, color: theme.primaryColor),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      language.isEmpty ? "code" : language.toUpperCase(),
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: codeContent));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text("Code copied to clipboard!"),
                        backgroundColor: theme.cardColor,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: theme.primaryColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.copy_rounded, size: 12, color: theme.primaryColor),
                        const SizedBox(width: 4),
                        Text(
                          "Copy",
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // High-precision Colorful Code Renderer
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(11),
              bottomRight: Radius.circular(11),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: HighlightView(
                codeContent,
                language: language.isEmpty ? 'plaintext' : language.toLowerCase(),
                theme: customSyntaxTheme,
                padding: EdgeInsets.zero,
                textStyle: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
