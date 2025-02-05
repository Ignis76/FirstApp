import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

class LobbyDetailScreen extends StatefulWidget {
  final Map<String, dynamic> lobby;
  final Future<void> Function() saveLobbies;

  const LobbyDetailScreen({
    super.key,
    required this.lobby,
    required this.saveLobbies,
  });

  @override
  State<LobbyDetailScreen> createState() => _LobbyDetailScreenState();
}

class _LobbyDetailScreenState extends State<LobbyDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredDocuments = [];
  bool _isLoading = false;
  String _sortBy = 'date';
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _filteredDocuments = List.from(widget.lobby['content']['documents'] ?? []);
    _searchController.addListener(_filterDocuments);
  }

  void _filterDocuments() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredDocuments = (widget.lobby['content']['documents'] ?? [])
          .where((doc) =>
              doc['name'].toString().toLowerCase().contains(query) ||
              doc['type'].toString().toLowerCase().contains(query))
          .toList();
      _sortDocuments();
    });
  }

  void _sortDocuments() {
    setState(() {
      _filteredDocuments.sort((a, b) {
        switch (_sortBy) {
          case 'name':
            return _sortAscending
                ? a['name'].compareTo(b['name'])
                : b['name'].compareTo(a['name']);
          case 'type':
            return _sortAscending
                ? a['type'].compareTo(b['type'])
                : b['type'].compareTo(a['type']);
          case 'date':
            return _sortAscending
                ? a['date'].compareTo(b['date'])
                : b['date'].compareTo(a['date']);
          default:
            return 0;
        }
      });
    });
  }

  Future<void> _uploadFile() async {
    try {
      setState(() => _isLoading = true);

      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx'],
      );

      if (result != null) {
        for (var file in result.files) {
          final newDoc = {
            'name': file.name,
            'type': file.extension,
            'size': file.size,
            'date': DateTime.now().toIso8601String(),
            'path': file.path,
          };

          widget.lobby['content']['documents'] ??= [];
          widget.lobby['content']['documents'].add(newDoc);
        }

        await widget.saveLobbies();
        _filterDocuments();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Загружено файлов: ${result.files.length}',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteDocument(Map<String, dynamic> document) async {
    try {
      setState(() => _isLoading = true);

      widget.lobby['content']['documents'].remove(document);
      await widget.saveLobbies();
      _filterDocuments();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Документ удален'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка удаления: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lobby['name']),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.folder), text: 'Файлы'),
            Tab(icon: Icon(Icons.people), text: 'Участники'),
            Tab(icon: Icon(Icons.settings), text: 'Настройки'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showLobbyInfo(),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFilesTab(),
          _buildMembersTab(),
          _buildSettingsTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: _isLoading ? null : _uploadFile,
              icon: const Icon(Icons.upload_file),
              label: const Text('Загрузить'),
            )
          : null,
    );
  }

  Widget _buildFilesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Поиск документов...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: PopupMenuButton<String>(
                    icon: const Icon(Icons.sort),
                    onSelected: (value) {
                      setState(() {
                        if (_sortBy == value) {
                          _sortAscending = !_sortAscending;
                        } else {
                          _sortBy = value;
                          _sortAscending = true;
                        }
                        _sortDocuments();
                      });
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'name',
                        child: Text('По имени'),
                      ),
                      const PopupMenuItem(
                        value: 'type',
                        child: Text('По типу'),
                      ),
                      const PopupMenuItem(
                        value: 'date',
                        child: Text('По дате'),
                      ),
                    ],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Всего файлов: ${_filteredDocuments.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredDocuments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_open,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Нет документов',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _filteredDocuments.length,
                      itemBuilder: (context, index) {
                        final doc = _filteredDocuments[index];
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: _getFileIcon(doc['type']),
                            title: Text(doc['name']),
                            subtitle: Text(
                              '${doc['type'].toUpperCase()} • ${_formatFileSize(doc['size'])}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  DateFormat('dd.MM.yyyy')
                                      .format(DateTime.parse(doc['date'])),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                PopupMenuButton(
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'open',
                                      child: Text('Открыть'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'share',
                                      child: Text('Поделиться'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Удалить'),
                                    ),
                                  ],
                                  onSelected: (value) {
                                    switch (value) {
                                      case 'open':
                                        // Implement file opening
                                        break;
                                      case 'share':
                                        // Implement file sharing
                                        break;
                                      case 'delete':
                                        _deleteDocument(doc);
                                        break;
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _getFileIcon(String fileType) {
    IconData iconData;
    Color iconColor;

    switch (fileType.toLowerCase()) {
      case 'pdf':
        iconData = Icons.picture_as_pdf;
        iconColor = Colors.red;
        break;
      case 'doc':
      case 'docx':
        iconData = Icons.description;
        iconColor = Colors.blue;
        break;
      case 'xls':
      case 'xlsx':
        iconData = Icons.table_chart;
        iconColor = Colors.green;
        break;
      default:
        iconData = Icons.insert_drive_file;
        iconColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, color: iconColor),
    );
  }

  Widget _buildMembersTab() {
    return const Center(child: Text('Список участников (в разработке)'));
  }

  Widget _buildSettingsTab() {
    return const Center(child: Text('Настройки лобби (в разработке)'));
  }

  void _showLobbyInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.lobby['name']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('Документов'),
              trailing: Text('${_filteredDocuments.length}'),
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Участников'),
              trailing: const Text('0'),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Создано'),
              trailing: const Text('01.01.2024'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
