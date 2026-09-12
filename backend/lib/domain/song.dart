class Song {
  const Song({required this.id, required this.title, required this.artist});

  final String id;
  final String title;
  final String artist;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Song) return false;
    return id == other.id && title == other.title && artist == other.artist;
  }

  @override
  int get hashCode => Object.hash(id, title, artist);

  Map<String, Object?> toJson() => {'id': id, 'title': title, 'artist': artist};
}