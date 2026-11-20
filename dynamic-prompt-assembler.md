# LinguaFlow — Prompt 变量总表 & 存储 & 兜底策略

> 本文档仅描述各板块 AI Prompt 模板中的变量定义、数据来源、读取方式、兜底值。
> 板块 Prompt 模板文本、建表 SQL、保存流程等已在其他文档中定义，此处不重复。

---

## 一、变量总表（16 个）

| # | 变量名 | 出现在哪些板块 | 数据类型 | 说明 |
|---|--------|--------------|---------|------|
| 1 | `current_level` | 全部 6 个 | string | 用户当前等级，如 'B1' |
| 2 | `struggle_areas_json` | 全部 6 个 | string[] | 薄弱语法标签数组 |
| 3 | `recent_accuracy` | 词汇、听力、阅读、写作 | number (0-1) | 近 7 天平均正确率 |
| 4 | `recent_errors_json` | 写作 | object[] | 近期纠错记录 |
| 5 | `repeat_errors_json` | 口语 | object[] | 重复出现的语法错误 |
| 6 | `known_words_json` | 词汇、写作 | string[] | 已学单词列表 |
| 7 | `session_count` | 词汇、写作 | number | 累计练习次数 |
| 8 | `daily_goal` | 词汇 | number | 每日目标词数 |
| 9 | `theme` | 词汇、写作 | string | 练习主题 |
| 10 | `tech_focus` | 词汇 | string ('true'/'false') | 是否优先技术职场词汇 |
| 11 | `recent_unknown_words` | 听力 | string[] | 近期听力生词 |
| 12 | `grammar_focus` | 听力、阅读 | string | 单个重点语法标签 |
| 13 | `guided_prompts_grammar` | 口语 | string | 用 `|` 连接的语法标签 |
| 14 | `user_text` | 写作 | string | 用户实时输入文本 |
| 15 | `due_count` | 复习 | number | 当前到期待复习数量 |
| 16 | `mixed_items_json` | 复习 | object[] | 混合来源的复习内容 |

---

## 二、逐变量详解

### 1. current_level

| 项目 | 值 |
|------|-----|
| 存储表 | `user_profile` |
| 字段 | `current_level` TEXT |
| 写入时机 | 用户注册/首次启动初始化 |
| 读取 SQL | `SELECT current_level FROM user_profile WHERE user_id = ?` |
| 各板块用途 | 控制 AI 生成内容的语言难度 |
| 兜底值 | `'B1'` |
| 合法值 | `'A1' \| 'A2' \| 'B1' \| 'B2' \| 'C1' \| 'C2'` |

### 2. struggle_areas_json

| 项目 | 值 |
|------|-----|
| 存储表 | `user_grammar_profile` |
| 字段 | `grammar_tag` TEXT, `status` TEXT |
| 写入时机 | 每次练习完成 → `updateGrammarProfile()` |
| 读取 SQL | `SELECT grammar_tag FROM user_grammar_profile WHERE user_id = ? AND status = 'struggling' ORDER BY total_errors DESC LIMIT ?` |
| 各板块 LIMIT | 词汇 5 / 听力 3 / 阅读 5 / 口语 3 / 写作 5 / 复习 全部 |
| 各板块用途 | 例句嵌入薄弱语法 / 材料埋线索 / 长难句优先 / 引导语提示 |
| 兜底值 | `[]` (空数组 → `JSON.stringify([])` → `'[]'`) |

### 3. recent_accuracy

| 项目 | 值 |
|------|-----|
| 存储表 | 各板块 sessions 表 |
| 字段 | 词汇: `accuracy_rate` / 听力: `score` / 阅读: `score` / 写作: `grammar_score` |
| 写入时机 | 每次练习完成保存 session 时 |
| 读取 SQL | `SELECT AVG(对应字段) as avg FROM {board}_sessions WHERE user_id = ? AND created_at > datetime('now', '-7 days')` |
| 数据类型 | number (0-1) |
| 兜底值 | `0.7` |
| 格式化 | `.toFixed(2)` → 如 `"0.70"` |

### 4. recent_errors_json

