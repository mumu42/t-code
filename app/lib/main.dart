/// 入口 — 初始化存储后启动 App
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 离线初始化本地数据库（Web 端不支持 sqflite，App 内已降级提示）
  // 初始化失败不阻塞启动：首页会显示降态 UI
  try {
    await StorageService.instance.init();
  } catch (_) {}

  runApp(const ProviderScope(child: LinguaFlowApp()));
}
