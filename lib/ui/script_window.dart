import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:path/path.dart' as p;

// ============================================================
// Модели данных
// ============================================================

class BlockDefinition {
  final String id;
  final String name;
  final String category;
  final Color color;
  final IconData icon;
  final int inputs;
  final int outputs;

  const BlockDefinition({
    required this.id,
    required this.name,
    required this.category,
    required this.color,
    required this.icon,
    this.inputs = 1,
    this.outputs = 1,
  });
}

class ScriptNode {
  final String id;
  final BlockDefinition definition;
  Offset position;

  ScriptNode({
    required this.id,
    required this.definition,
    required this.position,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'typeId': definition.id,
        'px': position.dx,
        'py': position.dy,
      };

  factory ScriptNode.fromMap(Map<String, dynamic> map, List<BlockDefinition> catalog) {
    final typeId = map['typeId'];
    final def = catalog.firstWhere((d) => d.id == typeId, 
        orElse: () => catalog.first); // fallback to something if not found
    return ScriptNode(
      id: map['id'],
      definition: def,
      position: Offset(map['px'], map['py']),
    );
  }
}

class NodeConnection {
  final String id;
  final String fromNodeId;
  final int fromOutputIndex;
  final String toNodeId;
  final int toInputIndex;

  NodeConnection({
    required this.id,
    required this.fromNodeId,
    required this.fromOutputIndex,
    required this.toNodeId,
    required this.toInputIndex,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromNodeId': fromNodeId,
        'fromOutputIndex': fromOutputIndex,
        'toNodeId': toNodeId,
        'toInputIndex': toInputIndex,
      };

  factory NodeConnection.fromJson(Map<String, dynamic> json) {
    return NodeConnection(
      id: json['id'],
      fromNodeId: json['fromNodeId'],
      fromOutputIndex: json['fromOutputIndex'],
      toNodeId: json['toNodeId'],
      toInputIndex: json['toInputIndex'],
    );
  }
}

// ============================================================
// Каталог блоков
// ============================================================

const List<BlockDefinition> kBlockCatalog = [
  BlockDefinition(id: 'start', name: 'Start', category: 'Flow', color: Color(0xFF4CAF50), icon: Icons.play_arrow, inputs: 0, outputs: 1),
  BlockDefinition(id: 'end', name: 'End', category: 'Flow', color: Color(0xFFF44336), icon: Icons.stop, inputs: 1, outputs: 0),
  BlockDefinition(id: 'if_cond', name: 'If / Else', category: 'Logic', color: Color(0xFFFF9800), icon: Icons.call_split, inputs: 1, outputs: 2),
  BlockDefinition(id: 'loop', name: 'Loop', category: 'Logic', color: Color(0xFFFF5722), icon: Icons.loop, inputs: 1, outputs: 1),
  BlockDefinition(id: 'delay', name: 'Delay', category: 'Time', color: Color(0xFF9C27B0), icon: Icons.timer, inputs: 1, outputs: 1),
  BlockDefinition(id: 'log', name: 'Log', category: 'Debug', color: Color(0xFF607D8B), icon: Icons.article, inputs: 1, outputs: 1),
  BlockDefinition(id: 'variable', name: 'Variable', category: 'Data', color: Color(0xFF2196F3), icon: Icons.data_object, inputs: 0, outputs: 1),
  BlockDefinition(id: 'math_add', name: 'Math Add', category: 'Math', color: Color(0xFF00BCD4), icon: Icons.add_circle_outline, inputs: 2, outputs: 1),
  BlockDefinition(id: 'math_mul', name: 'Math Multiply', category: 'Math', color: Color(0xFF009688), icon: Icons.close, inputs: 2, outputs: 1),
  BlockDefinition(id: 'compare', name: 'Compare', category: 'Logic', color: Color(0xFFCDDC39), icon: Icons.compare_arrows, inputs: 2, outputs: 1),
  BlockDefinition(id: 'random', name: 'Random', category: 'Math', color: Color(0xFFE91E63), icon: Icons.casino, inputs: 0, outputs: 1),
  BlockDefinition(id: 'http_req', name: 'HTTP Request', category: 'Network', color: Color(0xFF3F51B5), icon: Icons.http, inputs: 1, outputs: 1),
  BlockDefinition(id: 'file_read', name: 'File Read', category: 'IO', color: Color(0xFF795548), icon: Icons.file_open, inputs: 1, outputs: 1),
  BlockDefinition(id: 'string_concat', name: 'String Join', category: 'Data', color: Color(0xFF00ACC1), icon: Icons.text_fields, inputs: 2, outputs: 1),
];

// ============================================================
// Главный виджет
// ============================================================

class ScriptWindow extends StatefulWidget {
  final Color accentColor;
  final String? projectDirectory;

