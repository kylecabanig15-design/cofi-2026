import 'package:flutter/material.dart';

// Aidy App Color Palette (Notion-style Black & White)
const primary = Color(0xFF8B0C17); // Black
const accent = Color(0xFF666666); // Dark Grey Accent
const background = Color(0xFF090707); // Dark background
const surface = Color(0xFFFFFFFF); // Surface color (white)
const textLight = Color(0xFF000000); // Primary text (black)
const textGrey = Color(0xFF666666); // Secondary text (dark grey)
const buttonText = Color(0xFFFFFFFF); // Button text color (white)

// Legacy colors (keeping for backward compatibility)
const secondary = Color(0xFF888888); // Medium Grey
const darkPrimary = Color(0xFF222222); // Almost Black
const black = Color(0xFF000000); // Black
const white = Color(0xFFFFFFFF); // White
const grey = Color(0xFFCCCCCC); // Light Grey

TimeOfDay parseTime(String timeString) {
  List<String> parts = timeString.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}
