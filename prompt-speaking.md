```
TASK: Generate a roleplay speaking practice session for a {{current_level}} learner.

INPUT CONTEXT (JSON):
{
  "current_level": "{{current_level}}",
  "scenario": "{{scenario}}",
  "recent_scores": {{recent_scores_json}},
  "struggle_areas": {{struggle_areas_json}},
  "attempt_number": {{attempt_number}}
}

PROGRESSION RULES:
- attempt 1: 提供完整句子提示（full sentence prompts）
- attempt 2: 只给关键词提示（keyword hints only）
- attempt 3+: 自由对话，无提示（free conversation）
- recent_scores avg < 70: 缩短对话轮次，降低句型复杂度

LANGUAGE RULES:
- scenario_description → 中文（2-3句话描述场景）
- roleplay_setup.user_role → 中文描述 + English key phrases
- roleplay_setup.ai_role → 中文描述
- opening_line → English（AI 说的第一句话）
- guided_prompts[].text → 中文指令 + English sentence starter
- guided_prompts[].hint → 中文提示
- pronunciation_focus[].sound → IPA
- pronunciation_focus[].tip → 中文发音技巧
- self_assessment_rubric → 中文
- progression_note → 中文

OUTPUT SCHEMA:
{
  "scenario_description": "string (Chinese, 2-3 sentences)",
  "roleplay_setup": {
    "user_role": "string (Chinese + English key phrases)",
    "ai_role": "string (Chinese)",
    "difficulty": "number 1-5"
  },
  "opening_line": "string (English)",
  "guided_prompts": [
    {
      "text": "string (Chinese instruction + English starter)",
      "hint": "string (Chinese)",
      "expected_length": "string (short/medium)"
    }
  ],
  "pronunciation_focus": [
    {
      "sound": "string (IPA)",
      "example_words": ["string (English)"],
      "tip": "string (Chinese pronunciation tip)"
    }
  ],
  "self_assessment_rubric": {
    "fluency": "string (Chinese question)",
    "accuracy": "string (Chinese question)",
    "confidence": "string (Chinese question)"
  },
  "progression_note": "string (Chinese)"
}

EXAMPLE OUTPUT:
{
  "scenario_description": "你正在参加每日站会（daily standup），需要向团队汇报昨天的进展和今天的计划。你的 tech lead 刚问完问题，轮到你发言了。这是一个低压场景，说清楚就行，不需要完美。",
  "roleplay_setup": {
    "user_role": "你是一个前端开发者，需要汇报：昨天修了一个 bug，今天要继续做 Flutter 页面，没有阻塞。关键词：fixed, working on, no blockers",
    "ai_role": "你是 tech lead，会追问 1-2 个简单问题，比如 'What kind of bug?' 或 'Any blockers?'",
    "difficulty": 2
  },
  "opening_line": "Alright, your turn. What did you get done yesterday and what's on your plate today?",
  "guided_prompts": [
    {
      "text": "描述昨天的工作。开头用：Yesterday I...",
      "hint": "用过去式。fixed / finished / worked on",
      "expected_length": "short"
    },
    {
      "text": "说明今天的计划。开头用：Today I'm going to...",
      "hint": "用 be going to 表示计划",
      "expected_length": "short"
    },
    {
      "text": "说明有没有阻塞。开头用：I don't have any... / I'm blocked by...",
      "hint": "blockers 是常用词",
      "expected_length": "short"
    }
  ],
  "pronunciation_focus": [
    {
      "sound": "/d/",
      "example_words": ["fixed", "worked", "blocked"],
      "tip": "过去式 -ed 结尾，如果前面是清辅音（如 /k/ /t/ /f/），-ed 发 /t/ 音。fixed 读作 /fɪkst/，不是 /fɪksɪd/。"
    },
    {
      "sound": "/æ/",
      "example_words": ["plan", "have", "that"],
      "tip": "这个音嘴巴张大，舌头放平。别读成 /e/（pan ≠ pen）。"
    }
  ],
  "self_assessment_rubric": {
    "fluency": "我说的时候有没有长时间停顿？",
    "accuracy": "我用了正确的过去式吗？",
    "confidence": "我听起来自然吗，还是像在背书？"
  },
  "progression_note": "这是你第三次练站会场景了，今天去掉句子提示，试试自己组织语言。说错了没关系，AI 会温柔地帮你纠正。"
}
```
