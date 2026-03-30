import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// Данные о распознанном лице
class FaceDetection {
  final Rect boundingBox;
  final String? name;
  final double confidence;
  final List<Offset> oval; // Точки контура лица

  FaceDetection({
    required this.boundingBox,
    this.name,
    this.confidence = 0.0,
    this.oval = const [],
  });

  Map<String, dynamic> toJson() => {
    'x': boundingBox.left,
    'y': boundingBox.top,
    'w': boundingBox.width,
    'h': boundingBox.height,
    'name': name,
    'confidence': confidence,
    'oval': oval.map((o) => {'x': o.dx, 'y': o.dy}).toList(),
  };
}

/// Данные о распознанном скелете тела
class PoseDetection {
  final List<PosePoint> points;

  PoseDetection({required this.points});
}

class PosePoint {
  final double x;
  final double y;
  final double z;
  final double visibility;

  PosePoint({
    required this.x,
    required this.y,
    required this.z,
    required this.visibility,
  });
}

/// Запись в базе данных лиц
class FaceRecord {
  final String id;
  final String name;
  final String? imagePath;

  FaceRecord({
    required this.id,
    required this.name,
    this.imagePath,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'imagePath': imagePath,
  };

  factory FaceRecord.fromJson(Map<String, dynamic> json) {
    return FaceRecord(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      imagePath: json['imagePath'],
    );
  }
}

/// Сервис для управления внешними базами данных лиц
class FaceDbService {
  static final String dbDir = p.join(Directory.current.path, '..', 'vision_db');

