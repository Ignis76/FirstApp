// lobby_list.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'main.dart'; // Import main.dart for AuthWrapper

// Removed the main() function from this file

// Enums for access levels
enum AccessLevel {
  read,
  full,
}

class Lobby {
  String name;
  final String password;
  AccessLevel accessLevel;
    final String creatorId; // Add creatorId
  final Map<String, dynamic> content;

  Lobby({
    required this.name,
    required this.password,
    required this.accessLevel,
    required this.creatorId,  // Initialize creatorId
    required this.content,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'password': password,
      'accessLevel': accessLevel.toString(),
       'creatorId': creatorId,  // Serialize creatorId
      'content': content,
    };
  }

  factory Lobby.fromJson(Map<String, dynamic> json) {
    return Lobby(
      name: json['name'],
      password: json['password'],
      accessLevel: AccessLevel.values.firstWhere(
        (e) => e.toString() == json['accessLevel'],
        orElse: () => AccessLevel.read,
      ),
        creatorId: json['creatorId'],  // Deserialize creatorId
      content: json['content'],
    );
  }
}

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  List<Lobby> _lobbies = [];
  final TextEditingController _searchController = TextEditingController();
  List<Lobby> _filteredLobbies = [];
  bool _isLoading = true;

    User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadLobbies();
    _searchController.addListener(_filterLobbies);
  }

     Future<void> _loadCurrentUser() async {
    FirebaseAuth auth = FirebaseAuth.instance;
    User? user = auth.currentUser;
    setState(() {
      _currentUser = user;
    });
  }


  void _filterLobbies() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredLobbies = _lobbies.where((lobby) {
        return lobby.name.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _saveLobbies() async {
    final prefs = await SharedPreferences.getInstance();
    final lobbiesJson = jsonEncode(_lobbies.map((e) => e.toJson()).toList());
    await prefs.setString('lobbies', lobbiesJson);
  }

  Future<void> _loadLobbies() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final lobbiesJson = prefs.getString('lobbies');
      if (lobbiesJson != null) {
        final List<dynamic> decoded = jsonDecode(lobbiesJson);
        setState(() {
          _lobbies = decoded.map((e) => Lobby.fromJson(e)).toList();
          _filteredLobbies = List.from(_lobbies);
        });
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

   void _createLobby(String name, String password) {
     if (_currentUser == null) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Необходимо войти в аккаунт')),
       );
       return;
     }

    final newLobby = Lobby(
      name: name,
      password: password,
      accessLevel: AccessLevel.full,
       creatorId: _currentUser!.uid,  // Set creatorId here
      content: {'documents': []},
    );

    setState(() {
      _lobbies.add(newLobby);
      _filterLobbies();
    });
    _saveLobbies();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Лобби "$name" создано!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }



  void _showCreateLobbyDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Создать лобби'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: 'Введите название лобби',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.group),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Введите пароль',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.lock),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final password = passwordController.text.trim();
              if (name.isNotEmpty && password.isNotEmpty) {
                Navigator.of(context).pop();
                _createLobby(name, password);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Заполните все поля!')),
                );
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
       if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const AuthWrapper()), // Navigate to AuthWrapper
                  (Route<dynamic> route) => false,);
        }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка выхода: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lobby List'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => NewsPage()),
              );
            },
            icon: const Icon(Icons.newspaper),
            tooltip: 'Новости',
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Выйти',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск лобби...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLobbies.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Лобби не найдены',
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
                        itemCount: _filteredLobbies.length,
                        itemBuilder: (context, index) {
                          final lobby = _filteredLobbies[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 8,
                            ),
                            child: ListTile(
                              leading: Icon(
                                lobby.accessLevel == AccessLevel.read
                                    ? Icons.remove_red_eye
                                    : Icons.admin_panel_settings,
                                color: lobby.accessLevel == AccessLevel.read
                                    ? Colors.blue
                                    : Colors.green,
                              ),
                              title: Text(
                                lobby.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                lobby.accessLevel == AccessLevel.read
                                    ? 'Только чтение'
                                    : 'Полный доступ',
                                style: TextStyle(
                                  color: lobby.accessLevel == AccessLevel.read
                                      ? Colors.blue
                                      : Colors.green,
                                ),
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios),
                              onTap: () => _enterLobby(lobby),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateLobbyDialog,
        icon: const Icon(Icons.add),
        label: const Text('Создать лобби'),
      ),
    );
  }

  void _enterLobby(Lobby lobby) {
    final TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Вход в лобби "${lobby.name}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Введите пароль',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Уровень доступа: ${lobby.accessLevel == AccessLevel.read ? "Только чтение" : "Полный доступ"}',
              style: TextStyle(
                color: lobby.accessLevel == AccessLevel.read
                    ? Colors.blue
                    : Colors.green,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              if (passwordController.text == lobby.password) {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => LobbyDetailScreen(
                      lobby: lobby,
                      saveLobbies: _saveLobbies,
                      currentUser: _currentUser,  // Pass the current user
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Неверный пароль!'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Войти'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// Rest of the code remains the same, just update LobbyDetailScreen to respect access levels
class LobbyDetailScreen extends StatefulWidget {
  final Lobby lobby;
  final Future<void> Function() saveLobbies;
   final User? currentUser;


  const LobbyDetailScreen({
    required this.lobby,
    required this.saveLobbies,
      this.currentUser,
    super.key,
  });

  @override
  _LobbyDetailScreenState createState() => _LobbyDetailScreenState();
}

class _LobbyDetailScreenState extends State<LobbyDetailScreen> {
  List<String> documents = [];

  @override
  void initState() {
    super.initState();
    documents = List<String>.from(widget.lobby.content['documents'] ?? []);
  }

  Future<void> _pickPdfFile() async {
     if (widget.currentUser == null || widget.lobby.creatorId != widget.currentUser!.uid) {
      if (widget.lobby.accessLevel == AccessLevel.read) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('У вас нет прав для загрузки файлов'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result != null) {
      if (kIsWeb) {
        // web
        final fileBytes = result.files.first.bytes;

        if (fileBytes != null) {
          final blob = html.Blob([fileBytes]);
          final url = html.Url.createObjectUrlFromBlob(blob);

          String fileName = result.files.first.name;
          if (fileName.isEmpty) {
            final uri = Uri.parse(url);
            fileName = uri.pathSegments.last;
          }

          setState(() {
            documents.add(
                jsonEncode({"fileName": fileName, "fileBytes": fileBytes}));
          });
          widget.lobby.content['documents'] = documents;
          await widget.saveLobbies();

          html.Url.revokeObjectUrl(url);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Файл загружен!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else {
        // mobile
        File file = File(result.files.single.path!);
        setState(() {
          documents.add(file.path);
        });
        widget.lobby.content['documents'] = documents;
        await widget.saveLobbies();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Файл загружен!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Файл не выбран')),
        );
      }
    }
  }

  Future<void> _deleteDocument(int index) async {
      if (widget.currentUser == null || widget.lobby.creatorId != widget.currentUser!.uid) {
    if (widget.lobby.accessLevel == AccessLevel.read) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('У вас нет прав для удаления файлов'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
      }

    setState(() {
      documents.removeAt(index);
    });
    widget.lobby.content['documents'] = documents;
    await widget.saveLobbies();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Файл удалён!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _shareDocument(String filePath) async {
    if (kIsWeb) {
      try {
        if (filePath.startsWith("blob")) {
          await Share.share(filePath);
        } else if (filePath.startsWith("{")) {
          final decoded = jsonDecode(filePath);
          final fileBytes = decoded['fileBytes'];
          final blob = html.Blob([fileBytes]);
          final url = html.Url.createObjectUrlFromBlob(blob);
          await Share.share(url);
          html.Url.revokeObjectUrl(url);
        } else {
          final fileBytes = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
          ).then((result) => result?.files.first.bytes);
          if (fileBytes != null) {
            final blob = html.Blob([fileBytes]);
            final url = html.Url.createObjectUrlFromBlob(blob);
            await Share.share(url);
            html.Url.revokeObjectUrl(url);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка при отправке: $e')),
          );
        }
      }
    } else {
      try {
        await Share.shareXFiles([XFile(filePath)]);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка при отправке: $e')),
          );
        }
      }
    }
  }

  Future<void> _openPdf(String filePath) async {
    if (kIsWeb) {
      if (filePath.startsWith("blob")) {
        html.window.open(filePath, '_blank');
      } else if (filePath.startsWith("{")) {
        final decoded = jsonDecode(filePath);
        final fileBytes = decoded['fileBytes'];
        final blob = html.Blob([fileBytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.window.open(url, '_blank');
        html.Url.revokeObjectUrl(url);
      } else {
        final fileBytes = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        ).then((result) => result?.files.first.bytes);

        if (fileBytes != null) {
          final blob = html.Blob([fileBytes]);
          final url = html.Url.createObjectUrlFromBlob(blob);
          html.window.open(url, '_blank');
          html.Url.revokeObjectUrl(url);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Файл недоступен')),
            );
          }
        }
      }
    } else if (File(filePath).existsSync()) {
      if (filePath.toLowerCase().endsWith('.pdf')) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfViewerPage(filePath: filePath),
          ),
        );
      } else {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => Dialog(child: Image.file(File(filePath))),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Файл не найден')),
        );
      }
    }
  }

  void _showLobbySettingsDialog() {
    final TextEditingController nameController =
        TextEditingController(text: widget.lobby.name);
    AccessLevel selectedAccessLevel = widget.lobby.accessLevel;
    
       if (widget.currentUser == null || widget.lobby.creatorId != widget.currentUser!.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('У вас нет прав для изменения настроек лобби'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Настройки лобби'),
              content: StatefulBuilder(
                builder: (context, setState) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: 'Введите название лобби',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.group),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<AccessLevel>(
                      value: selectedAccessLevel,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.security),
                      ),
                      items: AccessLevel.values.map((level) {
                        return DropdownMenuItem(
                          value: level,
                          child: Text(level == AccessLevel.read
                              ? 'Только чтение'
                              : 'Полный доступ'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => selectedAccessLevel = value!);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final newName = nameController.text.trim();
                    if (newName.isNotEmpty) {
                      setState(() {
                        widget.lobby.name = newName;
                        widget.lobby.accessLevel = selectedAccessLevel;
                      });
                      await widget.saveLobbies();
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Настройки лобби изменены')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Введите новое имя лобби!')),
                      );
                    }
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            ));
  }

  void _openNewsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NewsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Лобби: ${widget.lobby.name}'),
        actions: [
          IconButton(
            onPressed: _openNewsPage,
            icon: const Icon(Icons.newspaper),
            tooltip: 'Новости',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showLobbySettingsDialog,
            tooltip: 'Настройки лобби',
          ),
          IconButton(
            icon: Icon(
              widget.lobby.accessLevel == AccessLevel.read
                  ? Icons.remove_red_eye
                  : Icons.admin_panel_settings,
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Информация о доступе'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: Icon(
                          widget.lobby.accessLevel == AccessLevel.read
                              ? Icons.remove_red_eye
                              : Icons.admin_panel_settings,
                          color: widget.lobby.accessLevel == AccessLevel.read
                              ? Colors.blue
                              : Colors.green,
                        ),
                        title: Text(
                          'Уровень доступа:',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        subtitle: Text(
                          widget.lobby.accessLevel == AccessLevel.read
                              ? 'Только чтение'
                              : 'Полный доступ',
                          style: TextStyle(
                            color: widget.lobby.accessLevel == AccessLevel.read
                                ? Colors.blue
                                : Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.lobby.accessLevel == AccessLevel.read
                            ? 'Вы можете только просматривать документы'
                            : 'Вы можете загружать и удалять документы',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Понятно'),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'Информация о доступе',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.lobby.name}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        'Уровень доступа: ${widget.lobby.accessLevel == AccessLevel.read ? "Только чтение" : "Полный доступ"}',
                        style: TextStyle(
                          color: widget.lobby.accessLevel == AccessLevel.read
                              ? Colors.blue
                              : Colors.green,
                        ),
                      ),
                      Text(
                        'Всего документов: ${documents.length}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: documents.isEmpty
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
                          'Нет загруженных документов',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (widget.lobby.accessLevel == AccessLevel.full)
                          const SizedBox(height: 8),
                        if (widget.lobby.accessLevel == AccessLevel.full)
                          Text(
                            'Нажмите кнопку ниже, чтобы загрузить',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: documents.length,
                    itemBuilder: (context, index) {
                      final document = documents[index];
                      String fileName = "";

                      if (document.startsWith("{")) {
                        final decoded = jsonDecode(document);
                        fileName = decoded['fileName'];
                      } else {
                        fileName = document.split('/').last;
                      }

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: document.toLowerCase().endsWith('.pdf') ||
                                    document.startsWith("{")
                                ? Icon(
                                    Icons.picture_as_pdf,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  )
                                : Image.network(
                                    document,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.lobby.accessLevel == AccessLevel.full)
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _deleteDocument(index),
                                ),
                              IconButton(
                                icon: const Icon(Icons.share),
                                onPressed: () => _shareDocument(document),
                              ),
                            ],
                          ),
                          onTap: () => _openPdf(document),
                        ),
                      );
                    },
                  ),
          ),
          if (widget.lobby.accessLevel == AccessLevel.full)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: _pickPdfFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('Загрузить PDF/Фото'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Define PdfViewerPage
class PdfViewerPage extends StatelessWidget {
  final String filePath;
  const PdfViewerPage({super.key, required this.filePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Viewer'),
      ),
      body: SfPdfViewer.file(File(filePath)),
    );
  }
}





