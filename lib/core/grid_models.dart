import 'package:flutter/material.dart';

enum GridMode {
  system,
  grid_2x2,
  grid_3x3,
  custom;

  static GridMode fromModeString(String id) {
    switch (id) {
      case 'system':
        return GridMode.system;
      case 'grid_2x2':
        return GridMode.grid_2x2;
      case 'grid_3x3':
        return GridMode.grid_3x3;
      case 'custom':
        return GridMode.custom;
      default:
        return GridMode.system;
    }
  }
}

class GridLine {
  final String id;
  final bool isVertical; // true = вертикальная линия (режет по X)
  final double position; // 0..1
  
  // Новые поля для In-Box сплитов
  final double crossStart; // 0..1 (для верт. линии это Y-начало, для гориз. - X-начало)
  final double crossEnd;   // 0..1 (для верт. линии это Y-конец, для гориз. - X-конец)

  GridLine({
    required this.id,
    required this.isVertical,
    required this.position,
    this.crossStart = 0.0,
    this.crossEnd = 1.0,
  });

  bool get isGlobal => crossStart <= 0.0 && crossEnd >= 1.0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'isVertical': isVertical,
    'position': position,
    'crossStart': crossStart,
    'crossEnd': crossEnd,
  };

  factory GridLine.fromJson(Map<String, dynamic> json) {
    double start = 0.0;
    double end = 1.0;
    if (json.containsKey('crossStart')) {
      start = (json['crossStart'] as num).toDouble();
      end = (json['crossEnd'] as num).toDouble();
    } else if (json['isGlobal'] == false) {
       // Legacy
    }

    return GridLine(
      id: json['id'],
      isVertical: json['isVertical'] as bool,
      position: (json['position'] as num).toDouble(),
      crossStart: start,
      crossEnd: end,
    );
  }
}

class GridCell {
  final Rect rect; // 0..1
  GridCell(this.rect);
}

class VisualLine {
  final GridLine line;
  final Offset start; // 0..1
  final Offset end;   // 0..1
  
  VisualLine(this.line, this.start, this.end);
}

class GridMetadata {
  final String id;
  final String name;
  final List<GridLine> lines;
  final int colorValue;
  final IconData icon;

  GridMetadata({
    required this.id,
    required this.name,
    required this.lines,
    this.colorValue = 0xFFFFAB40, // orangeAccent
    this.icon = Icons.grid_on_rounded,
  });

  Color get color => Color(colorValue);

  GridMetadata copyWith({
    String? id,
    String? name,
    List<GridLine>? lines,
    int? colorValue,
    IconData? icon,
  }) {
    return GridMetadata(
      id: id ?? this.id,
      name: name ?? this.name,
      lines: lines ?? List.from(this.lines),
      colorValue: colorValue ?? this.colorValue,
      icon: icon ?? this.icon,
    );
  }

  // --- ЯДРО АЛГОРИТМА IN-BOX СЕТКИ ---

  List<GridCell> computeCells() {
    List<GridCell> cells = [GridCell(const Rect.fromLTWH(0, 0, 1, 1))]; // Начальный холст

    for (var line in lines) {
      cells = _splitCells(cells, line);
    }

    return cells;
  }

