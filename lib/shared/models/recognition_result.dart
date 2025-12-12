class RecognitionResult {
  final String? personId;
  final double confidence;
  final DateTime timestamp;
  final Map<String, double>? boundingBox;
  final String imagePath;

  RecognitionResult({
    this.personId,
    required this.confidence,
    required this.timestamp,
    this.boundingBox,
    required this.imagePath,
  });

  // Convert to JSON for cloud storage
  Map<String, dynamic> toJson() {
    return {
      'personId': personId,
      'confidence': confidence,
      'timestamp': timestamp.toIso8601String(),
      'boundingBox': boundingBox,
      'imagePath': imagePath,
    };
  }

  // Create from JSON
  factory RecognitionResult.fromJson(Map<String, dynamic> json) {
    return RecognitionResult(
      personId: json['personId'],
      confidence: json['confidence'],
      timestamp: DateTime.parse(json['timestamp']),
      boundingBox: json['boundingBox'] != null
          ? Map<String, double>.from(json['boundingBox'])
          : null,
      imagePath: json['imagePath'],
    );
  }

  @override
  String toString() {
    return 'RecognitionResult(personId: $personId, confidence: $confidence, timestamp: $timestamp)';
  }
}
