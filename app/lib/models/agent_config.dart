/// Agent（AI 服务）配置模型 — OpenAI 兼容格式
///
/// 配置一次缓存本地（agent_config 表，单行），下次打开无需重配。
/// 字段：baseURL / apiKey / model / timeoutSec / proxy。
library;

class AgentConfig {
  const AgentConfig({
    this.baseUrl = '',
    this.apiKey = '',
    this.model = '',
    this.timeoutSec = 60,
    this.proxy,
    this.updatedAt,
  });

  final String baseUrl;
  final String apiKey;
  final String model;
  final int timeoutSec;
  final String? proxy; // 如 '127.0.0.1:7890'，null = 直连
  final DateTime? updatedAt;

  /// 三项核心配置齐全才算可用
  bool get isConfigured =>
      baseUrl.isNotEmpty && apiKey.isNotEmpty && model.isNotEmpty;

  AgentConfig copyWith({
    String? baseUrl,
    String? apiKey,
    String? model,
    int? timeoutSec,
    String? proxy,
    bool clearProxy = false,
    DateTime? updatedAt,
  }) =>
      AgentConfig(
        baseUrl: baseUrl ?? this.baseUrl,
        apiKey: apiKey ?? this.apiKey,
        model: model ?? this.model,
        timeoutSec: timeoutSec ?? this.timeoutSec,
        proxy: clearProxy ? null : (proxy ?? this.proxy),
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory AgentConfig.fromMap(Map<String, Object?> map) => AgentConfig(
        baseUrl: (map['base_url'] as String?) ?? '',
        apiKey: (map['api_key'] as String?) ?? '',
        model: (map['model'] as String?) ?? '',
        timeoutSec: (map['timeout_sec'] as int?) ?? 60,
        proxy: (map['proxy'] as String?),
        updatedAt: map['updated_at'] == null
            ? null
            : DateTime.parse(map['updated_at']! as String),
      );

  Map<String, Object?> toMap() => {
        'id': 1,
        'base_url': baseUrl,
        'api_key': apiKey,
        'model': model,
        'timeout_sec': timeoutSec,
        'proxy': proxy,
        'updated_at': updatedAt?.toIso8601String(),
      };
}
