/// Agent API 客户端 — OpenAI 兼容格式
///
/// 端点约定（baseURL 原样使用，不自动补全）：
/// - 模型列表：GET  {base}/models
/// - 对话补全：POST {base}/chat/completions
///
/// 鉴权：`Authorization: Bearer <api_key>`
/// 网络：支持 HTTP 代理（国内直连部分服务需要）+ 每请求超时。
/// 所有 AI 调用（各板块 Prompt 发送）后续统一走本客户端。
library;

import 'dart:async' show TimeoutException;
import 'dart:convert';
import 'dart:io' show HttpClient;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../../models/agent_config.dart';

/// baseURL 归一化（纯函数，供单测）：
/// 仅去除首尾空白与尾部多余斜杠，**不做任何路径补全**——用户填的什么就是什么
/// （如需 `/v1` 前缀，由用户在 baseURL 中完整填写）。
String normalizeBaseUrl(String raw) {
  var url = raw.trim();
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  return url;
}

/// 代理地址归一化（纯函数）：'http://127.0.0.1:7890' → '127.0.0.1:7890'
String? normalizeProxy(String? raw) {
  if (raw == null) return null;
  var p = raw.trim();
  if (p.isEmpty) return null;
  for (final scheme in ['http://', 'https://', 'socks5://']) {
    if (p.startsWith(scheme)) {
      p = p.substring(scheme.length);
      break;
    }
  }
  return p.isEmpty ? null : p;
}

/// 连接测试结果
class TestResult {
  const TestResult({
    required this.ok,
    required this.message,
    this.modelExists,
  });

  final bool ok;
  final String message;
  final bool? modelExists; // /models 可用时：配置的 model 是否在列表中
}

class ChatMessage {
  const ChatMessage(this.role, this.content);

  final String role; // 'system' | 'user' | 'assistant'
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};
}

class AgentApiClient {
  AgentApiClient(this.config);

  final AgentConfig config;

