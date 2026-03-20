import 'package:flutter/material.dart';

/// App-wide constants
class AppConstants {
  // App Info
  static const String appName = 'linkspec';
  static const String appTagline = 'Professional Networking, Domain-Focused';
  
  // Domains
  static const List<String> domains = [
    'Software Development',
    'AI, Data & Analytics',
    'Data Engineering & Databases',
    'Cloud, DevOps & Infrastructure',
    'Cybersecurity & Risk',
    'Networking & IT Support',
    'Business, Product & Management',
    'Finance, Risk & Compliance',
    'Healthcare & Life Sciences',
    'Core Engineering',
    'Agriculture & Environmental',
    'Design & Creative',
    'Sales, Marketing & CRM',
    'ERP & Enterprise Systems',
    'HR, Operations & Support',
  ];
  
  // Domain Icons
  static const Map<String, IconData> domainIcons = {
    'Software Development':          Icons.code,
    'AI, Data & Analytics':          Icons.auto_awesome,
    'Data Engineering & Databases':  Icons.storage,
    'Cloud, DevOps & Infrastructure':Icons.cloud_queue,
    'Cybersecurity & Risk':          Icons.security,
    'Networking & IT Support':       Icons.router,
    'Business, Product & Management':Icons.business_center,
    'Finance, Risk & Compliance':    Icons.account_balance,
    'Healthcare & Life Sciences':    Icons.local_hospital,
    'Core Engineering':              Icons.engineering,
    'Agriculture & Environmental':   Icons.eco,
    'Design & Creative':             Icons.palette,
    'Sales, Marketing & CRM':        Icons.campaign,
    'ERP & Enterprise Systems':      Icons.hub,
    'HR, Operations & Support':      Icons.people,
  };
  
  // Domain Colors
  static const Map<String, Color> domainColors = {
    'Software Development':          Color(0xFF1565C0),
    'AI, Data & Analytics':          Color(0xFF6A1B9A),
    'Data Engineering & Databases':  Color(0xFF00838F),
    'Cloud, DevOps & Infrastructure':Color(0xFF0277BD),
    'Cybersecurity & Risk':          Color(0xFFC62828),
    'Networking & IT Support':       Color(0xFF00695C),
    'Business, Product & Management':Color(0xFF558B2F),
    'Finance, Risk & Compliance':    Color(0xFF2E7D32),
    'Healthcare & Life Sciences':    Color(0xFFE53935),
    'Core Engineering':              Color(0xFFE65100),
    'Agriculture & Environmental':   Color(0xFF388E3C),
    'Design & Creative':             Color(0xFFAD1457),
    'Sales, Marketing & CRM':        Color(0xFFFF6F00),
    'ERP & Enterprise Systems':      Color(0xFF4527A0),
    'HR, Operations & Support':      Color(0xFF00897B),
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

