import 'package:flutter/material.dart';

class Category {
  final int? id;
  final String name;
  final int iconCodePoint;
  final int colorValue;

  Category({
    this.id,
    required this.name,
    required this.iconCodePoint,
    required this.colorValue,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon_code_point': iconCodePoint,
      'color_value': colorValue,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      iconCodePoint: map['icon_code_point'],
      colorValue: map['color_value'],
    );
  }

  Category copyWith({
    int? id,
    String? name,
    int? iconCodePoint,
    int? colorValue,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);
} 