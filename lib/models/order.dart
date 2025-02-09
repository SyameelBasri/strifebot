class Order {
  final String? orderId;
  final User? buyer;
  final User? seller;
  final Transaction? transaction;
  final String? status;
  final Resolution? resolution;

  Order({
    this.orderId,
    this.buyer,
    this.seller,
    this.transaction,
    this.status,
    this.resolution,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      orderId: json['orderId'],
      buyer: json['buyer'] != null ? User.fromJson(json['buyer']) : null,
      seller: json['seller'] != null ? User.fromJson(json['seller']) : null,
      transaction: json['transaction'] != null ? Transaction.fromJson(json['transaction']) : null,
      status: json['status'],
      resolution: json['resolution'] != null ? Resolution.fromJson(json['resolution']) : null,
    );
  }
}

class User {
  final String? name;
  final String? chatInitial;

  User({
    this.name,
    this.chatInitial,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      name: json['name'],
      chatInitial: json['chatInitial'],
    );
  }
}

class Transaction {
  final String? rate;
  final String? send;
  final String? receive;
  final String? time;
  final String? paymentDetails;
  final String? instructions;
  final String? orderTitle;

  Transaction({
    this.rate,
    this.send,
    this.receive,
    this.time,
    this.paymentDetails,
    this.instructions,
    this.orderTitle,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      rate: json['rate'],
      send: json['send'],
      receive: json['receive'],
      time: json['time'],
      paymentDetails: json['paymentDetails'],
      instructions: json['instructions'],
      orderTitle: json['orderTitle'],
    );
  }
}

class Resolution {
  final String? description;
  final DateTime? resolvedAt;
  final String? resolvedBy;

  Resolution({
    this.description,
    this.resolvedAt,
    this.resolvedBy,
  });

  factory Resolution.fromJson(Map<String, dynamic> json) {
    String? mappedResolvedBy;
    if (json['resolvedBy'] != null) {
      mappedResolvedBy = json['resolvedBy'] == 'human' 
          ? 'Customer Support Agent' 
          : json['resolvedBy'] == 'ai' 
              ? 'StrifeBot' 
              : null;
    }

    return Resolution(
      description: json['description'],
      resolvedAt: json['resolvedAt'] != null ? DateTime.parse(json['resolvedAt']) : null,
      resolvedBy: mappedResolvedBy,
    );
  }
} 