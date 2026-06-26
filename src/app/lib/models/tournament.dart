import 'package:cloud_firestore/cloud_firestore.dart';

/// A tournament groups matches. The app is generic — the frontend never
/// hard-codes "World Cup 2026"; it loads whichever tournament the user (or the
/// default) points at. Stored at match-chat/app/tournaments/{id}.
class Tournament {
  Tournament({
    required this.id,
    required this.name,
    required this.sport,
    this.isDefault = false,
    this.order = 0,
  });

  final String id;
  final String name;
  final String sport;
  final bool isDefault;
  final int order;

  factory Tournament.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return Tournament(
      id: doc.id,
      name: (d['name'] ?? 'Tournament') as String,
      sport: (d['sport'] ?? 'soccer') as String,
      isDefault: (d['isDefault'] ?? false) as bool,
      order: (d['order'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'name': name,
    'sport': sport,
    'isDefault': isDefault,
    'order': order,
  };
}
