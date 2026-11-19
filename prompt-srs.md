```
TASK: Act as the SRS scheduler. Given a user's review history, decide today's review session plan.

INPUT CONTEXT (JSON):
{
  "review_history": {{review_history_json}},
  "current_queue": {{current_queue_json}},
  "user_streak_days": {{streak}},
  "recent_session_performance": {{recent_performance_json}}
}

DECISION LOGIC:
1. streak >= 7 AND recent > 0.8 → mix 20% challenge items (one level harder)
2. recent < 0.6 → pause new, show only review items from last 3 days
3. > 50 due → prioritize by: (1) due longest, (2) lowest stability, (3) weakest board
4. total_cards = min(20, due_count)

LANGUAGE RULES:
- session_plan.cards[].reason → 中文（为什么排这张）
- insight → 中文（本周 vs 上周对比）
- difficulty_adjustment → "降低"/"保持"/"提高"
- reason → 中文（调整理由）
- progression_note → 中文

OUTPUT SCHEMA:
{
  "session_plan": {
    "total_cards": "number",
    "breakdown": {
      "vocabulary": "number",
      "writing_errors": "number",
      "listening_clips": "number",
      "reading_clips": "number",
      "grammar_points": "number"
    },
    "estimated_minutes": "number",
    "cards": [
      {
        "card_id": "string",
        "board_source": "string",
        "priority": "number 1-5",
        "reason": "string (Chinese)"
      }
    ]
  },
  "insight": "string (Chinese, compare this week vs last)",
  "difficulty_adjustment": "string (降低/保持/提高)",
  "reason": "string (Chinese)",
  "progression_note": "string (Chinese)"
}

EXAMPLE OUTPUT:
{
  "session_plan": {
    "total_cards": 12,
    "breakdown": {
      "vocabulary": 5,
      "writing_errors": 3,
      "listening_clips": 2,
      "reading_clips": 1,
      "grammar_points": 1
    },
    "estimated_minutes": 8,
    "cards": [
      {
        "card_id": "card_001",
        "board_source": "writing",
        "priority": 5,
        "reason": "3天前你写错了 'maked'，这是高频错误，必须优先巩固"
      },
      {
        "card_id": "card_002",
        "board_source": "writing",
        "priority": 5,
        "reason": "同一类时态错误出现了 3 次，今天再强化一次"
      },
      {
        "card_id": "card_003",
        "board_source": "vocabulary",
        "priority": 4,
        "reason": "这个词已经 7 天没复习了，快到遗忘临界点"
      },
      {
        "card_id": "card_004",
        "board_source": "listening",
        "priority": 3,
        "reason": "上周听力中听错的句子，巩固连读感知"
      },
      {
        "card_id": "card_005",
        "board_source": "vocabulary",
        "priority": 3,
        "reason": "稳定性较低（stability=1.2），需要加密复习"
      }
    ]
  },
  "insight": "这周你已经复习了 45 个记忆项，比上周多了 12 个。你的记忆保留率从 82% 升到了 87%，说明间隔复习正在起效果。写作错误中，时态类错误从 5 次降到了 2 次，进步很明显！",
  "difficulty_adjustment": "保持",
  "reason": "最近 3 次练习正确率在 75%-82% 之间，处于 i+1 最佳区间，暂时不需要调整难度。如果连续 3 次超过 85%，明天会加入 B2 级别的挑战词。",
  "progression_note": "今天有 12 张卡到期，其中 3 张是你写错的句子——这些是最重要的，因为它们是你真正会犯的错误。做完今天的复习，你的时态类记忆稳定性会再提升一档。"
}
```
