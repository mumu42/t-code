# LinguaFlow — 六大板块数据串联规范

你正在为一个英语学习 App 设计本地数据层。App 有 6 个板块，数据必须按以下规则串联。

## 板块与职责

| 板块 | 职责 | 产生的数据 |
|------|------|-----------|
| ① 词汇 | 单词记忆，例句嵌入语法 | 词卡（含 grammar_tags） |
| ② 听力 | 听懂，检测语法线索 | 听力 session + 生词 + grammar_focus |
| ③ 阅读 | 读懂，长难句标注 | 阅读 session + 硬句（含 grammar_note） |
| ④ 口语 | 说出来，轻量纠错 | 对话日志 + grammar_tip + 重复错误 |
| ⑤ 写作 | 写下来，深讲语法 | 纠错明细（含 explanation_cn + grammar_depth） |
| ⑥ 复习 | 统一 FSRS 调度 | review_queue 混排所有来源 |

## 串联规则

### 1. 统一语法标签
所有板块的语法标记引用同一张 grammar_tags 表（tag_id 如 "tense:past_simple"），禁止自由文本。

### 2. 错误自动晋升到复习队列
| 来源 | 触发条件 | 入队类型 |
|------|---------|---------|
| 写作纠错 | severity=high 或 同类错误 ≥3 次 | correction |
| 口语错误 | 同类重复 ≥2 次 | grammar_point |
| 阅读硬句 | 用户标记"没看懂" | hard_sentence |
| 听力生词 | 标记为不认识 | word_card |
| 词汇错例 | 连续 2 次识别失败 | grammar_point |

晋升时写入 review_queue，冗余存储 content_json，标记 source_board + grammar_tag。

### 3. 薄弱点回灌（反向流动）
user_grammar_profile 中 status='struggling' 的标签，下次生成各板块内容时必须被读取：
- 词汇：例句嵌入该语法点
- 听力：材料埋该语法线索词
- 阅读：优先选含该结构的长难句
- 口语：引导语提示用该语法
- 写作：对比历史错误，判断是否重复
- 复习：priority_boost +2，提高出现频率

### 4. 复习队列混合比例
每次 session（默认 20 张）：词汇 40-50%，写作纠错 20-25%，阅读硬句 10-15%，口语语法 10-15%，听力生词 5-10%，语法专项 0-30%（动态）。

### 5. 禁止闭环
复习只读取原板块内容，不直接修改原表。通过 user_grammar_profile 间接影响下次生成。

## 核心表（必须有的）

- grammar_tags（统一标签）
- user_grammar_profile（薄弱点聚合）
- vocab_cards / listening_sessions / reading_sessions / speaking_sessions / writing_sessions（各板块原始数据）
- writing_corrections / speaking_grammar_errors / reading_hard_sentences / listening_unknown_words（各板块错误明细）
- review_queue（统一调度）
- review_logs（复习答题记录）

## 要求

根据以上规则，生成：
1. 完整的 SQLite 建表 SQL（含外键）
2. 错误晋升逻辑的伪代码或 SQL trigger
3. 薄弱点回灌到各板块 Prompt 的数据读取逻辑
4. review_queue 生成算法（含混合比例 + FSRS 排程）