  const ScriptWindow({super.key, required this.accentColor, this.projectDirectory});

  @override
  State<ScriptWindow> createState() => _ScriptWindowState();
}

class _ScriptWindowState extends State<ScriptWindow> {
  final List<String> _scripts = [];
  String? _activeScript;

  final List<ScriptNode> _nodes = [];
  final List<NodeConnection> _connections = [];
  Offset _canvasOffset = Offset.zero;
  double _canvasScale = 1.0;

  String? _draggingNodeId;
  Offset _dragStart = Offset.zero;
  String? _connectingFromNodeId;
  int? _connectingFromOutput;
  Offset? _connectingEndPoint;

  bool _isShopOpen = true;
  String? _selectedNodeId;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isLeftPanelOpen = true;

  // Для жестов масштабирования
  double _baseScale = 1.0;
  Offset _baseOffset = Offset.zero;

  static const double kNodeWidth = 160;
  static const double kNodeHeight = 80;
  static const double kPinRadius = 7;

  @override
  void initState() {
    super.initState();
    _loadScripts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _scriptsDir {
    final projDir = widget.projectDirectory ?? Directory.current.path;
    return p.join(projDir, 'scripts');
  }

  Future<void> _loadScripts() async {
    final dir = Directory(_scriptsDir);
    if (!await dir.exists()) {
      setState(() => _scripts.clear());
      return;
    }
    final files = await dir.list().where((e) => e is File && e.path.endsWith('.json')).toList();
    setState(() {
      _scripts.clear();
      for (var f in files) {
        _scripts.add(p.basenameWithoutExtension(f.path));
      }
    });

    if (_scripts.isNotEmpty) {
      _openScript(_scripts.first);
    }
  }

  Future<void> _saveCurrentScript() async {
    if (_activeScript == null) return;
    try {
      final file = File(p.join(_scriptsDir, '$_activeScript.json'));
      final data = {
        'nodes': _nodes.map((n) => n.toJson()).toList(),
        'connections': _connections.map((c) => c.toJson()).toList(),
        'offset': {'x': _canvasOffset.dx, 'y': _canvasOffset.dy},
        'scale': _canvasScale,
      };
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      // Silent error
    }
  }

  Future<void> _createNewScript() async {
    final nameCtrl = TextEditingController(text: 'script_${_scripts.length + 1}');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xff2d2d2d),
        title: const Text('Новый скрипт', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.black26,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: widget.accentColor),
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    if (name == null || name.isEmpty) return;

    final dir = Directory(_scriptsDir);
    if (!await dir.exists()) await dir.create(recursive: true);

    final file = File(p.join(_scriptsDir, '$name.json'));
    await file.writeAsString('{"nodes":[],"connections":[],"offset":{"x":0,"y":0},"scale":1.0}');

    setState(() {
      if (!_scripts.contains(name)) _scripts.add(name);
      _activeScript = name;
      _nodes.clear();
      _connections.clear();
      _canvasOffset = Offset.zero;
      _canvasScale = 1.0;
    });
  }

