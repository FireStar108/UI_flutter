import 'package:camera_macos/camera_macos.dart';

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

  /// Загрузить список камер
  Future<List<CameraInfo>> loadCameras() => getAvailableCameras();

  /// Обновить список камер
  Future<List<CameraInfo>> refreshCameras() => getAvailableCameras();

  /// Получить список доступных камер через официальный пакет camera_macos
  Future<List<CameraInfo>> getAvailableCameras() async {
    try {
      final devices = await CameraMacOS.instance.listDevices(
        deviceType: CameraMacOSDeviceType.video,
      );
      
      return devices.map((d) => CameraInfo(
        deviceId: d.deviceId ?? 'unknown',
        name: d.localizedName ?? 'Unknown Camera',
      )).toList();
    } catch (e) {
      return [];
    }
  }
}
