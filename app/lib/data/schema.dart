/// 统一建表 Schema（v1）— 汇总自 f1/f3/f4/f5.md
///
/// ⚠️ 设计决策：复习调度采用 f4.md 的 `srs_cards` + `srs_reviews` 模型，
/// 替代 modules-connect.md 早期草案中的 `review_queue` + `review_logs`
/// （后者仅保留概念，不再建表）。理由见仓库根 README.md「关键设计决策」。
///
/// 外键约定：所有用户数据表外键指向 user_profile(user_id)。
/// schema 升级时新增版本迁移，禁止修改历史语句。
library;

/// 按执行顺序排列的 DDL 语句列表（sqflite execute 一次一条）
const List<String> kSchemaStatements = [
  // ═══════════ 用户主表 ═══════════
  '''
  CREATE TABLE IF NOT EXISTS user_profile (
    user_id TEXT PRIMARY KEY,
    current_level TEXT NOT NULL DEFAULT 'B1',
    target_level TEXT NOT NULL DEFAULT 'B2',
    need_placement INTEGER NOT NULL DEFAULT 1,
    need_placement_reminder INTEGER NOT NULL DEFAULT 1,
    placement_completed_at DATETIME,
    total_sessions INTEGER NOT NULL DEFAULT 0,
    daily_goal_vocab INTEGER NOT NULL DEFAULT 10,
    total_xp INTEGER NOT NULL DEFAULT 0,
    current_level_index INTEGER NOT NULL DEFAULT 0,
    streak_days INTEGER NOT NULL DEFAULT 0,
    last_active_date TEXT,
    tts_rate_override REAL,
    tts_accent TEXT NOT NULL DEFAULT 'us',
    tts_autoplay INTEGER NOT NULL DEFAULT 1
  )
  ''',

  // ═══════════ 统一语法标签（modules-connect §1）═══════════
  '''
  CREATE TABLE IF NOT EXISTS grammar_tags (
    tag_id TEXT PRIMARY KEY,
    name_cn TEXT NOT NULL
  )
  ''',

  // ═══════════ 薄弱点聚合（modules-connect §3；source 字段见 f1 §2.2）═══════════
  '''
  CREATE TABLE IF NOT EXISTS user_grammar_profile (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    grammar_tag TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'struggling',
    total_errors INTEGER NOT NULL DEFAULT 1,
    last_seen_at DATETIME,
    source TEXT NOT NULL DEFAULT 'practice',
    UNIQUE(user_id, grammar_tag),
    FOREIGN KEY (user_id) REFERENCES user_profile(user_id)
  )
  ''',

  // ═══════════ 定级模块（f1 §2.1）═══════════
  '''
  CREATE TABLE IF NOT EXISTS placement_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    question_id TEXT NOT NULL,
    cefr TEXT NOT NULL,
    type TEXT NOT NULL,
    correct INTEGER NOT NULL CHECK (correct IN (0, 1)),
    grammar_tags_json TEXT,
    answered_at DATETIME NOT NULL,
    FOREIGN KEY (user_id) REFERENCES user_profile(user_id)
  )
  ''',

  // ═══════════ SRS 复习引擎（f4 §二）═══════════
  '''
  CREATE TABLE IF NOT EXISTS srs_cards (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    item_type TEXT NOT NULL,
    item_id TEXT NOT NULL,
    difficulty REAL NOT NULL DEFAULT 5.0,
    stability REAL NOT NULL DEFAULT 1.0,
    retrievability REAL DEFAULT 1.0,
    state TEXT NOT NULL DEFAULT 'new',
    step INTEGER DEFAULT 0,
    interval_days INTEGER DEFAULT 0,
    due_date DATETIME NOT NULL,
    last_reviewed_at DATETIME,
    review_count INTEGER DEFAULT 0,
    lapse_count INTEGER DEFAULT 0,
    total_time_spent INTEGER DEFAULT 0,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    UNIQUE(user_id, item_type, item_id),
    FOREIGN KEY (user_id) REFERENCES user_profile(user_id)
  )
  ''',
  'CREATE INDEX IF NOT EXISTS idx_srs_cards_due ON srs_cards(user_id, due_date)',
  'CREATE INDEX IF NOT EXISTS idx_srs_cards_state ON srs_cards(user_id, state)',
  '''
  CREATE TABLE IF NOT EXISTS srs_reviews (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    card_id INTEGER NOT NULL,
    item_type TEXT NOT NULL,
    item_id TEXT NOT NULL,
    rating INTEGER NOT NULL,
    response_time_ms INTEGER,
    difficulty_before REAL,
    stability_before REAL,
    interval_before INTEGER,
    difficulty_after REAL,
    stability_after REAL,
    interval_after INTEGER,
    reviewed_at DATETIME NOT NULL,
    FOREIGN KEY (user_id) REFERENCES user_profile(user_id),
    FOREIGN KEY (card_id) REFERENCES srs_cards(id)
  )
  ''',

  // ═══════════ 激励层（f3 §三）═══════════
  '''
  CREATE TABLE IF NOT EXISTS xp_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    source TEXT NOT NULL,
    amount INTEGER NOT NULL,
    board TEXT,
    related_id TEXT,
    created_at DATETIME NOT NULL,
    FOREIGN KEY (user_id) REFERENCES user_profile(user_id)
  )
  ''',
  'CREATE INDEX IF NOT EXISTS idx_xp_log_user_date ON xp_log(user_id, date(created_at))',
  '''
  CREATE TABLE IF NOT EXISTS level_unlocks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    level_index INTEGER NOT NULL,
    unlocked_at DATETIME NOT NULL,
    viewed INTEGER DEFAULT 0,
    UNIQUE(user_id, level_index),
    FOREIGN KEY (user_id) REFERENCES user_profile(user_id)
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS streak_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    date TEXT NOT NULL,
    sessions_count INTEGER NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL,
    UNIQUE(user_id, date),
    FOREIGN KEY (user_id) REFERENCES user_profile(user_id)
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS streak_freezes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL UNIQUE,
    quantity INTEGER NOT NULL DEFAULT 0,
    last_awarded_at DATETIME,
    FOREIGN KEY (user_id) REFERENCES user_profile(user_id)
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS daily_quests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    quest_date TEXT NOT NULL,
    quest_1_done INTEGER DEFAULT 0,
    quest_2_done INTEGER DEFAULT 0,
    quest_3_done INTEGER DEFAULT 0,
    all_completed INTEGER DEFAULT 0,
    reward_claimed INTEGER DEFAULT 0,
    created_at DATETIME NOT NULL,
    UNIQUE(user_id, quest_date),
    FOREIGN KEY (user_id) REFERENCES user_profile(user_id)
  )
  ''',

  // ═══════════ 各板块 session / response（f5 §四）═══════════
  '''
  CREATE TABLE IF NOT EXISTS vocab_sessions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    level TEXT NOT NULL,
    mode TEXT NOT NULL,
    total_items INTEGER NOT NULL,
    correct_count INTEGER NOT NULL,
    wrong_count INTEGER NOT NULL,
    accuracy REAL NOT NULL,
    time_spent_sec INTEGER NOT NULL,
    started_at DATETIME NOT NULL,
    completed_at DATETIME NOT NULL,
    created_at DATETIME NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS vocab_responses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    word_id TEXT NOT NULL,
    user_answer TEXT NOT NULL,
    correct_answer TEXT NOT NULL,
    correct INTEGER NOT NULL,
    response_time_ms INTEGER,
    created_at DATETIME NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS listening_sessions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    level TEXT NOT NULL,
    audio_mode TEXT NOT NULL,
    total_items INTEGER NOT NULL,
    correct_count INTEGER NOT NULL,
    wrong_count INTEGER NOT NULL,
    accuracy REAL NOT NULL,
    time_spent_sec INTEGER NOT NULL,
    started_at DATETIME NOT NULL,
    completed_at DATETIME NOT NULL,
    created_at DATETIME NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS listening_responses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    sentence_id TEXT NOT NULL,
    user_transcript TEXT,
    correct_answer TEXT NOT NULL,
    correct INTEGER NOT NULL,
    audio_play_count INTEGER DEFAULT 1,
    response_time_ms INTEGER,
    created_at DATETIME NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS reading_sessions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    passage_id TEXT NOT NULL,
    level TEXT NOT NULL,
    total_items INTEGER NOT NULL,
    correct_count INTEGER NOT NULL,
    wrong_count INTEGER NOT NULL,
    accuracy REAL NOT NULL,
    time_spent_sec INTEGER NOT NULL,
    started_at DATETIME NOT NULL,
    completed_at DATETIME NOT NULL,
    created_at DATETIME NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS reading_responses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    passage_id TEXT NOT NULL,
    question_id TEXT NOT NULL,
    question_type TEXT NOT NULL,
    user_answer TEXT NOT NULL,
    correct_answer TEXT NOT NULL,
    correct INTEGER NOT NULL,
    response_time_ms INTEGER,
    created_at DATETIME NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS speaking_sessions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    scenario_id TEXT NOT NULL,
    level TEXT NOT NULL,
    total_items INTEGER NOT NULL,
    completed_count INTEGER NOT NULL,
    accuracy REAL NOT NULL,
    time_spent_sec INTEGER NOT NULL,
    started_at DATETIME NOT NULL,
    completed_at DATETIME NOT NULL,
    created_at DATETIME NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS speaking_responses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    scenario_id TEXT NOT NULL,
    prompt_text TEXT NOT NULL,
    user_text TEXT,
    recording_path TEXT,
    recording_duration_ms INTEGER,
    completed INTEGER NOT NULL,
    created_at DATETIME NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS writing_sessions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    prompt_id TEXT NOT NULL,
    level TEXT NOT NULL,
    total_items INTEGER NOT NULL,
    submitted_count INTEGER NOT NULL,
    avg_ai_score REAL,
    time_spent_sec INTEGER NOT NULL,
    started_at DATETIME NOT NULL,
    completed_at DATETIME NOT NULL,
    created_at DATETIME NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS writing_responses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    prompt_id TEXT NOT NULL,
    user_text TEXT NOT NULL,
    word_count INTEGER NOT NULL,
    ai_score INTEGER,
    grammar_errors_json TEXT,
    completed INTEGER NOT NULL,
    created_at DATETIME NOT NULL
  )
  ''',

  // ═══════════ Agent（AI 服务）配置 ═══════════
  // 单行表（id 恒为 1）。OpenAI 兼容格式：base_url + api_key + model。
  // 本地明文存储（纯本地单用户应用，见 README「关键设计决策」）。
  '''
  CREATE TABLE IF NOT EXISTS agent_config (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    base_url TEXT NOT NULL DEFAULT '',
    api_key TEXT NOT NULL DEFAULT '',
    model TEXT NOT NULL DEFAULT '',
    timeout_sec INTEGER NOT NULL DEFAULT 60,
    proxy TEXT,
    updated_at DATETIME
  )
  ''',

  // ═══════════ 词汇内容表（v3 新增）═══════════
  // 设计决策：词汇内容双表——seed_words 为随版本发布的内置词库（只读、
  // 无 user_id），vocab_cards 为运行时产生的用户/AI 词卡。两表字段同构，
  // 复习页按 id 前缀（w_ / uv_）决定解析去向。软下线用 active 标记，
  // 不物理删除（防孤儿 srs_cards，f4 §九）。

  // ── seed_words：内置词库（自研技术词库，LinguaFlow.md §三.1）──
  '''
  CREATE TABLE IF NOT EXISTS seed_words (
    id TEXT PRIMARY KEY,
    word TEXT NOT NULL UNIQUE,
    phonetics TEXT,
    part_of_speech TEXT,
    meaning_cn TEXT NOT NULL,
    example TEXT,
    example_cn TEXT,
    cefr TEXT NOT NULL,
    difficulty INTEGER NOT NULL DEFAULT 3,
    tags_json TEXT NOT NULL DEFAULT '[]',
    grammar_tags_json TEXT,
    active INTEGER NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL
  )
  ''',
  'CREATE INDEX IF NOT EXISTS idx_seed_words_cefr ON seed_words(cefr, difficulty)',
  'CREATE INDEX IF NOT EXISTS idx_seed_words_active ON seed_words(active)',

  // ── vocab_cards：用户/AI 词卡（modules-connect 词汇板块产出）──
  '''
  CREATE TABLE IF NOT EXISTS vocab_cards (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    word TEXT NOT NULL,
    phonetics TEXT,
    part_of_speech TEXT,
    meaning_cn TEXT NOT NULL,
    example TEXT,
    example_cn TEXT,
    cefr TEXT NOT NULL,
    difficulty INTEGER NOT NULL DEFAULT 3,
    tags_json TEXT NOT NULL DEFAULT '[]',
    grammar_tags_json TEXT,
    source TEXT NOT NULL DEFAULT 'ai',
    active INTEGER NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    UNIQUE(user_id, word),
    FOREIGN KEY (user_id) REFERENCES user_profile(user_id)
  )
  ''',
  'CREATE INDEX IF NOT EXISTS idx_vocab_cards_user ON vocab_cards(user_id, cefr)',

  // ── seed_meta：种子导入版本记录 ──
  '''
  CREATE TABLE IF NOT EXISTS seed_meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
  )
  ''',

  // ═══════════ 其余板块种子内容表（v4 新增）═══════════
  // 与 seed_words 同族规范：只读静态内容、无 user_id、id 前缀跨版本稳定、
  // active 软下线不物理删除。字段对齐 prompt.md 各板块输出 schema，
  // 运行时 AI 生成的题目/标注不入库。

  // ── seed_sentences：听力精听句 + 阅读硬句 + 口语跟读句（三板块共用）──
  '''
  CREATE TABLE IF NOT EXISTS seed_sentences (
    id TEXT PRIMARY KEY,
    text TEXT NOT NULL,
    translation_cn TEXT,
    cefr TEXT NOT NULL,
    difficulty INTEGER NOT NULL DEFAULT 3,
    word_count INTEGER,
    source_type TEXT NOT NULL,
    source_ref TEXT,
    keywords_json TEXT,
    grammar_tags_json TEXT,
    audio_hint_json TEXT,
    active INTEGER NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL
  )
  ''',
  'CREATE INDEX IF NOT EXISTS idx_seed_sentences_cefr ON seed_sentences(cefr, source_type)',
  'CREATE INDEX IF NOT EXISTS idx_seed_sentences_active ON seed_sentences(active)',

  // ── seed_reading_passages：阅读分级短文 ──
  '''
  CREATE TABLE IF NOT EXISTS seed_reading_passages (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    passage TEXT NOT NULL,
    cefr TEXT NOT NULL,
    difficulty INTEGER NOT NULL DEFAULT 3,
    word_count INTEGER,
    topic_tags_json TEXT,
    grammar_tags_json TEXT,
    source TEXT,
    active INTEGER NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL
  )
  ''',
  'CREATE INDEX IF NOT EXISTS idx_seed_passages_cefr ON seed_reading_passages(cefr, difficulty)',

  // ── seed_speaking_scenarios：口语场景骨架（对话细节由 AI 按 prompt.md §三展开）──
  '''
  CREATE TABLE IF NOT EXISTS seed_speaking_scenarios (
    id TEXT PRIMARY KEY,
    scenario_type TEXT NOT NULL,
    title TEXT NOT NULL,
    description_cn TEXT,
    user_role_cn TEXT,
    ai_role_cn TEXT,
    cefr TEXT NOT NULL,
    difficulty INTEGER NOT NULL DEFAULT 3,
    keywords_json TEXT,
    grammar_tags_json TEXT,
    active INTEGER NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL
  )
  ''',
  'CREATE INDEX IF NOT EXISTS idx_seed_scenarios_cefr ON seed_speaking_scenarios(cefr, scenario_type)',

  // ── seed_collocations：写作动词搭配 ──
  '''
  CREATE TABLE IF NOT EXISTS seed_collocations (
    id TEXT PRIMARY KEY,
    phrase TEXT NOT NULL UNIQUE,
    meaning_cn TEXT NOT NULL,
    example TEXT,
    example_cn TEXT,
    cefr TEXT NOT NULL,
    difficulty INTEGER NOT NULL DEFAULT 3,
    tags_json TEXT,
    active INTEGER NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL
  )
  ''',
  'CREATE INDEX IF NOT EXISTS idx_seed_collocations_cefr ON seed_collocations(cefr, difficulty)',

  // ── seed_writing_prompts：写作题目（「描述你今天修的 bug」类技术职场题）──
  '''
  CREATE TABLE IF NOT EXISTS seed_writing_prompts (
    id TEXT PRIMARY KEY,
    prompt_cn TEXT NOT NULL,
    keywords_json TEXT,
    theme TEXT,
    cefr TEXT NOT NULL,
    difficulty INTEGER NOT NULL DEFAULT 3,
    tags_json TEXT,
    active INTEGER NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL
  )
  ''',
  'CREATE INDEX IF NOT EXISTS idx_seed_writing_prompts_cefr ON seed_writing_prompts(cefr, difficulty)',

  // ═══════════ 口语录音元数据（f2 §八）═══════════
  '''
  CREATE TABLE IF NOT EXISTS speaking_recordings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    session_id TEXT NOT NULL,
    file_path TEXT NOT NULL,
    duration_ms INTEGER NOT NULL,
    size_bytes INTEGER NOT NULL,
    transcript TEXT,
    grammar_errors_json TEXT,
    platform TEXT,
    created_at DATETIME NOT NULL,
    FOREIGN KEY (user_id) REFERENCES user_profile(user_id)
  )
  ''',
];