  static Future<void> init() async {
    final dir = Directory(dbDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  static Future<List<String>> listDatabases() async {
    await init();
    final dir = Directory(dbDir);
    final List<String> dbs = [];
    try {
      final files = await dir.list().toList();
      for (var f in files) {
        if (f is File && f.path.endsWith('.json')) {
          dbs.add(p.basenameWithoutExtension(f.path));
        }
      }
    } catch (_) {}
    return dbs;
  }

  static Future<List<Map<String, dynamic>>> loadDatabase(String name) async {
    final file = File(p.join(dbDir, '$name.json'));
    if (!await file.exists()) return [];
    try {
      final content = await file.readAsString();
      final data = jsonDecode(content);
      if (data is Map && data['faces'] is List) {
        return List<Map<String, dynamic>>.from(data['faces']);
      }
    } catch (_) {}
    return [];
  }

  static Future<void> saveDatabase(String name, List<dynamic> faces) async {
    final file = File(p.join(dbDir, '$name.json'));
    final data = {
      'name': name,
      'updated': DateTime.now().toIso8601String(),
      'faces': faces,
    };
    await file.writeAsString(jsonEncode(data));
  }
  
  static Future<void> createEmpty(String name) async {
    await saveDatabase(name, []);
  }
}

/// Конфигурация скрипта — что именно включено
class ScriptConfig {
  final bool faceEnabled;
  final bool poseEnabled;
  final String? cameraId;
  final double fps;

  const ScriptConfig({
    this.faceEnabled = false,
    this.poseEnabled = false,
    this.cameraId,
    this.fps = 5.0,
  });

  bool get isActive => faceEnabled || poseEnabled;
}

/// Сервис компьютерного зрения (Face Recognition + MediaPipe Backend)
class VisionService {
  static final VisionService _instance = VisionService._internal();
  factory VisionService() => _instance;
  VisionService._internal();

  bool _isInitialized = false;
  bool _isTrained = false;

  /// Карта конфигураций для всех запущенных скриптов {имя_скрипта: конфиг}
  final Map<String, ScriptConfig> _scriptsConfigs = {};

  /// Итоговая объединенная конфигурация
  final ValueNotifier<ScriptConfig?> configNotifier = ValueNotifier(null);
  
  void updateConfig(String name, ScriptConfig? config) {
    if (config == null) {
      _scriptsConfigs.remove(name);
    } else {
      _scriptsConfigs[name] = config;
    }
    _recalculateMergedConfig();
  }

  void _recalculateMergedConfig() {
    if (_scriptsConfigs.isEmpty) {
      configNotifier.value = null;
      return;
    }

    bool face = false;
    bool pose = false;
    String? cam;
    double fps = 1.0;

    for (var cfg in _scriptsConfigs.values) {
      if (cfg.faceEnabled) face = true;
      if (cfg.poseEnabled) pose = true;
      if (cfg.cameraId != null) cam = cfg.cameraId; // Берем последнее или по приоритету? Пока последнее.
      if (cfg.fps > fps) fps = cfg.fps; // Берем максимальный FPS
    }

    configNotifier.value = ScriptConfig(
      faceEnabled: face,
      poseEnabled: pose,
      cameraId: cam,
      fps: fps,
    );
  }
  
  // Визуальные настройки
  final ValueNotifier<Color> faceColorNotifier = ValueNotifier(const Color(0xFF03A9F4));
  final ValueNotifier<Color> poseColorNotifier = ValueNotifier(const Color(0xFF4CAF50));
  final ValueNotifier<bool> showPoseConnectionsNotifier = ValueNotifier(true);

  final ValueNotifier<List<FaceDetection>> detectionsNotifier = ValueNotifier([]);
  final ValueNotifier<List<PoseDetection>> posesNotifier = ValueNotifier([]);
  final ValueNotifier<List<String>> logsNotifier = ValueNotifier([]);
  
  final _logController = StreamController<String>.broadcast();
  Stream<String> get logStream => _logController.stream;

  Process? _pythonProcess;

  void addLog(String message) {
    final time = DateTime.now().toString().split(' ').last.split('.').first;
    final fullMsg = '[$time] $message';
    _logController.add('$fullMsg\r\n'); // \r\n для терминала
    
    final currentLogs = List<String>.from(logsNotifier.value);
    currentLogs.insert(0, fullMsg);
    if (currentLogs.length > 50) currentLogs.removeLast();
    logsNotifier.value = currentLogs;
    debugPrint('VISION LOG: $fullMsg');
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
  }

  /// Запуск Python-бэкенда
  Future<void> startBackend(String projectRoot) async {
    if (_pythonProcess != null) return;

    final venvPython = p.join(projectRoot, 'backend', 'venv', 'bin', 'python');
    final mainPy = p.join(projectRoot, 'backend', 'main.py');

    debugPrint('VISION: Starting Python backend: $venvPython $mainPy');
    
    try {
      _pythonProcess = await Process.start(venvPython, [mainPy]);
      
      _pythonProcess!.stdout.transform(utf8.decoder).listen((data) {
        debugPrint('PYTHON STDOUT: $data');
      });

      _pythonProcess!.stderr.transform(utf8.decoder).listen((data) {
        debugPrint('PYTHON STDERR: $data');
      });

      // Даем серверу время на запуск
      await Future.delayed(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('VISION: Failed to start Python backend: $e');
    }
  }

  /// Остановка Python-бэкенда
  void stopBackend() {
    _pythonProcess?.kill();
    _pythonProcess = null;
  }

  /// Полная остановка всего: бэкенд + данные + конфигурация
  void stopAll() {
    stopBackend();
    _scriptsConfigs.clear();
    configNotifier.value = null;
    detectionsNotifier.value = [];
    posesNotifier.value = [];
    _isTrained = false;
    _lastFaceConfigHash = null;
    addLog('System: Все скрипты остановлены');
  }

  String? _lastFaceConfigHash;

  /// Обучение нейросети на базе лиц из блоков
  Future<void> train(List<Map<String, dynamic>> persons) async {
    final currentHash = jsonEncode(persons);
    if (currentHash == _lastFaceConfigHash && _isTrained) {
      debugPrint('VISION: Training skipped (no changes)');
      return;
    }

    try {
      final List<Map<String, dynamic>> trainingData = [];
      
      for (final p in persons) {
        final List<String> imagesBase64 = [];
        final List faces = p['faces'] ?? [];
        
        for (final face in faces) {
          final path = face['path'] as String?;
          if (path != null && File(path).existsSync()) {
            final bytes = await File(path).readAsBytes();
            imagesBase64.add(base64Encode(bytes));
          }
        }
        
        if (imagesBase64.isNotEmpty) {
          trainingData.add({
            'name': p['name'],
            'images': imagesBase64,
          });
        }
      }

      if (trainingData.isEmpty) {
        _isTrained = false;
        _lastFaceConfigHash = null;
        return;
      }

      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/train'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'persons': trainingData}),
      );

      if (response.statusCode == 200) {
        debugPrint('VISION: Training successful: ${response.body}');
        _isTrained = true;
        _lastFaceConfigHash = currentHash;
      } else {
        debugPrint('VISION: Training failed: ${response.statusCode}');
        _isTrained = false;
      }
    } catch (e) {
      debugPrint('VISION: Error during training: $e');
      _isTrained = false;
    }
  }

  /// Обработка кадра через Python-бэкенд
  Future<List<FaceDetection>> processFrame(Uint8List imageBytes) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://127.0.0.1:8000/detect'),
      );
      
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: 'frame.jpg',
      ));