| 项目 | 值 |
|------|-----|
| 存储表 | `writing_corrections` |
| 字段 | `error_type` TEXT, `explanation_cn` TEXT |
| 写入时机 | 写作练习完成 → 拆纠错明细 |
| 读取 SQL | `SELECT error_type, explanation_cn FROM writing_corrections WHERE user_id = ? ORDER BY created_at DESC LIMIT 10` |
| 输出格式 | `[{"type": "tense:past_simple", "explanation": "你用了过去时但语境需要现在完成时..."}]` |
| 兜底值 | `[]` |

### 5. repeat_errors_json

| 项目 | 值 |
|------|-----|
| 存储表 | `speaking_grammar_errors` |
| 字段 | `error_type` TEXT, `repeat_count` INTEGER |
| 写入时机 | 口语练习完成 → 检测重复错误 |
| 读取 SQL | `SELECT error_type, repeat_count FROM speaking_grammar_errors WHERE user_id = ? AND repeat_count >= 2 ORDER BY repeat_count DESC LIMIT 5` |
| 输出格式 | `[{"error_type": "article:missing", "repeat_count": 3}]` |
| 兜底值 | `[]` |

### 6. known_words_json

| 项目 | 值 |
|------|-----|
| 存储表 | `vocab_cards` |
| 字段 | `word` TEXT |
| 写入时机 | 词汇练习完成 → 新词卡写入 |
| 读取 SQL | `SELECT word FROM vocab_cards WHERE user_id = ? ORDER BY created_at DESC LIMIT 50` |
| 输出格式 | `["algorithm", "deploy", "refactor", ...]` |
| 兜底值 | `[]` |

### 7. session_count

| 项目 | 值 |
|------|-----|
| 存储表 | `user_profile` |
| 字段 | `total_sessions` INTEGER |
| 写入时机 | 每次练习完成 → `updateGlobalProgress()` +1 |
| 读取 SQL | `SELECT total_sessions FROM user_profile WHERE user_id = ?` |
| 注意 | 读取后 +1 再填入模板（表示"本次是第 N+1 次"） |
| 兜底值 | `1` |

### 8. daily_goal

| 项目 | 值 |
|------|-----|
| 存储表 | `user_profile` |
| 字段 | `daily_goal_vocab` INTEGER |
| 写入时机 | 用户设置中修改 |
| 读取 SQL | `SELECT daily_goal_vocab FROM user_profile WHERE user_id = ?` |
| 兜底值 | `10` |

### 9. theme

| 项目 | 值 |
|------|-----|
| 来源 | 用户输入 / 场景选择（非数据库） |
| 写入时机 | 用户主动选择或留空 |
| 兜底值 | `''` (空字符串) |
| 说明 | 空字符串时 AI 自行决定主题 |

### 10. tech_focus

| 项目 | 值 |
|------|-----|
| 来源 | 固定值或用户设置 |
| 默认值 | `'true'` |
| 说明 | 控制是否优先技术职场词汇 |

### 11. recent_unknown_words

| 项目 | 值 |
|------|-----|
| 存储表 | `listening_unknown_words` |
| 字段 | `word` TEXT |
| 写入时机 | 听力练习完成 → 用户标记不认识 |
| 读取 SQL | `SELECT DISTINCT word FROM listening_unknown_words WHERE user_id = ? ORDER BY id DESC LIMIT 20` |
| 输出格式 | `["scalability", "latency", ...]` |
| 兜底值 | `[]` |

### 12. grammar_focus

| 项目 | 值 |
|------|-----|
| 存储表 | `user_grammar_profile` |
| 读取 SQL | `SELECT grammar_tag FROM user_grammar_profile WHERE user_id = ? AND status = 'struggling' ORDER BY total_errors DESC LIMIT 1` |
| 输出格式 | 单个 tag 字符串，如 `"tense:present_perfect"` |
| 兜底值 | `''` |

### 13. guided_prompts_grammar

| 项目 | 值 |
|------|-----|
| 存储表 | `user_grammar_profile` |
| 读取 SQL | 同 `struggle_areas_json` LIMIT 3 |
| 格式化 | tags 用 `\|` 连接，如 `"tense:past_simple\|article:definite\|preposition:in_on_at"` |
| 兜底值 | `''` |

### 14. user_text

| 项目 | 值 |
|------|-----|
| 来源 | 用户实时输入（非数据库） |
| 说明 | 写作板块用户提交的文本，直接传入 assemble 方法 |
| 兜底值 | 无（调用方必须传入） |