  String get _base => normalizeBaseUrl(config.baseUrl);
  Uri get _modelsUrl => Uri.parse('$_base/models');
  Uri get _chatUrl => Uri.parse('$_base/chat/completions');

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${config.apiKey}',
        'Content-Type': 'application/json',
      };

  Duration get _timeout => Duration(seconds: config.timeoutSec);

  /// 构建带代理的 HTTP 客户端（Web 端忽略代理，浏览器自行管理）
  http.Client _createClient() {
    if (kIsWeb) return http.Client();
    final proxy = normalizeProxy(config.proxy);
    if (proxy == null) return http.Client();
    final inner = HttpClient();
    inner.findProxy = (uri) => 'PROXY $proxy';
    return IOClient(inner);
  }

  // ──────────────────────────────────────────────────────────
  // 模型列表
  // ──────────────────────────────────────────────────────────

  /// 拉取该服务支持的模型 id 列表（按 id 排序）
  Future<List<String>> fetchModels() async {
    final client = _createClient();
    try {
      final resp = await client
          .get(_modelsUrl, headers: _headers)
          .timeout(_timeout);
      if (resp.statusCode != 200) {
        throw _httpError('拉取模型列表', resp.statusCode, resp.body);
      }
      final data = jsonDecode(resp.body) as Map<String, Object?>;
      final list = (data['data'] as List?) ?? [];
      final ids = list
          .map((m) => ((m as Map)['id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toList()
        ..sort();
      return ids;
    } finally {
      client.close();
    }
  }

  // ──────────────────────────────────────────────────────────
  // 连接测试
  // ──────────────────────────────────────────────────────────

  /// 测试连接：优先 GET /models（轻量）；
  /// 服务未实现 /models（404/405）时回退为最小 chat 请求。
  Future<TestResult> testConnection() async {
    if (!config.isConfigured) {
      return const TestResult(
          ok: false, message: '请先填写 baseURL、API Key 和模型名');
    }
    final client = _createClient();
    try {
      final resp = await client
          .get(_modelsUrl, headers: _headers)
          .timeout(_timeout);

      if (resp.statusCode == 404 || resp.statusCode == 405) {
        // await：确保 finally 的 client.close() 在回退请求完成后才执行
        return await _testViaMinimalChat(client);
      }
      if (resp.statusCode == 401 || resp.statusCode == 403) {
        return const TestResult(ok: false, message: '鉴权失败：API Key 无效或无权限');
      }
      if (resp.statusCode != 200) {
        return TestResult(
            ok: false,
            message: '服务返回 ${resp.statusCode}：${_briefBody(resp.body)}');
      }

      final data = jsonDecode(resp.body) as Map<String, Object?>;
      final list = (data['data'] as List?) ?? [];
      final ids = list.map((m) => ((m as Map)['id'] ?? '').toString());
      final modelExists = ids.contains(config.model);
      return TestResult(
        ok: true,
        modelExists: modelExists,
        message: modelExists
            ? '连接成功，模型 ${config.model} 可用（服务共 ${ids.length} 个模型）'
            : '连接成功，但模型列表中没有 ${config.model}，请核对模型名',
      );
    } on TimeoutException catch (_) {
      return TestResult(
          ok: false, message: '请求超时（${config.timeoutSec}s），检查网络/代理或调大超时');
    } catch (e) {
      return TestResult(ok: false, message: '网络错误：$e');
    } finally {
      client.close();
    }
  }

  Future<TestResult> _testViaMinimalChat(http.Client client) async {
    try {
      final body = jsonEncode({
        'model': config.model,
        'messages': [
          {'role': 'user', 'content': 'ping'},
        ],
        'max_tokens': 1,
      });
      final resp = await client
          .post(_chatUrl, headers: _headers, body: body)
          .timeout(_timeout);
      if (resp.statusCode == 200) {
        return const TestResult(ok: true, message: '连接成功（对话接口验证通过）');
      }
      if (resp.statusCode == 401 || resp.statusCode == 403) {
        return const TestResult(ok: false, message: '鉴权失败：API Key 无效或无权限');
      }
      if (resp.statusCode == 404) {
        return TestResult(
            ok: false, message: '模型不存在：${_briefBody(resp.body)}');
      }
      return TestResult(
          ok: false, message: '服务返回 ${resp.statusCode}：${_briefBody(resp.body)}');
    } on TimeoutException catch (_) {
      return TestResult(
          ok: false, message: '请求超时（${config.timeoutSec}s），检查网络/代理或调大超时');
    } catch (e) {
      return TestResult(ok: false, message: '网络错误：$e');
    }
  }

  // ──────────────────────────────────────────────────────────
  // 对话补全（各板块 AI 调用的统一入口）
  // ──────────────────────────────────────────────────────────

  /// 发送 chat 请求，返回首个回复的文本内容
  Future<String> chat(
    List<ChatMessage> messages, {
    double? temperature,
    int? maxTokens,
  }) async {
    final client = _createClient();
    try {
      final body = jsonEncode({
        'model': config.model,
        'messages': messages.map((m) => m.toJson()).toList(),
        'temperature': ?temperature,
        'max_tokens': ?maxTokens,
      });
      final resp = await client
          .post(_chatUrl, headers: _headers, body: body)
          .timeout(_timeout);
      if (resp.statusCode != 200) {
        throw _httpError('AI 请求', resp.statusCode, resp.body);
      }
      final data = jsonDecode(resp.body) as Map<String, Object?>;
      final choices = (data['choices'] as List?) ?? [];
      if (choices.isEmpty) throw const FormatException('AI 返回空 choices');
      final message = (choices.first as Map)['message'] as Map?;
      return (message?['content'] ?? '').toString();
    } finally {
      client.close();
    }
  }

  // ──────────────────────────────────────────────────────────
  // 工具
  // ──────────────────────────────────────────────────────────

  Exception _httpError(String action, int status, String body) =>
      Exception('$action失败（HTTP $status）：${_briefBody(body)}');

  static String _briefBody(String body) {
    final b = body.trim();
    return b.length > 200 ? '${b.substring(0, 200)}…' : b;
  }
}
