import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

class ChatProvider extends ChangeNotifier {
  WebSocketChannel? _channel;
  List<ChatMessage> chatMessages = [];  // For buyer-seller messages
  List<BotMessage> botMessages = [];    // For chatbot messages
  bool isConnected = false;
  List<ChatButton> currentButtons = [];
  String? _currentRole;
  List<ChatFormField> currentFormFields = [];
  bool isInDispute = false;
  String? _currentSession;
  List<PendingAttachment> pendingAttachments = [];
  bool waitResponse = false;  // Add this property
  bool isStreaming = false;  // Add this property

  ChatProvider();

  void setRole(String role) {
    if (_currentRole != role) {
      _currentRole = role;
      _connect();
    }
  }

  void _connect() {
    if (_currentRole == null) return;
    
    if (_channel != null && isConnected) {
      _channel!.sink.close();
    }
    
    final wsPath = '/ws/${_currentRole!}';
    
    _channel = WebSocketChannel.connect(
      Uri.parse('ws://k2pat.net:3000$wsPath'),
    );
    
    _initializeWebSocket();
  }

  void _initializeWebSocket() {
    chatMessages.clear();
    botMessages.clear();
    
    _channel?.stream.listen(
      (message) {
        try {
          debugPrint('Received websocket message: $message');
          final data = jsonDecode(message.toString());
          
          if (data is List) {
            // Handle array of messages
            for (final msg in data) {
              _handleMessage(msg);
            }
          } else {
            // Handle single message
            _handleMessage(data);
          }
          
          notifyListeners();
        } catch (e, stackTrace) {
          debugPrint('Error parsing message: $e');
          debugPrint('Stack trace: $stackTrace');
          debugPrint('Raw message: $message');
          notifyListeners();
        }
      },
      onDone: () {
        isConnected = false;
        if (_channel != null) {
          Future.delayed(const Duration(seconds: 3), _connect);
        }
        notifyListeners();
      },
      onError: (error) {
        debugPrint('WebSocket Error: $error');
        isConnected = false;
        notifyListeners();
      },
    );
    
    isConnected = true;
    notifyListeners();
  }

  void _handleMessage(Map<String, dynamic> msg) {
    final messageType = msg['type'];
    
    if (messageType == 'chat') {
      _handleChatMessage(msg);
    } else if (messageType == 'text') {
      if (isInDispute) {
        _handleBotText(msg['text']);
      } else {
        _handleStreamingText(msg['text'], msg['role']);
      }
    } else if (messageType == 'done') {
      isStreaming = false;  // Set to false when streaming is done
      _handleDoneResponse(msg['content']);
    } else if (messageType == 'state') {
      _handleState(msg);
    }
    notifyListeners();
  }

  void _handleState(Map<String, dynamic> msg) {
    final state = msg['state'];
    if (state == 'dispute') {
      isInDispute = true;
      notifyListeners();
    }
  }

  void _handleBotText(String text) {
    waitResponse = false;  // Set to false when bot starts responding
    if (botMessages.isNotEmpty && !botMessages.last.isUser) {
      botMessages.last.text += text;
    } else {
      botMessages.add(BotMessage(text: text));
    }
    notifyListeners();
  }

  void _handleStreamingText(String text, [String? role]) {
    isStreaming = true;  // Set to true when streaming starts
    if (chatMessages.isNotEmpty && 
        !chatMessages.last.isUser && 
        chatMessages.last.role == 'system') {
      chatMessages.last.text += text;
    } else {
      chatMessages.add(ChatMessage(
        text: text,
        isUser: false,
        role: 'system',
      ));
    }
    notifyListeners();
  }

