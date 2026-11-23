/// Agent 配置服务 — 配置的读取与持久化
///
/// 存储约定：agent_config 表单行（id=1），INSERT OR REPLACE 全量覆盖。
/// Web 端不支持 SQLite 时返回默认空配置（不抛错，UI 走降级）。
library;

import '../../data/storage_service.dart';
import '../../models/agent_config.dart';

class AgentConfigService {
  AgentConfigService._();

  static final AgentConfigService instance = AgentConfigService._();

  /// 读取配置；未配置过 / Web 端返回空配置（各字段为空串）
  Future<AgentConfig> load() async {
    final storage = StorageService.instance;
    if (!storage.isReady) return const AgentConfig();
    final rows = await storage.query('SELECT * FROM agent_config WHERE id = 1');
    if (rows.isEmpty) return const AgentConfig();
    return AgentConfig.fromMap(rows.first);
  }

  /// 保存配置（全量覆盖，幂等）
  Future<void> save(AgentConfig config) async {
    final storage = StorageService.instance;
    if (!storage.isReady) {
      throw StateError('当前平台不支持本地存储，无法保存配置');
    }
    final updated = config.copyWith(updatedAt: DateTime.now());
    await storage.execute(
      'INSERT OR REPLACE INTO agent_config '
      '(id, base_url, api_key, model, timeout_sec, proxy, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      [
        1,
        updated.baseUrl,
        updated.apiKey,
        updated.model,
        updated.timeoutSec,
        updated.proxy,
        updated.updatedAt?.toIso8601String(),
      ],
    );
  }
}
