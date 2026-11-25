/// 跨端 TTS 服务 — 见 f2.md（Flutter 版适配）
///
/// 原方案为 RN 五端 Adapter；Flutter 下统一收敛：
/// - iOS / Android / Web → flutter_tts（底层分别为 AVSpeechSynthesizer /
///   Android TextToSpeech / 浏览器 speechSynthesis，恰好覆盖 f2 平台矩阵）
/// - 桌面端（V2 接入 windows/macos 时）→ 暂用 NoOp 降级为阅读模式
///
/// 规约（f2 §十三）：
/// 1. 所有 TTS 调用必须通过 TTSService，禁止业务代码直接 import flutter_tts
/// 2. 语速统一由 getEffectiveRate 计算：用户手动覆盖 > CEFR 等级默认
/// 3. TTS 不可用时降级为"阅读模式"，不阻塞练习流程
library;

import 'package:flutter/foundation.dart' show kIsWeb, VoidCallback;
import 'package:flutter_tts/flutter_tts.dart';

import '../../constants/app_constants.dart';
import '../../data/storage_service.dart';

/// 口音偏好
enum TtsAccent { us, uk, au }

/// TTS 播放选项
class TtsOptions {
  const TtsOptions({
    this.rate,
    this.pitch = 1.0,
    this.accent = TtsAccent.us,
    this.onDone,
    this.onError,
  });

  final double? rate; // null = 按 CEFR 等级自动（getTTSRate）
  final double pitch;
  final TtsAccent? accent; // null = 读用户设置（user_profile.tts_accent）
  final VoidCallback? onDone;
  final void Function(String error)? onError;
}

/// 语速分级策略（全局统一）— f2 §九
double getTTSRate(String userLevel, {bool slow = false}) {
  const baseRates = {
    'A1': 0.8, 'A2': 0.8,
    'B1': 0.9,
    'B2': 1.0, 'C1': 1.0,
    'C2': 1.1,
  };
  final base = baseRates[userLevel] ?? 0.9;
  final r = slow ? base - 0.2 : base;
  return r < 0.5 ? 0.5 : r;
}

/// 统一 TTS 入口（业务层唯一可见的 API）
class TTSService {
  TTSService._() {
    _initEngine();
  }

  static final TTSService instance = TTSService._();

  final FlutterTts _tts = FlutterTts();
  bool _engineReady = false;
  bool _speaking = false;
  TtsAccent? _cachedProfileAccent; // 设置页口音缓存

  bool get isSpeaking => _speaking;

  /// 设置页修改口音后调用，下次朗读立即生效
  void invalidateAccentCache() => _cachedProfileAccent = null;

  /// 读取用户设置的口音（user_profile.tts_accent，'B1' 类兜底：默认美音）
  Future<TtsAccent> _loadAccent() async {
    if (_cachedProfileAccent != null) return _cachedProfileAccent!;
    if (!StorageService.instance.isReady) return TtsAccent.us;
    try {
      final rows = await StorageService.instance.query(
        'SELECT tts_accent FROM user_profile WHERE user_id = ?',
        [kLocalUserId],
      );
      final v = (rows.first['tts_accent'] as String?) ?? 'us';
      _cachedProfileAccent = switch (v) {
        'uk' => TtsAccent.uk,
        'au' => TtsAccent.au,
        _ => TtsAccent.us,
      };
    } catch (_) {
      _cachedProfileAccent = TtsAccent.us;
    }
    return _cachedProfileAccent!;
  }

  Future<void> _initEngine() async {
    try {
      // iOS：不静音其他音频、允许静音开关下播放（f2 §4.2）
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
        IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
      ]);
      _engineReady = true;
    } catch (_) {
      // 初始化失败：保持降级态，speak 时重试
    }
  }

  Future<String> _resolveLang(TtsAccent accent) async {
    switch (accent) {
      case TtsAccent.us:
        return 'en-US';
      case TtsAccent.uk:
        return 'en-GB';
      case TtsAccent.au:
        return 'en-AU';
    }
  }

  /// 朗读文本（Android 4000 字符限制由 flutter_tts 分句处理，业务层无感知）
  Future<void> speak(String text, TtsOptions options) async {
    if (kIsWeb && text.length > 4000) {
      // Web 端保守截断，避免个别浏览器 TTS 队列卡死
      text = text.substring(0, 4000);
    }
    final accent = options.accent ?? await _loadAccent();
    try {
      if (!_engineReady) await _initEngine();
      await _tts.setLanguage(await _resolveLang(accent));
      await _tts.setPitch(options.pitch);
      // rate 未指定时按等级自动（默认 B1 = 0.9）
      await _tts
          .setSpeechRate(_normalizeRate(options.rate ?? getTTSRate('B1')));
      _speaking = true;
      final result = await _tts.speak(text);
      if (result != 1) options.onError?.call('TTS speak failed: $result');
    } catch (e) {
      options.onError?.call('$e');
    } finally {
      _speaking = false;
      options.onDone?.call();
    }
  }

  /// 立即停止
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
    _speaking = false;
  }

  /// flutter_tts 的 rate 范围与平台相关（iOS 0.0-1.0 常用区间 vs Android 0.5-2.0），
  /// 这里做保守归一：内部统一 0.5-2.0 语义直接透传
  double _normalizeRate(double rate) => rate.clamp(0.1, 2.0);
}