  void _handleChatMessage(Map<String, dynamic> msg) {
    _currentSession = msg['session']?.toString();
    
    if (msg['content'] == null) return;

    final contentList = msg['content'] as List;
    String? messageText;
    final List<MessageAttachment> messageAttachments = [];

    for (final content in contentList) {
      if (content['type'] == 'text') {
        messageText = content['text']?.toString();
      } else if (content['type'] == 'image' || content['type'] == 'document') {
        final source = content['source'] as Map<String, dynamic>;
        messageAttachments.add(MessageAttachment(
          type: content['type'],
          mediaType: source['media_type'],
          data: source['data'],
        ));
      }
    }

    if (messageText != null) {
      chatMessages.add(ChatMessage(
        text: messageText,
        isUser: false,
        role: _currentRole == 'buyer' ? 'seller' : 'buyer',  // Only set buyer/seller for non-bot messages
        attachments: messageAttachments,
      ));
    }
  }

  void _handleDoneResponse(Map<String, dynamic> content) {
    currentButtons.clear();
    currentFormFields.clear();

    if (content['buttons'] != null) {
      final buttons = content['buttons'] as List;
      currentButtons = buttons.map((btn) => ChatButton(
        label: btn['label'],
        description: btn['description'],
      )).toList();
    } 

    // Handle both array and single form field formats
    if (content['form'] != null) {
      if (content['form'] is List) {
        // Handle array format
        final formFields = content['form'] as List;
        currentFormFields = formFields.map((field) => ChatFormField(
          label: field['label'],
          inputType: field['inputType'],
          required: field['required'] ?? false,
          options: field['options'] != null
              ? (field['options'] as List).map((opt) => FormOption(
                    label: opt['label'],
                    value: opt['value'],
                  )).toList()
              : null,
        )).toList();
      } else {
        // Handle single field format
        final field = content['form'] as Map<String, dynamic>;
        currentFormFields = [
          ChatFormField(
            label: field['label'],
            inputType: field['inputType'],
            required: field['required'] ?? false,
            options: field['options'] != null
                ? (field['options'] as List).map((opt) => FormOption(
                      label: opt['label'],
                      value: opt['value'],
                    )).toList()
                : null,
          )
        ];
      }
    }
    notifyListeners();
  }

  void startDispute() {
    isInDispute = true;
    botMessages.clear();  // Only clear messages when initiating dispute
    final request = {
      'content': [
        {
          'type': 'state',
          'state': 'dispute'
        },
        {
          'type': 'text',
          'text': 'I want to dispute this transaction.'
        }
      ]
    };
    _channel?.sink.add(jsonEncode(request));
    notifyListeners();
  }

  void sendMessage(String message) {
    if (message.trim().isEmpty) return;
    
    final formattedMessage = {
      'content': [
        {
          'type': 'text',
          'text': message
        }
      ]
    };
    
    if (isInDispute) {
      botMessages.add(BotMessage(text: message, isUser: true));
      waitResponse = true;  // Set to true when user sends message
      print(message);
    } else {
      chatMessages.add(ChatMessage(
        text: message,
        isUser: true,
        role: _currentRole ?? 'system',
      ));
    }
    
    _channel?.sink.add(jsonEncode(formattedMessage));
    currentButtons.clear();
    currentFormFields.clear();
    notifyListeners();
  }

  Future<void> sendFiles(List<PlatformFile> files) async {
    final List<Map<String, dynamic>> content = [];
    
    for (final file in files) {
      final bytes = await file.bytes;
      if (bytes == null) continue;

      final base64Data = base64Encode(bytes);
      final mediaType = _getMediaType(file.extension ?? '');
      
      if (mediaType.startsWith('image/')) {
        content.add({
          'type': 'image',
          'source': {
            'type': 'base64',
            'media_type': mediaType,
            'data': base64Data,
          },
        });
      } else if (mediaType == 'application/pdf') {
        content.add({
          'type': 'document',
          'source': {
            'type': 'base64',
            'media_type': 'application/pdf',
            'data': base64Data,
          },
        });
      }
    }

    if (content.isNotEmpty) {
      final request = {
        'content': content
      };
      _channel?.sink.add(jsonEncode(request));  // Send the properly formatted request
      notifyListeners();
    }
  }

