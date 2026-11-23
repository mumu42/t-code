/// Prompt 组装器 — 见 dynamic-prompt-assembler.md
///
/// 规约：
/// - 读取不到的变量一律用兜底值（kPromptDefaults），禁止空串/null 直接填入
/// - JSON 数组类变量以 `_json` 结尾；数字填入前必须 String() 转换
/// - 组装完成后必须检查未替换变量并清理（§五.4 安全检查）
/// - 各板块 assemble 各自独立查询，不共享缓存（§五.5）
///
/// V1 各板块 Prompt 模板文本后续放在 lib/boards/*/prompt_templates.dart，
/// 通过 AI 代理（Node.js 后端，见 LinguaFlow.md §五）发送。
library;

import 'dart:developer' as dev;

import '../constants/prompt_defaults.dart';

class PromptAssembler {
  PromptAssembler._();

  static final PromptAssembler instance = PromptAssembler._();

  /// 组装：模板占位符 `{{var}}` → 值
  ///
  /// [vars] 中缺少的变量自动回落到 [kPromptDefaults]；
  /// 仍未覆盖的占位符记录警告并替换为空串（安全检查，§五.4）。
  String assemble(String template, Map<String, String> vars) {
    var prompt = template;
    final merged = {...kPromptDefaults, ...vars};

    for (final entry in merged.entries) {
      prompt = prompt.replaceAll('{{${entry.key}}}', entry.value);
    }

    // 安全检查：残留的 {{...}} 一律警告并清空
    final remaining = RegExp(r'\{\{[^}]+\}\}').allMatches(prompt).toList();
    if (remaining.isNotEmpty) {
      final names =
          remaining.map((m) => m.group(0)).whereType<String>().toSet().toList();
      dev.log('[PromptAssembler] Unreplaced: $names', name: 'prompt');
      for (final name in names) {
        prompt = prompt.replaceAll(name, '');
      }
    }
    return prompt;
  }
}
