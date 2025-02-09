import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:universal_html/html.dart' as html;
import 'package:lottie/lottie.dart';

class ChatScreen extends StatefulWidget {
  final String role;
  final ScrollController? scrollController;
  final String orderId;
  
  const ChatScreen({
    super.key, 
    required this.role,
    required this.orderId,
    this.scrollController,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  late final ScrollController _scrollController;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() {
      context.read<ChatProvider>().setRole(widget.role);
    });
  }

  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Handle role changes if the widget is updated
    if (oldWidget.role != widget.role) {
      context.read<ChatProvider>().setRole(widget.role);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildDragHandle(),
          _buildHeader(),
          _buildTabs(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildChatContent(),
                _buildDisputeContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      height: 4,
      width: 40,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE9ECEF))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Order #${widget.orderId}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF212529),
            ),
          ),
          _buildConnectionStatus(),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Consumer<ChatProvider>(
      builder: (context, provider, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: provider.isConnected ? const Color(0xFF28A745) : const Color(0xFFDC3545),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            provider.isConnected ? 'StrifeBot Online' : 'StrifeBot Offline',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE9ECEF))),
      ),
      child: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Chat'),
          Tab(text: 'StrifeBot'),
        ],
        labelColor: const Color(0xFFE74C3C),
        unselectedLabelColor: const Color(0xFF6C757D),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        indicatorColor: const Color(0xFFE74C3C),
        indicatorWeight: 2,
      ),
    );
  }

  Widget _buildChatContent() {
    return Column(
      children: [
        Expanded(child: _buildChatMessageList()),
        Consumer<ChatProvider>(
          builder: (context, provider, _) {
            if (!provider.isInDispute) {
              return _buildInputArea();
            } else {
              return Container(
                padding: const EdgeInsets.all(20),
                child: const Text(
                  'Chat is frozen due to ongoing dispute',
                  style: TextStyle(color: Colors.red),
                ),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildDisputeContent() {
    return Consumer<ChatProvider>(
      builder: (context, provider, _) {
        if (!provider.isInDispute) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: Lottie.asset(
                    'strifebot.json',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => provider.startDispute(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFE74C3C),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text(
                    'Complaint',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
          );
        }

        // Get the latest messages...
        String? latestUserMessage;
        String? latestBotMessage;
        if (provider.botMessages.isNotEmpty) {
          for (int i = provider.botMessages.length - 1; i >= 0; i--) {
            final message = provider.botMessages[i];
            if (message.isUser && latestUserMessage == null) {
              latestUserMessage = message.text;
            } else if (!message.isUser && latestBotMessage == null) {
              latestBotMessage = message.text;
            }
            if (latestUserMessage != null && latestBotMessage != null) break;
          }
        }

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // User's query at the top
                    if (latestUserMessage != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          latestUserMessage,
                          style: const TextStyle(
                            fontSize: 14,
                          ),
                        ),
                      ),

                    // Latest bot response
                    if (latestBotMessage != null && !provider.waitResponse)
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE74C3C),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          latestBotMessage.replaceAll('\\n', '\n'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),

                    // Show either waiting animation, interaction elements, or thinking animation
                    if (provider.waitResponse)
                      Container(
                        padding: const EdgeInsets.only(left: 16),
                        margin: const EdgeInsets.only(bottom: 20),
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: 100,
                          height: 100,
                          child: Lottie.asset(
                            'strifebot.json',
                            fit: BoxFit.contain,
                          ),
                        ),
                      )
                    else if (provider.currentButtons.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: provider.currentButtons.map((button) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: ElevatedButton(
                                onPressed: () {
                                  context.read<ChatProvider>().sendMessage(button.description);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFFE74C3C),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: const BorderSide(color: Color(0xFFE74C3C)),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(button.label),
                              ),
                            );
                          }).toList(),
                        ),
                      )
                    else if (provider.currentFormFields.isNotEmpty)
                      _buildDisputeForm(provider.currentFormFields)
                    else
                      Container(
                        padding: const EdgeInsets.only(left: 16),
                        margin: const EdgeInsets.only(bottom: 20),
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: 100,
                          height: 100,
                          child: Lottie.asset(
                            'strifebot.json',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            _buildInputArea(),
          ],
        );
      },
    );
  }

  Widget _buildDisputeForm(List<ChatFormField> fields) {
    final formKey = GlobalKey<FormState>();
    final Map<String, TextEditingController> controllers = {};

    for (var field in fields) {
      controllers[field.label] = TextEditingController();
    }

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...fields.map((field) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  field.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF212529),
                  ),
                ),
                const SizedBox(height: 8),
                if (field.inputType == 'dropdown' && field.options != null)
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFDEE2E6)),
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFDEE2E6)),
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF007BFF)),
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: field.options!.map((option) {
                      return DropdownMenuItem(
                        value: option.value,
                        child: Text(option.label),
                      );
                    }).toList(),
                    onChanged: (value) {
                      controllers[field.label]!.text = value ?? '';
                    },
                    validator: field.required
                        ? (value) => value == null || value.isEmpty ? 'This field is required' : null
                        : null,
                  )
                else
                  TextFormField(
                    controller: controllers[field.label],
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFDEE2E6)),
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFDEE2E6)),
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF007BFF)),
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    validator: field.required
                        ? (value) => value == null || value.isEmpty ? 'This field is required' : null
                        : null,
                  ),
              ],
            ),
          )).toList(),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final formContent = fields
                    .map((field) => '${field.label}: ${controllers[field.label]!.text}')
                    .join('\n');
                context.read<ChatProvider>().sendMessage(formContent);
                for (var controller in controllers.values) {
                  controller.clear();
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE74C3C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Widget _buildChatMessageList() {
    return Consumer<ChatProvider>(
      builder: (context, provider, _) {
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(20),
          itemCount: provider.chatMessages.length,
          itemBuilder: (context, index) {
            final message = provider.chatMessages[index];
            return message.text.trim().isNotEmpty 
                ? _buildChatBubble(message)
                : const SizedBox.shrink();
          },
        );
      },
    );
  }

  Widget _buildChatBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Column(
          crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (message.text.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!message.isUser) // Show name only for non-user messages
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                      child: Text(
                        _getName(message.role), // Make sure message has a senderName property
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: message.role == "system" ? const Color(0xFFE74C3C) : message.isUser 
                          ? const Color(0xFF007BFF) 
                          : const Color(0xFFE9ECEF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      message.text,
                      style: TextStyle(
                        color: message.role == "system" || message.isUser ? Colors.white : Colors.black,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            if (message.attachments.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: message.attachments.map((attachment) {
                  if (attachment.isImage) {
                    return GestureDetector(
                      onTap: () => _showImagePreview(context, attachment),
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFDEE2E6)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(attachment.data),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  } else if (attachment.isPdf) {
                    return GestureDetector(
                      onTap: () => _downloadFile(attachment),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFDEE2E6)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.picture_as_pdf, color: Colors.red[700]),
                            const SizedBox(width: 8),
                            Text(
                              attachment.fileName ?? 'Document.pdf',
                              style: const TextStyle(
                                color: Color(0xFF007BFF),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getName(String role) {
    if (role == "system") {
      return "StrifeBot";
    } else {
      return widget.role == "buyer" ? "Sarah Seller" : "John Buyer";
    }
  }

  void _showImagePreview(BuildContext context, MessageAttachment attachment) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.memory(
                base64Decode(attachment.data),
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.download, color: Colors.white),
                onPressed: () => _downloadFile(attachment),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _downloadFile(MessageAttachment attachment) {
    final bytes = base64Decode(attachment.data);
    final blob = html.Blob([bytes], attachment.mediaType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    
    final fileName = attachment.fileName ?? (attachment.isPdf ? 'document.pdf' : 'file');
    
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE9ECEF))),
      ),
      child: Column(
        children: [
          Consumer<ChatProvider>(
            builder: (context, provider, _) {
              if (provider.pendingAttachments.isNotEmpty) {
                return _buildAttachmentPreviews(provider.pendingAttachments);
              }
              return const SizedBox.shrink();
            },
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.attach_file),
                onPressed: _pickFiles,
                color: const Color(0xFF007BFF),
                iconSize: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Type your message...',
                    hintStyle: TextStyle(color: Color(0xFF6C757D)),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFDEE2E6)),
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFDEE2E6)),
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF007BFF)),
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF212529),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              _buildSendButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentPreviews(List<PendingAttachment> attachments) {
    return Container(
      height: 100,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: attachments.length,
        itemBuilder: (context, index) {
          final attachment = attachments[index];
          return Container(
            width: 80,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFDEE2E6)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                if (attachment.isImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      base64Decode(attachment.base64Data),
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Center(
                    child: Icon(
                      Icons.picture_as_pdf,
                      color: Colors.red[700],
                      size: 40,
                    ),
                  ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => context
                        .read<ChatProvider>()
                        .removePendingAttachment(index),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Color(0xFF6C757D),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSendButton() {
    return Consumer<ChatProvider>(
      builder: (context, provider, _) {
        final hasText = _messageController.text.trim().isNotEmpty;
        final canSend = provider.isConnected && hasText;
        
        return ElevatedButton(
          onPressed: canSend ? _sendMessage : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF007BFF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Send',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      },
    );
  }

  Widget _buildButtonsContainer(List<ChatButton> buttons) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: buttons.map((button) => _buildActionButton(button)).toList(),
      ),
    );
  }

  Widget _buildActionButton(ChatButton button) {
    return ElevatedButton(
      onPressed: () {
        context.read<ChatProvider>().sendMessage(button.description);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF007BFF),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        button.label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildForm(List<ChatFormField> fields) {
    final formKey = GlobalKey<FormState>();
    final Map<String, TextEditingController> controllers = {};

    // Initialize controllers for each field
    for (var field in fields) {
      controllers[field.label] = TextEditingController();
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...fields.map((field) => _buildFormField(field, controllers[field.label]!)),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final formContent = fields
                      .map((field) => '${field.label}: ${controllers[field.label]!.text}')
                      .join('\n');
                  context.read<ChatProvider>().sendMessage(formContent);
                  // Clear form after submission
                  for (var controller in controllers.values) {
                    controller.clear();
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007BFF),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              child: const Text(
                'Submit',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField(ChatFormField field, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            field.label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 5),
          if (field.inputType == 'dropdown' && field.options != null)
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              items: field.options!.map((option) {
                return DropdownMenuItem(
                  value: option.value,
                  child: Text(option.label),
                );
              }).toList(),
              onChanged: (value) {
                controller.text = value ?? '';
              },
              validator: field.required
                  ? (value) => value == null || value.isEmpty ? 'This field is required' : null
                  : null,
            )
          else
            TextFormField(
              controller: controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              validator: field.required
                  ? (value) => value == null || value.isEmpty ? 'This field is required' : null
                  : null,
            ),
        ],
      ),
    );
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    final provider = context.read<ChatProvider>();
    
    if (message.isNotEmpty) {
      if (provider.pendingAttachments.isNotEmpty) {
        provider.sendMessageWithAttachments(message);
      } else {
        provider.sendMessage(message);
      }
      _messageController.clear();
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'pdf'],
        allowMultiple: true,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final supportedFiles = result.files.where((file) {
          final ext = file.extension?.toLowerCase() ?? '';
          return ['jpg', 'jpeg', 'png', 'gif', 'pdf'].contains(ext);
        }).toList();

        if (supportedFiles.isNotEmpty) {
          context.read<ChatProvider>().addPendingAttachments(supportedFiles);
        }
      }
    } catch (e) {
      debugPrint('Error picking files: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error picking files. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 