import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static const String _githubApiUrl =
      'https://api.github.com/repos/1184030957-cmd/gemini-voice-app/releases/latest';

  final Dio _dio = Dio();

  int compareVersions(String v1, String v2) {
    String cleanVersion(String v) {
      v = v.trim();
      int plusIndex = v.indexOf('+');
      if (plusIndex > 0) {
        v = v.substring(0, plusIndex);
      }
      v = v.replaceAll(RegExp(r'[^0-9.]'), '');
      return v;
    }

    v1 = cleanVersion(v1);
    v2 = cleanVersion(v2);

    final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    int maxLength = parts1.length > parts2.length ? parts1.length : parts2.length;
    for (int i = 0; i < maxLength; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 > p2) return 1;
      if (p1 < p2) return -1;
    }
    return 0;
  }

  Future<Map<String, dynamic>?> getLatestReleaseInfo() async {
    try {
      final response = await http.get(Uri.parse(_githubApiUrl));
      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body);
      return {
        'version': (data['tag_name'] as String).replaceAll('v', ''),
        'downloadUrl': data['assets'][0]['browser_download_url'] as String?,
        'releaseNotes': data['body'] as String?,
        'htmlUrl': data['html_url'] as String?,
      };
    } catch (e) {
      return null;
    }
  }

  Future<bool> downloadUpdate({
    required String downloadUrl,
    required Function(int, int) onProgress,
    required Function(String) onComplete,
    required Function(String) onError,
  }) async {
    try {
      final directory = await getExternalStorageDirectory();
      final savePath = '${directory!.path}/gemini_voice_app.apk';

      await _dio.download(
        downloadUrl,
        savePath,
        options: Options(
          headers: {
            HttpHeaders.acceptEncodingHeader: '*',
          },
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(received, total);
          }
        },
      );

      onComplete(savePath);
      return true;
    } catch (e) {
      onError(e.toString());
      return false;
    }
  }

  Future<void> installApk(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw Exception('APK文件不存在: $filePath');
    }

    try {
      final fileInfo = await file.stat();
      if (fileInfo.size == 0) {
        throw Exception('APK文件为空');
      }

      final uri = Uri.file(filePath);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('无法打开APK文件。请前往文件管理器找到该文件并手动安装。\n路径: $filePath');
      }
    } catch (e) {
      throw Exception('安装失败: $e');
    }
  }

  String getDownloadPath() {
    return '/storage/emulated/0/Android/data/com.example.gemini_voice_app/files/gemini_voice_app.apk';
  }
}
