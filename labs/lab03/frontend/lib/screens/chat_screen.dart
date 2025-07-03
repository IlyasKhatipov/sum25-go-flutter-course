// lib/screens/chat_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/message.dart';
import '../services/api_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _usernameController = TextEditingController(text: 'flutter_user');
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _usernameController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  Future<void> _sendMessage() async {
    final provider = context.read<ChatProvider>();
    final request = CreateMessageRequest(
      username: _usernameController.text,
      content: _messageController.text,
    );

    final validationError = request.validate();
    if (validationError != null) {
      _showSnackbar(validationError, isError: true);
      return;
    }

    try {
      await provider.createMessage(request);
      _messageController.clear();
      _showSnackbar('Message sent successfully!');
    } catch (e) {
      _showSnackbar(e.toString(), isError: true);
    }
  }

  Future<void> _editMessage(Message message) async {
    final editController = TextEditingController(text: message.content);
    final newContent = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: editController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'New content'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, editController.text),
              child: const Text('Save')),
        ],
      ),
    );

    if (newContent != null && newContent.isNotEmpty) {
      final provider = context.read<ChatProvider>();
      try {
        await provider
            .updateMessage(message.id, UpdateMessageRequest(content: newContent));
        _showSnackbar('Message updated successfully!');
      } catch (e) {
        _showSnackbar(e.toString(), isError: true);
      }
    }
  }

  Future<void> _deleteMessage(Message message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      final provider = context.read<ChatProvider>();
      try {
        await provider.deleteMessage(message.id);
        _showSnackbar('Message deleted.');
      } catch (e) {
        _showSnackbar(e.toString(), isError: true);
      }
    }
  }

  Future<void> _showHTTPStatus(int statusCode) async {
    final apiService = context.read<ApiService>();
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<HTTPStatusResponse>(
        future: apiService.getHTTPStatus(statusCode),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return AlertDialog(
                title: Text('Error: $statusCode'),
                content: Text(snapshot.error.toString()));
          }
          final status = snapshot.data!;
          return AlertDialog(
            title: Text('HTTP Status: ${status.statusCode}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(status.description,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  Image.network(
                    status.imageUrl,
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                            ? child
                            : const CircularProgressIndicator(),
                    errorBuilder: (context, error, stack) =>
                        const Text('Failed to load HTTP Cat :('),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'))
            ],
          );
        },
      ),
    );
  }

  Widget _buildMessageTile(Message message) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              Colors.primaries[message.username.hashCode % Colors.primaries.length],
          child: Text(message.username.substring(0, 1).toUpperCase()),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(message.username,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              DateFormat.jm().format(message.timestamp.toLocal()),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        subtitle: Text(message.content),
        trailing: PopupMenuButton(
          onSelected: (value) {
            if (value == 'edit') _editMessage(message);
            if (value == 'delete') _deleteMessage(message);
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Theme.of(context).cardColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Type your message...',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _sendMessage,
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              const Text('HTTP Cat Demo:'),
              ElevatedButton(
                  onPressed: () => _showHTTPStatus(200),
                  child: const Text('200')),
              ElevatedButton(
                  onPressed: () => _showHTTPStatus(404),
                  child: const Text('404')),
              ElevatedButton(
                  onPressed: () => _showHTTPStatus(500),
                  child: const Text('500')),
              ElevatedButton(
                  onPressed: () => HTTPStatusDemo.showRandomStatus(context),
                  child: const Icon(Icons.shuffle)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String? error, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 50),
            const SizedBox(height: 16),
            Text(
              'An Error Occurred',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error ?? 'Unknown error.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(child: CircularProgressIndicator());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Go + Flutter Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<ChatProvider>().loadMessages(),
          ),
        ],
      ),
      body: Consumer<ChatProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.messages.isEmpty) {
            return _buildLoadingWidget();
          }
          if (provider.error != null && provider.messages.isEmpty) {
            return _buildErrorWidget(
                provider.error, () => provider.loadMessages());
          }
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: provider.messages.length,
                  itemBuilder: (context, index) {
                    final message = provider.messages[index];
                    return _buildMessageTile(message);
                  },
                ),
              ),
              _buildMessageInput(),
            ],
          );
        },
      ),
    );
  }
}

class HTTPStatusDemo {
  static void showRandomStatus(BuildContext context) {
    final codes = [200, 201, 400, 404, 418, 500, 503];
    final randomCode = codes[Random().nextInt(codes.length)];

    // We need to access the screen's method. A bit of a workaround for a static helper.
    // A better approach in a larger app might be to pass the function itself.
    final state = context.findAncestorStateOfType<_ChatScreenState>();
    state?._showHTTPStatus(randomCode);
  }
}