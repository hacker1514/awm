import 'package:flutter/material.dart';

enum AppThemeMode {
  amoledBlack,
  cyberMidnight,
  slateNavy,
  emeraldObsidian,
}

class AppThemeData {
  final String name;
  final Color backgroundColor;
  final Color cardColor;
  final Color appBarColor;
  final Color primaryColor;
  final Color accentColor;
  final Color userBubbleGradientStart;
  final Color userBubbleGradientEnd;
  final Color aiBubbleColor;
  final Color textPrimary;
  final Color textSecondary;

  const AppThemeData({
    required this.name,
    required this.backgroundColor,
    required this.cardColor,
    required this.appBarColor,
    required this.primaryColor,
    required this.accentColor,
    required this.userBubbleGradientStart,
    required this.userBubbleGradientEnd,
    required this.aiBubbleColor,
    required this.textPrimary,
    required this.textSecondary,
  });
}

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  AppThemeMode _currentThemeMode = AppThemeMode.emeraldObsidian;
  double _fontSize = 15.0; // 14.0 = Small, 15.0 = Medium, 17.0 = Large
  String _activePersona = "Standard AWM";

  AppThemeMode get currentThemeMode => _currentThemeMode;
  double get fontSize => _fontSize;
  String get activePersona => _activePersona;

  static const Map<AppThemeMode, AppThemeData> themes = {
    AppThemeMode.amoledBlack: AppThemeData(
      name: "Pure AMOLED Black",
      backgroundColor: Color(0xFF000000),
      cardColor: Color(0xFF0E0E12),
      appBarColor: Color(0xFF070709),
      primaryColor: Color(0xFF6366F1),
      accentColor: Color(0xFF06B6D4),
      userBubbleGradientStart: Color(0xFF6366F1),
      userBubbleGradientEnd: Color(0xFF4F46E5),
      aiBubbleColor: Color(0xFF121218),
      textPrimary: Colors.white,
      textSecondary: Color(0xFF94A3B8),
    ),
    AppThemeMode.cyberMidnight: AppThemeData(
      name: "Cyber Midnight",
      backgroundColor: Color(0xFF050814),
      cardColor: Color(0xFF0F172A),
      appBarColor: Color(0xFF090D1F),
      primaryColor: Color(0xFF06B6D4),
      accentColor: Color(0xFF3B82F6),
      userBubbleGradientStart: Color(0xFF06B6D4),
      userBubbleGradientEnd: Color(0xFF2563EB),
      aiBubbleColor: Color(0xFF1E293B),
      textPrimary: Colors.white,
      textSecondary: Color(0xFF94A3B8),
    ),
    AppThemeMode.slateNavy: AppThemeData(
      name: "Deep Slate Navy",
      backgroundColor: Color(0xFF0B132B),
      cardColor: Color(0xFF1C2541),
      appBarColor: Color(0xFF111827),
      primaryColor: Color(0xFF38BDF8),
      accentColor: Color(0xFF818CF8),
      userBubbleGradientStart: Color(0xFF2563EB),
      userBubbleGradientEnd: Color(0xFF1D4ED8),
      aiBubbleColor: Color(0xFF1F2937),
      textPrimary: Colors.white,
      textSecondary: Color(0xFF9CA3AF),
    ),
    AppThemeMode.emeraldObsidian: AppThemeData(
      name: "Emerald Obsidian",
      backgroundColor: Color(0xFF040D08),
      cardColor: Color(0xFF0B1E14),
      appBarColor: Color(0xFF06140D),
      primaryColor: Color(0xFF10B981),
      accentColor: Color(0xFF34D399),
      userBubbleGradientStart: Color(0xFF059669),
      userBubbleGradientEnd: Color(0xFF047857),
      aiBubbleColor: Color(0xFF112A1D),
      textPrimary: Colors.white,
      textSecondary: Color(0xFFA7F3D0),
    ),
  };

  AppThemeData get activeTheme => themes[_currentThemeMode]!;

  void setThemeMode(AppThemeMode mode) {
    _currentThemeMode = mode;
    notifyListeners();
  }

  void setFontSize(double size) {
    _fontSize = size;
    notifyListeners();
  }

  void setActivePersona(String persona) {
    _activePersona = persona;
    notifyListeners();
  }
}