  Future<void> _openScript(String name) async {
    final file = File(p.join(_scriptsDir, '$name.json'));
    if (!await file.exists()) return;

    try {
      final content = await file.readAsString();
      final data = jsonDecode(content);
      
      setState(() {
        _activeScript = name;
        _nodes.clear();
        if (data['nodes'] != null) {
          _nodes.addAll((data['nodes'] as List).map((n) => ScriptNode.fromMap(n, kBlockCatalog)));
        }
        _connections.clear();
        if (data['connections'] != null) {
          _connections.addAll((data['connections'] as List).map((c) => NodeConnection.fromJson(c)));
        }
        if (data['offset'] != null) {
          _canvasOffset = Offset(data['offset']['x'], data['offset']['y']);
        } else {
          _canvasOffset = Offset.zero;
        }
        _canvasScale = data['scale'] ?? 1.0;
        _selectedNodeId = null;
      });
    } catch (e) {
      // Silent error
      setState(() {
        _activeScript = name;
        _nodes.clear();
        _connections.clear();
        _canvasOffset = Offset.zero;
        _canvasScale = 1.0;
        _selectedNodeId = null;
      });
    }
  }

  Future<void> _deleteScript(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xff2d2d2d),
        title: const Text('Удалить скрипт?', style: TextStyle(color: Colors.white)),
        content: Text('Скрипт "$name" будет безвозвратно удален.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final file = File(p.join(_scriptsDir, '$name.json'));
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      setState(() {
        _scripts.remove(name);
        if (_activeScript == name) {
          _activeScript = null;
          _nodes.clear();
          _connections.clear();
          _selectedNodeId = null;
        }
      });
    }
  }

  void _addNodeToCanvas(BlockDefinition def, Offset position) {
    final worldPos = _screenToWorld(position);
    setState(() {
      final newNodeId = '${def.id}_${DateTime.now().millisecondsSinceEpoch}';
      _nodes.add(ScriptNode(
        id: newNodeId,
        definition: def,
        position: worldPos,
      ));
      _selectedNodeId = newNodeId;
    });
    _saveCurrentScript();
  }

  void _removeNode(String nodeId) {
    setState(() {
      _nodes.removeWhere((n) => n.id == nodeId);
      _connections.removeWhere((c) => c.fromNodeId == nodeId || c.toNodeId == nodeId);
      if (_selectedNodeId == nodeId) _selectedNodeId = null;
    });
    _saveCurrentScript();
  }



  Offset _screenToWorld(Offset screen) {
    return (screen - _canvasOffset) / _canvasScale;
  }

  Offset _worldToScreen(Offset world) {
    return world * _canvasScale + _canvasOffset;
  }

  Offset _getOutputPinWorld(ScriptNode node, int index) {
    final y = node.position.dy + kNodeHeight / 2 +
        (index - (node.definition.outputs - 1) / 2.0) * 24;
    return Offset(node.position.dx + kNodeWidth, y);
  }

  Offset _getInputPinWorld(ScriptNode node, int index) {
    final y = node.position.dy + kNodeHeight / 2 +
        (index - (node.definition.inputs - 1) / 2.0) * 24;
    return Offset(node.position.dx, y);
  }

  String? _hitTestOutputPin(Offset worldPos) {
    for (final node in _nodes) {
      for (int i = 0; i < node.definition.outputs; i++) {
        final pinPos = _getOutputPinWorld(node, i);
        if ((worldPos - pinPos).distance < kPinRadius + 4) {
          _connectingFromOutput = i;
          return node.id;
        }
      }
    }
    return null;
  }

  (String, int)? _hitTestInputPin(Offset worldPos) {
    for (final node in _nodes) {
      for (int i = 0; i < node.definition.inputs; i++) {
        final pinPos = _getInputPinWorld(node, i);
        if ((worldPos - pinPos).distance < kPinRadius + 4) {
          return (node.id, i);
        }
      }
    }
    return null;
  }

