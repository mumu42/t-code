/// Prompt 变量兜底值 — 见 dynamic-prompt-assembler.md §三
///
/// 各板块 PromptAssembler 组装模板时，数据库读不到的变量一律
/// 使用此处的兜底值，禁止把空字符串 / null 直接填进模板。
library;

/// 变量名 → 兜底值（全部为字符串，JSON 类变量为字符串化的 JSON）
const Map<String, String> kPromptDefaults = {
  'current_level': 'B1',
  'struggle_areas_json': '[]',
  'recent_accuracy': '0.70',
  'recent_errors_json': '[]',
  'repeat_errors_json': '[]',
  'known_words_json': '[]',
  'session_count': '1',
  'daily_goal': '10',
  'theme': '',
  'tech_focus': 'true',
  'recent_unknown_words': '[]',
  'grammar_focus': '',
  'guided_prompts_grammar': '',
  'user_text': '', // 调用方负责传
  'due_count': '0',
  'mixed_items_json': '[]',
};