  String _getMediaType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> addPendingAttachments(List<PlatformFile> files) async {
    for (final file in files) {
      final bytes = await file.bytes;
      if (bytes == null) continue;

      final base64Data = base64Encode(bytes);
      final mediaType = _getMediaType(file.extension ?? '');
      
      if (mediaType.startsWith('image/') || mediaType == 'application/pdf') {
        pendingAttachments.add(PendingAttachment(
          fileName: file.name,
          mediaType: mediaType,
          base64Data: base64Data,
        ));
      }
    }
    notifyListeners();
  }

  void removePendingAttachment(int index) {
    pendingAttachments.removeAt(index);
    notifyListeners();
  }

  void sendMessageWithAttachments(String message) {
    if (message.trim().isEmpty || pendingAttachments.isEmpty) return;
    
    final List<Map<String, dynamic>> content = [];
    final List<MessageAttachment> messageAttachments = [];
    
    // Add text message first
    content.add({
      'type': 'text',
      'text': message,
    });

    // Add attachments
    for (final attachment in pendingAttachments) {
      if (attachment.mediaType.startsWith('image/')) {
        content.add({
          'type': 'image',
          'source': {
            'type': 'base64',
            'media_type': attachment.mediaType,
            'data': attachment.base64Data,
          },
        });
        messageAttachments.add(MessageAttachment(
          type: 'image',
          mediaType: attachment.mediaType,
          data: attachment.base64Data,
          fileName: attachment.fileName,
        ));
      } else if (attachment.mediaType == 'application/pdf') {
        content.add({
          'type': 'document',
          'source': {
            'type': 'base64',
            'media_type': 'application/pdf',
            'data': attachment.base64Data,
          },
        });
        messageAttachments.add(MessageAttachment(
          type: 'document',
          mediaType: 'application/pdf',
          data: attachment.base64Data,
          fileName: attachment.fileName,
        ));
      }
    }

    final request = {
      'content': content
    };
    
    if (isInDispute) {
      botMessages.add(BotMessage(text: message, isUser: true));
      waitResponse = true;  // Set to true for attachment messages too
    } else {
      chatMessages.add(ChatMessage(
        text: message,
        isUser: true,
        role: _currentRole ?? 'system',
        attachments: messageAttachments,
      ));
    }
    
    _channel?.sink.add(jsonEncode(request));
    pendingAttachments.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _channel = null;
    super.dispose();
  }
}

class ChatMessage {
  final bool isUser;
  final String role;
  String text;
  List<MessageAttachment> attachments;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.role,
    this.attachments = const [],
  });
}

class MessageAttachment {
  final String type;  // 'image' or 'document'
  final String mediaType;
  final String data;
  final String? fileName;

  MessageAttachment({
    required this.type,
    required this.mediaType,
    required this.data,
    this.fileName,
  });

  bool get isImage => type == 'image';
  bool get isPdf => type == 'document' && mediaType == 'application/pdf';
}

class BotMessage {
  final bool isUser;
  String text;

  BotMessage({
    required this.text,
    this.isUser = false,
  });
}

class ChatButton {
  final String label;
  final String description;

  ChatButton({
    required this.label,
    required this.description,
  });
}

class ChatFormField {
  final String label;
  final String inputType;
  final bool required;
  final List<FormOption>? options;

  ChatFormField({
    required this.label,
    required this.inputType,
    required this.required,
    this.options,
  });
}

class FormOption {
  final String label;
  final String value;

  FormOption({
    required this.label,
    required this.value,
  });
}

class PendingAttachment {
  final String fileName;
  final String mediaType;
  final String base64Data;

  PendingAttachment({
    required this.fileName,
    required this.mediaType,
    required this.base64Data,
  });

  bool get isImage => mediaType.startsWith('image/');
  bool get isPdf => mediaType == 'application/pdf';
} 