import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ModelManager {
  static const String modelUrl =
      "https://huggingface.co/bartowski/SmolLM2-360M-Instruct-GGUF/resolve/main/SmolLM2-360M-Instruct-Q4_K_M.gguf";
  static const String modelUrlFallback =
      "https://huggingface.co/HuggingFaceTB/SmolLM2-360M-Instruct-GGUF/resolve/main/SmolLM2-360M-Instruct-Q4_K_M.gguf";
  static const String modelFilename = "AWM_AI_Core.gguf";
  static const int expectedSizeBytes = 270590880; // ~258 MB

  bool _isDownloading = false;
  bool get isDownloading => _isDownloading;

  Future<String> getModelPath() async {
    final dir = await getApplicationSupportDirectory();
    return "${dir.path}/$modelFilename";
  }

  Future<bool> isModelDownloaded() async {
    final path = await getModelPath();
    final file = File(path);
    if (await file.exists()) {
      final size = await file.length();
      if (size > 100 * 1024 * 1024) {
        return await verifyModel();
      }
    }
    return false;
  }

  Future<int> getDownloadedSize() async {
    final path = await getModelPath();
    final file = File(path);
    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  }

  Future<bool> downloadModel({
    required Function(double progress, int downloadedBytes, int totalBytes, String speedStr)
        onProgress,
    required Function(String error) onError,
  }) async {
    if (_isDownloading) return false;
    _isDownloading = true;

    http.Client? client;
    IOSink? sink;

    try {
      // Robust network check with short timeout
      try {
        final socket = await Socket.connect('8.8.8.8', 53, timeout: const Duration(seconds: 4));
        socket.destroy();
      } catch (_) {
        try {
          final lookup = await InternetAddress.lookup('huggingface.co')
              .timeout(const Duration(seconds: 4));
          if (lookup.isEmpty || lookup[0].rawAddress.isEmpty) {
            throw const SocketException("No Internet");
          }
        } catch (_) {
          throw const SocketException("Please Connect To Internet");
        }
      }

      final path = await getModelPath();
      final file = File(path);
      final tempFile = File("$path.tmp");

      int existingBytes = 0;
      if (await tempFile.exists()) {
        existingBytes = await tempFile.length();
      }

      client = http.Client();
      http.StreamedResponse? response;
      String activeUrl = modelUrl;

      try {
        final request = http.Request('GET', Uri.parse(activeUrl));
        if (existingBytes > 0) {
          request.headers['Range'] = 'bytes=$existingBytes-';
        }
        response = await client.send(request).timeout(const Duration(seconds: 15));
        if (response.statusCode != 200 && response.statusCode != 206) {
          throw Exception("Primary URL returned status ${response.statusCode}");
        }
      } catch (primaryErr) {
        // Fallback to secondary repo if primary URL failed
        activeUrl = modelUrlFallback;
        final request = http.Request('GET', Uri.parse(activeUrl));
        if (existingBytes > 0) {
          request.headers['Range'] = 'bytes=$existingBytes-';
        }
        response = await client.send(request).timeout(const Duration(seconds: 15));
        if (response.statusCode != 200 && response.statusCode != 206) {
          throw Exception("Server returned HTTP status ${response.statusCode}");
        }
      }

      int totalContentBytes = response.contentLength ?? (expectedSizeBytes - existingBytes);
      int totalBytes = existingBytes + totalContentBytes;

      sink = tempFile.openWrite(mode: existingBytes > 0 ? FileMode.append : FileMode.write);

      int receivedBytes = existingBytes;
      DateTime lastSpeedCheck = DateTime.now();
      int bytesSinceLastCheck = 0;
      String currentSpeedStr = "0.0 MB/s";

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        bytesSinceLastCheck += chunk.length;

        final now = DateTime.now();
        final elapsed = now.difference(lastSpeedCheck).inMilliseconds;
        if (elapsed >= 500) {
          final speedMBs = (bytesSinceLastCheck / (1024 * 1024)) / (elapsed / 1000.0);
          currentSpeedStr = "${speedMBs.toStringAsFixed(1)} MB/s";
          lastSpeedCheck = now;
          bytesSinceLastCheck = 0;
        }

        final double progress = totalBytes > 0 ? (receivedBytes / totalBytes) : 0.0;
        onProgress(progress, receivedBytes, totalBytes, currentSpeedStr);
      }

      await sink.flush();
      await sink.close();
      sink = null;

      if (await tempFile.exists()) {
        if (await file.exists()) {
          await file.delete();
        }
        await tempFile.rename(path);
      }

      return true;
    } on SocketException {
      onError("Please Connect To Internet (Internet connection is required to download the AI model).");
      return false;
    } catch (e) {
      if (e.toString().contains("SocketException") ||
          e.toString().contains("ClientException") ||
          e.toString().contains("TimeoutException") ||
          e.toString().contains("HandshakeException")) {
        onError("Please Connect To Internet (Internet connection is required to download the AI model).");
      } else {
        onError("Download Error: Please check internet connection and try again.");
      }
      return false;
    } finally {
      _isDownloading = false;
      try {
        await sink?.close();
      } catch (_) {}
      client?.close();
    }
  }

  Future<bool> verifyModel() async {
    final path = await getModelPath();
    final file = File(path);
    if (!await file.exists()) return false;

    final length = await file.length();
    if (length < 100 * 1024 * 1024) return false;

    // Verify GGUF Magic Header 'GGUF'
    RandomAccessFile? handle;
    try {
      handle = await file.open(mode: FileMode.read);
      final header = await handle.read(4);
      if (header.length == 4) {
        final magic = String.fromCharCodes(header);
        if (magic == 'GGUF') {
          return true;
        }
      }
    } catch (_) {
      return false;
    } finally {
      await handle?.close();
    }
    return false;
  }

  Future<void> deleteModel() async {
    final path = await getModelPath();
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
    final tempFile = File("$path.tmp");
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
  }
}
