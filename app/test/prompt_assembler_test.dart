import 'package:flutter_test/flutter_test.dart';
import 'package:linguaflow/services/prompt_assembler.dart';
import 'package:linguaflow/constants/prompt_defaults.dart';

void main() {
  final assembler = PromptAssembler.instance;

  test('变量替换 + 缺失变量回落兜底值（dynamic-prompt-assembler §五.2）', () {
    final prompt = assembler.assemble(
      'Level: {{current_level}} | Struggle: {{struggle_areas_json}} | '
      'Accuracy: {{recent_accuracy}} | Theme: {{theme}}',
      {'theme': 'code review'},
    );
    expect(prompt,
        'Level: B1 | Struggle: [] | Accuracy: 0.70 | Theme: code review');
  });

  test('未注册变量残留时警告并清空（§五.4 安全检查）', () {
    final prompt = assembler.assemble(
      'Hello {{totally_unknown_var}} world',
      const {},
    );
    expect(prompt, 'Hello  world');
  });

  test('兜底值总表完整（16 个变量）', () {
    expect(kPromptDefaults.length, 16);
    expect(kPromptDefaults['current_level'], 'B1');
    expect(kPromptDefaults['recent_accuracy'], '0.70');
    expect(kPromptDefaults['mixed_items_json'], '[]');
  });
}
