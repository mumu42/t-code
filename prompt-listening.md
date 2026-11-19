```
TASK: Generate a listening exercise at i+1 difficulty for a B1 learner.

INPUT CONTEXT (JSON):
{
  "current_level": "{{current_level}}",
  "recent_accuracy": {{recent_accuracy}},
  "theme": "{{theme}}",
  "speed": "{{speed}}",
  "recent_scores": {{recent_scores_json}},
  "struggle_areas": {{struggle_areas_json}}
}

PROGRESSION RULES:
- recent_accuracy < 0.6: 40 words, 0.75x speed, max 2 new words, all literal questions
- recent_accuracy 0.6-0.85: 80 words, 1.0x, 3 new words, mix literal + inference
- recent_accuracy > 0.85: 120 words, 1.0x, 5 new words, add multi-speaker + inference

LANGUAGE RULES:
- script → English (the listening material itself)
- sentences[].text → English
- sentences[].keywords → English words (2-3 per sentence)
- questions[].question → 中文（题目用中文，让用户专注在"听懂"而非"读懂题"）
- questions[].options → 中文选项
- questions[].correct_index → number
- questions[].explanation_cn → 中文解析（为什么选这个）
- progression_note → 中文鼓励语

OUTPUT SCHEMA:
{
  "script": "string (English dialogue/monologue)",
  "sentences": [
    {
      "text": "string (English)",
      "difficulty": "number 1-5",
      "keywords": ["string (English)"],
      "pause_after_ms": "number (suggested pause for shadowing)"
    }
  ],
  "questions": [
    {
      "question": "string (Chinese)",
      "options": ["string (Chinese)", "string (Chinese)", "string (Chinese)"],
      "correct_index": "number 0-2",
      "explanation_cn": "string (Chinese, why this answer)",
      "type": "literal/inference/detail"
    }
  ],
  "estimated_seconds": "number",
  "progression_note": "string (Chinese)",
  "audio_settings": {
    "default_speed": "0.75/1.0/1.25",
    "loop_sentence": "boolean",
    "show_subtitles": "boolean"
  }
}

EXAMPLE OUTPUT (partial):
{
  "script": "Hey, did you see the build failed this morning? Yeah, I think it's because we merged the new Flutter widget without running tests. Oh no, I should have checked. No worries, I'll fix it and redeploy in about 10 minutes.",
  "sentences": [
    {
      "text": "Hey, did you see the build failed this morning?",
      "difficulty": 2,
      "keywords": ["build", "failed"],
      "pause_after_ms": 1500
    },
    {
      "text": "Yeah, I think it's because we merged the new Flutter widget without running tests.",
      "difficulty": 3,
      "keywords": ["merged", "widget", "tests"],
      "pause_after_ms": 2000
    },
    {
      "text": "Oh no, I should have checked.",
      "difficulty": 2,
      "keywords": ["should have checked"],
      "pause_after_ms": 1500
    },
    {
      "text": "No worries, I'll fix it and redeploy in about 10 minutes.",
      "difficulty": 3,
      "keywords": ["redeploy", "10 minutes"],
      "pause_after_ms": 1500
    }
  ],
  "questions": [
    {
      "question": "今天早上发生了什么问题？",
      "options": ["构建失败了", "测试通过了", "服务器宕机了"],
      "correct_index": 0,
      "explanation_cn": "第一句直接说了 'the build failed this morning'，所以选 A。",
      "type": "literal"
    },
    {
      "question": "为什么构建会失败？",
      "options": ["没写文档", "合并代码前没跑测试", "依赖版本不对"],
      "correct_index": 1,
      "explanation_cn": "第二句提到 'without running tests'，说明是没跑测试就合并了。",
      "type": "inference"
    },
    {
      "question": "修复大概需要多长时间？",
      "options": ["5 分钟", "10 分钟", "30 分钟"],
      "correct_index": 1,
      "explanation_cn": "最后一句说 'in about 10 minutes'。",
      "type": "detail"
    }
  ],
  "estimated_seconds": 45,
  "progression_note": "这次对话语速适中，场景是工作日常。你上次听力正确率不错，所以今天加了 1 个需要推理的题目，试试看能不能从上下文猜出原因。",
  "audio_settings": {
    "default_speed": "1.0",
    "loop_sentence": true,
    "show_subtitles": true
  }
}

GRAMMAR INTEGRATION (检测):
- 听力材料中，刻意包含 1-2 处用户薄弱的语法结构（从 struggle_areas 读取）
- 题目设计：至少 1 道题检测"是否听出了语法线索"
  例：听到 "I have been working" → 问 "说话人从什么时候开始工作？"（检测完成时）
- 题目选项里，用语法正确的中文表述作为选项
- 如果用户 recent_accuracy < 0.6 且 struggle_areas 包含 "tense"：
  → 材料中使用明显的时态标记词（yesterday/already/for 3 days）
  → 题目直接问时间线索

OUTPUT 新增字段：
{
  "questions": [{
    ...原有字段,
    "grammar_focus": "grammar:past_tense",  // 这道题检测的语法点
    "grammar_clue": "yesterday"  // 材料中的语法线索词
  }]
}
```
