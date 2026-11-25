/// SQLite 存储服务 — 所有落盘的唯一入口
///
/// 平台策略：
/// - Android / iOS / macOS → sqflite 原生实现
/// - Linux / Windows 桌面 → sqflite_common_ffi（自带 sqlite3 动态库）
/// - Web → 不支持（V2 计划接入 sqflite_common_ffi_web），调用 [init] 抛错
///
/// 规约（f5.md / f1.md）：
/// 1. 所有写入必须在 transaction() 中，要么全成要么全回滚
/// 2. 业务代码禁止直接持有 Database 对象，一律通过本服务
/// 3. 幂等：种子写入用 INSERT OR IGNORE
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../constants/app_constants.dart';
import '../constants/grammar_tags.dart';
import 'schema.dart';

class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();

  Database? _db;

  /// 是否完成初始化（Web 端恒为 false）
  bool get isReady => _db != null;

  /// 打开数据库并执行建表 + 种子写入（幂等，可重复调用）
  Future<void> init() async {
    if (kIsWeb) {
      throw UnsupportedError('Web 端暂不支持本地 SQLite（见 README「平台支持」）');
    }
    if (_db != null) return;

    // Linux / Windows 桌面：sqflite 无原生实现，切换到 FFI
    if (Platform.isLinux || Platform.isWindows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dir = await getApplicationDocumentsDirectory();
    _db = await openDatabase(
      p.join(dir.path, 'linguaflow.db'),
      version: 4,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        // 建表语句全部 IF NOT EXISTS，直接重放即可幂等迁移
        // v1 → v2：新增 agent_config 表
        // v2 → v3：新增 seed_words / vocab_cards / seed_meta 表
        // v3 → v4：新增 seed_sentences / seed_reading_passages /
        //          seed_speaking_scenarios / seed_collocations / seed_writing_prompts
        for (final stmt in kSchemaStatements) {
          await db.execute(stmt);
        }
      },
    );
    // 兜底：异常退出导致的半迁移状态，重放幂等 DDL
    await _onCreate(_db!, 4);
  }

  Future<void> _onCreate(Database db, int version) async {
    for (final stmt in kSchemaStatements) {
      await db.execute(stmt);
    }
    await _seed(db);
  }

  /// 种子数据：语法标签 + 默认用户行（见 dynamic-prompt-assembler §五.2）
  Future<void> _seed(Database db) async {
    final batch = db.batch();
    for (final entry in kGrammarTagTaxonomy.entries) {
      batch.insert('grammar_tags', {
        'tag_id': entry.key,
        'name_cn': entry.value,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    batch.insert('user_profile', {'user_id': kLocalUserId},
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await batch.commit(noResult: true);
  }

  /// 单条写入（不含事务）
  Future<void> execute(String sql, [List<Object?> args = const []]) async {
    _requireReady();
    await _db!.execute(sql, args);
  }

  /// 查询（始终返回 List，空表返回 []）
  Future<List<Map<String, Object?>>> query(
    String sql, [
    List<Object?> args = const [],
  ]) async {
    _requireReady();
    return _db!.rawQuery(sql, args);
  }

  /// 事务包裹：回调内使用 [tx]，要么全成要么全回滚
  Future<T> transaction<T>(Future<T> Function(DatabaseExecutor tx) action) async {
    _requireReady();
    return _db!.transaction(action);
  }

  void _requireReady() {
    if (_db == null) {
      throw StateError('StorageService 未初始化，请先在 main() 中调用 init()');
    }
  }
}
