import 'dart:io';

/// Информация о камере
class CameraInfo {
  final String deviceId;
  final String name;

  const CameraInfo({required this.deviceId, required this.name});

  @override
  String toString() => 'CameraInfo($name, $deviceId)';
}

/// Сервис обнаружения доступных камер (macOS)
class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  List<CameraInfo> _cameras = [];
  bool _loaded = false;

  List<CameraInfo> get cameras => _cameras;

  /// Получить список камер через system_profiler (macOS)
  Future<List<CameraInfo>> loadCameras() async {
    if (_loaded) return _cameras;

    try {
      if (Platform.isMacOS) {
        final result = await Process.run(
          'system_profiler',
          ['SPCameraDataType'],
        );
        if (result.exitCode == 0) {
          _cameras = _parseMacOSCameras(result.stdout as String);
        }
      }
      // Fallback — добавляем камеру по умолчанию если пусто
      if (_cameras.isEmpty) {
        _cameras = [const CameraInfo(deviceId: '0', name: 'Default Camera')];
      }
    } catch (e) {
      _cameras = [const CameraInfo(deviceId: '0', name: 'Default Camera')];
    }

    _loaded = true;
    return _cameras;
  }

  /// Принудительно обновить список
  Future<List<CameraInfo>> refreshCameras() async {
    _loaded = false;
    return loadCameras();
  }

  /// Парсинг вывода system_profiler SPCameraDataType
  List<CameraInfo> _parseMacOSCameras(String output) {
    final List<CameraInfo> cameras = [];
    final lines = output.split('\n');
    String? currentName;
    String? currentId;

    for (final line in lines) {
      final trimmed = line.trim();

      // Имя камеры — строка которая заканчивается на ':'  и не содержит "Camera:"
      if (trimmed.endsWith(':') && !trimmed.startsWith('Camera') && !trimmed.contains('SPCameraDataType')) {
        // Если предыдущая камера была, добавляем
        if (currentName != null) {
          cameras.add(CameraInfo(
            deviceId: currentId ?? cameras.length.toString(),
            name: currentName,
          ));
        }
        currentName = trimmed.substring(0, trimmed.length - 1).trim();
        currentId = null;
      }

      // Unique ID
      if (trimmed.startsWith('Unique ID:')) {
        currentId = trimmed.substring('Unique ID:'.length).trim();
      }
      if (trimmed.startsWith('Model ID:') && currentId == null) {
        currentId = trimmed.substring('Model ID:'.length).trim();
      }
    }

    // Последняя камера
    if (currentName != null) {
      cameras.add(CameraInfo(
        deviceId: currentId ?? cameras.length.toString(),
        name: currentName,
      ));
    }

    return cameras;
  }
}
