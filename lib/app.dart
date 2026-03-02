import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ui/grid_background.dart';
import 'ui/window_item.dart';
import 'core/grid_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;


class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final List<WindowData> _windows = [];
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
    
    // Загрузка кастомных метаданных, если они есть
    final hSplits = prefs.getStringList('custom_h_splits');
    final vSplits = prefs.getStringList('custom_v_splits');
    GridMetadata? customMeta;
    if (hSplits != null && vSplits != null) {
      customMeta = GridMetadata(
        horizontalSplits: hSplits.map(double.parse).toList(),
        verticalSplits: vSplits.map(double.parse).toList(),
      );
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
      await prefs.setStringList('custom_h_splits', metadata.horizontalSplits.map((e) => e.toString()).toList());
      await prefs.setStringList('custom_v_splits', metadata.verticalSplits.map((e) => e.toString()).toList());
    }
  }

  void _addWindow(String type) {
    setState(() {
      _windows.add(
        WindowData(
          id: DateTime.now().toString(),
          type: type,
          relativePosition: const Offset(0.1, 0.1),
          relativeSize: type == 'viewport_cam' 
              ? const Size(0.35, 0.197) 
              : type == 'settings_grid'
                  ? const Size(0.5, 0.45)
                  : const Size(0.3, 0.3),
          color: type == 'settings_grid' ? Colors.orangeAccent : Colors.blueAccent,
        ),
      );
      _isAddPanelVisible = false; // Закрываем панели после выбора
      _isSettingsPanelVisible = false;
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
      _windows.removeWhere((w) => w.id == id);
    });
  }

  void _handlePanUpdate(WindowData data, DragUpdateDetails details, Size areaSize) {
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
    setState(() {
      final relativeDeltaX = delta.dx / areaSize.width;
      final relativeDeltaY = delta.dy / areaSize.height;

      data.relativeSize = Size(
        math.max(0.05, data.relativeSize.width + relativeDeltaX),
        math.max(0.05, data.relativeSize.height + relativeDeltaY),
      );
    });
  }

  void _calculateSnapPreview(Offset cursorPosition, Size areaSize) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localCursor = renderBox.globalToLocal(cursorPosition);

    final metadata = GridMetadata.fromMode(_currentGridMode, customData: _customGridMetadata);
    
    // Списки всех границ (включая 0 и 1)
    final xBoundaries = [0.0, ...metadata.horizontalSplits, 1.0];
    final yBoundaries = [0.0, ...metadata.verticalSplits, 1.0];
    
    // Сортируем на всякий случай
    xBoundaries.sort();
    yBoundaries.sort();

    final normalizedCursorX = localCursor.dx / areaSize.width;
    final normalizedCursorY = localCursor.dy / areaSize.height;

    // Константа отступа
    const double gap = 3.0;
    final double padX = gap / areaSize.width;
    final double padY = gap / areaSize.height;

    // Поиск текущей ячейки по X
    double left = 0, right = 1;
    for (int i = 0; i < xBoundaries.length - 1; i++) {
      if (normalizedCursorX >= xBoundaries[i] && normalizedCursorX < xBoundaries[i + 1]) {
        left = xBoundaries[i];
        right = xBoundaries[i + 1];
        break;
      }
    }
    // Если на самом краю 1.0
    if (normalizedCursorX >= 1.0) {
      left = xBoundaries[xBoundaries.length - 2];
      right = 1.0;
    }

    // Поиск текущей ячейки по Y
    double top = 0, bottom = 1;
    for (int i = 0; i < yBoundaries.length - 1; i++) {
      if (normalizedCursorY >= yBoundaries[i] && normalizedCursorY < yBoundaries[i + 1]) {
        top = yBoundaries[i];
        bottom = yBoundaries[i + 1];
        break;
      }
    }
    if (normalizedCursorY >= 1.0) {
      top = yBoundaries[yBoundaries.length - 2];
      bottom = 1.0;
    }

    _previewPosition = Offset(left + padX, top + padY);
    _previewSize = Size(right - left - 2 * padX, bottom - top - 2 * padY);
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
      home: KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKeyEvent: (event) {
          setState(() {
            _isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
            if (!_isShiftPressed) {
              _previewPosition = null;
              _previewSize = null;
            }
          });
        },
        child: Scaffold(
          body: Column(
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
                    const Text(
                      'Панель управления',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _toggleSettingsPanel,
                      icon: Icon(_isSettingsPanelVisible ? Icons.close : Icons.settings),
                      label: const Text('Настройки'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isSettingsPanelVisible ? Colors.redAccent.withOpacity(0.2) : Colors.white10,
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
                        backgroundColor: _isAddPanelVisible ? Colors.redAccent.withOpacity(0.2) : Colors.white10,
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
                                      color: Colors.black.withOpacity(0.3),
                                      border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 2),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Окна
                        ..._windows.map((w) {
                          return WindowItem(
                            key: ValueKey(w.id),
                            data: w,
                            isShiftPressed: _isShiftPressed,
                            screenSize: workAreaSize,
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
                            onDelete: () => _removeWindow(w.id),
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
                                    onTap: () => _addWindow('viewport_cam'),
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
                                    onTap: () => _addWindow('settings_grid'),
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
        ),
      ),
    );
  }

  Widget _buildTypeOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
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
    );
  }
}
