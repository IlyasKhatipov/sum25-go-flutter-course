// lib/services/api_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../models/message.dart';

class ApiService {
  // Use 10.0.2.2 for Android emulator, otherwise localhost
  static final String baseUrl =
      Platform.isAndroid ? 'http://10.0.2.2:8080' : 'http://localhost:8080';
  static const Duration timeout = Duration(seconds: 10);

  late http.Client _client;

  ApiService() {
    _client = http.Client();
  }

  void dispose() {
    _client.close();
  }

  Map<String, String> _getHeaders() => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Future<T> _handleResponse<T>(
    http.Response response,
    T Function(dynamic) fromJson,
  ) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      final apiResponse = ApiResponse.fromJson(decoded, (data) => data);
      if (apiResponse.success) {
        return fromJson(apiResponse.data);
      } else {
        throw ApiException(apiResponse.error ?? 'Unknown API error');
      }
    } else if (response.statusCode >= 400 && response.statusCode < 500) {
      final errorBody = jsonDecode(response.body);
      throw ApiException(errorBody['error'] ?? 'Client error');
    } else if (response.statusCode >= 500) {
      throw ServerException('Server error: ${response.statusCode}');
    } else {
      throw ApiException('Unexpected error: ${response.statusCode}');
    }
  }

  Future<List<Message>> getMessages() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/messages'), headers: _getHeaders())
          .timeout(timeout);
      return _handleResponse<List<Message>>(response, (data) {
        final List<dynamic> messageList = data;
        return messageList.map((json) => Message.fromJson(json)).toList();
      });
    } on SocketException {
      throw NetworkException('No Internet connection or server is down.');
    } on TimeoutException {
      throw NetworkException('The connection has timed out.');
    }
  }

  Future<Message> createMessage(CreateMessageRequest request) async {
    final validationError = request.validate();
    if (validationError != null) {
      throw ValidationException(validationError);
    }
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/messages'),
            headers: _getHeaders(),
            body: jsonEncode(request.toJson()),
          )
          .timeout(timeout);
      return _handleResponse<Message>(
          response, (data) => Message.fromJson(data));
    } on SocketException {
      throw NetworkException('No Internet connection or server is down.');
    } on TimeoutException {
      throw NetworkException('The connection has timed out.');
    }
  }

  Future<Message> updateMessage(int id, UpdateMessageRequest request) async {
    final validationError = request.validate();
    if (validationError != null) {
      throw ValidationException(validationError);
    }
    try {
      final response = await _client
          .put(
            Uri.parse('$baseUrl/api/messages/$id'),
            headers: _getHeaders(),
            body: jsonEncode(request.toJson()),
          )
          .timeout(timeout);
      return _handleResponse<Message>(
          response, (data) => Message.fromJson(data));
    } on SocketException {
      throw NetworkException('No Internet connection or server is down.');
    } on TimeoutException {
      throw NetworkException('The connection has timed out.');
    }
  }

  Future<void> deleteMessage(int id) async {
    try {
      final response = await _client
          .delete(Uri.parse('$baseUrl/api/messages/$id'),
              headers: _getHeaders())
          .timeout(timeout);
      if (response.statusCode != 204) {
        throw ApiException(
            'Failed to delete message. Status: ${response.statusCode}');
      }
    } on SocketException {
      throw NetworkException('No Internet connection or server is down.');
    } on TimeoutException {
      throw NetworkException('The connection has timed out.');
    }
  }

  Future<HTTPStatusResponse> getHTTPStatus(int statusCode) async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/status/$statusCode'),
              headers: _getHeaders())
          .timeout(timeout);
      return _handleResponse<HTTPStatusResponse>(
          response, (data) => HTTPStatusResponse.fromJson(data));
    } on SocketException {
      throw NetworkException('No Internet connection or server is down.');
    } on TimeoutException {
      throw NetworkException('The connection has timed out.');
    }
  }

  Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/health'), headers: _getHeaders())
          .timeout(timeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw ServerException('Health check failed: ${response.statusCode}');
      }
    } on SocketException {
      throw NetworkException('No Internet connection or server is down.');
    } on TimeoutException {
      throw NetworkException('The connection has timed out.');
    }
  }
}

// Custom exceptions
class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class NetworkException extends ApiException {
  NetworkException(String message) : super(message);
}

class ServerException extends ApiException {
  ServerException(String message) : super(message);
}

class ValidationException extends ApiException {
  ValidationException(String message) : super(message);
}