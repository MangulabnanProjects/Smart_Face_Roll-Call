class DetectionVisualization {
  final String? camHeatmap;
  final String? featureLayers;
  final String? detectionGrid;
  final String? pipelineComparison;
  final String? featurePoints;
  final String? confidenceDistribution;
  final List<double> confidenceScores;
  final List<String> detectedIdentities;

  DetectionVisualization({
    this.camHeatmap,
    this.featureLayers,
    this.detectionGrid,
    this.pipelineComparison,
    this.featurePoints,
    this.confidenceDistribution,
    required this.confidenceScores,
    required this.detectedIdentities,
  });

  factory DetectionVisualization.fromJson(Map<String, dynamic> json) {
    final visualizations = json['visualizations'] as Map<String, dynamic>?;
    
    return DetectionVisualization(
      camHeatmap: visualizations?['cam'],
      featureLayers: visualizations?['feature_layers'],
      detectionGrid: visualizations?['detection_grid'],
      pipelineComparison: visualizations?['pipeline'],
      featurePoints: visualizations?['feature_points'],
      confidenceDistribution: visualizations?['confidence_dist'],
      confidenceScores: (json['confidence_scores'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      detectedIdentities: (json['detected_identities'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'visualizations': {
        'cam': camHeatmap,
        'feature_layers': featureLayers,
        'detection_grid': detectionGrid,
        'pipeline': pipelineComparison,
        'feature_points': featurePoints,
        'confidence_dist': confidenceDistribution,
      },
      'confidence_scores': confidenceScores,
      'detected_identities': detectedIdentities,
    };
  }

  bool get hasVisualizations => 
      camHeatmap != null || 
      featureLayers != null || 
      detectionGrid != null;

  double get averageConfidence {
    if (confidenceScores.isEmpty) return 0.0;
    return confidenceScores.reduce((a, b) => a + b) / confidenceScores.length;
  }
}
