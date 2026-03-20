import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';

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

/// Сервис компьютерного зрения (Face Recognition)
class VisionService {
  static final VisionService _instance = VisionService._internal();
  factory VisionService() => _instance;
  VisionService._internal();

  final List<FaceRecord> _faceDb = [];
  bool _isInitialized = false;
  final ValueNotifier<List<FaceDetection>> detectionsNotifier = ValueNotifier([]);

  List<FaceRecord> get faceDb => _faceDb;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
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

  /// "Обработка" кадра (симуляция)
  Future<List<FaceDetection>> processFrame(dynamic frameData, {double threshold = 0.6}) async {
    return []; 
  }

  /// Метод для генерации фиктивных данных детекции (для UI/Viewport)
  List<FaceDetection> generateMockDetections() {
    // Если база пуста, показываем "Unknown" для теста
    final String name = _faceDb.isEmpty ? "Unknown" : _faceDb.first.name;
    
    // Используем время для более размашистого движения
    final double time = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final double offsetX = 50 * math.sin(time);
    final double offsetY = 30 * math.cos(time * 1.5);

    return [
      FaceDetection(
        boundingBox: Rect.fromLTWH(100 + offsetX, 80 + offsetY, 150, 150),
        name: name,
        confidence: 0.85 + (0.1 * math.sin(time * 2).abs()),
      )
    ];
  }
}
