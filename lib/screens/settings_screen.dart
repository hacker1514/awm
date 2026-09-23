import 'package:flutter/material.dart';
import '../services/model_manager.dart';
import '../services/llama_service.dart';
import '../services/chat_storage.dart';
import '../services/theme_service.dart';
import 'model_setup_screen.dart';

class SettingsScreen extends StatefulWidget {
  final ModelManager modelManager;
  final LlamaService llamaService;

  const SettingsScreen({
    super.key,
    required this.modelManager,
    required this.llamaService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ThemeService _themeService = ThemeService();

  @override
  Widget build(BuildContext context) {
    final theme = _themeService.activeTheme;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarColor,
        elevation: 0,
        title: Text(
          "Settings",
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AWM Platform Identity Card (Developer name appears ONCE here)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.primaryColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [theme.primaryColor, theme.accentColor],
                      ),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/awy_logo.png',
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "AWM",
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          "AI With Me",
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Developer: Niranjan Kumar K",
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Theme Customization Section
            _buildSectionHeader("APPEARANCE & THEME", theme),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: AppThemeMode.values.map((mode) {
                  final themeData = ThemeService.themes[mode]!;
                  final isSelected = _themeService.currentThemeMode == mode;
                  return Column(
                    children: [
                      ListTile(
                        leading: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: themeData.backgroundColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: themeData.primaryColor, width: 2),
                          ),
                        ),
                        title: Text(
                          themeData.name,
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle_rounded, color: theme.primaryColor)
                            : null,
                        onTap: () {
                          setState(() {
                            _themeService.setThemeMode(mode);
                          });
                        },
                      ),
                      if (mode != AppThemeMode.values.last)
                        const Divider(color: Colors.white10, height: 1),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Font Size & Persona Controls
            _buildSectionHeader("CUSTOMIZATION", theme),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.format_size_rounded, color: theme.primaryColor),
                    title: Text("Chat Text Size", style: TextStyle(color: theme.textPrimary, fontSize: 15)),
                    subtitle: Text(
                      _themeService.fontSize == 14.0
                          ? "Small"
                          : (_themeService.fontSize == 15.0 ? "Medium" : "Large"),
                      style: TextStyle(color: theme.textSecondary, fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ChoiceChip(
                          label: const Text("S"),
                          selected: _themeService.fontSize == 14.0,
                          onSelected: (_) => setState(() => _themeService.setFontSize(14.0)),
                        ),
                        const SizedBox(width: 4),
                        ChoiceChip(
                          label: const Text("M"),
                          selected: _themeService.fontSize == 15.0,
                          onSelected: (_) => setState(() => _themeService.setFontSize(15.0)),
                        ),
                        const SizedBox(width: 4),
                        ChoiceChip(
                          label: const Text("L"),
                          selected: _themeService.fontSize == 17.0,
                          onSelected: (_) => setState(() => _themeService.setFontSize(17.0)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  ListTile(
                    leading: Icon(Icons.psychology_rounded, color: theme.primaryColor),
                    title: Text("Assistant Persona Mode", style: TextStyle(color: theme.textPrimary, fontSize: 15)),
                    subtitle: Text(_themeService.activePersona, style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                    trailing: DropdownButton<String>(
                      value: _themeService.activePersona,
                      dropdownColor: theme.cardColor,
                      underline: const SizedBox(),
                      style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold),
                      items: const [
                        DropdownMenuItem(value: "Standard AWM", child: Text("Standard")),
                        DropdownMenuItem(value: "Code Master", child: Text("Coder")),
                        DropdownMenuItem(value: "Creative Writer", child: Text("Creative")),
                        DropdownMenuItem(value: "Concise Expert", child: Text("Concise")),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _themeService.setActivePersona(val);
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Platform Details
            _buildSectionHeader("PLATFORM & ENGINE", theme),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  _buildSettingTile(
                    icon: Icons.memory_rounded,
                    title: "AI Engine",
                    subtitle: "AWM Core Engine (~258 MB)",
                    trailing: Text(
                      "v1.0.0",
                      style: TextStyle(color: theme.textSecondary, fontSize: 13),
                    ),
                    theme: theme,
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  _buildSettingTile(
                    icon: Icons.security_rounded,
                    title: "Privacy Standard",
                    subtitle: "100% On-Device • Zero Remote Data Collection",
                    trailing: const Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 20),
                    theme: theme,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Actions Section
            _buildSectionHeader("DATA & STORAGE", theme),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: Colors.white70),
                    title: Text("Clear Chat History", style: TextStyle(color: theme.textPrimary, fontSize: 15)),
                    subtitle: Text("Erases local conversation records", style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await ChatStorage().clearHistory();
                      if (!mounted) return;
                      messenger.showSnackBar(
                        const SnackBar(content: Text("Chat history cleared.")),
                      );
                    },
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  ListTile(
                    leading: const Icon(Icons.refresh_rounded, color: Color(0xFFF87171)),
                    title: const Text("Reset / Redownload AI Model", style: TextStyle(color: Color(0xFFF87171), fontSize: 15)),
                    subtitle: Text("Deletes local model file and re-downloads", style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                    onTap: () async {
                      final nav = Navigator.of(context);
                      await widget.llamaService.freeModel();
                      await widget.modelManager.deleteModel();
                      nav.pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => ModelSetupScreen(
                            modelManager: widget.modelManager,
                            llamaService: widget.llamaService,
                          ),
                        ),
                        (route) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, AppThemeData theme) {
    return Text(
      title,
      style: TextStyle(
        color: theme.primaryColor,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required AppThemeData theme,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: theme.primaryColor),
      title: Text(title, style: TextStyle(color: theme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: theme.textSecondary, fontSize: 12)),
      trailing: trailing,
    );
  }
}
