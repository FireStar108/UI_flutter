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

  // Новые состояния для рефакторинга меню и призрачных линий
  int? _activeMenuLineIndex; // Индекс линии с открытым меню
  bool _isVerticalMenu = false; // Вертикальная или горизонтальная линия
  bool _isPlacingLine = false; // Режим размещения новой линии
  bool _placingVertical = false; // Тип размещаемой линии
  double _ghostPosition = 0.5; // Позиция призрака (0..1)
  double _placementMin = 0.01; // Минимум для размещения
  double _placementMax = 0.99; // Максимум для размещения
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

        return MouseRegion(
          onHover: (event) {
            if (_isPlacingLine) {
              setState(() {
                final local = event.localPosition;
                _ghostPosition = (_placingVertical ? local.dx / size.width : local.dy / size.height)
                    .clamp(_placementMin, _placementMax);
              });
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              if (_isPlacingLine) {
                setState(() {
                  if (_placingVertical) {
                    _customMetadata.horizontalSplits.add(_ghostPosition);
                    _customMetadata.horizontalSplits.sort();
                  } else {
                    _customMetadata.verticalSplits.add(_ghostPosition);
                    _customMetadata.verticalSplits.sort();
                  }
                  _isPlacingLine = false;
                });
              } else {
                setState(() => _activeMenuLineIndex = null);
              }
            },
            child: Stack(
              children: [
                // Сама отрисовка линий
                CustomPaint(
                  size: size,
                  painter: GridPainter(mode: mode, customMetadata: metadata),
                ),
                // Призрачная линия
                if (_isPlacingLine) _buildGhostLine(size),
                // Интерактивные линии (перетаскивание)
                if (_isEditing) ..._buildDraggableLines(metadata, size),
                // Меню на линии
                if (_isEditing && _activeMenuLineIndex != null) _buildLineMenu(metadata, size),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGhostLine(Size size) {
    if (_placingVertical) {
      return Positioned(
        left: _ghostPosition * size.width - 1,
        top: 0,
        bottom: 0,
        child: Container(width: 2, color: Colors.orangeAccent.withOpacity(0.8)),
      );
    } else {
      return Positioned(
        top: _ghostPosition * size.height - 1,
        left: 0,
        right: 0,
        child: Container(height: 2, color: Colors.orangeAccent.withOpacity(0.8)),
      );
    }
  }

  Widget _buildLineMenu(GridMetadata metadata, Size size) {
    final splits = _isVerticalMenu ? [0.0, ...metadata.horizontalSplits, 1.0] : [0.0, ...metadata.verticalSplits, 1.0];
    final double posRatio = splits[_activeMenuLineIndex!];
    final bool isBorder = _activeMenuLineIndex == 0 || _activeMenuLineIndex == splits.length - 1;

    return Positioned(
      left: _isVerticalMenu ? posRatio * size.width + 10 : size.width / 2 - 40,
      top: _isVerticalMenu ? size.height / 2 - 40 : posRatio * size.height + 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orangeAccent),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ПЛЮСИК (Добавить линию в следующую ячейку)
            if (_activeMenuLineIndex! < splits.length - 1)
              _buildMenuIcon(
                icon: Icons.add_circle_outline_rounded,
                color: Colors.greenAccent,
                onTap: () {
                  setState(() {
                    _isPlacingLine = true;
                    _placingVertical = _isVerticalMenu;
                    _placementMin = splits[_activeMenuLineIndex!] + 0.02;
                    _placementMax = splits[_activeMenuLineIndex! + 1] - 0.02;
                    _ghostPosition = (_placementMin + _placementMax) / 2;
                    _activeMenuLineIndex = null;
                  });
                },
              ),
            if (!isBorder) ...[
              if (_activeMenuLineIndex! < splits.length - 1) const SizedBox(width: 4),
              // МИНУС (Удалить текущую линию)
              _buildMenuIcon(
                icon: Icons.remove_circle_outline_rounded,
                color: Colors.redAccent,
                onTap: () {
                  setState(() {
                    if (_isVerticalMenu) {
                      _customMetadata.horizontalSplits.removeAt(_activeMenuLineIndex! - 1);
                    } else {
                      _customMetadata.verticalSplits.removeAt(_activeMenuLineIndex! - 1);
                    }
                    _activeMenuLineIndex = null;
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMenuIcon({required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }

  List<Widget> _buildDraggableLines(GridMetadata metadata, Size size) {
    List<Widget> handles = [];

    // --- ВЕРТИКАЛЬНЫЕ ---
    final vSplits = [0.0, ...metadata.horizontalSplits, 1.0];
    for (int i = 0; i < vSplits.length; i++) {
      final x = vSplits[i] * size.width;
      final bool isBorder = i == 0 || i == vSplits.length - 1;
      final int splitIndex = i - 1; // Индекс в metadata.horizontalSplits

      handles.add(
        Positioned(
          left: x - 20,
          top: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _activeMenuLineIndex = i;
                _isVerticalMenu = true;
              });
            },
            onHorizontalDragUpdate: isBorder ? null : (details) {
              setState(() {
                double deltaX = details.delta.dx / size.width;
                double newX = metadata.horizontalSplits[splitIndex] + deltaX;
                
                double minBound = (splitIndex == 0) ? 0.01 : metadata.horizontalSplits[splitIndex - 1] + 0.02;
                double maxBound = (splitIndex == metadata.horizontalSplits.length - 1)
                    ? 0.99
                    : metadata.horizontalSplits[splitIndex + 1] - 0.02;
                
                _customMetadata.horizontalSplits[splitIndex] = newX.clamp(minBound, maxBound);
              });
            },
            child: Container(
              width: 40,
              color: Colors.transparent,
              child: Center(
                child: Container(
                  width: isBorder ? 1 : 2,
                  color: isBorder ? Colors.white12 : Colors.orangeAccent.withOpacity(0.5),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // --- ГОРИЗОНТАЛЬНЫЕ ---
    final hSplits = [0.0, ...metadata.verticalSplits, 1.0];
    for (int i = 0; i < hSplits.length; i++) {
      final y = hSplits[i] * size.height;
      final bool isBorder = i == 0 || i == hSplits.length - 1;
      final int splitIndex = i - 1;

      handles.add(
        Positioned(
          top: y - 20,
          left: 0,
          right: 0,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _activeMenuLineIndex = i;
                _isVerticalMenu = false;
              });
            },
            onVerticalDragUpdate: isBorder ? null : (details) {
              setState(() {
                double deltaY = details.delta.dy / size.height;
                double newY = metadata.verticalSplits[splitIndex] + deltaY;

                double minBound = (splitIndex == 0) ? 0.01 : metadata.verticalSplits[splitIndex - 1] + 0.02;
                double maxBound = (splitIndex == metadata.verticalSplits.length - 1)
                    ? 0.99
                    : metadata.verticalSplits[splitIndex + 1] - 0.02;

                _customMetadata.verticalSplits[splitIndex] = newY.clamp(minBound, maxBound);
              });
            },
            child: Container(
              height: 40,
              color: Colors.transparent,
              child: Center(
                child: Container(
                  height: isBorder ? 1 : 2,
                  color: isBorder ? Colors.white12 : Colors.orangeAccent.withOpacity(0.5),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return handles;
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

