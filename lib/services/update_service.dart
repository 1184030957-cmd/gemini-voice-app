import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static const String _githubApiUrl =
      'https://api.github.com/repos/1184030957-cmd/gemini-voice-app/releases/latest';

  Future<bool> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await http.get(Uri.parse(_githubApiUrl));
      if (response.statusCode != 200) {
        return false;
      }

      final data = jsonDecode(response.body);
      final latestVersion = (data['tag_name'] as String).replaceAll('v', '');

      return _compareVersions(latestVersion, currentVersion) > 0;
    } catch (e) {
      return false;
    }
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

  Future<void> downloadUpdate(String downloadUrl) async {
    final mirrorUrl = 'https://ghproxy.com/$downloadUrl';
    final uri = Uri.parse(mirrorUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('无法打开下载链接');
    }
  }

  int _compareVersions(String v1, String v2) {
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
}
