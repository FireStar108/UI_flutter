import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ui/grid_background.dart';
import 'ui/window_item.dart';
import 'dart:math' as math;


class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final List<WindowData> _windows = [];
  bool _isShiftPressed = false;
  bool _isAddPanelVisible = false; // Состояние панели выбора
  Offset? _previewPosition;
  Size? _previewSize;

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
                  ? const Size(0.25, 0.4)
                  : const Size(0.3, 0.3),
          color: type == 'settings_grid' ? Colors.orangeAccent : Colors.blueAccent,
        ),
      );
      _isAddPanelVisible = false; // Закрываем панель после выбора
    });
  }

  void _toggleAddPanel() {
    setState(() {
      _isAddPanelVisible = !_isAddPanelVisible;
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

    final splitX = 10 / 16;
    final splitY = 6 / 9;

    final normalizedCursorX = localCursor.dx / areaSize.width;
    final normalizedCursorY = localCursor.dy / areaSize.height;

    // Константа отступа (равна ширине сетки)
    const double gap = 3.0;
    final double padX = gap / areaSize.width;
    final double padY = gap / areaSize.height;

    if (normalizedCursorX < splitX && normalizedCursorY < splitY) {
      _previewPosition = Offset(padX, padY);
      _previewSize = Size(splitX - 2 * padX, splitY - 2 * padY);
    } else if (normalizedCursorX >= splitX && normalizedCursorY < splitY) {
      _previewPosition = Offset(splitX + padX, padY);
      _previewSize = Size(1 - splitX - 2 * padX, splitY - 2 * padY);
    } else if (normalizedCursorX < splitX && normalizedCursorY >= splitY) {
      _previewPosition = Offset(padX, splitY + padY);
      _previewSize = Size(splitX - 2 * padX, 1 - splitY - 2 * padY);
    } else {
      _previewPosition = Offset(splitX + padX, splitY + padY);
      _previewSize = Size(1 - splitX - 2 * padX, 1 - splitY - 2 * padY);
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
                      onPressed: () => _addWindow('settings_grid'),
                      icon: const Icon(Icons.settings),
                      label: const Text('Настройки'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white10,
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
                              const GridBackground(),
                              if (_previewPosition != null && _previewSize != null)
                                Positioned(
                                  left: _previewPosition!.dx * workAreaSize.width,
                                  top: _previewPosition!.dy * workAreaSize.height,
                                  child: Container(
                                    width: _previewSize!.width * workAreaSize.width,
                                    height: _previewSize!.height * workAreaSize.height,
                                    decoration: BoxDecoration(
                                      color: Colors.blueAccent.withOpacity(0.15),
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
                                    onTap: () => _addWindow('viewport_cam'),
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
            Icon(icon, size: 32, color: Colors.blueAccent),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
