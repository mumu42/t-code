import 'package:flutter_test/flutter_test.dart';
import 'package:linguaflow/services/agent/agent_api_client.dart';
import 'package:linguaflow/models/agent_config.dart';

void main() {
  group('normalizeBaseUrl — 原样使用，不做路径补全', () {
    test('仅去除尾部斜杠与空白', () {
      expect(normalizeBaseUrl('https://api.deepseek.com/v1/'),
          'https://api.deepseek.com/v1');
      expect(normalizeBaseUrl('  https://api.openai.com/v1  '),
          'https://api.openai.com/v1');
      expect(normalizeBaseUrl('https://example.com///'),
          'https://example.com');
    });

    test('未带 /v1 时保持原样（不自动补全）', () {
      expect(normalizeBaseUrl('https://api.deepseek.com'),
          'https://api.deepseek.com');
      expect(normalizeBaseUrl('http://localhost:11434/v1'),
          'http://localhost:11434/v1');
    });

    test('空串保持为空', () {
      expect(normalizeBaseUrl(''), '');
      expect(normalizeBaseUrl('   '), '');
    });
  });

  group('normalizeProxy — 代理地址归一化', () {
    test('去掉 scheme 前缀', () {
      expect(normalizeProxy('http://127.0.0.1:7890'), '127.0.0.1:7890');
      expect(normalizeProxy('socks5://127.0.0.1:1080'), '127.0.0.1:1080');
    });

    test('纯 host:port 原样保留', () {
      expect(normalizeProxy('127.0.0.1:7890'), '127.0.0.1:7890');
    });

    test('空值返回 null', () {
      expect(normalizeProxy(null), isNull);
      expect(normalizeProxy(''), isNull);
      expect(normalizeProxy('   '), isNull);
    });
  });

  group('AgentConfig.isConfigured', () {
    test('三项核心配置齐全才可用', () {
      const full =
          AgentConfig(baseUrl: 'https://x.com', apiKey: 'sk-1', model: 'm');
      expect(full.isConfigured, isTrue);

      const noModel =
          AgentConfig(baseUrl: 'https://x.com', apiKey: 'sk-1');
      expect(noModel.isConfigured, isFalse);

      expect(const AgentConfig().isConfigured, isFalse);
    });
  });
}
