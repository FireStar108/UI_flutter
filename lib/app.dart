import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ui/grid_background.dart';
import 'ui/window_item.dart';
import 'ui/taskbar.dart';
import 'ui/project_manager_dialog.dart';
import 'ui/flying_window.dart';
import 'ui/exploding_window.dart';
import 'core/grid_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'dart:convert';


class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final List<WindowData> _windows = [];
  final List<WindowData> _minimizedWindows = [];
  final List<Widget> _flyingAnimations = [];
  bool _isShiftPressed = false;
  bool _isAddPanelVisible = false; // Состояние панели выбора окон
  bool _isSettingsPanelVisible = false; // Состояние панели настроек
  GridMode _currentGridMode = GridMode.system;
  GridMetadata? _customGridMetadata;
  Offset? _previewPosition;
  Size? _previewSize;

  @override
  void initState() {
    super.initState();
    _loadGridMode();
  }

  Future<void> _loadGridMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt('grid_mode') ?? 0;
    
    // Загрузка кастомных метаданных из JSON
    final customMetaJson = prefs.getString('custom_grid_metadata');
    GridMetadata? customMeta;
    if (customMetaJson != null) {
      try {
        final map = jsonDecode(customMetaJson);
        customMeta = GridMetadata.fromJson(map);
      } catch (e) {
        debugPrint('Error loading grid metadata: $e');
      }
    }

    if (mounted) {
      setState(() {
        _currentGridMode = GridMode.values[modeIndex];
        _customGridMetadata = customMeta;
      });
    }
  }

  Future<void> _saveGridMode(GridMode mode, GridMetadata? metadata) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('grid_mode', mode.index);
    if (metadata != null) {
      await prefs.setString('custom_grid_metadata', jsonEncode(metadata.toJson()));
    }
  }

  void _addWindow(String type, BuildContext buttonContext) {
    // Временно определяем свойства нового окна
    final newWindow = WindowData(
      id: DateTime.now().toString(),
      type: type,
      relativePosition: const Offset(0.1, 0.1),
      relativeSize: type == 'viewport_cam' 
          ? const Size(0.4, 0.5) // Начальный размер для камеры (ширина, высота - в долях от экрана 0..1)
          : type == 'settings_grid'
              ? const Size(0.4, 0.5) // Начальный размер для настроек сетки
              : type == 'file_browser'
                  ? const Size(0.4, 0.5) // Начальный размер для файлового браузера
                  : const Size(0.4, 0.4),
      color: type == 'settings_grid' 
          ? Colors.orangeAccent 
          : type == 'file_browser'
              ? Colors.greenAccent
              : type == 'terminal'
                  ? Colors.purpleAccent
                  : Colors.blueAccent,
    );

    setState(() {
      _isAddPanelVisible = false; // Закрываем панели после выбора
      _isSettingsPanelVisible = false;

      // Получаем размеры области (экран)
      final size = MediaQuery.of(context).size;
      final areaSize = Size(size.width, size.height - 60);

      // Координаты старта
      final box = buttonContext.findRenderObject() as RenderBox?;
      Rect startRect;
      if (box != null) {
        final position = box.localToGlobal(Offset.zero);
        startRect = Rect.fromLTWH(position.dx, position.dy, box.size.width, box.size.height);
      } else {
        startRect = Rect.fromLTWH(size.width - 200, 10, 48, 48);
      }

      final endRect = Rect.fromLTWH(
        newWindow.relativePosition.dx * areaSize.width,
        newWindow.relativePosition.dy * areaSize.height + 60.0,
        newWindow.relativeSize.width * areaSize.width,
        newWindow.relativeSize.height * areaSize.height,
      );

      final key = GlobalKey();
      newWindow.isFlying = true;
      _windows.add(newWindow); // Сразу добавляем, но оно будет Offstage

      _flyingAnimations.add(
        FlyingWindow(
          key: key,
          data: newWindow,
          startRect: startRect,
          endRect: endRect,
          isMinimizing: false,
          onComplete: () {
            setState(() {
              _flyingAnimations.removeWhere((anim) => anim.key == key);
              newWindow.isFlying = false;
            });
          },
        ),
      );
    });
  }

  void _toggleAddPanel() {
    setState(() {
      _isAddPanelVisible = !_isAddPanelVisible;
      if (_isAddPanelVisible) _isSettingsPanelVisible = false;
    });
  }

  void _toggleSettingsPanel() {
    setState(() {
      _isSettingsPanelVisible = !_isSettingsPanelVisible;
      if (_isSettingsPanelVisible) _isAddPanelVisible = false;
    });
  }

  void _removeWindow(String id) {
    setState(() {
      // Ищем окно в активных
      try {
        final w = _windows.firstWhere((w) => w.id == id);
        _windows.remove(w);

        // Расчитываем текущую позицию
        final size = MediaQuery.of(context).size;
        final areaSize = Size(size.width, size.height - 60);
        final startRect = Rect.fromLTWH(
          w.relativePosition.dx * areaSize.width,
          w.relativePosition.dy * areaSize.height + 60.0,
          w.relativeSize.width * areaSize.width,
          w.relativeSize.height * areaSize.height,
        );

        final key = GlobalKey();
        _flyingAnimations.add(
          ExplodingWindow(
            key: key,
            data: w,
            startRect: startRect,
            onComplete: () {
              setState(() {
                _flyingAnimations.removeWhere((anim) => anim.key == key);
              });
            },
          ) as Widget,
        );
      } catch (e) {
        // Если окно уже было минимизировано
        try {
          final w = _minimizedWindows.firstWhere((w) => w.id == id);
          final index = _minimizedWindows.indexOf(w);
          w.isClosing = true; // Помечаем, чтобы скрыть из таскбара плавно

          final startRect = Rect.fromLTWH(180.0 + index * 150.0, 6.0, 140, 48);

          final key = GlobalKey();
          _flyingAnimations.add(
            ExplodingWindow(
              key: key,
              data: w,
              startRect: startRect,
              onComplete: () {
                setState(() {
                  _flyingAnimations.removeWhere((anim) => anim.key == key);
                  _minimizedWindows.remove(w); // Окончательно удаляем после взрыва
                });
              },
            ) as Widget,
          );
        } catch (_) {}
      }
    });
  }

  void _focusWindow(WindowData w) {
    if (_windows.isNotEmpty && _windows.last.id != w.id && _windows.contains(w)) {
      setState(() {
        _windows.remove(w);
        _windows.add(w);
      });
    }
  }

  void _minimizeWindow(WindowData w, Size areaSize) {
    setState(() {
      _focusWindow(w);
      w.isFlying = true;

      // Начальные координаты относительно экрана (добавляем 60px высоту панели)
      final startRect = Rect.fromLTWH(
        w.relativePosition.dx * areaSize.width,
        w.relativePosition.dy * areaSize.height + 60.0,
        w.relativeSize.width * areaSize.width,
        w.relativeSize.height * areaSize.height,
      );
      // Приблизительная позиция в Taskbar в верхней панели
      final endRect = Rect.fromLTWH(180.0 + _minimizedWindows.length * 150.0, 6.0, 140, 48);

      final key = GlobalKey();
      _flyingAnimations.add(
        FlyingWindow(
          key: key,
          data: w,
          startRect: startRect,
          endRect: endRect,
          isMinimizing: true,
          onComplete: () {
            setState(() {
              _flyingAnimations.removeWhere((anim) => anim.key == key);
              w.isFlying = false;
              w.isMinimized = true;
              _windows.remove(w);
              _minimizedWindows.add(w);
            });
          },
        ),
      );
    });
  }

  void _restoreWindow(WindowData w, Size areaSize) {
    setState(() {
      final index = _minimizedWindows.indexOf(w);
      _minimizedWindows.remove(w);
      _windows.add(w);
      w.isMinimized = false;
      w.isFlying = true;

      final startRect = Rect.fromLTWH(180.0 + index * 150.0, 6.0, 140, 48);
      // Конечные координаты (добавляем 60px высоту панели)
      final endRect = Rect.fromLTWH(
        w.relativePosition.dx * areaSize.width,
        w.relativePosition.dy * areaSize.height + 60.0,
        w.relativeSize.width * areaSize.width,
        w.relativeSize.height * areaSize.height,
      );

      final key = GlobalKey();
      _flyingAnimations.add(
        FlyingWindow(
          key: key,
          data: w,
          startRect: startRect,
          endRect: endRect,
          isMinimizing: false,
          onComplete: () {
            setState(() {
              _flyingAnimations.removeWhere((anim) => anim.key == key);
              w.isFlying = false;
            });
          },
        ),
      );
    });
  }

  void _onReorderMinimized(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final WindowData item = _minimizedWindows.removeAt(oldIndex);
      _minimizedWindows.insert(newIndex, item);
    });
  }


  void _handlePanUpdate(WindowData data, DragUpdateDetails details, Size areaSize) {
    _focusWindow(data);
    setState(() {
      // Конвертируем дельту из пикселей в относительные координаты
      final relativeDelta = Offset(
        details.delta.dx / areaSize.width,
        details.delta.dy / areaSize.height,
      );
      data.relativePosition += relativeDelta;
      
      if (_isShiftPressed) {
        _calculateSnapPreview(details.globalPosition, areaSize);
      } else {
        _previewPosition = null;
        _previewSize = null;
      }
    });
  }

  void _handleResizeUpdate(WindowData data, Offset delta, Size areaSize) {
    _focusWindow(data);
    setState(() {
      final relativeDeltaX = delta.dx / areaSize.width;
      final relativeDeltaY = delta.dy / areaSize.height;

      data.relativeSize = Size(
        math.max(0.25, data.relativeSize.width + relativeDeltaX), // 0.25 - это минимальная ширина окна (25% от экрана)
        math.max(0.25, data.relativeSize.height + relativeDeltaY), // 0.25 - это минимальная высота окна
      );
    });
  }

  void _calculateSnapPreview(Offset cursorPosition, Size areaSize) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localCursor = renderBox.globalToLocal(cursorPosition);

    final metadata = GridMetadata.fromMode(_currentGridMode, customData: _customGridMetadata);
    final cells = metadata.computeCells();

    final normalizedCursor = Offset(
      localCursor.dx / areaSize.width,
      localCursor.dy / areaSize.height,
    );

    // Константа отступа
    const double gap = 3.0;
    
    GridCell? targetCell;
    for (var cell in cells) {
      if (cell.rect.contains(normalizedCursor)) {
        targetCell = cell;
        break;
      }
    }

    if (targetCell != null) {
      final double relativeGapX = gap / areaSize.width;
      final double relativeGapY = gap / areaSize.height;

      _previewPosition = Offset(
        targetCell.rect.left + relativeGapX,
        targetCell.rect.top + relativeGapY,
      );
      _previewSize = Size(
        targetCell.rect.width - 2 * relativeGapX,
        targetCell.rect.height - 2 * relativeGapY,
      );
    } else {
      _previewPosition = null;
      _previewSize = null;
    }
  }

  void _handlePanEnd(WindowData data) {
    setState(() {
      if (_isShiftPressed && _previewPosition != null && _previewSize != null) {
        data.relativePosition = _previewPosition!;
        data.relativeSize = _previewSize!;
      }
      _previewPosition = null;
      _previewSize = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UI App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
      home: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          final isShift = HardwareKeyboard.instance.isShiftPressed;
          if (_isShiftPressed != isShift) {
            setState(() {
              _isShiftPressed = isShift;
              if (!_isShiftPressed) {
                _previewPosition = null;
                _previewSize = null;
              }
            });
          }
          return KeyEventResult.ignored; // Позволяем событиям идти дальше
        },
        child: Scaffold(
          body: Stack(
            children: [
              Column(
                children: [
                  // Верхняя плашка
                  Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  border: Border(bottom: BorderSide(color: Colors.white10, width: 1)),
                ),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          barrierDismissible: true,
                          builder: (context) => const ProjectManagerDialog(),
                        );
                      },
                      icon: const Icon(Icons.account_tree_outlined, color: Colors.blueAccent, size: 20),
                      label: const Text('PROJECTS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 24),
                    const Text(
                      'UI Workspace',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(width: 24),
                    // Панель задач здесь
                    Expanded(
                      child: Taskbar(
                        minimizedWindows: _minimizedWindows,
                        onReorder: _onReorderMinimized,
                        onRestore: (w) {
                          // Мы не можем получить workAreaSize напрямую тут,
                          // Поэтому используем MediaQuery и вычитаем 60px верхней панели
                          final size = MediaQuery.of(context).size;
                          final workAreaSize = Size(size.width, size.height - 60);
                          _restoreWindow(w, workAreaSize);
                        },
                        onClose: _removeWindow,
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _toggleSettingsPanel,
                      icon: Icon(_isSettingsPanelVisible ? Icons.close : Icons.settings),
                      label: const Text('Настройки'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isSettingsPanelVisible ? Colors.redAccent.withValues(alpha: 0.2) : Colors.white10,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _toggleAddPanel,
                      icon: Icon(_isAddPanelVisible ? Icons.close : Icons.add),
                      label: const Text('Добавить окно'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isAddPanelVisible ? Colors.redAccent.withValues(alpha: 0.2) : Colors.white10,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
              // Рабочая область
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final workAreaSize = Size(constraints.maxWidth, constraints.maxHeight);
                    
                    return Stack(
                      children: [
                        // Сетка
                        Container(
                          color: Colors.grey[900],
                          child: Stack(
                            children: [
                               GridBackground(mode: _currentGridMode, customMetadata: _customGridMetadata),
                              if (_previewPosition != null && _previewSize != null)
                                Positioned(
                                  left: _previewPosition!.dx * workAreaSize.width,
                                  top: _previewPosition!.dy * workAreaSize.height,
                                  child: Container(
                                    width: _previewSize!.width * workAreaSize.width,
                                    height: _previewSize!.height * workAreaSize.height,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.5), width: 2),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Окна (все)
                        ...[..._windows, ..._minimizedWindows].map((w) {
                          return WindowItem(
                            key: w.key,
                            data: w,
                            isHidden: w.isMinimized || w.isFlying,
                            isShiftPressed: _isShiftPressed,
                            screenSize: workAreaSize,
                            themeColor: w.color,
                             onGridModeChanged: (mode, metadata) {
                                  setState(() {
                                    _currentGridMode = mode;
                                    if (metadata != null) _customGridMetadata = metadata;
                                  });
                                  _saveGridMode(mode, metadata);
                                },
                              onPanUpdate: (details) => _handlePanUpdate(w, details, workAreaSize),
                              onResizeUpdate: (delta) => _handleResizeUpdate(w, delta, workAreaSize),
                              onPanEnd: () => _handlePanEnd(w),
                              onMinimize: () => _minimizeWindow(w, workAreaSize),
                              onDelete: () => _removeWindow(w.id),
                              onFocus: () => _focusWindow(w),
                            );
                        }),
                        // Анимированная панель выбора окон
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOutCubic,
                          top: _isAddPanelVisible ? 10 : -200, // Выезжает сверху
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[850],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black54,
                                    blurRadius: 20,
                                    offset: Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildTypeOption(
                                    icon: Icons.videocam_outlined,
                                    label: 'viewport_cam',
                                    color: Colors.blueAccent,
                                    onTap: (ctx) => _addWindow('viewport_cam', ctx),
                                  ),
                                  const SizedBox(width: 12),
                                  _buildTypeOption(
                                    icon: Icons.folder_open_rounded,
                                    label: 'file_browser',
                                    color: Colors.greenAccent,
                                    onTap: (ctx) => _addWindow('file_browser', ctx),
                                  ),
                                  const SizedBox(width: 12),
                                  _buildTypeOption(
                                    icon: Icons.terminal_rounded,
                                    label: 'terminal',
                                    color: Colors.purpleAccent,
                                    onTap: (ctx) => _addWindow('terminal', ctx),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Анимированная панель настроек
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOutCubic,
                          top: _isSettingsPanelVisible ? 10 : -200, // Выезжает сверху
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[850],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black54,
                                    blurRadius: 20,
                                    offset: Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildTypeOption(
                                    icon: Icons.grid_4x4,
                                    label: 'settings_grid',
                                    color: Colors.orangeAccent,
                                    onTap: (ctx) => _addWindow('settings_grid', ctx),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          // Летящие анимации поверх всего экрана (включая верхнюю панель)
          ..._flyingAnimations,
        ],
      ),
    )));
  }

  Widget _buildTypeOption({
    required IconData icon,
    required String label,
    required Color color,
    required void Function(BuildContext) onTap,
  }) {
    return Builder(
      builder: (context) => InkWell(
        onTap: () => onTap(context),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