      final response = await request.send();
      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final json = jsonDecode(respStr);
        final List<dynamic> detectionsJson = json['detections'];

        return detectionsJson.map((d) {
          final List<dynamic> ovalJson = d['oval'] ?? [];
          final oval = ovalJson.map((p) => Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble())).toList();

          return FaceDetection(
            boundingBox: Rect.fromLTWH(
              (d['x'] as num).toDouble(), 
              (d['y'] as num).toDouble(), 
              (d['w'] as num).toDouble(), 
              (d['h'] as num).toDouble()
            ),
            name: d['name'],
            confidence: (d['confidence'] as num).toDouble(),
            oval: oval,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('VISION: Error processing frame: $e');
    }
    return [];
  }

  /// Комплексная обработка кадра (лица + позы)
  Future<void> processVision(Uint8List imageBytes) async {
    final config = configNotifier.value;
    if (config == null || !config.isActive) return;

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://127.0.0.1:8000/detect'),
      );
      
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: 'frame.jpg',
      ));

      final response = await request.send();
      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final json = jsonDecode(respStr);
        
        // Парсим лица только если face включён
        if (config.faceEnabled) {
          final List<dynamic> detectionsJson = json['detections'] ?? [];
          final faces = detectionsJson.map((d) {
            final String name = d['name'] ?? 'Unknown';
            final double x = (d['x'] as num).toDouble();
            final double y = (d['y'] as num).toDouble();
            
            if (name != 'Unknown') {
              addLog('Face: $name at (${(x * 100).round()}%, ${(y * 100).round()}%)');
            }

            final List<dynamic> ovalJson = d['oval'] ?? [];
            final oval = ovalJson.map((p) => Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble())).toList();

            return FaceDetection(
              boundingBox: Rect.fromLTWH(
                (d['x'] as num).toDouble(), 
                (d['y'] as num).toDouble(), 
                (d['w'] as num).toDouble(), 
                (d['h'] as num).toDouble()
              ),
              name: d['name'],
              confidence: (d['confidence'] as num).toDouble(),
              oval: oval,
            );
          }).toList();
          detectionsNotifier.value = faces;
        } else {
          detectionsNotifier.value = [];
        }

        // Парсим позы только если pose включён
        if (config.poseEnabled) {
          final List<dynamic> posesJson = json['poses'] ?? [];
          final poses = posesJson.map((pList) {
            final pts = (pList as List).map((pt) => PosePoint(
              x: (pt['x'] as num).toDouble(),
              y: (pt['y'] as num).toDouble(),
              z: (pt['z'] as num).toDouble(),
              visibility: (pt['v'] as num).toDouble(),
            )).toList();

            if (pts.length > 32) {
              final lw = pts[15];
              final rw = pts[16];
              if (lw.visibility > 0.5) addLog('Pose: Left Hand at (${(lw.x * 100).round()}%, ${(lw.y * 100).round()}%)');
              if (rw.visibility > 0.5) addLog('Pose: Right Hand at (${(rw.x * 100).round()}%, ${(rw.y * 100).round()}%)');
            }

            return PoseDetection(points: pts);
          }).toList();
          posesNotifier.value = poses;
        } else {
          posesNotifier.value = [];
        }
      }
    } catch (e) {
      debugPrint('VISION: Error in processVision: $e');
    }
  }
}
