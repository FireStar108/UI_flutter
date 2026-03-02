import 'package:flutter/material.dart';
import '../core/grid_models.dart';
import 'grid_background.dart';

class GridTemplate {
  final String id;
  final String name;
  final IconData icon;
  final String description;

  GridTemplate({
    required this.id,
    required this.name,
    required this.icon,
    this.description = '',
  });
}

class SettingsGrid extends StatefulWidget {
  final Function(GridMode mode, GridMetadata? metadata)? onApply;
  const SettingsGrid({super.key, this.onApply});

  @override
  State<SettingsGrid> createState() => _SettingsGridState();
}

class _SettingsGridState extends State<SettingsGrid> {
  late List<GridTemplate> _templates;
  GridTemplate? _selectedTemplate;
  bool _isEditing = false;
  GridMetadata _customMetadata = GridMetadata(horizontalSplits: [0.5], verticalSplits: [0.5]);

  @override
  void initState() {
    super.initState();
    _templates = [
      GridTemplate(
        id: 'system',
        name: 'Системный',
        icon: Icons.settings_input_component,
        description: 'Стандартная системная сетка по умолчанию.',
      ),
      GridTemplate(
        id: 'grid_2x2',
        name: 'Сетка 2x2',
        icon: Icons.grid_view_rounded,
        description: 'Равномерное деление экрана на 4 зоны.',
      ),
      GridTemplate(
        id: 'grid_3x3',
        name: 'Сетка 3x3',
        icon: Icons.grid_on_rounded,
        description: 'Классическая сетка из 9 сегментов.',
      ),
      GridTemplate(
        id: 'cinematic',
        name: 'Cinematic',
        icon: Icons.movie_filter_outlined,
        description: 'Оптимизировано для мониторинга видеопотоков.',
      ),
    ];
    _selectedTemplate = _templates.first;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: Row(
        children: [
          // ЛЕВАЯ ЧАСТЬ: ПРЕВЬЮ И КНОПКИ (flex 5)
          Expanded(
            flex: 5,
            child: Container(
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: Colors.white10)),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: _buildPreviewArea(),
                    ),
                  ),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
          // ПРАВАЯ ЧАСТЬ: СПИСОК ШАБЛОНОВ (flex 1)
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.black.withValues(alpha: 0.2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Text(
                      'ШАБЛОНЫ',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _templates.length,
                      itemBuilder: (context, index) {
                        final template = _templates[index];
                        final isSelected = _selectedTemplate?.id == template.id;
                        return _buildTemplateItem(template, isSelected);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewArea() {
    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: Container(
          width: 400,
          height: 225,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                _buildInteractiveGrid(),
                if (!_isEditing)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _selectedTemplate?.icon,
                          size: 48,
                          color: Colors.white10,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _selectedTemplate?.name.toUpperCase() ?? '',
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
        ),
      ),
    );
  }

  Widget _buildInteractiveGrid() {
    final mode = _isEditing ? GridMode.custom : GridMode.fromModeString(_selectedTemplate?.id ?? 'system');
    final metadata = _isEditing ? _customMetadata : GridMetadata.fromMode(mode);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        
        return Stack(
          children: [
            // Сама отрисовка линий
            CustomPaint(
              size: size,
              painter: GridPainter(mode: mode, customMetadata: metadata),
            ),
            // Интерактивные линии (перетаскивание)
            if (_isEditing) ..._buildDraggableLines(metadata, size),
            // Кнопки добавления (только в режиме редактирования)
            if (_isEditing) ..._buildCellButtons(metadata, size),
          ],
        );
      },
    );
  }

