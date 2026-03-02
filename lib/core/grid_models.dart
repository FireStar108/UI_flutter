import 'package:flutter/material.dart';

enum GridMode { system, grid_2x2, grid_3x3, cinematic }

class GridMetadata {
  final List<double> horizontalSplits; // 0..1
  final List<double> verticalSplits;   // 0..1

  GridMetadata({required this.horizontalSplits, required this.verticalSplits});

  factory GridMetadata.fromMode(GridMode mode) {
    switch (mode) {
      case GridMode.system:
        return GridMetadata(
          horizontalSplits: [10 / 16],
          verticalSplits: [6 / 9],
        );
      case GridMode.grid_2x2:
        return GridMetadata(
          horizontalSplits: [0.5],
          verticalSplits: [0.5],
        );
      case GridMode.grid_3x3:
        return GridMetadata(
          horizontalSplits: [1 / 3, 2 / 3],
          verticalSplits: [1 / 3, 2 / 3],
        );
      case GridMode.cinematic:
        return GridMetadata(
          horizontalSplits: [0.25, 0.5, 0.75],
          verticalSplits: [0.25, 0.5, 0.75, 0.12, 0.88], // Cinematic has extra bars
        );
    }
  }
}
