// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/message.dart';
import 'screens/chat_screen.dart';
import 'services/api_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>(
          create: (_) => ApiService(),
          dispose: (_, apiService) => apiService.dispose(),
        ),
        ChangeNotifierProvider<ChatProvider>(
          create: (context) =>
              ChatProvider(context.read<ApiService>())..loadMessages(),
        ),
      ],
      child: MaterialApp(
        title: 'Lab 03 REST API Chat',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          colorScheme: ColorScheme.fromSwatch(
            primarySwatch: Colors.blue,
            accentColor: Colors.orange,
            brightness: Brightness.dark,
            cardColor: Colors.grey[800],
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.grey[900],
            elevation: 4,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.orange,
            ),
          ),
          useMaterial3: true,
        ),
        home: const ChatScreen(),
      ),
    );
  }
}

class ChatProvider extends ChangeNotifier {
  final ApiService _apiService;

  List<Message> _messages = [];
  bool _isLoading = false;
  String? _error;

  ChatProvider(this._apiService);

  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> _execute(Future<void> Function() action) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await action();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMessages() async {
    await _execute(() async {
      _messages = await _apiService.getMessages();
      _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });
  }

  Future<void> createMessage(CreateMessageRequest request) async {
    await _execute(() async {
      final newMessage = await _apiService.createMessage(request);
      _messages.insert(0, newMessage);
    });
    if (_error != null) throw ApiException(_error!);
  }

  Future<void> updateMessage(int id, UpdateMessageRequest request) async {
    await _execute(() async {
      final updatedMessage = await _apiService.updateMessage(id, request);
      final index = _messages.indexWhere((m) => m.id == id);
      if (index != -1) {
        _messages[index] = updatedMessage;
      }
    });
    if (_error != null) throw ApiException(_error!);
  }

  Future<void> deleteMessage(int id) async {
    await _execute(() async {
      await _apiService.deleteMessage(id);
      _messages.removeWhere((m) => m.id == id);
    });
    if (_error != null) throw ApiException(_error!);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}