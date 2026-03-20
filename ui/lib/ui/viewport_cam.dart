import 'package:flutter/material.dart';
import 'package:camera_macos/camera_macos.dart';
import '../../backend/vision_service.dart';

class ViewportCam extends StatefulWidget {
  const ViewportCam({super.key});

  @override
  State<ViewportCam> createState() => _ViewportCamState();
}

class _ViewportCamState extends State<ViewportCam> {
  // CameraMacOSController? _controller; // Убрано, так как не используется
  List<CameraMacOSDevice> _cameras = [];
  bool _isInitialized = false;
  CameraMacOSDevice? _selectedCamera;

  @override
  void initState() {
    super.initState();
    _initCameras();
  }

  Future<void> _initCameras() async {
    try {
      _cameras = await CameraMacOS.instance.listDevices(deviceType: CameraMacOSDeviceType.video);
      debugPrint('Fetched ${_cameras.length} cameras on macOS');
      for (var cam in _cameras) {
        debugPrint('Camera: ${cam.localizedName} (ID: ${cam.deviceId})');
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error fetching cameras: $e');
    }
  }

  void _onCameraSelected(CameraMacOSDevice camera) {
    setState(() {
      _selectedCamera = camera;
      _isInitialized = true;
    });
  }

  void _stopCamera() {
    setState(() {
      _selectedCamera = null;
      _isInitialized = false;
      // _controller = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[850],
      child: Stack(
        children: [
          // Основной контент (Превью или заглушка)
          Positioned.fill(
            bottom: 50,
            child: _isInitialized && _selectedCamera != null
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: CameraMacOSView(
                              key: ValueKey(_selectedCamera!.deviceId),
                              deviceId: _selectedCamera!.deviceId,
                              cameraMode: CameraMacOSMode.video,
                              fit: BoxFit.cover,
                              onCameraInizialized: (controller) {},
                            ),
                          ),
                          // Оверлей детекции лиц
                          ValueListenableBuilder<List<FaceDetection>>(
                            valueListenable: VisionService().detectionsNotifier,
                            builder: (context, detections, _) {
                              if (detections.isNotEmpty) {
                                debugPrint('VIEWPORT: Received ${detections.length} detections');
                              }
                              return Stack(
                                children: detections.map((d) => _buildDetectionBox(d, constraints.biggest)).toList(),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam_outlined, size: 64, color: Colors.white24),
                      const SizedBox(height: 16),
                      const Text(
                        'ADD NEW CAM',
                        style: TextStyle(
                          color: Colors.white24,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
          ),

          // Нижняя плашка со списком камер
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 50,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18, color: Colors.blueAccent),
                    tooltip: 'Обновить список камер',
                    onPressed: _initCameras,
                  ),
                  if (_isInitialized)
                    IconButton(
                      icon: const Icon(Icons.power_settings_new, size: 18, color: Colors.redAccent),
                      tooltip: 'Отключить камеру',
                      onPressed: _stopCamera,
                    ),
                  const VerticalDivider(width: 1, color: Colors.white10, indent: 15, endIndent: 15),
                  Expanded(
                    child: _cameras.isEmpty
                        ? const Center(
                            child: Text(
                              'Камеры не найдены. Проверьте разрешения в Системных настройках.',
                              style: TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            itemCount: _cameras.length,
                            itemBuilder: (context, index) {
                              final camera = _cameras[index];
                              final isSelected = _selectedCamera?.deviceId == camera.deviceId;

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                child: InkWell(
                                  onTap: () => _onCameraSelected(camera),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.blueAccent.withValues(alpha: 0.2) : Colors.white10,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: isSelected ? Colors.blueAccent : Colors.transparent,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      camera.localizedName ?? 'Camera ${index + 1}',
                                      style: TextStyle(
                                        color: isSelected ? Colors.blueAccent : Colors.white70,
                                        fontSize: 11,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                              );
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

  Widget _buildDetectionBox(FaceDetection detection, Size viewportSize) {
    // В реальности координаты детекции (0-1) нужно мапить на размер вьюпорта.
    // Если boundingBox в VisionService уже в пикселях симуляции, используем их напрямую или мапим.
    // Для нашего примера используем упрощенный маппинг.
    return Positioned(
      left: detection.boundingBox.left,
      top: detection.boundingBox.top,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: detection.boundingBox.width,
            height: detection.boundingBox.height,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF03A9F4), width: 2),
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: 4, spreadRadius: 1),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: const BoxDecoration(
              color: Color(0xFF03A9F4),
              borderRadius: BorderRadius.only(bottomRight: Radius.circular(4)),
            ),
            child: Text(
              '${detection.name ?? "Unknown"} ${(detection.confidence * 100).round()}%',
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
