// No imports needed for GridMode enum and basic class

enum GridMode {
  system,
  grid_2x2,
  grid_3x3,
  cinematic,
  custom;

  static GridMode fromModeString(String id) {
    switch (id) {
      case 'system':
        return GridMode.system;
      case 'grid_2x2':
        return GridMode.grid_2x2;
      case 'grid_3x3':
        return GridMode.grid_3x3;
      case 'cinematic':
        return GridMode.cinematic;
      case 'custom':
        return GridMode.custom;
      default:
        return GridMode.system;
    }
  }
}

class GridMetadata {
  final List<double> horizontalSplits; // 0..1
  final List<double> verticalSplits;   // 0..1

  GridMetadata({required this.horizontalSplits, required this.verticalSplits});

  GridMetadata copyWith({
    List<double>? horizontalSplits,
    List<double>? verticalSplits,
  }) {
    return GridMetadata(
      horizontalSplits: horizontalSplits ?? List.from(this.horizontalSplits),
      verticalSplits: verticalSplits ?? List.from(this.verticalSplits),
    );
  }

  factory GridMetadata.fromMode(GridMode mode, {GridMetadata? customData}) {
    if (mode == GridMode.custom && customData != null) {
      return customData;
    }
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
          verticalSplits: [0.25, 0.5, 0.75, 0.12, 0.88],
        );
      case GridMode.custom:
        return customData ?? GridMetadata(horizontalSplits: [], verticalSplits: []);
    }
  }
}
