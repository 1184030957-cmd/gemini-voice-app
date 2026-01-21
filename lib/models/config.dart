class ApiConfig {
  final String apiUrl;
  final String apiKey;
  final String model;

  ApiConfig({
    required this.apiUrl,
    required this.apiKey,
    required this.model,
  });

  bool get isValid {
    return apiUrl.isNotEmpty && apiKey.isNotEmpty && model.isNotEmpty;
  }

  Map<String, dynamic> toMap() {
    return {
      'apiUrl': apiUrl,
      'apiKey': apiKey,
      'model': model,
    };
  }

  factory ApiConfig.fromMap(Map<String, dynamic> map) {
    return ApiConfig(
      apiUrl: map['apiUrl'] ?? '',
      apiKey: map['apiKey'] ?? '',
      model: map['model'] ?? '',
    );
  }

  ApiConfig copyWith({
    String? apiUrl,
    String? apiKey,
    String? model,
  }) {
    return ApiConfig(
      apiUrl: apiUrl ?? this.apiUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
    );
  }
}
