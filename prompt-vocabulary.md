```
TASK: Generate {{count}} vocabulary cards for a learner at CEFR level {{current_level}}.

INPUT CONTEXT (JSON):
{
  "current_level": "{{current_level}}",
  "known_words_sample": {{known_words_json}},
  "theme": "{{theme}}",
  "recent_accuracy": {{recent_accuracy}},
  "session_number": {{session_number}},
  "struggle_areas": {{struggle_areas_json}}
}

DIFFICULTY RULES:
- recent_accuracy < 0.6: 90% review + 10% new, max difficulty 2
- recent_accuracy 0.6-0.85: 60% review + 40% new, max difficulty 3
- recent_accuracy > 0.85: 40% review + 60% new, max difficulty 4, allow 1 difficulty 5

LANGUAGE RULES:
- word → English
- phonetics → IPA symbols
- meaning_cn → 中文释义（1-2句话）
- example → English sentence (max 12 words, {{theme}} context)
- example_cn → 中文翻译
- session_meta.progression_note → 中文鼓励语（具体指出本次难度设计理由）

OUTPUT SCHEMA:
{
  "cards": [
    {
      "word": "string (English)",
      "phonetics": "string (IPA)",
      "meaning_cn": "string (Chinese, max 2 sentences)",
      "example": "string (English, max 12 words)",
      "example_cn": "string (Chinese translation)",
      "difficulty_score": "number 1-5",
      "cefr": "string (A1/A2/B1/B2/C1)",
      "tags": ["string (tech/daily/workplace)"],
      "is_new": "boolean"
    }
  ],
  "session_meta": {
    "new_count": "number",
    "review_count": "number",
    "estimated_minutes": "number",
    "progression_note": "string (Chinese, encouraging, specific)"
  }
}

EXAMPLE OUTPUT (partial):
{
  "cards": [
    {
      "word": "state",
      "phonetics": "/steɪt/",
      "meaning_cn": "状态。在编程中指应用在某一时刻的数据快照。",
      "example": "Manage your app's state efficiently to avoid bugs.",
      "example_cn": "高效管理应用状态可以避免 bug。",
      "difficulty_score": 2,
      "cefr": "B1",
      "tags": ["tech", "frontend"],
      "is_new": true
    },
    {
      "word": "refactor",
      "phonetics": "/riːˈfæktər/",
      "meaning_cn": "重构。在不改变外部行为的前提下改善代码结构。",
      "example": "We need to refactor this component before adding new features.",
      "example_cn": "在加新功能之前，我们需要重构这个组件。",
      "difficulty_score": 3,
      "cefr": "B2",
      "tags": ["tech", "workplace"],
      "is_new": true
    }
  ],
  "session_meta": {
    "new_count": 8,
    "review_count": 4,
    "estimated_minutes": 10,
    "progression_note": "今天复习了上周学的 4 个词，新加了 8 个前端常用词。你上次的正确率不错，所以今天稍微加了一点难度，试试看！"
  }
}
```
