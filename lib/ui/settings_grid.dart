import 'package:flutter/material.dart';
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
  final Function(GridMode mode)? onApply;
  const SettingsGrid({super.key, this.onApply});

  @override
  State<SettingsGrid> createState() => _SettingsGridState();
}

class _SettingsGridState extends State<SettingsGrid> {
  late List<GridTemplate> _templates;
  GridTemplate? _selectedTemplate;

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
              color: Colors.black.withOpacity(0.2),
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
    return Container(
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
            // Имитация сетки в превью
            _getGridPreview(_selectedTemplate?.id),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _selectedTemplate?.icon,
                    size: 64,
                    color: Colors.white10,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _selectedTemplate?.name.toUpperCase() ?? '',
                    style: const TextStyle(
                      color: Colors.white24,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
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

  Widget _getGridPreview(String? id) {
    if (id == 'grid_2x2') {
      return CustomPaint(
        size: Size.infinite,
        painter: GridPreviewPainter(rows: 2, cols: 2),
      );
    } else if (id == 'grid_3x3') {
      return CustomPaint(
        size: Size.infinite,
        painter: GridPreviewPainter(rows: 3, cols: 3),
      );
    } else if (id == 'system') {
      return CustomPaint(
        size: Size.infinite,
        painter: GridPreviewPainter(rows: 6, cols: 10, isDashed: true),
      );
    }
    return const SizedBox.shrink();
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
              label: 'ИЗМЕНИТЬ СЕТКУ',
              icon: Icons.edit_note_rounded,
              color: Colors.white10,
              onPressed: () {},
            ),
            const SizedBox(width: 8),
            _buildButton(
              label: 'ПРИМЕНИТЬ СЕТКУ',
              icon: Icons.check_circle_outline_rounded,
              color: Colors.orangeAccent,
              onPressed: () {
                if (widget.onApply != null && _selectedTemplate != null) {
                  GridMode mode;
                  switch (_selectedTemplate!.id) {
                    case 'system':
                      mode = GridMode.system;
                      break;
                    case 'grid_2x2':
                      mode = GridMode.grid_2x2;
                      break;
                    case 'grid_3x3':
                      mode = GridMode.grid_3x3;
                      break;
                    case 'cinematic':
                      mode = GridMode.cinematic;
                      break;
                    default:
                      mode = GridMode.system;
                  }
                  widget.onApply!(mode);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Сетка "${_selectedTemplate!.name}" применена'),
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

class GridPreviewPainter extends CustomPainter {
  final int rows;
  final int cols;
  final bool isDashed;

  GridPreviewPainter({required this.rows, required this.cols, this.isDashed = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 1; i < rows; i++) {
      final y = size.height * (i / rows);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    for (int i = 1; i < cols; i++) {
      final x = size.width * (i / cols);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
