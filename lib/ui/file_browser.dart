import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

enum FileViewMode { list, table }

class FileBrowser extends StatefulWidget {
  final Color accentColor;
  final String? initialDirectory;
  const FileBrowser({super.key, required this.accentColor, this.initialDirectory});

  @override
  State<FileBrowser> createState() => _FileBrowserState();
}

class _FileBrowserState extends State<FileBrowser> {
  String? _currentPath;
  List<FileSystemEntity> _entities = [];
  FileViewMode _viewMode = FileViewMode.list;
  bool _isLoading = false;

  double _sidebarWidth = 200.0;
  List<FileSystemEntity> _sidebarFolders = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialDirectory != null) {
      _currentPath = widget.initialDirectory;
      _refresh();
      _loadSidebar();
    }
  }

  Future<void> _loadSidebar() async {
    if (_currentPath == null) return;
    try {
      // For simplicity, we show folders in the parent directory or the current project root
      final projectDir = widget.initialDirectory != null ? Directory(widget.initialDirectory!) : Directory.current;
      final list = await projectDir.list().where((e) => e is Directory).toList();
      setState(() {
        _sidebarFolders = list;
      });
    } catch (e) {
      debugPrint('Error loading sidebar: $e');
    }
  }

  Future<void> _pickDirectory() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      setState(() {
        _currentPath = selectedDirectory;
      });
      _refresh();
      _loadSidebar();
    }
  }

  Future<void> _refresh() async {
    if (_currentPath == null) return;
    setState(() => _isLoading = true);
    try {
      final dir = Directory(_currentPath!);
      final list = await dir.list().toList();
      // Сортировка: сначала папки, потом файлы, по алфавиту
      list.sort((a, b) {
        if (a is Directory && b is! Directory) return -1;
        if (a is! Directory && b is Directory) return 1;
        return p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase());
      });
      setState(() {
        _entities = list;
      });
    } catch (e) {
      debugPrint('Error listing directory: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createFolder() async {
    if (_currentPath == null) return;
    final nameController = TextEditingController(text: 'New Folder');
    final name = await _showInputDialog('Создать папку', nameController);
    if (name != null && name.isNotEmpty) {
      try {
        await Directory(p.join(_currentPath!, name)).create();
        _refresh();
      } catch (e) {
        _showError('Ошибка при создании папки: $e');
      }
    }
  }

  Future<void> _createFile() async {
    if (_currentPath == null) return;
    final nameController = TextEditingController(text: 'new_file.txt');
    final name = await _showInputDialog('Создать файл', nameController);
    if (name != null && name.isNotEmpty) {
      try {
        await File(p.join(_currentPath!, name)).create();
        _refresh();
      } catch (e) {
        _showError('Ошибка при создании файла: $e');
      }
    }
  }

  Future<String?> _showInputDialog(String title, TextEditingController controller) async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: widget.accentColor.withValues(alpha: 0.5))),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: widget.accentColor)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ОТМЕНА', style: TextStyle(color: Colors.white24))),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('СОЗДАТЬ', style: TextStyle(color: widget.accentColor)),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xff141414),
      child: Column(
        children: [
          _buildToolbar(),
          Expanded(
            child: Row(
              children: [
                // Sidebar
                SizedBox(
                  width: _sidebarWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          alignment: Alignment.centerLeft,
                          child: const Text('FOLDERS', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _sidebarFolders.length,
                            itemBuilder: (context, index) {
                              final folder = _sidebarFolders[index];
                              final name = p.basename(folder.path);
                              final isActive = _currentPath == folder.path;
                              return InkWell(
                                onTap: () {
                                  setState(() => _currentPath = folder.path);
                                  _refresh();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  color: isActive ? widget.accentColor.withValues(alpha: 0.1) : Colors.transparent,
                                  child: Row(
                                    children: [
                                      Icon(Icons.folder_rounded, size: 16, color: isActive ? widget.accentColor : Colors.white38),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: TextStyle(
                                            color: isActive ? Colors.white : Colors.white60,
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
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

                // Resizer
                GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _sidebarWidth = (_sidebarWidth + details.delta.dx).clamp(100.0, 400.0);
                    });
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeLeftRight,
                    child: Container(
                      width: 4,
                      color: Colors.transparent,
                      height: double.infinity,
                    ),
                  ),
                ),

                // Content
                Expanded(
                  child: _currentPath == null ? _buildEmptyState() : _buildFileContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.black26,
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          if (_currentPath != null) ...[
            Expanded(
              child: _buildBreadcrumbs(),
            ),
            _buildToolbarIcon(Icons.refresh_rounded, _refresh, 'Обновить'),
            _buildToolbarIcon(Icons.create_new_folder_outlined, _createFolder, 'Новая папка'),
            _buildToolbarIcon(Icons.note_add_outlined, _createFile, 'Новый файл'),
            const VerticalDivider(color: Colors.white10, indent: 12, endIndent: 12),
          ],
          _buildToolbarIcon(
            _viewMode == FileViewMode.list ? Icons.grid_view_rounded : Icons.view_list_rounded,
            () => setState(() => _viewMode = _viewMode == FileViewMode.list ? FileViewMode.table : FileViewMode.list),
            'Режим просмотра',
          ),
          _buildToolbarIcon(Icons.folder_open_rounded, _pickDirectory, 'Открыть папку'),
        ],
      ),
    );
  }
  Widget _buildBreadcrumbs() {
    if (_currentPath == null) return const SizedBox.shrink();
    final parts = p.split(_currentPath!);
    List<Widget> crumbs = [];
    String cumulativePath = "";

    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (i == 0 && (part == '/' || part.contains(':'))) {
        cumulativePath = part;
      } else {
        cumulativePath = p.join(cumulativePath, i == 0 ? "" : part);
      }
      
      final currentSegmentPath = cumulativePath;
      final isLast = i == parts.length - 1;

      crumbs.add(
        InkWell(
          onTap: () {
            setState(() => _currentPath = currentSegmentPath);
            _refresh();
          },
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text(
              part == '/' ? 'Root' : part,
              style: TextStyle(
                color: isLast ? widget.accentColor : Colors.white60,
                fontSize: 11,
                fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      );

      if (!isLast) {
        crumbs.add(const Text('/', style: TextStyle(color: Colors.white24, fontSize: 11)));
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: crumbs),
    );
  }


  Widget _buildToolbarIcon(IconData icon, VoidCallback onTap, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon, size: 20, color: Colors.white54),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_rounded, size: 64, color: widget.accentColor.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _pickDirectory,
            icon: const Icon(Icons.add),
            label: const Text('OPEN DIRECTORY'),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.accentColor.withValues(alpha: 0.1),
              foregroundColor: widget.accentColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              side: BorderSide(color: widget.accentColor.withValues(alpha: 0.3)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileContent() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_entities.isEmpty) {
      return const Center(child: Text('Папка пуста', style: TextStyle(color: Colors.white24)));
    }

    if (_viewMode == FileViewMode.list) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _entities.length,
        itemBuilder: (context, index) => _buildListItem(_entities[index]),
      );
    } else {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 120,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        itemCount: _entities.length,
        itemBuilder: (context, index) => _buildGridItem(_entities[index]),
      );
    }
  }

  Widget _buildListItem(FileSystemEntity entity) {
    final name = p.basename(entity.path);
    final isDir = entity is Directory;
    return InkWell(
      onTap: isDir ? () {
        setState(() => _currentPath = entity.path);
        _refresh();
      } : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(isDir ? Icons.folder_rounded : Icons.insert_drive_file_outlined, 
                 size: 18, color: isDir ? widget.accentColor : Colors.white38),
            const SizedBox(width: 12),
            Expanded(
              child: Text(name, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridItem(FileSystemEntity entity) {
    final name = p.basename(entity.path);
    final isDir = entity is Directory;
    return InkWell(
      onTap: isDir ? () {
        setState(() => _currentPath = entity.path);
        _refresh();
      } : null,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isDir ? Icons.folder_rounded : Icons.insert_drive_file_outlined, 
               size: 48, color: isDir ? widget.accentColor : Colors.white38),
          const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
