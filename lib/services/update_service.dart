import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:android_intent_plus/android_intent_plus.dart';

class UpdateService {
  static const String _githubApiUrl =
      'https://api.github.com/repos/1184030957-cmd/gemini-voice-app/releases/latest';

  final Dio _dio = Dio();

  int compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map(int.parse).toList();
    final parts2 = v2.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
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
      final savePath = '${directory!.path}/gemini-voice-app.apk';

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
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        throw Exception('APK文件不存在');
      }

      if (Platform.isAndroid) {
        final intent = AndroidIntent(
          action: 'android.intent.action.VIEW',
          type: 'application/vnd.android.package-archive',
          data: Uri.file(filePath).toString(),
          flags: [Flag.FLAG_GRANT_READ_URI_PERMISSION],
        );
        await intent.launch();
      } else {
        await OpenFile.open(filePath);
      }
    } catch (e) {
      throw Exception('安装失败: $e');
    }
  }
}