  String? _hitTestNode(Offset worldPos) {
    for (final node in _nodes.reversed) {
      final rect = Rect.fromLTWH(node.position.dx, node.position.dy, kNodeWidth, kNodeHeight);
      if (rect.contains(worldPos)) {
        return node.id;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xff1a1a1a),
      child: Row(
        children: [
          if (_isLeftPanelOpen) _buildLeftPanel(),
          Expanded(
            child: _activeScript == null
                ? _buildEmptyCanvas()
                : _buildCanvas(),
          ),
          if (_activeScript != null && (_isShopOpen || _selectedNodeId != null))
            _buildRightPanel(),
        ],
      ),
    );
  }

  Widget _buildRightPanel() {
    if (_selectedNodeId != null) return _buildSettingsPanel();
    return _buildShopPanel();
  }

  Widget _buildSettingsPanel() {
    final node = _nodes.firstWhere((n) => n.id == _selectedNodeId, orElse: () => _nodes.first);
    return Container(
      width: 220,
      decoration: const BoxDecoration(color: Color(0xff141414), border: Border(left: BorderSide(color: Colors.white10))),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.settings, color: node.definition.color, size: 18),
                const SizedBox(width: 8),
                const Expanded(child: Text('Настройки', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold))),
                InkWell(onTap: () => setState(() => _selectedNodeId = null), child: const Icon(Icons.close, color: Colors.white38, size: 18)),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(node.definition.name, style: TextStyle(color: node.definition.color, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('ID: ${node.id}', style: const TextStyle(color: Colors.white24, fontSize: 10)),
                const SizedBox(height: 24),
                const Center(child: Text('Меню настроек пусто', style: TextStyle(color: Colors.white38, fontSize: 12))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftPanel() {
    return Container(
      width: 180,
      decoration: const BoxDecoration(
        color: Color(0xff141414),
        border: Border(right: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.folder_open, color: widget.accentColor, size: 18),
                const SizedBox(width: 8),
                const Expanded(child: Text('Скрипты', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold))),
                InkWell(
                  onTap: () => setState(() => _isLeftPanelOpen = false),
                  child: const Icon(Icons.chevron_left, color: Colors.white38, size: 18),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: InkWell(
              onTap: _createNewScript,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: widget.accentColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: widget.accentColor, size: 16),
                    const SizedBox(width: 6),
                    Text('New Script', style: TextStyle(color: widget.accentColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _scripts.length,
              itemBuilder: (_, i) {
                final name = _scripts[i];
                final isActive = name == _activeScript;
                return InkWell(
                  onTap: () => _openScript(name),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive ? widget.accentColor.withValues(alpha: 0.1) : Colors.transparent,
                      border: Border(left: BorderSide(color: isActive ? widget.accentColor : Colors.transparent, width: 3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.description, color: isActive ? widget.accentColor : Colors.white38, size: 14),
                        const SizedBox(width: 8),
                        Expanded(child: Text(name, style: TextStyle(color: isActive ? Colors.white : Colors.white54, fontSize: 12, fontWeight: isActive ? FontWeight.bold : FontWeight.normal), overflow: TextOverflow.ellipsis)),
                        if (isActive) 
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _deleteScript(name),
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
    );
  }

  Widget _buildEmptyCanvas() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_isLeftPanelOpen)
            IconButton(onPressed: () => setState(() => _isLeftPanelOpen = true), icon: const Icon(Icons.menu, color: Colors.white38)),
          Icon(Icons.account_tree_outlined, color: Colors.white12, size: 64),
          const SizedBox(height: 16),
          const Text('Создайте или выберите скрипт', style: TextStyle(color: Colors.white24, fontSize: 14)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _createNewScript,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New Script'),
            style: ElevatedButton.styleFrom(backgroundColor: widget.accentColor.withValues(alpha: 0.2), foregroundColor: widget.accentColor),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          final zoomDelta = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
          setState(() {
            final oldScale = _canvasScale;
            _canvasScale = (_canvasScale * zoomDelta).clamp(0.2, 3.0);
            final focalScreen = event.localPosition;
            _canvasOffset = focalScreen - (focalScreen - _canvasOffset) * (_canvasScale / oldScale);
          });
          _saveCurrentScript();
        }
      },
      child: GestureDetector(
        onScaleStart: (details) {
          _baseScale = _canvasScale;
          _baseOffset = _canvasOffset;

          final worldPos = _screenToWorld(details.localFocalPoint);
          final fromNode = _hitTestOutputPin(worldPos);
          if (fromNode != null) {
            _connectingFromNodeId = fromNode;
            _connectingEndPoint = details.localFocalPoint;
            return;
          }
          // Проверяем, попали ли на ноду
          final nodeId = _hitTestNode(worldPos);
          if (nodeId != null) {
            _draggingNodeId = nodeId;
            _dragStart = details.localFocalPoint;
            setState(() => _selectedNodeId = nodeId);
            final idx = _nodes.indexWhere((n) => n.id == nodeId);
            if (idx >= 0) {
              final node = _nodes.removeAt(idx);
              _nodes.add(node);
            }
            return;
          }
          setState(() => _selectedNodeId = null);
          _dragStart = details.localFocalPoint;
        },
        onScaleUpdate: (details) {
          setState(() {
            if (_connectingFromNodeId != null) {
              _connectingEndPoint = details.localFocalPoint;
            } else if (_draggingNodeId != null) {
              // Перетаскивание ноды
              final delta = (details.localFocalPoint - _dragStart) / _canvasScale;
              final node = _nodes.firstWhere((n) => n.id == _draggingNodeId);
              node.position += delta;
              _dragStart = details.localFocalPoint;
            } else if (details.pointerCount > 1) {
              // Пинч-зум
              _canvasScale = (_baseScale * details.scale).clamp(0.2, 3.0);
              final focalScreen = details.localFocalPoint;
              _canvasOffset = focalScreen - (focalScreen - _baseOffset) * (_canvasScale / _baseScale);
            } else {
              // Пан холста
              _canvasOffset += details.localFocalPoint - _dragStart;
              _dragStart = details.localFocalPoint;
            }
          });
        },
        onScaleEnd: (details) {
          if (_connectingFromNodeId != null && _connectingEndPoint != null) {
            final worldPos = _screenToWorld(_connectingEndPoint!);
            final hit = _hitTestInputPin(worldPos);
            if (hit != null && hit.$1 != _connectingFromNodeId) {
              final exists = _connections.any((c) =>
                  c.fromNodeId == _connectingFromNodeId &&
                  c.fromOutputIndex == _connectingFromOutput &&
                  c.toNodeId == hit.$1 &&
                  c.toInputIndex == hit.$2);
              if (!exists) {
                setState(() {
                  _connections.add(NodeConnection(
                    id: 'conn_${DateTime.now().millisecondsSinceEpoch}',
                    fromNodeId: _connectingFromNodeId!,
                    fromOutputIndex: _connectingFromOutput ?? 0,
                    toNodeId: hit.$1,
                    toInputIndex: hit.$2,
                  ));
                });
              }
            }
          }
          _connectingFromNodeId = null;
          _connectingFromOutput = null;
          _connectingEndPoint = null;
          _draggingNodeId = null;
          _saveCurrentScript();
        },
        child: ClipRect(
          child: Stack(
            children: [
              CustomPaint(
                painter: _CanvasPainter(
                  nodes: _nodes,
                  connections: _connections,
                  offset: _canvasOffset,
                  scale: _canvasScale,
                  connectingFromNodeId: _connectingFromNodeId,
                  connectingFromOutput: _connectingFromOutput,
                  connectingEndScreen: _connectingEndPoint,
                  getOutputPinWorld: _getOutputPinWorld,
                  getInputPinWorld: _getInputPinWorld,
                  worldToScreen: _worldToScreen,
                ),
                child: Container(color: Colors.transparent),
              ),
              Positioned(
                top: 8, left: 8,
                child: Row(
                  children: [
                    if (!_isLeftPanelOpen) _canvasButton(Icons.menu, () => setState(() => _isLeftPanelOpen = true)),
                    _canvasButton(Icons.center_focus_strong, () { 
                      setState(() { 
                        _canvasOffset = Offset.zero; 
                        _canvasScale = 1.0; 
                      }); 
                      _saveCurrentScript(); 
                    }),
                    const SizedBox(width: 4),
                    _canvasButton(_isShopOpen ? Icons.storefront : Icons.storefront_outlined, () => setState(() { _isShopOpen = !_isShopOpen; if (_isShopOpen) _selectedNodeId = null; })),
                  ],
                ),
              ),
              // Кнопка удаления выбранной ноды
              if (_selectedNodeId != null)
                Positioned(
                  top: 8, right: 8,
                  child: _canvasButton(Icons.delete_forever, () => _removeNode(_selectedNodeId!), color: Colors.redAccent),
                ),
              // Индикатор масштаба и Ползунок
              Positioned(
                bottom: 8, left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white10)),
                  child: Row(
                    children: [
                      Text('${(_canvasScale * 100).toInt()}%', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 120,
                        height: 20,
                        child: SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                            activeTrackColor: widget.accentColor,
                            inactiveTrackColor: Colors.white10,
                            thumbColor: Colors.white,
                          ),
                          child: Slider(
                            value: _canvasScale,
                            min: 0.2,
                            max: 3.0,
                            onChanged: (v) {
                              setState(() {
                                // При зуме ползунком зумим в центр экрана
                                final center = context.size != null 
                                    ? Offset(context.size!.width / 2, context.size!.height / 2)
                                    : Offset.zero;
                                final oldScale = _canvasScale;
                                _canvasScale = v;
                                _canvasOffset = center - (center - _canvasOffset) * (_canvasScale / oldScale);
                              });
                              _saveCurrentScript();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _canvasButton(IconData icon, VoidCallback onTap, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white10)),
          child: Icon(icon, color: color ?? Colors.white54, size: 16),
        ),
      ),
    );
  }

  Widget _buildShopPanel() {
    final filtered = _searchQuery.isEmpty ? kBlockCatalog : kBlockCatalog.where((b) => b.name.toLowerCase().contains(_searchQuery.toLowerCase()) || b.category.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    final Map<String, List<BlockDefinition>> grouped = {};
    for (final b in filtered) { grouped.putIfAbsent(b.category, () => []).add(b); }
    return Container(
      width: 220,
      decoration: const BoxDecoration(color: Color(0xff141414), border: Border(left: BorderSide(color: Colors.white10))),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.storefront, color: widget.accentColor, size: 18),
                const SizedBox(width: 8),
                const Expanded(child: Text('Блоки', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold))),
                InkWell(onTap: () => setState(() => _isShopOpen = false), child: const Icon(Icons.chevron_right, color: Colors.white38, size: 18)),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Поиск...', hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                prefixIcon: const Icon(Icons.search, color: Colors.white24, size: 16),
                filled: true, fillColor: Colors.black26, contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none), isDense: true,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: grouped.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(padding: const EdgeInsets.only(top: 8, bottom: 4, left: 4), child: Text(entry.key.toUpperCase(), style: TextStyle(color: widget.accentColor.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1))),
                    ...entry.value.map((def) => _buildShopItem(def)),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopItem(BlockDefinition def) {
    return Draggable<BlockDefinition>(
      data: def,
      feedback: Material(color: Colors.transparent, child: _buildNodePreview(def)),
      childWhenDragging: Opacity(opacity: 0.3, child: _buildShopCard(def)),
      onDragEnd: (details) {
        final renderBox = context.findRenderObject() as RenderBox;
        final localPos = renderBox.globalToLocal(details.offset);
        _addNodeToCanvas(def, localPos);
      },
      child: _buildShopCard(def),
    );
  }

  Widget _buildShopCard(BlockDefinition def) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: def.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: def.color.withValues(alpha: 0.2))),
      child: Row(
        children: [
          Icon(def.icon, color: def.color, size: 16), const SizedBox(width: 8),
          Expanded(child: Text(def.name, style: TextStyle(color: def.color, fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
          Icon(Icons.drag_indicator, color: def.color.withValues(alpha: 0.4), size: 14),
        ],
      ),
    );
  }

  Widget _buildNodePreview(BlockDefinition def) {
    return Container(
      width: kNodeWidth, height: kNodeHeight,
      decoration: BoxDecoration(color: const Color(0xff222222), borderRadius: BorderRadius.circular(8), border: Border.all(color: def.color, width: 2), boxShadow: [BoxShadow(color: def.color.withValues(alpha: 0.3), blurRadius: 12)]),
      child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(def.icon, color: def.color, size: 20), const SizedBox(width: 8), Text(def.name, style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))])),
    );
  }
}

class _CanvasPainter extends CustomPainter {
  final List<ScriptNode> nodes;
  final List<NodeConnection> connections;
  final Offset offset;
  final double scale;
  final String? connectingFromNodeId;
  final int? connectingFromOutput;
  final Offset? connectingEndScreen;
  final Offset Function(ScriptNode, int) getOutputPinWorld;
  final Offset Function(ScriptNode, int) getInputPinWorld;
  final Offset Function(Offset) worldToScreen;

  _CanvasPainter({
    required this.nodes, required this.connections, required this.offset, required this.scale,
    this.connectingFromNodeId, this.connectingFromOutput, this.connectingEndScreen,
    required this.getOutputPinWorld, required this.getInputPinWorld, required this.worldToScreen,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);
    for (final conn in connections) {
      final fromNode = nodes.where((n) => n.id == conn.fromNodeId).firstOrNull;
      final toNode = nodes.where((n) => n.id == conn.toNodeId).firstOrNull;
      if (fromNode == null || toNode == null) continue;
      _drawConnection(canvas, getOutputPinWorld(fromNode, conn.fromOutputIndex), getInputPinWorld(toNode, conn.toInputIndex), fromNode.definition.color);
    }
    for (final node in nodes) { _drawNode(canvas, node); }
    canvas.restore();

    if (connectingFromNodeId != null && connectingEndScreen != null) {
      final fromNode = nodes.where((n) => n.id == connectingFromNodeId).firstOrNull;
      if (fromNode != null) {
        _drawConnectionScreen(canvas, worldToScreen(getOutputPinWorld(fromNode, connectingFromOutput ?? 0)), connectingEndScreen!, fromNode.definition.color);
      }
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.05)..strokeWidth = 0.5;
    final paintThick = Paint()..color = Colors.white.withValues(alpha: 0.08)..strokeWidth = 1.0;
    
    const double spacing = 40.0;
    final double scaledSpacing = spacing * scale;
    
    final double startX = offset.dx % scaledSpacing;
    final double startY = offset.dy % scaledSpacing;

    // Вертикальные линии
    for (double x = startX; x < size.width; x += scaledSpacing) {
      // Каждая 5-я линия толще
      final bool isMajor = (((x - offset.dx) / scaledSpacing).round() % 5 == 0);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), isMajor ? paintThick : paint);
    }

    // Горизонтальные линии
    for (double y = startY; y < size.height; y += scaledSpacing) {
      final bool isMajor = (((y - offset.dy) / scaledSpacing).round() % 5 == 0);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), isMajor ? paintThick : paint);
    }
  }

