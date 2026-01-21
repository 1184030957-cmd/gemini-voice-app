class Validators {
  static String? validateApiUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入 API 地址';
    }
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      return '请输入有效的地址 (http:// 或 https://)';
    }
    try {
      final uri = Uri.parse(value);
      if (!uri.hasAuthority) {
        return '请输入有效的地址';
      }
    } catch (e) {
      return '请输入有效的 URL';
    }
    return null;
  }

  static String? validateApiKey(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入 API Key';
    }
    if (value.trim().length < 8) {
      return 'API Key 长度至少 8 个字符';
    }
    return null;
  }

  static String? validateModel(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入模型名称';
    }
    return null;
  }
}
