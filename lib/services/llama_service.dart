import 'dart:async';
import 'package:flutter/services.dart';
import '../models/chat_message.dart';

class LlamaService {
  static const MethodChannel _methodChannel =
      MethodChannel('com.awm.aiwithme/llama_method');
  static const EventChannel _eventChannel =
      EventChannel('com.awm.aiwithme/llama_event');

  StreamSubscription? _eventSubscription;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  bool _isGenerating = false;
  bool get isGenerating => _isGenerating;

  static const String baseSystemPrompt =
      "You are AWM (AI With Me), an advanced, intelligent, and friendly offline AI assistant created and developed by Niranjan Kumar K.\n"
      "Key Facts about AWM:\n"
      "- Identity: AWM (AI With Me)\n"
      "- Creator & Developer: Niranjan Kumar K\n"
      "- Nature: 100% offline, privacy-first local AI assistant running directly on the user's mobile device.\n"
      "- Purpose: Help users with coding, writing, reasoning, math, answering questions, and daily tasks with zero internet.\n"
      "Whenever asked who you are, what AWM is, or who developed you, state clearly that you are AWM (AI With Me), created and developed by Niranjan Kumar K.";

  String getSystemPromptForPersona(String persona) {
    switch (persona) {
      case "Code Master":
        return "$baseSystemPrompt\nMode: Code Master. Focus on precise code implementations, clear logic, clean structure, and efficient software design.";
      case "Creative Writer":
        return "$baseSystemPrompt\nMode: Creative Writer. Focus on engaging storytelling, expressive language, and creative ideas.";
      case "Concise Expert":
        return "$baseSystemPrompt\nMode: Concise Expert. Keep responses brief, direct, bulleted, and to the point.";
      default:
        return baseSystemPrompt;
    }
  }

  Future<bool> initModel(String modelPath, {int nCtx = 1024, int nThreads = 2}) async {
    try {
      final bool success = await _methodChannel.invokeMethod('initModel', {
        'modelPath': modelPath,
        'nCtx': nCtx,
        'nThreads': nThreads,
      });
      _isInitialized = success;
      return success;
    } catch (e) {
      _isInitialized = false;
      return false;
    }
  }

  String formatPrompt(
    String currentInput,
    List<ChatMessage> history, {
    String persona = "Standard AWM",
    bool singleQuestionMode = true,
  }) {
    final sb = StringBuffer();
    final systemPrompt = getSystemPromptForPersona(persona);

    // Phi-3 / SmolLM Chat Template (<|im_start|>system / user / assistant <|im_end|>)
    sb.write("<|im_start|>system\n$systemPrompt<|im_end|>\n");

    // Only include recent history if singleQuestionMode is false
    if (!singleQuestionMode && history.isNotEmpty) {
      final recentHistory = history.length > 2
          ? history.sublist(history.length - 2)
          : history;

      for (final msg in recentHistory) {
        if (msg.role == MessageRole.user) {
          sb.write("<|im_start|>user\n${msg.content}<|im_end|>\n");
        } else if (msg.role == MessageRole.assistant) {
          sb.write("<|im_start|>assistant\n${msg.content}<|im_end|>\n");
        }
      }
    }

    // Current prompt (Single Question & Answer mode)
    sb.write("<|im_start|>user\n$currentInput<|im_end|>\n");
    sb.write("<|im_start|>assistant\n");

    return sb.toString();
  }

  Stream<String> generateResponse(
    String currentInput,
    List<ChatMessage> history, {
    String persona = "Standard AWM",
    bool singleQuestionMode = true,
  }) {
    final controller = StreamController<String>();
    final formattedPrompt = formatPrompt(
      currentInput,
      history,
      persona: persona,
      singleQuestionMode: singleQuestionMode,
    );

    _isGenerating = true;

    _eventSubscription?.cancel();
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map) {
          final type = event['type'];
          if (type == 'token') {
            final content = event['content'] as String?;
            if (content != null) {
              controller.add(content);
            }
          } else if (type == 'done') {
            _isGenerating = false;
            controller.close();
          }
        }
      },
      onError: (error) {
        _isGenerating = false;
        controller.addError(error);
        controller.close();
      },
      onDone: () {
        _isGenerating = false;
        if (!controller.isClosed) {
          controller.close();
        }
      },
    );

    _methodChannel.invokeMethod('generate', {'prompt': formattedPrompt}).catchError((err) {
      _isGenerating = false;
      controller.addError("Generation error: $err");
      controller.close();
    });

    return controller.stream;
  }

  Future<void> stopGeneration() async {
    try {
      await _methodChannel.invokeMethod('stopGeneration');
    } catch (_) {}
    _isGenerating = false;
  }

  Future<void> freeModel() async {
    _eventSubscription?.cancel();
    try {
      await _methodChannel.invokeMethod('freeModel');
    } catch (_) {}
    _isInitialized = false;
    _isGenerating = false;
  }
}
