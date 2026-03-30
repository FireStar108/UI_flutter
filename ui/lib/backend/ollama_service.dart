import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Сервис для общения с Ollama API (localhost:11434)
class OllamaService {
  static final OllamaService _instance = OllamaService._internal();
  factory OllamaService() => _instance;
  OllamaService._internal();

  final String _baseUrl = 'http://localhost:11434';

  /// Получить список доступных моделей
  Future<List<String>> listModels() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/tags'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = (data['models'] as List)
            .map<String>((m) => m['name'] as String)
            .toList();
        return models;
      }
    } catch (e) {
      debugPrint('OLLAMA: Error listing models: $e');
    }
    return [];
  }

  /// Проверить доступность Ollama
  Future<bool> isAvailable() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/tags'))
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Стриминг ответа от модели
  Stream<String> chatStream({
    required String model,
    required List<Map<String, String>> messages,
  }) async* {
    try {
      final client = HttpClient();
      final request = await client.postUrl(Uri.parse('$_baseUrl/api/chat'));
      request.headers.set('Content-Type', 'application/json; charset=utf-8');

      final bodyBytes = utf8.encode(jsonEncode({
        'model': model,
        'messages': messages,
        'stream': true,
      }));
      request.add(bodyBytes);

      final response = await request.close();

      await for (final chunk in response.transform(utf8.decoder)) {
        for (final line in chunk.split('\n')) {
          if (line.trim().isEmpty) continue;
          try {
            final json = jsonDecode(line);
            final content = json['message']?['content'] ?? '';
            if (content.isNotEmpty) {
              yield content;
            }
            if (json['done'] == true) return;
          } catch (_) {}
        }
      }
    } catch (e) {
      yield '\n[Ошибка: $e]';
    }
  }
}