  List<Widget> _buildDraggableLines(GridMetadata metadata, Size size) {
    List<Widget> handles = [];

    // Вертикальные линии (двигаем по X)
    for (int i = 0; i < metadata.horizontalSplits.length; i++) {
      final x = metadata.horizontalSplits[i] * size.width;
      handles.add(
        Positioned(
          left: x - 15,
          top: 0,
          bottom: 0,
          child: GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                double newX = (details.localPosition.dx + x - 15) / size.width;
                // Ограничения: не выходить за соседние линии
                double minBound = (i == 0) ? 0.01 : metadata.horizontalSplits[i - 1] + 0.02;
                double maxBound = (i == metadata.horizontalSplits.length - 1)
                    ? 0.99
                    : metadata.horizontalSplits[i + 1] - 0.02;
                _customMetadata.horizontalSplits[i] = newX.clamp(minBound, maxBound);
              });
            },
            child: Container(
              width: 30,
              color: Colors.transparent,
              child: Center(
                child: Container(
                  width: 2,
                  color: Colors.orangeAccent.withOpacity(0.5),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Горизонтальные линии (двигаем по Y)
    for (int i = 0; i < metadata.verticalSplits.length; i++) {
      final y = metadata.verticalSplits[i] * size.height;
      handles.add(
        Positioned(
          top: y - 15,
          left: 0,
          right: 0,
          child: GestureDetector(
            onVerticalDragUpdate: (details) {
              setState(() {
                double newY = (details.localPosition.dy + y - 15) / size.height;
                // Ограничения: не выходить за соседние линии
                double minBound = (i == 0) ? 0.01 : metadata.verticalSplits[i - 1] + 0.02;
                double maxBound = (i == metadata.verticalSplits.length - 1)
                    ? 0.99
                    : metadata.verticalSplits[i + 1] - 0.02;
                _customMetadata.verticalSplits[i] = newY.clamp(minBound, maxBound);
              });
            },
            child: Container(
              height: 30,
              color: Colors.transparent,
              child: Center(
                child: Container(
                  height: 2,
                  color: Colors.orangeAccent.withOpacity(0.5),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return handles;
  }

  List<Widget> _buildCellButtons(GridMetadata metadata, Size size) {
    final xBounds = [0.0, ...metadata.horizontalSplits, 1.0]..sort();
    final yBounds = [0.0, ...metadata.verticalSplits, 1.0]..sort();
    List<Widget> buttons = [];

    for (int ix = 0; ix < xBounds.length - 1; ix++) {
      for (int iy = 0; iy < yBounds.length - 1; iy++) {
        final left = xBounds[ix] * size.width;
        final right = xBounds[ix + 1] * size.width;
        final top = yBounds[iy] * size.height;
        final bottom = yBounds[iy + 1] * size.height;

        final centerX = (left + right) / 2;
        final centerY = (top + bottom) / 2;

        // Кнопки рядом горизонтально
        buttons.add(
          Positioned(
            left: centerX - 34,
            top: centerY - 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Вертикальное деление (view_column)
                _buildAddButton(
                  icon: Icons.view_column_rounded,
                  onPressed: () {
                    setState(() {
                      final newSplit = (xBounds[ix] + xBounds[ix + 1]) / 2;
                      _customMetadata.horizontalSplits.add(newSplit);
                      _customMetadata.horizontalSplits.sort();
                    });
                  },
                ),
                const SizedBox(width: 4),
                // Горизонтальное деление (view_stream)
                _buildAddButton(
                  icon: Icons.view_stream_rounded,
                  onPressed: () {
                    setState(() {
                      final newSplit = (yBounds[iy] + yBounds[iy + 1]) / 2;
                      _customMetadata.verticalSplits.add(newSplit);
                      _customMetadata.verticalSplits.sort();
                    });
                  },
                ),
              ],
            ),
          ),
        );
      }
    }
    return buttons;
  }

  Widget _buildAddButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.orangeAccent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 18,
          color: Colors.black,
        ),
      ),
    );
  }


  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.black26,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildButton(
              label: _isEditing ? 'ЗАКОНЧИТЬ' : 'ИЗМЕНИТЬ СЕТКУ',
              icon: _isEditing ? Icons.check_rounded : Icons.edit_note_rounded,
              color: _isEditing ? Colors.greenAccent : Colors.white10,
              onPressed: () {
                setState(() {
                  if (!_isEditing) {
                    // При входе в режим редактирования копируем текущую сетку
                    final currentMode = GridMode.fromModeString(_selectedTemplate?.id ?? 'system');
                    final currentMeta = GridMetadata.fromMode(currentMode);
                    _customMetadata = currentMeta.copyWith();
                  }
                  _isEditing = !_isEditing;
                });
              },
            ),
            if (_isEditing) ...[
              const SizedBox(width: 8),
              _buildButton(
                label: 'СБРОСИТЬ',
                icon: Icons.refresh_rounded,
                color: Colors.orangeAccent.withOpacity(0.1),
                onPressed: () {
                  setState(() {
                    final currentMode = GridMode.fromModeString(_selectedTemplate?.id ?? 'system');
                    final currentMeta = GridMetadata.fromMode(currentMode);
                    _customMetadata = currentMeta.copyWith();
                  });
                },
              ),
            ],
            const SizedBox(width: 32),
            _buildButton(
              label: 'ПРИМЕНИТЬ СЕТКУ',
              icon: Icons.check_circle_outline_rounded,
              color: Colors.orangeAccent,
              onPressed: () {
                if (widget.onApply != null && _selectedTemplate != null) {
                  final mode = _isEditing ? GridMode.custom : GridMode.fromModeString(_selectedTemplate!.id);
                  widget.onApply!(mode, _isEditing ? _customMetadata : null);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_isEditing ? 'Кастомная сетка применена' : 'Сетка "${_selectedTemplate!.name}" применена'),
                      duration: const Duration(seconds: 2),
                      backgroundColor: Colors.orangeAccent,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    final bool isAccent = color == Colors.orangeAccent;
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: isAccent ? Colors.black : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildTemplateItem(GridTemplate template, bool isSelected) {
    return InkWell(
      onTap: () => setState(() => _selectedTemplate = template),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orangeAccent.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.orangeAccent.withOpacity(0.5) : Colors.transparent,
          ),
        ),
        child: Column(
          children: [
            Container(
              height: 60,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                template.icon,
                size: 24,
                color: isSelected ? Colors.orangeAccent : Colors.white24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              template.name,
              style: TextStyle(
                color: isSelected ? Colors.orangeAccent : Colors.white54,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

