import 'package:flutter/material.dart';
import 'package:camera_macos/camera_macos.dart';
import '../backend/vision_service.dart';

class ViewportCam extends StatefulWidget {
  const ViewportCam({super.key});

  @override
  State<ViewportCam> createState() => _ViewportCamState();
}

class _ViewportCamState extends State<ViewportCam> {
  CameraMacOSController? _controller;
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
    _startAnalysisLoop();
  }

  void _startAnalysisLoop() async {
    while (_selectedCamera != null && mounted) {
      final vision = VisionService();
      final config = vision.configNotifier.value;
      
      // Анализируем только если конфиг активен И камера совпадает
      if (_controller != null && config != null && config.isActive && config.cameraId == _selectedCamera?.deviceId) {
        try {
          final imageData = await _controller!.takePicture();
          if (imageData != null && imageData.bytes != null) {
            await vision.processVision(imageData.bytes!);
          }
        } catch (e) {
          debugPrint('VIEWPORT: Error in analysis loop: $e');
        }
      } else {
        // Если условия не соблюдены — очищаем
        if (vision.detectionsNotifier.value.isNotEmpty) {
          vision.detectionsNotifier.value = [];
        }
        if (vision.posesNotifier.value.isNotEmpty) {
          vision.posesNotifier.value = [];
        }
      }
      
      // FPS из конфигурации (минимум 33мс для 30fps)
      final fps = config?.fps ?? 5.0;
      final interval = (1000 / fps).round().clamp(33, 2000);
      await Future.delayed(Duration(milliseconds: interval));
    }
  }

  void _stopCamera() {
    setState(() {
      _selectedCamera = null;
      _isInitialized = false;
      _controller = null;
    });
    VisionService().detectionsNotifier.value = [];
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
                              onCameraInizialized: (controller) {
                                setState(() {
                                  _controller = controller;
                                });
                              },
                            ),
                          ),
                          // Оверлей детекции лиц
                          ValueListenableBuilder<List<FaceDetection>>(
                            valueListenable: VisionService().detectionsNotifier,
                            builder: (context, detections, _) {
                              return Stack(
                                children: detections.map((d) => _buildDetectionBox(d, constraints.biggest)).toList(),
                              );
                            },
                          ),
                          // Оверлей детекции тела (Pose)
                          ValueListenableBuilder<List<PoseDetection>>(
                            valueListenable: VisionService().posesNotifier,
                            builder: (context, poses, _) {
                              return Stack(
                                children: poses.map((p) => _buildPoseOverlay(p, constraints.biggest)).toList(),
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
    return Positioned.fill(
      child: CustomPaint(
        painter: FacePainter(
          detection: detection,
          viewportSize: viewportSize,
        ),
      ),
    );
  }

  Widget _buildPoseOverlay(PoseDetection pose, Size viewportSize) {
    return Positioned.fill(
      child: CustomPaint(
        painter: PosePainter(
          pose: pose,
          viewportSize: viewportSize,
        ),
      ),
    );
  }
}

class FacePainter extends CustomPainter {
  final FaceDetection detection;
  final Size viewportSize;

  FacePainter({required this.detection, required this.viewportSize});

  @override
  void paint(Canvas canvas, Size size) {
    // Рисуем квадратную рамку (как просил пользователь)
    final rect = Rect.fromLTWH(
      detection.boundingBox.left * viewportSize.width,
      detection.boundingBox.top * viewportSize.height,
      detection.boundingBox.width * viewportSize.width,
      detection.boundingBox.height * viewportSize.height,
    );

    final color = VisionService().faceColorNotifier.value;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Рамка с небольшим свечением
    canvas.drawRect(rect, paint);
    canvas.drawRect(rect, Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

    // Текст с именем
    final name = detection.name ?? "Unknown";
    final textPainter = TextPainter(
      text: TextSpan(
        text: ' $name ${(detection.confidence * 100).round()}% ',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          backgroundColor: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    
    textPainter.paint(canvas, Offset(rect.left, rect.top - 20));
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) => true;
}

class PosePainter extends CustomPainter {
  final PoseDetection pose;
  final Size viewportSize;

  PosePainter({required this.pose, required this.viewportSize});

  @override
  void paint(Canvas canvas, Size size) {
    final vision = VisionService();
    final color = vision.poseColorNotifier.value;
    final showConnections = vision.showPoseConnectionsNotifier.value;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4.0
      ..style = PaintingStyle.fill;

    // Список соединений (индексы MediaPipe Pose)
    final connections = [
      [11, 12], [11, 23], [12, 24], [23, 24], // Torso
      [11, 13], [13, 15], [12, 14], [14, 16], // Arms
      [23, 25], [25, 27], [24, 26], [26, 28], // Legs
      [27, 29], [29, 31], [27, 31],           // Left foot
      [28, 30], [30, 32], [28, 32],           // Right foot
    ];

    // Рисуем линии
    if (showConnections) {
      for (final connection in connections) {
        final p1 = pose.points[connection[0]];
        final p2 = pose.points[connection[1]];

        if (p1.visibility > 0.5 && p2.visibility > 0.5) {
          canvas.drawLine(
            Offset(p1.x * viewportSize.width, p1.y * viewportSize.height),
            Offset(p2.x * viewportSize.width, p2.y * viewportSize.height),
            paint,
          );
        }
      }
    }

    // Рисуем точки (суставы)
    for (final p in pose.points) {
      if (p.visibility > 0.5) {
        canvas.drawCircle(
          Offset(p.x * viewportSize.width, p.y * viewportSize.height),
          3.0,
          pointPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) => true;
}
