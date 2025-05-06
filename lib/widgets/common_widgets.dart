import 'package:flutter/material.dart';

// A collection of common widgets used throughout the app

class StatusBadge extends StatelessWidget {
  final String status;
  
  const StatusBadge({
    super.key,
    required this.status,
  });
  
  @override
  Widget build(BuildContext context) {
    final isActive = status == 'Active';
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: isActive ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: isActive ? Colors.green[700] : Colors.red[700],
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class RoleBadge extends StatelessWidget {
  final String role;
  
  const RoleBadge({
    super.key,
    required this.role,
  });
  
  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    
    if (role == 'Budget Manager') {
      backgroundColor = Colors.blue[50]!;
      textColor = Colors.blue[700]!;
    } else if (role == 'Financial Planning and Analysis Manager') {
      backgroundColor = Colors.purple[50]!;
      textColor = Colors.purple[700]!;
    } else {
      backgroundColor = Colors.green[50]!;
      textColor = Colors.green[700]!;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class CustomSearchField extends StatelessWidget {
  final String hintText;
  final ValueChanged<String>? onChanged;
  
  const CustomSearchField({
    super.key,
    required this.hintText,
    this.onChanged,
  });
  
  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
      ),
    );
  }
}

// More common widgets can be added here as needed