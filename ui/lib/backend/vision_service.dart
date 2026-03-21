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

  FaceDetection({
    required this.boundingBox,
    this.name,
    this.confidence = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'x': boundingBox.left,
    'y': boundingBox.top,
    'w': boundingBox.width,
    'h': boundingBox.height,
    'name': name,
    'confidence': confidence,
  };
}

/// Запись в базе данных лиц
class FaceRecord {
  final String id;
  final String name;
  final List<double> embedding;
  final String? imagePath;

  FaceRecord({
    required this.id,
    required this.name,
    required this.embedding,
    this.imagePath,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'embedding': embedding,
    'imagePath': imagePath,
  };

  factory FaceRecord.fromJson(Map<String, dynamic> json) {
    return FaceRecord(
      id: json['id'],
      name: json['name'],
      embedding: List<double>.from(json['embedding']),
      imagePath: json['imagePath'],
    );
  }
}

/// Сервис компьютерного зрения (Face Recognition + MediaPipe Backend)
class VisionService {
  static final VisionService _instance = VisionService._internal();
  factory VisionService() => _instance;
  VisionService._internal();

  final List<FaceRecord> _faceDb = [];
  bool _isInitialized = false;
  final ValueNotifier<List<FaceDetection>> detectionsNotifier = ValueNotifier([]);
  Process? _pythonProcess;

  List<FaceRecord> get faceDb => _faceDb;

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

  /// Добавить лицо в базу
  void addFace(String name, List<double> embedding, {String? imagePath}) {
    _faceDb.add(FaceRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      embedding: embedding,
      imagePath: imagePath,
    ));
  }

  /// Удалить лицо из базы
  void removeFace(String id) {
    _faceDb.removeWhere((f) => f.id == id);
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
          // Координаты приходят нормализованные (0-1)
          // Мы пока возвращаем их как есть, а ViewportCam будет их мапить на свой размер
          return FaceDetection(
            boundingBox: Rect.fromLTWH(
              d['x'] * 1.0, 
              d['y'] * 1.0, 
              d['w'] * 1.0, 
              d['h'] * 1.0
            ),
            name: _faceDb.isEmpty ? "Unknown" : _faceDb.first.name, // Заглушка для имени пока
            confidence: d['confidence'],
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
