/// 全局常量 — 见 LinguaFlow.md / modules-connect.md
///
/// V1 为纯本地应用（无注册登录），全库固定单用户 'local'。
library;

/// 本地单用户 ID（V1 无账号系统，见 f1.md §七.9）
const String kLocalUserId = 'local';

/// CEFR 等级顺序（定级模块难度阶梯，见 f1.md §三.1）
const List<String> kCefrOrder = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

/// 复习 Session 每轮上限（见 f4.md §十.8：20 due + 5 new = 25 张）
const int kReviewSessionDueLimit = 20;
const int kReviewSessionNewLimit = 5;
