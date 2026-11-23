/// 统一语法标签 taxonomy — 见 grammar.js / modules-connect.md §串联规则 1
///
/// 所有板块的语法标记必须引用本表中的 tag_id，禁止自由文本。
/// 首次建库时写入 grammar_tags 表。
library;

/// tag_id → 中文名称
const Map<String, String> kGrammarTagTaxonomy = {
  // 时态
  'tense:present_simple': '一般现在时',
  'tense:present_continuous': '现在进行时',
  'tense:present_perfect': '现在完成时',
  'tense:present_perfect_continuous': '现在完成进行时',
  'tense:past_simple': '一般过去时',
  'tense:past_continuous': '过去进行时',
  'tense:past_perfect': '过去完成时',
  'tense:future': '将来时',
  'tense:used_to': 'used to / would',

  // 语态
  'voice:active': '主动语态',
  'voice:passive': '被动语态',

  // 情态动词
  'modal:can_could': 'can/could',
  'modal:should_must': 'should/must/ought to',
  'modal:may_might': 'may/might',

  // 非谓语
  'nonfinite:infinitive': '不定式',
  'nonfinite:gerund': '动名词',
  'nonfinite:participle': '分词',

  // 从句
  'clause:relative': '定语从句',
  'clause:noun': '名词性从句',
  'clause:adverbial': '状语从句',
  'clause:conditional': '条件句',

  // 词法
  'lexical:article': '冠词',
  'lexical:preposition': '介词',
  'lexical:conjunction': '连词',
  'lexical:irregular_verb': '不规则动词',
  'lexical:countable_uncountable': '可数/不可数名词',
  'lexical:comparative_superlative': '比较级/最高级',

  // 句子结构
  'structure:word_order': '语序',
  'structure:question': '疑问句',
  'structure:negative': '否定句',
  'structure:reported_speech': '间接引语',

  // 技术英语特有
  'tech:passive_in_docs': '技术文档中的被动语态',
  'tech:imperative_in_instructions': '指令中的祈使句',
  'tech:conditional_in_specs': '规格说明中的条件句',
};
