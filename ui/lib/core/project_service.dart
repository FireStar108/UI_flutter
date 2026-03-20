import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../core/grid_models.dart';
import '../ui/window_item.dart';

class ProjectModel {
  String id;
  String name;
  String preset;
  bool useCuda;
  String directoryPath;
  String gridModeId;
  GridMetadata? gridData;
  List<WindowData> windows;

  ProjectModel({
    required this.id,
    required this.name,
    required this.directoryPath,
    this.preset = 'default',
    this.useCuda = false,
    this.gridModeId = 'system',
    this.gridData,
    List<WindowData>? windows,
  }) : windows = windows ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'preset': preset,
        'useCuda': useCuda,
        'directoryPath': directoryPath,
        'gridModeId': gridModeId,
        'gridData': gridData?.toJson(),
        'windows': windows.map((w) => w.toJson()).toList(),
      };

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Untitled',
      preset: json['preset'] ?? 'default',
      useCuda: json['useCuda'] ?? false,
      directoryPath: json['directoryPath'] ?? '',
      gridModeId: json['gridModeId'] ?? 'system',
      gridData: json['gridData'] != null ? GridMetadata.fromJson(json['gridData']) : null,
      windows: json['windows'] != null 
          ? (json['windows'] as List).map((w) => WindowData.fromJson(w)).toList()
          : [],
    );
  }
}

class ProjectService {
  static final ProjectService _instance = ProjectService._internal();
  factory ProjectService() => _instance;
  ProjectService._internal();

  /// Папка для хранения реестра проектов
  Future<Directory> _getAppDataDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'UI_Flutter_Workspace'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Файл-реестр: список путей ко всем проектам
  Future<File> _getRegistryFile() async {
    final appDir = await _getAppDataDir();
    return File(p.join(appDir.path, 'registry.json'));
  }

  /// Читаем список путей из реестра
  Future<List<String>> _loadRegistry() async {
    final file = await _getRegistryFile();
    if (!await file.exists()) return [];
    try {
      final content = await file.readAsString();
      final list = jsonDecode(content) as List;
      return list.cast<String>();
    } catch (e) {
      return [];
    }
  }

  /// Сохраняем список путей в реестр
  Future<void> _saveRegistry(List<String> paths) async {
    final file = await _getRegistryFile();
    await file.writeAsString(jsonEncode(paths));
  }

  /// Добавить путь в реестр (если ещё нет)
  Future<void> _registerProject(String dirPath) async {
    final paths = await _loadRegistry();
    if (!paths.contains(dirPath)) {
      paths.add(dirPath);
      await _saveRegistry(paths);
    }
  }

  /// Удалить путь из реестра
  Future<void> _unregisterProject(String dirPath) async {
    final paths = await _loadRegistry();
    paths.remove(dirPath);
    await _saveRegistry(paths);
  }

  /// Загрузить все проекты из реестра
  Future<List<ProjectModel>> loadProjects() async {
    final paths = await _loadRegistry();
    final List<ProjectModel> projects = [];

    for (final dirPath in paths) {
      final configFile = File(p.join(dirPath, 'config.json'));
      if (await configFile.exists()) {
        try {
          final content = await configFile.readAsString();
          final json = jsonDecode(content);
          projects.add(ProjectModel.fromJson(json));
        } catch (e) {
          // Пропускаем битые конфиги
        }
      }
    }

    projects.sort((a, b) => a.name.compareTo(b.name));
    return projects;
  }

  /// Создать проект в указанной директории
  Future<ProjectModel> createProjectInDirectory(String name, String dirPath) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final project = ProjectModel(
      id: id,
      name: name,
      directoryPath: dir.path,
    );

    await updateProject(project);
    await _registerProject(dir.path);
    return project;
  }

  /// Создать проект в дефолтной папке (для первого запуска)
  Future<ProjectModel> createProject(String name) async {
    final appDir = await _getAppDataDir();
    final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\s]'), '').trim().replaceAll(' ', '_');
    final folderName = safeName.isEmpty ? 'Project_${DateTime.now().millisecondsSinceEpoch}' : safeName;
    
    var dir = Directory(p.join(appDir.path, folderName));
    int suffix = 1;
    while (await dir.exists()) {
      dir = Directory(p.join(appDir.path, '${folderName}_$suffix'));
      suffix++;
    }
    
    return createProjectInDirectory(name, dir.path);
  }

  /// Сохранить настройки проекта на диск
  Future<void> updateProject(ProjectModel project) async {
    final dir = Directory(project.directoryPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final configFile = File(p.join(dir.path, 'config.json'));
    await configFile.writeAsString(jsonEncode(project.toJson()));
  }

  /// Удалить проект из реестра и удалить config.json
  Future<void> deleteProject(ProjectModel project) async {
    final configFile = File(p.join(project.directoryPath, 'config.json'));
    if (await configFile.exists()) {
      await configFile.delete();
    }
    await _unregisterProject(project.directoryPath);
  }

  /// Открыть проект из папки (если config.json есть — читаем, если нет — создаём)
  Future<ProjectModel?> openProjectFromDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return null;

    final configFile = File(p.join(dir.path, 'config.json'));
    if (await configFile.exists()) {
      try {
        final content = await configFile.readAsString();
        final json = jsonDecode(content);
        final proj = ProjectModel.fromJson(json);
        await _registerProject(dirPath);
        return proj;
      } catch (_) {}
    }

    // config.json нет — создаём новый
    final folderName = dirPath.split(Platform.pathSeparator).last;
    return createProjectInDirectory(
      folderName.length > 20 ? folderName.substring(0, 20) : folderName,
      dirPath,
    );
  }
}
