import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/order.dart';
import 'package:intl/intl.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  String _selectedRole = 'buyer';
  String _counterParty = 'seller';
  double _dragExtent = 0;
  static const double _minFlingVelocity = 700;
  static const double _dragIndicatorHeight = 80;
  Order? order;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchOrder();
  }

  Future<void> _fetchOrder() async {
    try {
      final response = await http.get(
        Uri.parse('http://k2pat.net:3000/api/order/123456789'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          order = Order.fromJson(data);
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'Failed to load order data';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Future<void> _resetOrder() async {
    try {
      final response = await http.post(
        Uri.parse('http://k2pat.net:3000/api/order/reset'),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Refresh order data after reset
        _fetchOrder();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to reset order'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragExtent -= details.primaryDelta!;
      _dragExtent = _dragExtent.clamp(0, _dragIndicatorHeight);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() > _minFlingVelocity || _dragExtent > _dragIndicatorHeight / 2) {
      _showChatSheet();
    }
    setState(() {
      _dragExtent = 0;
    });
  }

  void _showChatSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => ChatScreen(
          role: _selectedRole,
          orderId: order?.orderId ?? '',
          scrollController: scrollController,
        ),
      ),
    ).then((_) => _fetchOrder());
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'active':
        return Color(0xFF28A745);
      case 'disputed':
        return Color(0xFFFFA500);
      case 'resolved':
        return Color(0xFF007BFF);
      default:
        return Colors.black;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Date not available';
    return DateFormat('dd MMM yyyy, HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(child: Text(error!));
    }

    return Scaffold(
      body: Stack(
        children: [
          Container(
            color: const Color(0xFFF5F5F5),
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFDEE2E6)),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: DropdownButton<String>(
                                value: _selectedRole,
                                isExpanded: true,
                                underline: const SizedBox(),
                                items: const [
                                  DropdownMenuItem(value: 'buyer', child: Text('Buyer')),
                                  DropdownMenuItem(value: 'seller', child: Text('Seller')),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => {
                                      _selectedRole = value,
                                      _counterParty = value == 'buyer' ? 'seller' : 'buyer'
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _resetOrder,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE74C3C),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                            child: const Text(
                              'RESET',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Confirm payment',
                          style: TextStyle(
                            color: Color(0xFFE74C3C),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(order?.status),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                order?.status?.toUpperCase() ?? "-",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (order?.status == 'resolved')
                              IconButton(
                                icon: const Icon(Icons.info_outline),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: const Text('Resolution Details', style: TextStyle(fontWeight: FontWeight.bold)),
                                        content: SingleChildScrollView(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text(
                                                'Description',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(order?.resolution?.description ?? 'No description available'),
                                              const SizedBox(height: 16),
                                              const Text(
                                                'Resolved By',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(order?.resolution?.resolvedBy ?? 'Unknown'),
                                              const SizedBox(height: 16),
                                              const Text(
                                                'Resolved At',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                order?.resolution?.resolvedAt != null
                                                    ? _formatDate(order?.resolution?.resolvedAt)
                                                    : 'Date not available'
                                              ),
                                            ],
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                            child: const Text('Close'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      order?.transaction?.receive ?? "0",
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Order ID ${order?.orderId}',
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Buyer\'s name', order?.buyer?.name ?? "-"),
                    _buildInfoRow('Receive', order?.transaction?.receive ?? "0"),
                    _buildInfoRow('Send', order?.transaction?.send ?? "0"),
                    _buildInfoRow('Rate (1 USD)', order?.transaction?.rate ?? "0"),
                    _buildInfoRow('Time', order?.transaction?.time ?? ""),
                    const SizedBox(height: 24),
                    _buildSection('Your payment details:', order?.transaction?.paymentDetails ?? "-"),
                    const SizedBox(height: 8),
                    _buildSection('Buyer\'s instructions:', order?.transaction?.instructions ?? "-"),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE74C3C),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'I\'ve received payment',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onVerticalDragUpdate: _handleDragUpdate,
              onVerticalDragEnd: _handleDragEnd,
              child: Container(
                height: _dragIndicatorHeight + _dragExtent,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Chat with ${_counterParty}',
                      style: TextStyle(
                        color: Color(0xFFE74C3C),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF666666),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          content,
          style: const TextStyle(
            color: Color(0xFF666666),
            fontSize: 14,
          ),
        ),
      ],
    );
  }
} 