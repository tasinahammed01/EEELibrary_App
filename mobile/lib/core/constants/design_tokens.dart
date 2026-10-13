import 'package:flutter/material.dart';

abstract final class AppColors {
  static const navy = Color(0xFF142B50);
  static const blue = Color(0xFF244BC5);
  static const gold = Color(0xFFF2BD57);
  static const background = Color(0xFFF8F7F3);
  static const surface = Colors.white;
  static const muted = Color(0xFF59677C);
  static const outline = Color(0xFFD7DDE7);
  static const blueTint = Color(0xFFEBEFFB);
  static const goldTint = Color(0xFFFFF3D9);
}

abstract final class AppSpace {
  static const xs = 8.0;
  static const sm = 16.0;
  static const md = 24.0;
  static const lg = 32.0;
  static const xl = 48.0;
}

abstract final class AppRadius {
  static const control = 12.0;
  static const card = 16.0;
}

abstract final class AppSizes {
  static const touchTarget = 48.0;
  static const buttonHeight = 56.0;
  static const contentWidth = 480.0;
  static const illustrationIcon = 72.0;
}
