import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../backend/ollama_service.dart';

class AiChatWindow extends StatefulWidget {
  final Color accentColor;
  const AiChatWindow({super.key, required this.accentColor});

  @override
  State<AiChatWindow> createState() => _AiChatWindowState();
}

class _AiChatWindowState extends State<AiChatWindow> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  
  List<String> _availableModels = [];
  String? _selectedModel;
  bool _isLoading = false;
  bool _ollamaConnected = false;
  StreamSubscription<String>? _streamSub;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _streamSub?.cancel();
    super.dispose();
  }

  Future<void> _loadModels() async {
    final available = await OllamaService().isAvailable();
    if (!available) {
      setState(() => _ollamaConnected = false);
      return;
    }
    final models = await OllamaService().listModels();
    setState(() {
      _ollamaConnected = true;
      _availableModels = models;
      if (models.isNotEmpty && _selectedModel == null) {
        _selectedModel = models.first;
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading || _selectedModel == null) return;

    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _messages.add(ChatMessage(role: 'assistant', content: ''));
      _isLoading = true;
    });
    _messageController.clear();
    _scrollToBottom();

    // Собираем историю для API
    final history = _messages
        .where((m) => m.content.isNotEmpty)
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

    final stream = OllamaService().chatStream(
      model: _selectedModel!,
      messages: history,
    );

    _streamSub = stream.listen(
      (token) {
        setState(() {
          _messages.last.content += token;
        });
        _scrollToBottom();
      },
      onDone: () {
        setState(() => _isLoading = false);
      },
      onError: (e) {
        setState(() {
          _messages.last.content += '\n[Ошибка: $e]';
          _isLoading = false;
        });
      },
    );
  }

  void _clearChat() {
    _streamSub?.cancel();
    setState(() {
      _messages.clear();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xff0d0d0d),
      child: Column(
        children: [
          // Верхняя панель
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xff141414),
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, size: 16, color: widget.accentColor),
                const SizedBox(width: 8),
                const Text('AI Chat', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                // Статус подключения
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _ollamaConnected ? Colors.greenAccent : Colors.redAccent,
                  ),
                ),
                const Spacer(),
                // Кнопка обновления моделей
                IconButton(
                  onPressed: _loadModels,
                  icon: const Icon(Icons.refresh, size: 14, color: Colors.white38),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Обновить модели',
                ),
                const SizedBox(width: 8),
                // Кнопка очистки
                IconButton(
                  onPressed: _clearChat,
                  icon: const Icon(Icons.delete_sweep, size: 14, color: Colors.white38),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Очистить чат',
                ),
                const SizedBox(width: 12),
                // Выбор модели
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedModel,
                      dropdownColor: const Color(0xff1e1e1e),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      icon: const Icon(Icons.expand_more, size: 16, color: Colors.white38),
                      hint: const Text('Нет моделей', style: TextStyle(color: Colors.white24, fontSize: 12)),
                      items: _availableModels.map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(m, overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedModel = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Область сообщений
          Expanded(
            child: !_ollamaConnected
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off, size: 48, color: Colors.white12),
                        const SizedBox(height: 16),
                        const Text('Ollama не подключена', style: TextStyle(color: Colors.white24, fontSize: 14)),
                        const SizedBox(height: 4),
                        const Text('Запустите Ollama и нажмите ↻', style: TextStyle(color: Colors.white12, fontSize: 11)),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: _loadModels,
                          icon: Icon(Icons.refresh, size: 14, color: widget.accentColor),
                          label: Text('Переподключить', style: TextStyle(color: widget.accentColor, fontSize: 12)),
                        ),
                      ],
                    ),
                  )
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome, size: 48, color: widget.accentColor.withValues(alpha: 0.2)),
                            const SizedBox(height: 16),
                            const Text('Начните диалог', style: TextStyle(color: Colors.white24, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text(
                              _selectedModel ?? 'Модель не выбрана',
                              style: const TextStyle(color: Colors.white12, fontSize: 11),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          if (msg.role == 'assistant' && msg.content.isEmpty && _isLoading) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: SizedBox(
                                  width: 24, height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: widget.accentColor.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                            );
                          }
                          final isUser = msg.role == 'user';
                          return Align(
                            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.6),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? widget.accentColor.withValues(alpha: 0.15)
                                    : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isUser
                                      ? widget.accentColor.withValues(alpha: 0.3)
                                      : Colors.white10,
                                ),
                              ),
                              child: SelectableText(
                                msg.content,
                                style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Поле ввода
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xff141414),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: KeyboardListener(
                    focusNode: FocusNode(),
                    onKeyEvent: (event) {
                      if (event is KeyDownEvent && 
                          event.logicalKey == LogicalKeyboardKey.enter &&
                          !HardwareKeyboard.instance.isShiftPressed) {
                        _sendMessage();
                      }
                    },
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      maxLines: 3,
                      minLines: 1,
                      enabled: _ollamaConnected && !_isLoading,
                      decoration: InputDecoration(
                        hintText: _isLoading ? 'Генерация ответа...' : 'Напишите сообщение...',
                        hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                        filled: true,
                        fillColor: Colors.black26,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: widget.accentColor.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isLoading ? null : _sendMessage,
                  icon: Icon(
                    _isLoading ? Icons.hourglass_top : Icons.send_rounded, 
                    color: _isLoading ? Colors.white24 : widget.accentColor,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: widget.accentColor.withValues(alpha: _isLoading ? 0.05 : 0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String role;
  String content;

  ChatMessage({required this.role, required this.content});
}