  List<GridCell> _splitCells(List<GridCell> currentCells, GridLine line) {
    List<GridCell> nextCells = [];
    for (var cell in currentCells) {
      if (line.isVertical) {
        bool intersectsX = line.position > cell.rect.left + 0.001 && line.position < cell.rect.right - 0.001;
        bool intersectsY = (line.crossEnd > cell.rect.top + 0.001) && (line.crossStart < cell.rect.bottom - 0.001);
        
        if (intersectsX && intersectsY) {
          nextCells.add(GridCell(Rect.fromLTRB(cell.rect.left, cell.rect.top, line.position, cell.rect.bottom)));
          nextCells.add(GridCell(Rect.fromLTRB(line.position, cell.rect.top, cell.rect.right, cell.rect.bottom)));
        } else {
          nextCells.add(cell);
        }
      } else {
        bool intersectsY = line.position > cell.rect.top + 0.001 && line.position < cell.rect.bottom - 0.001;
        bool intersectsX = (line.crossEnd > cell.rect.left + 0.001) && (line.crossStart < cell.rect.right - 0.001);
        
        if (intersectsY && intersectsX) {
          nextCells.add(GridCell(Rect.fromLTRB(cell.rect.left, cell.rect.top, cell.rect.right, line.position)));
          nextCells.add(GridCell(Rect.fromLTRB(cell.rect.left, line.position, cell.rect.right, cell.rect.bottom)));
        } else {
          nextCells.add(cell);
        }
      }
    }
    return nextCells;
  }

  List<VisualLine> computeVisualLines() {
    List<VisualLine> vLines = [];
    for (var line in lines) {
      if (line.isVertical) {
         vLines.add(VisualLine(line, Offset(line.position, line.crossStart), Offset(line.position, line.crossEnd)));
      } else {
         vLines.add(VisualLine(line, Offset(line.crossStart, line.position), Offset(line.crossEnd, line.position)));
      }
    }
    return vLines;
  }

  factory GridMetadata.fromMode(GridMode mode, {GridMetadata? customData}) {
    if (mode == GridMode.custom && customData != null) {
      return customData;
    }
    switch (mode) {
      case GridMode.system:
        return GridMetadata(
          id: 'system',
          name: 'Системный',
          lines: [
            GridLine(id: 's_v1', isVertical: true, position: 10 / 16),
            GridLine(id: 's_h1', isVertical: false, position: 6 / 9),
          ],
          icon: Icons.settings_input_component,
        );
      case GridMode.grid_2x2:
        return GridMetadata(
          id: 'grid_2x2',
          name: 'Сетка 2x2',
          lines: [
            GridLine(id: 'g2_v1', isVertical: true, position: 0.5),
            GridLine(id: 'g2_h1', isVertical: false, position: 0.5),
          ],
          icon: Icons.grid_view_rounded,
        );
      case GridMode.grid_3x3:
        return GridMetadata(
          id: 'grid_3x3',
          name: 'Сетка 3x3',
          lines: [
            GridLine(id: 'g3_v1', isVertical: true, position: 1 / 3),
            GridLine(id: 'g3_v2', isVertical: true, position: 2 / 3),
            GridLine(id: 'g3_h1', isVertical: false, position: 1 / 3),
            GridLine(id: 'g3_h2', isVertical: false, position: 2 / 3),
          ],
          icon: Icons.grid_on_rounded,
        );
      case GridMode.custom:
        return customData ?? GridMetadata(
          id: 'custom_init',
          name: 'Новая сетка',
          lines: [],
        );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'lines': lines.map((l) => l.toJson()).toList(),
      'color': colorValue,
      'icon': icon.codePoint,
    };
  }

  factory GridMetadata.fromJson(Map<String, dynamic> json) {
    List<GridLine> parsedLines = [];
    if (json.containsKey('lines')) {
      parsedLines = (json['lines'] as List).map((l) => GridLine.fromJson(l)).toList();
    } else {
      // Legacy support for migrations
      int inc = 0;
      if (json['v'] != null) {
        for (var h in json['v']) {
          parsedLines.add(GridLine(id: 'mig_v_${inc++}', isVertical: false, position: h));
        }
      }
      if (json['h'] != null) {
        for (var v in json['h']) {
          parsedLines.add(GridLine(id: 'mig_h_${inc++}', isVertical: true, position: v));
        }
      }
    }

    return GridMetadata(
      id: json['id'],
      name: json['name'],
      lines: parsedLines,
      colorValue: json['color'],
      icon: IconData(json['icon'] ?? Icons.grid_on_rounded.codePoint, fontFamily: 'MaterialIcons'),
    );
  }
}
