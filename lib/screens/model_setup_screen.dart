import 'package:flutter/material.dart';
import '../services/model_manager.dart';
import '../services/llama_service.dart';
import '../services/theme_service.dart';
import 'chat_screen.dart';

class ModelSetupScreen extends StatefulWidget {
  final ModelManager modelManager;
  final LlamaService llamaService;

  const ModelSetupScreen({
    super.key,
    required this.modelManager,
    required this.llamaService,
  });

  @override
  State<ModelSetupScreen> createState() => _ModelSetupScreenState();
}

class _ModelSetupScreenState extends State<ModelSetupScreen> {
  bool _isChecking = true;
  bool _isDownloaded = false;
  bool _isDownloading = false;
  bool _isLoadingModel = false;
  double _progress = 0.0;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  String _speedStr = "";
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkModelStatus();
  }

  Future<void> _checkModelStatus() async {
    setState(() {
      _isChecking = true;
      _errorMessage = null;
    });

    final downloaded = await widget.modelManager.isModelDownloaded();
    if (!mounted) return;
    setState(() {
      _isDownloaded = downloaded;
      _isChecking = false;
    });
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _progress = 0.0;
      _downloadedBytes = 0;
      _totalBytes = ModelManager.expectedSizeBytes;
      _speedStr = "Connecting...";
    });

    final success = await widget.modelManager.downloadModel(
      onProgress: (progress, downloaded, total, speed) {
        if (!mounted) return;
        setState(() {
          _progress = progress;
          _downloadedBytes = downloaded;
          _totalBytes = total;
          _speedStr = speed;
        });
      },
      onError: (errorMsg) {
        if (!mounted) return;
        setState(() {
          _isDownloading = false;
          _errorMessage = errorMsg;
        });
      },
    );

    if (success) {
      final verified = await widget.modelManager.verifyModel();
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        if (verified) {
          _isDownloaded = true;
        } else {
          _errorMessage = "Model verification failed. Please try downloading again.";
        }
      });
      if (verified) {
        _launchChat();
      }
    }
  }

  Future<void> _launchChat() async {
    setState(() {
      _isLoadingModel = true;
      _errorMessage = null;
    });

    final modelPath = await widget.modelManager.getModelPath();
    final initialized = await widget.llamaService.initModel(modelPath);

    if (!mounted) return;

    setState(() {
      _isLoadingModel = false;
    });

    if (initialized) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            llamaService: widget.llamaService,
            modelManager: widget.modelManager,
          ),
        ),
      );
    } else {
      setState(() {
        _errorMessage = "Failed to load AI engine. Please tap retry to load again.";
      });
    }
  }

  String _formatMB(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB";
    }
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeService().activeTheme;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // Official Logo
              Center(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [theme.primaryColor, theme.accentColor],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.primaryColor.withValues(alpha: 0.4),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/awy_logo.png',
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [theme.textPrimary, theme.accentColor],
                ).createShader(bounds),
                child: const Text(
                  "AWM",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 3,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "AI WITH ME",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: theme.primaryColor,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Developer: Niranjan Kumar K",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: theme.textSecondary,
                ),
              ),
              const Spacer(),

              // Card Container
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.primaryColor.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _isDownloaded
                                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isDownloaded
                                ? Icons.verified_rounded
                                : Icons.cloud_download_rounded,
                            color: _isDownloaded
                                ? const Color(0xFF34D399)
                                : const Color(0xFFFBBF24),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          _isDownloaded ? "AI Core Ready" : "Download AI Model",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Divider(color: Colors.white12, height: 1),
                    ),
                    _buildInfoRow("AI Engine", "AWM Core Engine", theme),
                    const SizedBox(height: 10),
                    _buildInfoRow(
                      "Download Size",
                      _totalBytes > 0 ? _formatMB(_totalBytes) : "~258 MB",
                      theme,
                    ),
                    const SizedBox(height: 10),
                    _buildInfoRow(
                      "Status",
                      _isDownloaded
                          ? "Installed & Verified"
                          : (_isDownloading ? "Downloading..." : "Not Installed"),
                      theme,
                      statusColor: _isDownloaded
                          ? const Color(0xFF34D399)
                          : (_isDownloading ? const Color(0xFFFBBF24) : theme.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Download Progress Bar
              if (_isDownloading) ...[
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${(_progress * 100).toStringAsFixed(1)}%",
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          "${_formatMB(_downloadedBytes)} / ${_formatMB(_totalBytes)} ($_speedStr)",
                          style: TextStyle(color: theme.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _progress > 0 ? _progress : null,
                        minHeight: 12,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // Error Banner with Retry
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.wifi_off_rounded, color: Color(0xFFFCA5A5)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: _startDownload,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                        label: const Text("Retry Download", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Action Buttons
              if (_isChecking || _isLoadingModel) ...[
                Center(
                  child: CircularProgressIndicator(color: theme.primaryColor),
                ),
              ] else if (_isDownloaded) ...[
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [theme.primaryColor, theme.accentColor],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.primaryColor.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _launchChat,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white),
                    label: const Text(
                      "Start Chat",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () async {
                    await widget.modelManager.deleteModel();
                    _checkModelStatus();
                  },
                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFF87171), size: 18),
                  label: const Text(
                    "Delete AI Model",
                    style: TextStyle(color: Color(0xFFF87171), fontSize: 14),
                  ),
                ),
              ] else if (!_isDownloading) ...[
                Text(
                  "Download the AWM AI engine to chat 100% offline.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [theme.primaryColor, theme.accentColor],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.accentColor.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _startDownload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.download_rounded, color: Colors.white),
                    label: const Text(
                      "Download AI Model",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, AppThemeData theme, {Color? statusColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: theme.textSecondary, fontSize: 14),
        ),
        Text(
          value,
          style: TextStyle(
            color: statusColor ?? theme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
