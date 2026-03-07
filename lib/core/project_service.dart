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
  }) : this.windows = windows ?? [];

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

  /// Главная папка для хранения проектов
  Future<Directory> getWorkspaceDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final workspace = Directory(p.join(docs.path, 'UI_Flutter_Workspace'));
    if (!await workspace.exists()) {
      await workspace.create(recursive: true);
    }
    return workspace;
  }

  /// Получить все существующие проекты
  Future<List<ProjectModel>> loadProjects() async {
    final workspace = await getWorkspaceDirectory();
    final List<ProjectModel> projects = [];

    await for (var entity in workspace.list(followLinks: false)) {
      if (entity is Directory) {
        final configFile = File(p.join(entity.path, 'config.json'));
        if (await configFile.exists()) {
          try {
            final content = await configFile.readAsString();
            final json = jsonDecode(content);
            projects.add(ProjectModel.fromJson(json));
          } catch (e) {
             print('Error reading project config in ${entity.path}: $e');
          }
        }
      }
    }
    
    // Сортировка по имени (может быть и по дате, если добавить)
    projects.sort((a, b) => a.name.compareTo(b.name));
    return projects;
  }

  /// Создать новый проект на диске
  Future<ProjectModel> createProject(String name) async {
    final workspace = await getWorkspaceDirectory();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    // Делаем безопасное имя папки
    final sanitizeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\s]'), '').trim();
    final safeFolderName = sanitizeName.isEmpty ? 'Project_$id' : sanitizeName.replaceAll(' ', '_');
    
    var dir = Directory(p.join(workspace.path, safeFolderName));
    // Если папка существует, добавляем суффикс
    int suffix = 1;
    while (await dir.exists()) {
      dir = Directory(p.join(workspace.path, '${safeFolderName}_$suffix'));
      suffix++;
    }
    
    await dir.create(recursive: true);
    
    final project = ProjectModel(
      id: id,
      name: name,
      directoryPath: dir.path,
    );
    
    await updateProject(project);
    return project;
  }

  /// Сохранить настройки проекта
  Future<void> updateProject(ProjectModel project) async {
    final dir = Directory(project.directoryPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    final configFile = File(p.join(dir.path, 'config.json'));
    await configFile.writeAsString(jsonEncode(project.toJson()));
  }

  /// Удалить проект (удаляем только config.json, не папку пользователя)
  Future<void> deleteProject(ProjectModel project) async {
    final configFile = File(p.join(project.directoryPath, 'config.json'));
    if (await configFile.exists()) {
      await configFile.delete();
    }
  }

  /// Создать проект в конкретной выбранной пользователем папке
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
    return project;
  }

  /// Открыть проект из существующей папки (прочитать config.json если есть, или создать новый)
  Future<ProjectModel?> openProjectFromDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return null;

    final configFile = File(p.join(dir.path, 'config.json'));
    if (await configFile.exists()) {
      try {
        final content = await configFile.readAsString();
        final json = jsonDecode(content);
        return ProjectModel.fromJson(json);
      } catch (e) {
        print('Error reading config.json in $dirPath: $e');
      }
    }

    // Если config.json нет — создаём новый проект в этой папке
    final folderName = dirPath.split(Platform.pathSeparator).last;
    return createProjectInDirectory(
      folderName.length > 20 ? folderName.substring(0, 20) : folderName,
      dirPath,
    );
  }
}
