class Song {
  const Song({
    required this.id,
    required this.title,
    required this.artist,
  });

  final String id;
  final String title;
  final String artist;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Song) {
      return false;
    }
    return other.id == id && other.title == title && other.artist == artist;
  }

  @override
  int get hashCode => Object.hash(id, title, artist);
}
