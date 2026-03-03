import 'package:flutter/material.dart';
import '../core/grid_models.dart';
import 'grid_background.dart';

// GridMetadata is now used directly as a template

class SettingsGrid extends StatefulWidget {
  final Function(GridMode mode, GridMetadata? metadata)? onApply;
  const SettingsGrid({super.key, this.onApply});

  @override
  State<SettingsGrid> createState() => _SettingsGridState();
}

class _SettingsGridState extends State<SettingsGrid> {
  late List<GridMetadata> _templates;
  GridMetadata? _selectedTemplate;
  GridMetadata? _lastAppliedMetadata; // Для сброса
  
  bool _isEditing = false;
  GridMetadata _customMetadata = GridMetadata.fromMode(GridMode.system); // Текущее правка

  // Остояние редактора линий
  String? _activeLineId;

  @override
  void initState() {
    super.initState();
    _templates = [
      GridMetadata.fromMode(GridMode.system),
      GridMetadata.fromMode(GridMode.grid_2x2),
      GridMetadata.fromMode(GridMode.grid_3x3),
    ];
    _selectedTemplate = _templates.first;
    _customMetadata = _selectedTemplate!.copyWith();
    _lastAppliedMetadata = _selectedTemplate!.copyWith();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: Row(
        children: [
          // ЛЕВАЯ ЧАСТЬ: ПРЕВЬЮ И КНОПКИ (flex 4)
          Expanded(
            flex: 4,
            child: Container(
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: Colors.white10)),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      // 🪟 НАСТРОЙКА БОРТИКОВ (ОТСТУПОВ) ПРЕВЬЮ
                      // Измените значение 16.0 на нужное (например, 8.0 для ещё меньших бортиков)
                      padding: const EdgeInsets.all(16.0),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Адаптивное превью 16:9
                          double width = constraints.maxWidth;
                          double height = constraints.maxHeight;
                          double targetWidth = width;
                          double targetHeight = width * (9 / 16);

                          if (targetHeight > height) {
                            targetHeight = height;
                            targetWidth = height * (16 / 9);
                          }

                          return Center(
                            child: SizedBox(
                              width: targetWidth,
                              height: targetHeight,
                              child: _buildPreviewArea(),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
          // ПРАВАЯ ЧАСТЬ: НАСТРОЙКИ (flex 2)
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.black.withValues(alpha: 0.2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSidebarHeader('ШАБЛОНЫ'),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _templates.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _templates.length) {
                          return _buildAddTemplateButton();
                        }
                        final template = _templates[index];
                        final isSelected = _selectedTemplate?.id == template.id;
                        return _buildTemplateItem(template, isSelected);
                      },
                    ),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  if (_isEditing) ...[
                    _buildSidebarHeader('СВОЙСТВА'),
                    _buildSidebarEditor(),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader(String title) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildPreviewArea() {
    final metadata = _isEditing ? _customMetadata : _selectedTemplate!;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            _buildInteractiveGrid(metadata),
            if (!_isEditing)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      metadata.icon,
                      size: 48,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      metadata.name.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white24,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveGrid(GridMetadata metadata) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            setState(() => _activeLineId = null);
          },
          onSecondaryTapUp: (details) {
            if (!_isEditing) return;
            _showContextMenu(context, details.localPosition, size);
          },
          child: Stack(
            children: [
              // Сама отрисовка линий
              CustomPaint(
                size: size,
                painter: GridPainter(
                  mode: GridMode.custom,
                  customMetadata: metadata,
                ),
              ),
              
              // Подсказка для пустой сетки
              if (_isEditing && metadata.lines.isEmpty)
                Center(
                  child: Text(
                    'Кликните правой кнопкой мыши\nили двумя пальцами (по тачпаду),\nчтобы добавить первую линию',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white24, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                
              // Интерактивные линии (перетаскивание)
              if (_isEditing) ..._buildDraggableLines(metadata, size),
            ],
          ),
        );
      },
    );
  }

  void _showContextMenu(BuildContext context, Offset localPos, Size size) {
    final relPos = Offset(localPos.dx / size.width, localPos.dy / size.height);
    
    // Показываем меню с кнопками
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) {
        return Stack(
          children: [
            Positioned(
              left: localPos.dx,
              top: localPos.dy,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orangeAccent, width: 1.5),
                    boxShadow: [
                      BoxShadow(color: Colors.black54, blurRadius: 12, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildContextMenuItem(
                        icon: Icons.view_column_rounded,
                        label: 'ВЕРТИКАЛЬНАЯ',
                        onTap: () {
                          Navigator.pop(context);
                          _addLine(true, relPos.dx, relPos);
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildContextMenuItem(
                        icon: Icons.view_stream_rounded,
                        label: 'ГОРИЗОНТАЛЬНАЯ',
                        onTap: () {
                          Navigator.pop(context);
                          _addLine(false, relPos.dy, relPos);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContextMenuItem({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.orangeAccent, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  void _addLine(bool isVertical, double position, Offset anchor) {
    setState(() {
      final newLine = GridLine(
        id: 'line_${DateTime.now().millisecondsSinceEpoch}',
        isVertical: isVertical,
        position: position,
        isGlobal: true, // По умолчанию пока глобальная (или In-Box, если хотим)
        anchor: anchor,
      );
      _customMetadata.lines.add(newLine);
      _activeLineId = newLine.id;
    });
  }

  List<Widget> _buildDraggableLines(GridMetadata metadata, Size size) {
    List<Widget> handles = [];

    final vLines = metadata.computeVisualLines();
    
    for (int i = 0; i < metadata.lines.length; i++) {
      final line = metadata.lines[i];
      final isSelected = _activeLineId == line.id;
      
      // Ищем визуальную линию для получения start/end
      VisualLine? vLine;
      try {
        vLine = vLines.firstWhere((v) => v.line.id == line.id);
      } catch (_) {}
      
      if (vLine == null) continue;

      if (line.isVertical) {
        handles.add(
          Positioned(
            left: vLine.start.dx * size.width - 20,
            top: vLine.start.dy * size.height,
            height: (vLine.end.dy - vLine.start.dy) * size.height,
            child: GestureDetector(
              onTapDown: (_) => setState(() => _activeLineId = line.id),
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _activeLineId = line.id;
                  double deltaX = details.delta.dx / size.width;
                  double newPos = (line.position + deltaX).clamp(0.01, 0.99);
                  
                  // Создаем обновленную линию
                  _customMetadata.lines[i] = GridLine(
                    id: line.id,
                    isVertical: line.isVertical,
                    position: newPos,
                    isGlobal: line.isGlobal,
                    anchor: line.anchor,
                  );
                });
              },
              child: Container(
                width: 40,
                color: Colors.transparent,
                child: Center(
                  child: Container(
                    width: isSelected ? 4 : 2,
                    color: isSelected ? Colors.redAccent : Colors.orangeAccent.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ),
        );
      } else {
        handles.add(
          Positioned(
            left: vLine.start.dx * size.width,
            top: vLine.start.dy * size.height - 20,
            width: (vLine.end.dx - vLine.start.dx) * size.width,
            child: GestureDetector(
              onTapDown: (_) => setState(() => _activeLineId = line.id),
              onVerticalDragUpdate: (details) {
                setState(() {
                  _activeLineId = line.id;
                  double deltaY = details.delta.dy / size.height;
                  double newPos = (line.position + deltaY).clamp(0.01, 0.99);
                  
                  _customMetadata.lines[i] = GridLine(
                    id: line.id,
                    isVertical: line.isVertical,
                    position: newPos,
                    isGlobal: line.isGlobal,
                    anchor: line.anchor,
                  );
                });
              },
              child: Container(
                height: 40,
                color: Colors.transparent,
                child: Center(
                  child: Container(
                    height: isSelected ? 4 : 2,
                    color: isSelected ? Colors.redAccent : Colors.orangeAccent.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return handles;
  }


  Widget _buildTemplateItem(GridMetadata template, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTemplate = template;
          _isEditing = false;
          _customMetadata = template.copyWith();
          _lastAppliedMetadata = template.copyWith();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orangeAccent.withValues(alpha: 0.1) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? Colors.orangeAccent : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              template.icon,
              size: 20,
              color: isSelected ? Colors.orangeAccent : Colors.white38,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                template.name.toUpperCase(),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.normal,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddTemplateButton() {
    return InkWell(
      onTap: _showAddTemplateDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: const Row(
          children: [
            Icon(Icons.add_rounded, size: 20, color: Colors.greenAccent),
            SizedBox(width: 12),
            Text(
              'НОВЫЙ ШАБЛОН',
              style: TextStyle(
                color: Colors.greenAccent,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTemplateDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('НОВЫЙ ШАБЛОН', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'НАЗВАНИЕ',
            labelStyle: TextStyle(color: Colors.white38, fontSize: 10),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.orangeAccent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ОТМЕНА', style: TextStyle(color: Colors.white38, fontSize: 11)),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
            final newTemplate = GridMetadata(
                  id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                  name: controller.text,
                  lines: [],
                );
                setState(() {
                  _templates.add(newTemplate);
                  _selectedTemplate = newTemplate;
                  _isEditing = true;
                  _customMetadata = newTemplate.copyWith();
                  _lastAppliedMetadata = newTemplate.copyWith();
                });
                Navigator.pop(context);
              }
            },
            child: const Text('СОЗДАТЬ', style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarEditor() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('НАЗВАНИЕ', style: TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 8),
          TextField(
            onChanged: (val) => setState(() => _customMetadata = _customMetadata.copyWith(name: val)),
            controller: TextEditingController(text: _customMetadata.name)
              ..selection = TextSelection.collapsed(offset: _customMetadata.name.length),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.orangeAccent)),
            ),
          ),
          const SizedBox(height: 24),
          const Text('ЦВЕТ ЛИНИЙ', style: TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildColorOption(const Color(0xFFFFAB40)), // orangeAccent
              _buildColorOption(const Color(0xFF448AFF)), // blueAccent
              _buildColorOption(const Color(0xFF69F0AE)), // greenAccent
              _buildColorOption(const Color(0xFFFF5252)), // redAccent
              _buildColorOption(const Color(0xFFE040FB)), // purpleAccent
              _buildColorOption(const Color(0xFFBDBDBD)), // grey
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorOption(Color color) {
    final isSelected = _customMetadata.colorValue == color.toARGB32();
    return GestureDetector(
      onTap: () => setState(() => _customMetadata = _customMetadata.copyWith(colorValue: color.toARGB32())),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.white, width: 2) : Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 1)] : null,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      // 🎛 НАСТРОЙКА ОТСТУПОВ ВОКРУГ НИЖНИХ КНОПОК ("ПРИМЕНИТЬ", "РЕДАКТИРОВАТЬ")
      // Уменьшите с 16.0 до 8.0, если кнопки не влезают по высоте
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: Colors.black26,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (!_isEditing) ...[
            _buildButton(
              label: 'РЕДАКТИРОВАТЬ',
              icon: Icons.edit_rounded,
              color: Colors.white10,
              onPressed: () {
                setState(() {
                  _isEditing = true;
                  _customMetadata = _selectedTemplate!.copyWith();
                  _lastAppliedMetadata = _selectedTemplate!.copyWith();
                });
              },
            ),
            const SizedBox(width: 16),
             _buildButton(
              label: 'ПРИМЕНИТЬ',
              icon: Icons.check_circle_outline_rounded,
              color: Colors.orangeAccent,
              textColor: Colors.black,
              onPressed: () {
                if (widget.onApply != null) {
                  widget.onApply!(GridMode.custom, _selectedTemplate ?? _customMetadata);
                }
              },
            ),
          ] else ...[
            _buildButton(
              label: 'СБРОСИТЬ',
              icon: Icons.refresh_rounded,
              color: Colors.redAccent.withValues(alpha: 0.1),
              onPressed: () {
                setState(() {
                  _customMetadata = _lastAppliedMetadata!.copyWith();
                });
              },
            ),
            const SizedBox(width: 16),
            _buildButton(
              label: 'ПРИМЕНИТЬ',
              icon: Icons.check_circle_outline_rounded,
              color: Colors.orangeAccent,
              textColor: Colors.black,
              onPressed: () {
                setState(() {
                  // Обновляем текущий шаблон в списке
                  final index = _templates.indexWhere((t) => t.id == _selectedTemplate?.id);
                  if (index != -1) {
                    _templates[index] = _customMetadata.copyWith();
                    _selectedTemplate = _templates[index];
                  }
                  _lastAppliedMetadata = _customMetadata.copyWith();
                  _isEditing = false;
                });
                widget.onApply?.call(GridMode.custom, _customMetadata);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required IconData icon,
    required Color color,
    Color textColor = Colors.white,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: textColor), // Уменьшили размер иконки (было 20)
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 10, // Уменьшили шрифт (было 11)
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

