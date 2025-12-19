import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import '../../shared/models/detection_visualization.dart';
import '../../shared/widgets/confidence_indicator.dart';
import '../../shared/widgets/analysis_card.dart';

class DetectionAnalysisScreen extends StatelessWidget {
  final Map<String, dynamic> detectionResult;
  final File originalImage;

  const DetectionAnalysisScreen({
    super.key,
    required this.detectionResult,
    required this.originalImage,
  });

  @override
  Widget build(BuildContext context) {
    final visualization = DetectionVisualization.fromJson(detectionResult);
    final avgConfidence = visualization.averageConfidence;
    final identities = visualization.detectedIdentities;

    return Scaffold(
      backgroundColor: const Color(0xFF1E2329),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2329),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Analysis Complete',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Color(0xFF00D9C9)),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Download feature coming soon')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with status
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D9C9).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00D9C9).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D9C9).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Color(0xFF00D9C9),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Detection Successful',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'AI model analysis complete',
                            style: TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Primary Detection Card - DARK THEME with overflow fix
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2F3A),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00D9C9).withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Top row: Image and Info
                    Row(
                      children: [
                        // Original image thumbnail
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            originalImage,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                        
                        const SizedBox(width: 16),
                        
                        // Detection info - Flexible to prevent overflow
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PRIMARY DETECTION',
                                style: TextStyle(
                                  color: Color(0xFF00D9C9),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                identities.isNotEmpty
                                    ? identities.join(', ')
                                    : 'Person Detected',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Detected with high precision',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Confidence indicator (moved below to prevent overflow)
                    Center(
                      child: ConfidenceIndicator(
                        confidence: avgConfidence,
                        size: 110,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Neural Feature Analysis Section
              const Row(
                children: [
                  Icon(Icons.psychology, color: Color(0xFF00D9C9), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Neural Feature Analysis',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 4),
              
              const Text(
                'Model visualizations showing detection process',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
              
              const SizedBox(height: 16),
              
              // Visualization Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
                children: [
                  AnalysisCard(
                    imageBase64: visualization.camHeatmap,
                    title: 'Class Activation Map',
                    subtitle: 'Heat-colored critical regions',
                    onTap: () => _showFullImage(
                      context,
                      visualization.camHeatmap,
                      'Class Activation Map',
                    ),
                    isLightTheme: false,
                  ),
                  AnalysisCard(
                    imageBase64: visualization.featureLayers,
                    title: 'Deep Layer Features',
                    subtitle: 'Neural network extraction',
                    onTap: () => _showFullImage(
                      context,
                      visualization.featureLayers,
                      'Deep Layer Features',
                    ),
                    isLightTheme: false,
                  ),
                  AnalysisCard(
                    imageBase64: visualization.detectionGrid,
                    title: 'Detection Grid',
                    subtitle: 'YOLO grid cells',
                    onTap: () => _showFullImage(
                      context,
                      visualization.detectionGrid,
                      'Detection Grid',
                    ),
                    isLightTheme: false,
                  ),
                  AnalysisCard(
                    imageBase64: visualization.pipelineComparison,
                    title: 'Processing Pipeline',
                    subtitle: 'Enhancement stages',
                    onTap: () => _showFullImage(
                      context,
                      visualization.pipelineComparison,
                      'Processing Pipeline',
                    ),
                    isLightTheme: false,
                  ),
                  AnalysisCard(
                    imageBase64: visualization.featurePoints,
                    title: 'Feature Points',
                    subtitle: 'Facial landmarks',
                    onTap: () => _showFullImage(
                      context,
                      visualization.featurePoints,
                      'Feature Points',
                    ),
                    isLightTheme: false,
                  ),
                  AnalysisCard(
                    imageBase64: visualization.confidenceDistribution,
                    title: 'Confidence Distribution',
                    subtitle: 'Detection breakdown',
                    onTap: () => _showFullImage(
                      context,
                      visualization.confidenceDistribution,
                      'Confidence Distribution',
                    ),
                    isLightTheme: false,
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Bottom actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _showTechnicalDetails(context, visualization);
                      },
                      icon: const Icon(Icons.info_outline),
                      label: const Text('Details'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF00D9C9),
                        side: const BorderSide(color: Color(0xFF00D9C9)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Done'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00D9C9),
                        foregroundColor: const Color(0xFF1E2329),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context, String? base64Image, String title) {
    if (base64Image == null || base64Image.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Visualization not available')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1E2329),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.memory(
                  base64Decode(base64Image),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showTechnicalDetails(BuildContext context, DetectionVisualization viz) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2F3A),
        title: const Text(
          'Technical Details',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Model', 'YOLOv11'),
              _buildDetailRow('Detections', '${viz.detectedIdentities.length}'),
              _buildDetailRow(
                'Avg. Confidence',
                '${(viz.averageConfidence * 100).toStringAsFixed(2)}%',
              ),
              if (viz.confidenceScores.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Individual Scores:',
                  style: TextStyle(
                    color: Color(0xFF00D9C9),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...viz.detectedIdentities.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final name = entry.value;
                  final conf = viz.confidenceScores.length > idx
                      ? viz.confidenceScores[idx]
                      : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(name, style: const TextStyle(color: Colors.white70)),
                        Text(
                          '${(conf * 100).toStringAsFixed(2)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFF00D9C9)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