// Define NewsPage
class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  List<NewsItem> _news = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNews();
  }

  Future<void> _fetchNews() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await http.get(Uri.parse(
          'https://newsapi.org/v2/everything?q=flutter&apiKey=fcad28e01553422686ed25e282562722'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = jsonDecode(response.body);
        if (decoded['articles'] != null) {
          setState(() {
            _news = (decoded['articles'] as List)
                .take(5)
                .map((item) => NewsItem(
                    title: item['title'] ?? 'Нет заголовка',
                    body: item['description'] ?? 'Нет описания',
                    url: item['url'] ?? ''))
                .toList();
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Не удалось загрузить новости: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки новостей: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Новости'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: _news.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                color: Colors.grey,
              ),
              itemBuilder: (context, index) {
                return _buildNewsItem(
                    _news[index].title,
                    _news[index].body,
                    DateFormat('yyyy-MM-dd').format(DateTime.now()),
                    _news[index].url);
              },
            ),
    );
  }

  Widget _buildNewsItem(
      String title, String description, String date, String url) {
    return Card(
      margin: const EdgeInsets.all(10),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.bottomRight,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                IconButton(
                  onPressed: () => _launchUrl(url),
                  icon: const Icon(Icons.launch),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    if (url.isNotEmpty && await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось открыть новость')));
      }
    }
  }
}

class NewsItem {
  final String title;
  final String body;
  final String url;

  NewsItem({required this.title, required this.body, required this.url});

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      title: json['title'] ?? 'Без заголовка',
      body: json['body'] ?? 'Без текста',
      url: json['url'] ?? '',
    );
  }
}