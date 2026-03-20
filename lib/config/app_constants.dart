import 'package:flutter/material.dart';

/// App-wide constants
class AppConstants {
  // App Info
  static const String appName = 'linkspec';
  static const String appTagline = 'Professional Networking, Domain-Focused';
  
  // Domains
  static const List<String> domains = [
    'Medical',
    'IT/Software',
    'Civil Engineering',
    'Law',
    'Business',
    'Global',
  ];
  
  // Domain Icons
  static const Map<String, IconData> domainIcons = {
    'Medical': Icons.local_hospital,
    'IT/Software': Icons.computer,
    'Civil Engineering': Icons.engineering,
    'Law': Icons.gavel,
    'Business': Icons.business_center,
    'Global': Icons.public_rounded,
  };
  
  // Domain Colors
  static const Map<String, Color> domainColors = {
    'Medical': Color(0xFFE53935),
    'IT/Software': Color(0xFF1E88E5),
    'Civil Engineering': Color(0xFFFB8C00),
    'Law': Color(0xFF8E24AA),
    'Business': Color(0xFF00897B),
    'Global': Color(0xFF00BFA5), // Teal for global
  };
  
  // Validation
  static const int minNameLength = 2;
  static const int maxNameLength = 50;
  static const int maxBioLength = 200;
  static const int minPostLength = 500;
  static const int maxPostLength = 5000;
  
  // Media Upload
  static const int maxMediaSize = 10 * 1024 * 1024; // 10MB
  static const List<String> allowedImageExtensions = ['jpg', 'jpeg', 'png'];
  static const List<String> allowedVideoExtensions = ['mp4'];
  static const String defaultCacheControl = '3600';
  
  // UI
  static const double defaultPadding = 16.0;
  static const double defaultRadius = 12.0;
  static const Duration animationDuration = Duration(milliseconds: 300);
}

