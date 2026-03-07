import 'package:flutter/material.dart';
import '../core/project_service.dart';

class ProjectManagerDialog extends StatefulWidget {
  const ProjectManagerDialog({super.key});

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
    setState(() {
      _projects = projs;
      _isLoading = false;
      if (_projects.isNotEmpty) {
        _selectProject(_projects.first);
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

  Future<void> _createNewProject() async {
    final newProj = await ProjectService().createProject('New Project ${_projects.length + 1}');
    setState(() {
      _projects.add(newProj);
      _selectProject(newProj);
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
      insetPadding: const EdgeInsets.all(32), // Оставляем немного места по краям
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
            // Header / Close button
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
            // Body Panels
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
                          padding: const EdgeInsets.all(16.0),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _createNewProject,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Создать новый проект'),
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
                        Expanded(
                          child: _isLoading 
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                            itemCount: _projects.length,
                            itemBuilder: (context, index) {
                              final proj = _projects[index];
                              final isSelected = _selectedProject?.id == proj.id;
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
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 18),
                                  onPressed: () async {
                                    await ProjectService().deleteProject(proj);
                                    _loadProjects(); // Перезагружаем список
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
                          : Column(
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
                                
                                const Spacer(),
                                
                                // Save / Open button
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      _saveCurrentProject().then((_) {
                                        Navigator.of(context).pop(_selectedProject);
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
