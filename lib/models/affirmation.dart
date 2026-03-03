/// Data model for a single affirmation.
/// Used for display, favorites, and sharing.
class Affirmation {
  final String id;
  final String text;
  final String category;
  bool isFavorite;

  Affirmation({
    required this.id,
    required this.text,
    required this.category,
    this.isFavorite = false,
  });

  /// Create from JSON (e.g. from affirmations.json).
  factory Affirmation.fromJson(Map<String, dynamic> json) {
    return Affirmation(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      category: json['category'] as String? ?? 'general',
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'category': category,
        'isFavorite': isFavorite,
      };

  Affirmation copyWith({
    String? id,
    String? text,
    String? category,
    bool? isFavorite,
  }) {
    return Affirmation(
      id: id ?? this.id,
      text: text ?? this.text,
      category: category ?? this.category,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
