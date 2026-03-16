import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../core/project_service.dart';

class ProjectManagerDialog extends StatefulWidget {
  final ProjectModel? currentProject;
  const ProjectManagerDialog({super.key, this.currentProject});

  @override
  State<ProjectManagerDialog> createState() => _ProjectManagerDialogState();
}

class _ProjectManagerDialogState extends State<ProjectManagerDialog> {
  List<ProjectModel> _projects = [];
  bool _isLoading = true;
  ProjectModel? _selectedProject;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final projs = await ProjectService().loadProjects();
    if (!mounted) return;
    setState(() {
      _projects = projs;
      _isLoading = false;
      if (_projects.isNotEmpty && _selectedProject == null) {
        // Try to find and select the current project
        if (widget.currentProject != null) {
          final match = _projects.where((p) => p.directoryPath == widget.currentProject!.directoryPath).firstOrNull;
          if (match != null) {
            _selectProject(match);
          } else {
            _selectProject(_projects.first);
          }
        } else {
          _selectProject(_projects.first);
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _selectProject(ProjectModel proj) {
    setState(() {
      _selectedProject = proj;
      _nameController.text = proj.name;
    });
  }

  /// Создать проект: ввести имя → выбрать родительскую папку → создать подпапку
  Future<void> _createNewProject() async {
    // 1) Спрашиваем имя проекта
    final nameCtrl = TextEditingController(text: 'New Project');
    final projectName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xff2d2d2d),
        title: const Text('Название проекта', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameCtrl,
          maxLength: 20,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.black26,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            child: const Text('Далее'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    if (projectName == null || projectName.isEmpty) return;

    // 2) Выбираем родительскую папку
    final parentDir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Выберите где создать папку "$projectName"',
    );
    if (parentDir == null) return;

    // 3) Создаём подпапку с именем проекта
    final safeName = projectName.replaceAll(RegExp(r'[^a-zA-Zа-яА-Я0-9_\-\s]'), '').trim().replaceAll(' ', '_');
    final folderName = safeName.isEmpty ? 'Project_${DateTime.now().millisecondsSinceEpoch}' : safeName;
    var projectDir = Directory('$parentDir${Platform.pathSeparator}$folderName');
    int suffix = 1;
    while (await projectDir.exists()) {
      projectDir = Directory('$parentDir${Platform.pathSeparator}${folderName}_$suffix');
      suffix++;
    }

    final proj = await ProjectService().createProjectInDirectory(projectName, projectDir.path);
    if (!mounted) return;
    setState(() {
      _projects.add(proj);
      _selectProject(proj);
    });
  }

  /// Открыть существующий проект: выбрать папку с config.json
  Future<void> _openExistingProject() async {
    final selectedDir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Выберите папку существующего проекта',
    );
    if (selectedDir == null) return;

    final proj = await ProjectService().openProjectFromDirectory(selectedDir);
    if (proj == null || !mounted) return;

    // Проверяем, что проект ещё не в списке
    final exists = _projects.any((p) => p.directoryPath == proj.directoryPath);
    setState(() {
      if (!exists) _projects.add(proj);
      _selectProject(proj);
    });
  }

  Future<void> _saveCurrentProject() async {
    if (_selectedProject != null) {
      await ProjectService().updateProject(_selectedProject!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(32),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xff1e1e1e),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                children: [
                  const Text('Project Manager', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white54),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: Row(
                children: [
                  // Left Panel: Project List
                  Container(
                    width: 280,
                    decoration: const BoxDecoration(
                      color: Color(0xff181818),
                      border: Border(right: BorderSide(color: Colors.white10)),
                      borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16)),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _createNewProject,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Создать проект'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
                                foregroundColor: Colors.blueAccent,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _openExistingProject,
                              icon: const Icon(Icons.folder_open, size: 18),
                              label: const Text('Открыть проект'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.greenAccent.withValues(alpha: 0.15),
                                foregroundColor: Colors.greenAccent,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: _isLoading 
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                            itemCount: _projects.length,
                            itemBuilder: (context, index) {
                              final proj = _projects[index];
                              final isSelected = _selectedProject?.directoryPath == proj.directoryPath;
                              return ListTile(
                                tileColor: isSelected ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
                                leading: Icon(Icons.folder, color: isSelected ? Colors.blueAccent : Colors.white54),
                                title: Text(
                                  proj.name,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.white70,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                subtitle: Text(
                                  proj.directoryPath,
                                  style: const TextStyle(color: Colors.white24, fontSize: 10),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 18),
                                  onPressed: () async {
                                    await ProjectService().deleteProject(proj);
                                    if (_selectedProject?.directoryPath == proj.directoryPath) {
                                      _selectedProject = null;
                                    }
                                    _loadProjects();
                                  },
                                ),
                                onTap: () => _selectProject(proj),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Right Panel: Project Settings
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      child: _selectedProject == null
                          ? const Center(child: Text('Выберите проект для настройки', style: TextStyle(color: Colors.white54)))
                          : SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Настройки проекта', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 32),
                                  
                                  // Name field
                                  const Text('Название', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _nameController,
                                    maxLength: 20,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: Colors.black26,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.blueAccent)),
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedProject!.name = val;
                                      });
                                      _saveCurrentProject();
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // Directory display
                                  const Text('Директория проекта', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.black26,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.folder, color: Colors.white38, size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _selectedProject!.directoryPath,
                                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  
                                  // Preset Selector
                                  const Text('Пресет (Preset)', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.black26,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedProject!.preset,
                                        isExpanded: true,
                                        dropdownColor: const Color(0xff2d2d2d),
                                        style: const TextStyle(color: Colors.white),
                                        items: const [
                                          DropdownMenuItem(value: 'default', child: Text('Default Profile')),
                                          DropdownMenuItem(value: 'custom', child: Text('Custom Configuration')),
                                        ],
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() => _selectedProject!.preset = val);
                                            _saveCurrentProject();
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  
                                  // CUDA Settings
                                  const Text('Аппаратное ускорение', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                  const SizedBox(height: 8),
                                  CheckboxListTile(
                                    title: const Text('Использовать CUDA ядра', style: TextStyle(color: Colors.white)),
                                    subtitle: const Text('Ускоряет вычисления за счет видеокарты (если поддерживается)', style: TextStyle(color: Colors.white38, fontSize: 12)),
                                    value: _selectedProject!.useCuda,
                                    onChanged: (val) {
                                      setState(() => _selectedProject!.useCuda = val ?? false);
                                      _saveCurrentProject();
                                    },
                                    activeColor: Colors.blueAccent,
                                    checkColor: Colors.white,
                                    contentPadding: EdgeInsets.zero,
                                    controlAffinity: ListTileControlAffinity.leading,
                                  ),
                                  
                                  const SizedBox(height: 32),
                                  
                                  // Save / Open button
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        _saveCurrentProject().then((_) {
                                          if (mounted) {
                                            Navigator.of(context).pop(_selectedProject);
                                          }
                                        });
                                      },
                                      icon: const Icon(Icons.check),
                                      label: const Text('СОХРАНИТЬ И ОТКРЫТЬ'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blueAccent,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
