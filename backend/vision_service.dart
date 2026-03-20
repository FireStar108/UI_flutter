import 'dart:convert';
import 'dart:io';
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

  List<FaceRecord> get faceDb => _faceDb;

  Future<void> initialize() async {
    if (_isInitialized) return;
    // В реальном приложении здесь была бы загрузка БД из файла
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
    // Сохранение в файл...
  }

  /// Удалить лицо из базы
  void removeFace(String id) {
    _faceDb.removeWhere((f) => f.id == id);
  }

  /// "Обработка" кадра (симуляция для текущей реализации)
  /// В будущем здесь будет вызов TFLite или медиапайп
  Future<List<FaceDetection>> processFrame(dynamic frameData, {double threshold = 0.6}) async {
    // Симуляция: если в базе есть люди, "находим" их с некоторой вероятностью
    if (_faceDb.isEmpty) return [];

    // Для демонстрации возвращаем случайные детекции, если имитируем работу
    // В реальном сценарии мы бы прогнали кадр через нейронку
    return []; 
  }

  /// Метод для генерации фиктивных данных детекции (для UI/Viewport)
  List<FaceDetection> generateMockDetections() {
    if (_faceDb.isEmpty) return [];
    
    // Возвращаем детекцию для первого человека в базе для теста
    return [
      FaceDetection(
        boundingBox: const Rect.fromLTWH(100, 100, 150, 150),
        name: _faceDb.first.name,
        confidence: 0.98,
      )
    ];
  }
}
