import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:file_picker/file_picker.dart';
import '../backend/vision_service.dart';

class TerminalSession {
  final String id;
  String name;
  final Terminal terminal;
  Pty? pty;
  final bool isSystem;

  TerminalSession({required this.id, required this.name, required this.terminal, this.pty, this.isSystem = false});
}

class TerminalWindow extends StatefulWidget {
  final Color accentColor;
  final String? initialDirectory;

  const TerminalWindow({super.key, required this.accentColor, this.initialDirectory});

  @override
  State<TerminalWindow> createState() => _TerminalWindowState();
}

class _TerminalWindowState extends State<TerminalWindow> {
  String? _workingDirectory;
  final List<TerminalSession> _sessions = [];
  String? _activeSessionId;

  late final TerminalController _terminalController;

  double _sidebarWidth = 240.0;

  @override
  void initState() {
    super.initState();
    _terminalController = TerminalController();
    _workingDirectory = widget.initialDirectory ?? Platform.environment['HOME'] ?? Directory.current.path;
    _createSystemSession();
    _createNewSession();
  }

  void _createSystemSession() {
    final id = 'system_logs';
    final terminal = Terminal(maxLines: 10000);
    final session = TerminalSession(id: id, name: 'SYSTEM', terminal: terminal, isSystem: true);
    
    VisionService().logStream.listen((text) {
      terminal.write(text);
    });

    terminal.write('--- SYSTEM LOGS STARTED ---\r\n');
    
    setState(() {
      _sessions.add(session);
      if (_activeSessionId == null) _activeSessionId = id;
    });
  }

  @override
  void dispose() {
    for (var session in _sessions) {
      session.pty?.kill();
    }
    super.dispose();
  }

  void _createNewSession([String? customName]) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final name = customName ?? 'Terminal ${_sessions.length + 1}';
    
    final terminal = Terminal(
      maxLines: 10000,
    );
    
    final session = TerminalSession(id: id, name: name, terminal: terminal);
    
    _startPty(session);

    terminal.onOutput = (String data) {
      if (session.isSystem) return;
      session.pty?.write(Uint8List.fromList(utf8.encode(data)));
    };

    terminal.onResize = (int width, int height, int pixelWidth, int pixelHeight) {
      session.pty?.resize(height, width);
    };

    setState(() {
      _sessions.add(session);
      _activeSessionId = id;
    });
  }

  void _startPty(TerminalSession session) {
    if (_workingDirectory == null) return;

    try {
      final shell = Platform.environment['SHELL'] ?? 'bash';
      final pty = Pty.start(
        shell,
        columns: session.terminal.viewWidth,
        rows: session.terminal.viewHeight,
        workingDirectory: _workingDirectory,
      );

      pty.output.cast<List<int>>().transform(const Utf8Decoder(allowMalformed: true)).listen((text) {
        session.terminal.write(text);
      });

      pty.exitCode.then((code) {
        session.terminal.write('\r\n[Process exited with code $code]\r\n');
      });

      session.pty = pty;
    } catch (e) {
      session.terminal.write('\r\n[Error starting PTY: $e]\r\n');
    }
  }

  void _deleteSession(String id) {
    final session = _sessions.firstWhere((s) => s.id == id);
    session.pty?.kill();
    setState(() {
      _sessions.removeWhere((s) => s.id == id);
      if (_activeSessionId == id) {
        _activeSessionId = _sessions.isNotEmpty ? _sessions.first.id : null;
      }
    });

    if (_sessions.isEmpty) {
      _createNewSession();
    }
  }

  Future<void> _pickDirectory() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      setState(() {
        _workingDirectory = selectedDirectory;
      });
      // Optionally create a new session in the new directory
      _createNewSession();
    }
  }

  void _showNewTerminalDialog() {
    final controller = TextEditingController(text: 'Terminal ${_sessions.length + 1}');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Новый терминал', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Имя Терминала',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: widget.accentColor)),
          ),
          autofocus: true,
          onSubmitted: (_) {
            Navigator.pop(context, controller.text);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ОТМЕНА', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('СОЗДАТЬ', style: TextStyle(color: widget.accentColor)),
          ),
        ],
      ),
    ).then((name) {
      if (name != null && name.toString().isNotEmpty) {
        _createNewSession(name.toString());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xff1e1e1e), // VSCode default dark background
      child: Row(
        children: [
          // Sidebar
          SizedBox(
            width: _sidebarWidth,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[900],
                border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
              ),
              child: Column(
                children: [
                  // Toolbar
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        /* Open Directory */
                        IconButton(
                          onPressed: _pickDirectory,
                          icon: const Icon(Icons.folder_open_rounded, color: Colors.white54, size: 20),
                          tooltip: 'Выбрать папку',
                          hoverColor: Colors.white10,
                          splashRadius: 20,
                        ),
                        const Spacer(),
                        /* New Terminal */
                        IconButton(
                          onPressed: _showNewTerminalDialog,
                          icon: Icon(Icons.add_rounded, color: widget.accentColor, size: 24),
                          tooltip: 'Новый терминал',
                          hoverColor: Colors.white10,
                          splashRadius: 20,
                        ),
                      ],
                    ),
                  ),
                  if (_workingDirectory != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _workingDirectory!,
                          style: const TextStyle(color: Colors.white38, fontSize: 10, overflow: TextOverflow.ellipsis),
                          maxLines: 1,
                        ),
                      ),
                    ),
                  const Divider(color: Colors.white10, height: 1),
                  // Session List
                  Expanded(
                    child: ListView.builder(
                      itemCount: _sessions.length,
                      itemBuilder: (context, index) {
                        final session = _sessions[index];
                        final isActive = _activeSessionId == session.id;

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _activeSessionId = session.id;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isActive ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
                              border: Border(
                                left: BorderSide(
                                  color: isActive ? widget.accentColor : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  session.isSystem ? Icons.analytics_outlined : Icons.terminal_rounded, 
                                  size: 16, 
                                  color: isActive ? widget.accentColor : Colors.white54
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    session.name,
                                    style: TextStyle(
                                      color: isActive ? Colors.white : Colors.white60,
                                      fontSize: 12,
                                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (isActive)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          session.terminal.eraseDisplay();
                                          session.terminal.setCursor(0, 0);
                                        },
                                        child: const Icon(Icons.clear_all_rounded, color: Colors.white54, size: 16),
                                      ),
                                      const SizedBox(width: 8),
                                      if (!session.isSystem)
                                        GestureDetector(
                                          onTap: () => _deleteSession(session.id),
                                          child: const Icon(Icons.close_rounded, color: Colors.white54, size: 16),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Resizer
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                _sidebarWidth = (_sidebarWidth + details.delta.dx).clamp(200.0, 400.0);
              });
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: Container(
                width: 4,
                color: Colors.transparent,
                height: double.infinity,
              ),
            ),
          ),

          // Terminal View Area
          Expanded(
            child: _sessions.isEmpty
                ? Center(
                    child: Text(
                      'Нет открытых терминалов',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                    ),
                  )
                : Builder(
                    builder: (context) {
                      final session = _sessions.firstWhere((s) => s.id == _activeSessionId, orElse: () => _sessions.first);
                      return TerminalView(
                        session.terminal,
                        key: ValueKey('TerminalView-${session.id}'),
                        controller: _terminalController,
                        autofocus: true,
                        backgroundOpacity: 0.0,
                        textStyle: const TerminalStyle(
                          fontSize: 13,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
