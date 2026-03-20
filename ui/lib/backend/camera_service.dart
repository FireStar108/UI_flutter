import 'dart:io';

/// Информация о камере
class CameraInfo {
  final String deviceId;
  final String name;

  const CameraInfo({required this.deviceId, required this.name});

  @override
  String toString() => 'CameraInfo($name, $deviceId)';
}

/// Сервис для работы с камерами на macOS
class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  /// Загрузить список камер (alias для обратной совместимости)
  Future<List<CameraInfo>> loadCameras() => getAvailableCameras();

  /// Обновить список камер (alias)
  Future<List<CameraInfo>> refreshCameras() => getAvailableCameras();

  /// Получить список доступных камер через системную утилиту system_profiler
  Future<List<CameraInfo>> getAvailableCameras() async {
    if (!Platform.isMacOS) return [];

    try {
      final result = await Process.run('system_profiler', ['SPCameraDataType']);
      if (result.exitCode != 0) return [];

      final lines = (result.stdout as String).split('\n');
      List<CameraInfo> cameras = [];
      String? currentName;
      String? currentId;

      for (var line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        if (line.startsWith('          ') && !trimmed.startsWith('Unique ID:')) {
           currentName = trimmed.replaceAll(':', '');
        } else if (trimmed.startsWith('Unique ID:')) {
          currentId = trimmed.replaceFirst('Unique ID:', '').trim();
          if (currentName != null && currentId != null) {
            cameras.add(CameraInfo(name: currentName, deviceId: currentId));
            currentName = null;
            currentId = null;
          }
        }
      }
      return cameras;
    } catch (e) {
      return [];
    }
  }
}
