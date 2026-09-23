import 'package:flutter/material.dart';
import 'services/model_manager.dart';
import 'services/llama_service.dart';
import 'services/theme_service.dart';
import 'screens/model_setup_screen.dart';
import 'screens/chat_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AWMApp());
}

class AWMApp extends StatelessWidget {
  const AWMApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();

    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        final activeTheme = themeService.activeTheme;

        return MaterialApp(
          title: 'AWM — AI With Me',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: activeTheme.backgroundColor,
            primaryColor: activeTheme.primaryColor,
            colorScheme: ColorScheme.dark(
              primary: activeTheme.primaryColor,
              surface: activeTheme.backgroundColor,
            ),
            useMaterial3: true,
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final ModelManager _modelManager = ModelManager();
  final LlamaService _llamaService = LlamaService();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final isDownloaded = await _modelManager.isModelDownloaded();

    if (!mounted) return;

    if (isDownloaded) {
      final modelPath = await _modelManager.getModelPath();
      final initialized = await _llamaService.initModel(modelPath);

      if (!mounted) return;

      if (initialized) {
        // Model is installed & loaded -> Navigate DIRECTLY to ChatScreen!
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              llamaService: _llamaService,
              modelManager: _modelManager,
            ),
          ),
        );
        return;
      }
    }

    // Model is NOT installed -> Open Download Screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ModelSetupScreen(
          modelManager: _modelManager,
          llamaService: _llamaService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeService().activeTheme;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [theme.primaryColor, theme.accentColor],
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.primaryColor.withValues(alpha: 0.4),
                    blurRadius: 30,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/awy_logo.png',
                  width: 110,
                  height: 110,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "AWM",
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: theme.textPrimary,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "AI WITH ME",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: theme.primaryColor,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Developer: Niranjan Kumar K",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.textSecondary,
              ),
            ),
            const SizedBox(height: 36),
            CircularProgressIndicator(color: theme.primaryColor),
          ],
        ),
      ),
    );
  }
}
