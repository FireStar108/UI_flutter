import 'package:flutter/material.dart';
import 'viewport_cam.dart';
import 'settings_grid.dart';
import 'file_browser.dart';
import '../core/grid_models.dart';

class WindowData {
  final GlobalKey key;
  final String id;
  final String type; // Тип окна
  Offset relativePosition; // 0..1
  Size relativeSize; // 0..1
  final Color color;
  bool isMinimized;
  bool isClosing; // Флаг для анимации закрытия из панели задач
  bool isFlying; // Флаг для скрытия окна во время перелета

  WindowData({
    GlobalKey? key,
    required this.id,
    this.type = 'Окно',
    this.relativePosition = Offset.zero,
    this.relativeSize = const Size(0.3, 0.3), // 20% от экрана
    this.color = const Color(0xFF212121), // Темно-серый по умолчанию
    this.isMinimized = false,
    this.isClosing = false,
    this.isFlying = false,
  }) : key = key ?? GlobalKey();
}

class WindowItem extends StatelessWidget {
  final WindowData data;
  final bool isShiftPressed;
  final Size screenSize;
  final Function(DragUpdateDetails details) onPanUpdate;
  final Function(Offset delta) onResizeUpdate;
  final Function() onPanEnd;
  final Function() onMinimize;
  final Function() onDelete;
  final Function() onFocus;
  final Function(GridMode mode, GridMetadata? metadata)? onGridModeChanged;
  final Color themeColor;

  const WindowItem({
    super.key,
    required this.data,
    required this.isShiftPressed,
    required this.screenSize,
    required this.onPanUpdate,
    required this.onResizeUpdate,
    required this.onPanEnd,
    required this.onMinimize,
    required this.onDelete,
    required this.onFocus,
    this.onGridModeChanged,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    final left = data.relativePosition.dx * screenSize.width;
    final top = data.relativePosition.dy * screenSize.height;
    final width = data.relativeSize.width * screenSize.width;
    final height = data.relativeSize.height * screenSize.height;

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTapDown: (_) => onFocus(),
        behavior: HitTestBehavior.deferToChild,
        child: Stack(
          children: [
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.grey[900]?.withValues(alpha: 0.98),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: themeColor.withValues(alpha: 0.7), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Панель заголовка для перемещения
                GestureDetector(
                  onPanUpdate: onPanUpdate,
                  onPanEnd: (_) => onPanEnd(),
                  child: Container(
                    height: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 8),
                        const Icon(Icons.drag_handle, size: 16, color: Colors.white54),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            data.type.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white54,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.minimize, size: 16, color: Colors.white54),
                          onPressed: onMinimize,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 16,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16, color: Colors.white54),
                          onPressed: onDelete,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 16,
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: data.type == 'viewport_cam'
                      ? const ViewportCam()
                      : data.type == 'settings_grid'
                          ? SettingsGrid(onApply: onGridModeChanged)
                          : data.type == 'file_browser'
                              ? FileBrowser(accentColor: themeColor)
                              : const Center(
                              child: Icon(Icons.window, color: Colors.white30, size: 40),
                            ),
                ),
              ],
            ),
          ),
          // Ручка изменения размера (правый нижний угол)
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onPanUpdate: (details) => onResizeUpdate(details.delta),
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeDownRight,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                  child: const Align(
                    alignment: Alignment.bottomRight,
                    child: Icon(
                      Icons.drag_handle,
                      size: 16,
                      color: Colors.white30,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ));
  }
}
