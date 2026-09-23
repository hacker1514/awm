import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';

class ChatStorage {
  static const String _storageKey = "awy_chat_history_v1";

  Future<List<ChatMessage>> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr == null || jsonStr.isEmpty) return [];

      final List<dynamic> list = jsonDecode(jsonStr);
      return list.map((item) => ChatMessage.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveHistory(List<ChatMessage> history) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = history.map((msg) => msg.toJson()).toList();
      final jsonStr = jsonEncode(list);
      await prefs.setString(_storageKey, jsonStr);
    } catch (_) {}
  }

  Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {}
  }
}