### 15. due_count

| 项目 | 值 |
|------|-----|
| 存储表 | `review_queue` |
| 字段 | `fsrs_due` DATETIME |
| 读取 SQL | `SELECT COUNT(*) as count FROM review_queue WHERE user_id = ? AND fsrs_due <= datetime('now')` |
| 兜底值 | `0` |

### 16. mixed_items_json

| 项目 | 值 |
|------|-----|
| 存储表 | `review_queue` |
| 读取 SQL | 按板块混合比例查询（词汇 45% / 写作 22% / 阅读 13% / 口语 12% / 听力 8% / 语法专项 余量） |
| 输出格式 | `[{"review_id": "...", "source_board": "writing", "content_json": {...}, ...}]` |
| 兜底值 | `[]` |

---

## 三、兜底值汇总（复制即用）

``` typescript
const PROMPT_DEFAULTS = {
current_level: 'B1',
struggle_areas_json: '[]',
recent_accuracy: '0.70',
recent_errors_json: '[]',
repeat_errors_json: '[]',
known_words_json: '[]',
session_count: '1',
daily_goal: '10',
theme: '',
tech_focus: 'true',
recent_unknown_words: '[]',
grammar_focus: '',
guided_prompts_grammar: '',
user_text: '', // 调用方负责传
due_count: '0',
mixed_items_json: '[]',
} as const;
```

---

## 四、各板块变量速查（哪些板块用哪些变量）

| 板块 | 使用的变量 |
|------|-----------|
| 词汇 | 1, 2, 3, 6, 7, 8, 9, 10 |
| 听力 | 1, 2, 3, 11, 12 |
| 阅读 | 1, 2, 3, 12 |
| 口语 | 1, 2, 5, 13 |
| 写作 | 1, 2, 3, 4, 6, 7, 9, 14 |
| 复习 | 1, 2, 15, 16 |

---

## 五、补充 & 注意事项（之前未明确写出的）

### 1. 变量命名约定
- JSON 数组类变量统一以 `_json` 结尾（如 `struggle_areas_json`）
- 纯数字变量填入模板前必须 `String()` 转换
- 百分比/准确率变量填入前必须 `.toFixed(2)`

### 2. 空库初始化顺序

#### App 启动 → initializeDatabase()
→ 建表
→ 插 grammar_tags（如为空）
→ 插 user_profile 默认行（如不存在）
→ PRAGMA 设置

只有 `user_profile` 有默认行，其他表（sessions、corrections 等）首次全为空，靠兜底值覆盖。

### 3. 变量更新时机总结
| 变量 | 何时开始有真实数据 |
|------|------------------|
| `current_level` | 首次启动即有 |
| `struggle_areas_json` | 第 1 次练习完成后 |
| `recent_accuracy` | 第 1 次练习完成后 |
| `recent_errors_json` | 第 1 次写作练习完成后 |
| `repeat_errors_json` | 第 2 次口语练习（且出现重复错误）后 |
| `known_words_json` | 第 1 次词汇练习完成后 |
| `session_count` | 第 1 次练习完成后 +1 |
| `daily_goal` | 首次启动即有 |
| `recent_unknown_words` | 第 1 次听力练习完成后 |
| `grammar_focus` | 第 1 次练习完成后（有 struggling tag 时） |
| `guided_prompts_grammar` | 同 grammar_focus |
| `due_count` | 第 1 次错误晋升到复习队列后 |
| `mixed_items_json` | 同 due_count |

### 4. 安全检查（必须实现）

``` typescript
// 每次 assemble 完成后执行
const remainingVars = prompt.match(/{{[^}]+}}/g);
if (remainingVars?.length) {
console.warn('[PromptAssembler] Unreplaced:', remainingVars);
for (const v of remainingVars) prompt = prompt.replace(v, '');
}
```

### 5. 变量冲突处理
如果同一变量在不同板块读取的 SQL 不同（如 `recent_accuracy` 各板块字段名不同），**每个板块的 assemble 方法各自独立查询**，不共享缓存结果。理由：各板块数据量小，独立查询更清晰，避免跨板块耦合。

### 6. 未来扩展
- 新增板块时，只需从以上 16 个变量中选择需要的，不需要发明新变量
- 如果必须新增变量，遵循命名 `_json` / `_cn` 后缀约定，并在本文档注册
