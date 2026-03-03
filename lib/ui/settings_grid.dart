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

  // Новые состояния для рефакторинга меню и призрачных линий
  int? _activeMenuLineIndex; 
  bool _isVerticalMenu = false; 
  bool _isPlacingLine = false; 
  bool _placingVertical = false; 
  double _ghostPosition = 0.5; 
  double _placementMin = 0.01; 
  double _placementMax = 0.99;

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
                  painter: GridPainter(
                    mode: GridMode.custom,
                    customMetadata: metadata,
                  ),
                ),
                // Кнопки для пустой сетки
                if (_isEditing && metadata.horizontalSplits.isEmpty && metadata.verticalSplits.isEmpty && !_isPlacingLine)
                  _buildStartButtons(size),
                
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

  Widget _buildStartButtons(Size size) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBigAddButton(
            icon: Icons.view_column_rounded,
            label: 'ВЕРТИКАЛЬ',
            onTap: () {
              setState(() {
                _isPlacingLine = true;
                _placingVertical = true;
                _placementMin = 0.05;
                _placementMax = 0.95;
                _ghostPosition = 0.5;
              });
            },
          ),
          const SizedBox(width: 20),
          _buildBigAddButton(
            icon: Icons.view_stream_rounded,
            label: 'ГОРИЗОНТАЛЬ',
            onTap: () {
              setState(() {
                _isPlacingLine = true;
                _placingVertical = false;
                _placementMin = 0.05;
                _placementMax = 0.95;
                _ghostPosition = 0.5;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBigAddButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.orangeAccent, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGhostLine(Size size) {
    if (_placingVertical) {
      return Positioned(
        left: _ghostPosition * size.width - 1,
        top: 0,
        bottom: 0,
        child: Container(width: 2, color: Colors.orangeAccent.withValues(alpha: 0.8)),
      );
    } else {
      return Positioned(
        top: _ghostPosition * size.height - 1,
        left: 0,
        right: 0,
        child: Container(height: 2, color: Colors.orangeAccent.withValues(alpha: 0.8)),
      );
    }
  }

  Widget _buildLineMenu(GridMetadata metadata, Size size) {
    final splits = _isVerticalMenu ? [0.0, ...metadata.horizontalSplits, 1.0] : [0.0, ...metadata.verticalSplits, 1.0];
    final double posRatio = splits[_activeMenuLineIndex!];
    final bool isBorder = _activeMenuLineIndex == 0 || _activeMenuLineIndex == splits.length - 1;

    // Пытаемся центрировать меню относительно линии
    // Для вертикальных линий меню будет ВДОЛЬ линии (вертикальное), для горизонтальных - ВДОЛЬ линии (горизонтальное)
    return Positioned(
      left: _isVerticalMenu ? posRatio * size.width - 20 : size.width / 2 - 60,
      top: _isVerticalMenu ? size.height / 2 - 60 : posRatio * size.height - 20,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.orangeAccent, width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black54, blurRadius: 12, offset: const Offset(0, 6)),
          ],
        ),
        child: _isVerticalMenu 
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: _buildMenuButtons(splits, isBorder),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: _buildMenuButtons(splits, isBorder),
            ),
      ),
    );
  }

  List<Widget> _buildMenuButtons(List<double> splits, bool isBorder) {
    final int idx = _activeMenuLineIndex!;
    return [
      // Плюс с одной стороны (Слева или Сверху)
      if (idx > 0)
        _buildMenuIcon(
          icon: Icons.add_circle_outline_rounded,
          color: Colors.greenAccent,
          onTap: () => _addSmartLine(splits[idx-1], splits[idx]),
        ),
      
      if (idx > 0 && idx < splits.length - 1) const SizedBox(width: 4, height: 4),

      // Кнопка удаления (по центру, если не граница)
      if (!isBorder)
        _buildMenuIcon(
          icon: Icons.delete_outline_rounded,
          color: Colors.redAccent,
          onTap: () {
            setState(() {
              if (_isVerticalMenu) {
                _customMetadata.horizontalSplits.removeAt(idx - 1);
              } else {
                _customMetadata.verticalSplits.removeAt(idx - 1);
              }
              _activeMenuLineIndex = null;
            });
          },
        )
      else 
        // Если это граница, то в центре просто иконка запрета или ничего
        const Padding(
          padding: EdgeInsets.all(8.0),
          child: Icon(Icons.lock_outline_rounded, color: Colors.white24, size: 20),
        ),

      if (idx < splits.length - 1) const SizedBox(width: 4, height: 4),

      // Плюс с другой стороны (Справа или Снизу)
      if (idx < splits.length - 1)
        _buildMenuIcon(
          icon: Icons.add_circle_outline_rounded,
          color: Colors.greenAccent,
          onTap: () => _addSmartLine(splits[idx], splits[idx+1]),
        ),
    ];
  }

  void _addSmartLine(double min, double max) {
    setState(() {
      _isPlacingLine = true;
      _placingVertical = _isVerticalMenu;
      _placementMin = min + 0.01;
      _placementMax = max - 0.01;
      _ghostPosition = (min + max) / 2;
      _activeMenuLineIndex = null;
    });
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
                  color: isBorder ? Colors.white12 : Colors.orangeAccent.withValues(alpha: 0.5),
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
                  color: isBorder ? Colors.white12 : Colors.orangeAccent.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        ),
      );
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
                  horizontalSplits: [],
                  verticalSplits: [],
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
          if (!_isEditing)
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
            )
          else ...[
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

