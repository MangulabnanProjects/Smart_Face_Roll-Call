import 'package:flutter/material.dart';
import 'dart:convert';

class AnalysisCard extends StatelessWidget {
  final String? imageBase64;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool isLightTheme;

  const AnalysisCard({
    super.key,
    required this.imageBase64,
    required this.title,
    this.subtitle,
    this.onTap,
    this.isLightTheme = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isLightTheme ? Colors.white : const Color(0xFF2A2F3A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isLightTheme 
                ? Colors.blue.withOpacity(0.2)
                : const Color(0xFF00D9C9).withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isLightTheme 
                  ? Colors.black.withOpacity(0.08)
                  : Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Container(
                height: 120,
                width: double.infinity,
                color: isLightTheme ? Colors.grey[100] : const Color(0xFF1E2329),
                child: imageBase64 != null && imageBase64!.isNotEmpty
                    ? Image.memory(
                        base64Decode(imageBase64!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(Icons.error_outline, color: Colors.red),
                          );
                        },
                      )
                    : Center(
                        child: Icon(
                          Icons.image_not_supported,
                          color: isLightTheme ? Colors.grey[400] : Colors.grey,
                          size: 40,
                        ),
                      ),
              ),
            ),
            
            // Title and subtitle
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isLightTheme ? Colors.black87 : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: isLightTheme ? Colors.grey[600] : Colors.white54,
                        fontSize: 10,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

