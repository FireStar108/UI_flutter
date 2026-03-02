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

class GridMetadata {
  final String id;
  final String name;
  final List<double> horizontalSplits; // 0..1
  final List<double> verticalSplits;   // 0..1
  final int colorValue;
  final IconData icon;

  GridMetadata({
    required this.id,
    required this.name,
    required this.horizontalSplits,
    required this.verticalSplits,
    this.colorValue = 0xFFFFAB40, // orangeAccent
    this.icon = Icons.grid_on_rounded,
  });

  Color get color => Color(colorValue);

  GridMetadata copyWith({
    String? id,
    String? name,
    List<double>? horizontalSplits,
    List<double>? verticalSplits,
    int? colorValue,
    IconData? icon,
  }) {
    return GridMetadata(
      id: id ?? this.id,
      name: name ?? this.name,
      horizontalSplits: horizontalSplits ?? List.from(this.horizontalSplits),
      verticalSplits: verticalSplits ?? List.from(this.verticalSplits),
      colorValue: colorValue ?? this.colorValue,
      icon: icon ?? this.icon,
    );
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
          horizontalSplits: [10 / 16],
          verticalSplits: [6 / 9],
          icon: Icons.settings_input_component,
        );
      case GridMode.grid_2x2:
        return GridMetadata(
          id: 'grid_2x2',
          name: 'Сетка 2x2',
          horizontalSplits: [0.5],
          verticalSplits: [0.5],
          icon: Icons.grid_view_rounded,
        );
      case GridMode.grid_3x3:
        return GridMetadata(
          id: 'grid_3x3',
          name: 'Сетка 3x3',
          horizontalSplits: [1 / 3, 2 / 3],
          verticalSplits: [1 / 3, 2 / 3],
          icon: Icons.grid_on_rounded,
        );
      case GridMode.custom:
        return customData ?? GridMetadata(
          id: 'custom_init',
          name: 'Новая сетка',
          horizontalSplits: [],
          verticalSplits: [],
        );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'h': horizontalSplits,
      'v': verticalSplits,
      'color': colorValue,
      'icon': icon.codePoint,
    };
  }

  factory GridMetadata.fromJson(Map<String, dynamic> json) {
    return GridMetadata(
      id: json['id'],
      name: json['name'],
      horizontalSplits: List<double>.from(json['h']),
      verticalSplits: List<double>.from(json['v']),
      colorValue: json['color'],
      icon: IconData(json['icon'] ?? Icons.grid_on_rounded.codePoint, fontFamily: 'MaterialIcons'),
    );
  }
}
