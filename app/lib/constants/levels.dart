/// 12 级能力等级定义 — 见 f3.md §五
///
/// 激励层的 current_level_index (0-11) 与定级模块的 CEFR current_level
/// 相互独立：CEFR 决定内容难度，XP 等级决定能力感知展示。
library;

class LevelDef {
  const LevelDef({
    required this.index,
    required this.name,
    required this.title,
    required this.description,
    required this.cefrRange,
    required this.visual,
    required this.scene,
  });

  final int index;
  final String name; // 英文短名
  final String title; // 中文标题
  final String description; // "你现在能..."
  final String cefrRange; // 对应 CEFR
  final String visual; // emoji 图标
  final String scene; // 解锁场景描述
}

const List<LevelDef> kLevels = [
  LevelDef(
    index: 0,
    name: 'Seed',
    title: '破土',
    description: '你能在工作中认出基础技术词汇，比如 "deploy", "bug", "API"。',
    cefrRange: 'A1',
    visual: '🌱',
    scene: '看懂同事发的 "The build is broken" 这种 Slack 消息',
  ),
  LevelDef(
    index: 1,
    name: 'Sprout',
    title: '萌芽',
    description: '你能写出简单的工作邮件，描述一个 bug 或请求帮助。',
    cefrRange: 'A2',
    visual: '🌿',
    scene: '给海外同事发 "Could you help me check this error?"',
  ),
  LevelDef(
    index: 2,
    name: 'Budding',
    title: '抽枝',
    description: '你能参与技术讨论，听懂大部分日常技术对话，偶尔需要追问。',
    cefrRange: 'A2+',
    visual: '🌳',
    scene: "在站会上听懂 \"I'll pick up that ticket after standup\"",
  ),
  LevelDef(
    index: 3,
    name: 'Growing',
    title: '生长',
    description: '你能读懂英文技术文档的核心段落，不需要逐词翻译。',
    cefrRange: 'B1',
    visual: '🪴',
    scene: '直接读 React / Flutter 官方文档，理解 70% 以上',
  ),
  LevelDef(
    index: 4,
    name: 'Flourishing',
    title: '繁茂',
    description: '你能写英文技术文档和 PR 描述，语法基本正确。',
    cefrRange: 'B1+',
    visual: '🌸',
    scene: '写 GitHub PR description，review 别人的代码注释',
  ),
  LevelDef(
    index: 5,
    name: 'Skilled',
    title: '熟手',
    description: '你能独立阅读英文技术博客和 RFC，理解作者意图。',
    cefrRange: 'B2-',
    visual: '🔧',
    scene: '读完一篇 Martin Fowler 文章，能复述核心观点',
  ),
  LevelDef(
    index: 6,
    name: 'Competent',
    title: '胜任',
    description: '你能参与英文技术会议，表达观点、提问、反驳。',
    cefrRange: 'B2',
    visual: '🎯',
    scene: '在跨国会议中说出 "I disagree with this approach because..."',
  ),
  LevelDef(
    index: 7,
    name: 'Proficient',
    title: '精通',
    description: '你能用英语做技术分享，逻辑清晰，听众能跟上。',
    cefrRange: 'B2+',
    visual: '🎤',
    scene: '给团队做 15 分钟英文 tech talk，不需要提前写逐字稿',
  ),
  LevelDef(
    index: 8,
    name: 'Advanced',
    title: '进阶',
    description: '你能读懂学术论文和复杂技术提案，提取关键信息。',
    cefrRange: 'C1-',
    visual: '📄',
    scene: '读一篇 ACM 论文的 abstract + intro，判断值不值得深读',
  ),
  LevelDef(
    index: 9,
    name: 'Expert',
    title: '专家',
    description: '你能用英语撰写技术提案，说服他人采纳你的方案。',
    cefrRange: 'C1',
    visual: '📋',
    scene: '写一份英文 ADR (Architecture Decision Record) 推动团队决策',
  ),
  LevelDef(
    index: 10,
    name: 'Master',
    title: '大师',
    description: '你能用英语谈判、争取资源、推动跨团队项目。',
    cefrRange: 'C1+',
    visual: '🤝',
    scene: '在谈判中说 "We can compromise on timeline but not on scope"',
  ),
  LevelDef(
    index: 11,
    name: 'Legend',
    title: '传奇',
    description: '英语不再是障碍，它是你的职业加速器。你可以用英语做任何事。',
    cefrRange: 'C2',
    visual: '🚀',
    scene: '在 DevRel 大会上用英文演讲，台下坐着你崇拜的大佬',
  ),
];