  void _drawNode(Canvas canvas, ScriptNode node) {
    final rect = Rect.fromLTWH(node.position.dx, node.position.dy, _ScriptWindowState.kNodeWidth, _ScriptWindowState.kNodeHeight);
    final color = node.definition.color;
    canvas.drawRRect(RRect.fromRectAndRadius(rect.inflate(2), const Radius.circular(8)), Paint()..color = color.withValues(alpha: 0.15)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), Paint()..color = const Color(0xff222222));
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), Paint()..style = PaintingStyle.stroke..color = color..strokeWidth = 1.5);
    canvas.drawRRect(RRect.fromRectAndCorners(Rect.fromLTWH(rect.left, rect.top, rect.width, 24), topLeft: const Radius.circular(8), topRight: const Radius.circular(8)), Paint()..color = color.withValues(alpha: 0.3));
    TextPainter(text: TextSpan(text: node.definition.name, style: TextStyle(color: Colors.white, fontSize: 11 / scale.clamp(0.5, 1.5), fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)..layout(maxWidth: rect.width - 16)..paint(canvas, Offset(rect.left + 8, rect.top + 5));
    for (int i = 0; i < node.definition.inputs; i++) { _drawPin(canvas, Offset(node.position.dx, node.position.dy + _ScriptWindowState.kNodeHeight / 2 + (i - (node.definition.inputs - 1) / 2.0) * 24), color, true); }
    for (int i = 0; i < node.definition.outputs; i++) { _drawPin(canvas, Offset(node.position.dx + _ScriptWindowState.kNodeWidth, node.position.dy + _ScriptWindowState.kNodeHeight / 2 + (i - (node.definition.outputs - 1) / 2.0) * 24), color, false); }
  }

  void _drawPin(Canvas canvas, Offset pos, Color color, bool isInput) {
    canvas.drawCircle(pos, _ScriptWindowState.kPinRadius, Paint()..color = const Color(0xff333333));
    canvas.drawCircle(pos, _ScriptWindowState.kPinRadius - 2, Paint()..color = color);
    canvas.drawCircle(pos, _ScriptWindowState.kPinRadius, Paint()..style = PaintingStyle.stroke..color = color.withValues(alpha: 0.7)..strokeWidth = 1);
  }

  void _drawConnection(Canvas canvas, Offset start, Offset end, Color color) {
    final paint = Paint()..color = color.withValues(alpha: 0.7)..strokeWidth = 2.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final path = Path();
    final dx = (end.dx - start.dx).abs() * 0.5;
    path.moveTo(start.dx, start.dy);
    path.cubicTo(start.dx + dx, start.dy, end.dx - dx, end.dy, end.dx, end.dy);
    canvas.drawPath(path, paint);
    _drawArrow(canvas, start, end, color);
  }

  void _drawConnectionScreen(Canvas canvas, Offset start, Offset end, Color color) {
    final paint = Paint()..color = color.withValues(alpha: 0.5)..strokeWidth = 2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final path = Path();
    final dx = (end.dx - start.dx).abs() * 0.4;
    path.moveTo(start.dx, start.dy);
    path.cubicTo(start.dx + dx, start.dy, end.dx - dx, end.dy, end.dx, end.dy);
    canvas.drawPath(path, paint);
  }

  void _drawArrow(Canvas canvas, Offset start, Offset end, Color color) {
    final dx = (end.dx - start.dx).abs() * 0.5;
    const t = 0.85; final t1 = 1 - t;
    final midX = t1 * t1 * t1 * start.dx + 3 * t1 * t1 * t * (start.dx + dx) + 3 * t1 * t * t * (end.dx - dx) + t * t * t * end.dx;
    final midY = t1 * t1 * t1 * start.dy + 3 * t1 * t1 * t * start.dy + 3 * t1 * t * t * end.dy + t * t * t * end.dy;
    final angle = math.atan2(end.dy - midY, end.dx - midX);
    const arrowSize = 8.0;
    final arrowPath = Path();
    arrowPath.moveTo(end.dx, end.dy);
    arrowPath.lineTo(end.dx - arrowSize * math.cos(angle - 0.4), end.dy - arrowSize * math.sin(angle - 0.4));
    arrowPath.moveTo(end.dx, end.dy);
    arrowPath.lineTo(end.dx - arrowSize * math.cos(angle + 0.4), end.dy - arrowSize * math.sin(angle + 0.4));
    canvas.drawPath(arrowPath, Paint()..color = color.withValues(alpha: 0.7)..strokeWidth = 2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _CanvasPainter old) => true;
}
