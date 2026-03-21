import 'dart:convert';
import 'dart:io';
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
      id: json['id'],
      name: json['name'],
      imagePath: json['imagePath'],
    );
  }
}

/// Сервис компьютерного зрения (Face Recognition + MediaPipe Backend)
class VisionService {
  static final VisionService _instance = VisionService._internal();
  factory VisionService() => _instance;
  VisionService._internal();

  bool _isInitialized = false;
  bool isAnalysisEnabled = false; // Флаг: разрешено ли анализировать лица (есть ли связь в скрипте)
  final ValueNotifier<List<FaceDetection>> detectionsNotifier = ValueNotifier([]);
  Process? _pythonProcess;

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
    detectionsNotifier.value = [];
  }

  /// Обучение нейросети на базе лиц из блоков
  Future<void> train(List<Map<String, dynamic>> persons) async {
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
            'name': p['name'], // Это можнт быть имя ноды или общее имя
            'images': imagesBase64,
          });
        }
      }

      if (trainingData.isEmpty) return;

      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/train'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'persons': trainingData}),
      );

      if (response.statusCode == 200) {
        debugPrint('VISION: Training successful: ${response.body}');
      } else {
        debugPrint('VISION: Training failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('VISION: Error during training: $e');
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
              (num.parse(d['y'].toString())).toDouble(), 
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

  /// Метод для генерации данных (уже не нужен, но оставим для совместимости или уберем)
  List<FaceDetection> generateMockDetections() {
    // В новой реализации мы не генерим моки, а ждем данных от processFrame
    return detectionsNotifier.value;
  }
}
