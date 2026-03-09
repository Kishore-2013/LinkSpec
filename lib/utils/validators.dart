import 'package:flutter/material.dart';

class Validators {
  /// Strictly validates emails based on RegEx and certain blocked domains.
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }

    final email = value.trim();

    // 1. Strict RegEx matching
    // - Prefix before @
    // - Domain with at least one dot
    // - TLD at least 2 characters long
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&' r"'" r'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid professional email';
    }

    // 2. Block obviously fake domains
    final blockedDomains = ['mail.com', 'test.com', 'example.com', 'tempmail.com'];
    final domain = email.split('@').last.toLowerCase();

    if (blockedDomains.contains(domain)) {
      return 'Please use a professional email address (no $domain)';
    }

    return null;
  }
}
