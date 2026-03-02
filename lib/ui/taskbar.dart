import 'package:flutter/material.dart';
import 'window_item.dart';

class Taskbar extends StatelessWidget {
  final List<WindowData> minimizedWindows;
  final Function(int oldIndex, int newIndex) onReorder;
  final Function(WindowData) onRestore;
  final Function(String) onClose;
  // Ключ для получения позиции (если нужно точной координаты, но пока можно захардкодить)
  
  const Taskbar({
    super.key,
    required this.minimizedWindows,
    required this.onReorder,
    required this.onRestore,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (minimizedWindows.isEmpty) {
      return const SizedBox(height: 48); // Пустой таскбар
    }

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        buildDefaultDragHandles: false,
        onReorder: onReorder,
        itemCount: minimizedWindows.length,
        itemBuilder: (context, index) {
          final w = minimizedWindows[index];
          return _buildTaskbarItem(w, index);
        },
      ),
    );
  }

  Widget _buildTaskbarItem(WindowData w, int index) {
    return ReorderableDragStartListener(
      key: ValueKey(w.id),
      index: index,
      child: Padding(
        padding: const EdgeInsets.only(right: 8.0, top: 4, bottom: 4),
        child: InkWell(
          onTap: () => onRestore(w),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 140,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: w.color.withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: w.color.withValues(alpha: 0.2),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  w.type == 'viewport_cam'
                      ? Icons.videocam_outlined
                      : w.type == 'settings_grid'
                          ? Icons.grid_4x4_rounded
                          : w.type == 'file_browser'
                              ? Icons.folder_open_rounded
                              : Icons.window,
                  size: 16,
                  color: w.color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    w.type.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => onClose(w.id),
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(2.0),
                    child: Icon(Icons.close, size: 14, color: Colors.white54),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
