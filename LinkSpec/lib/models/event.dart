
class AppEvent {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final String location;
  final String? imageUrl;
  final String attendeeCount;
  final String domainId;

  AppEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.location,
    this.imageUrl,
    required this.attendeeCount,
    required this.domainId,
  });
}
