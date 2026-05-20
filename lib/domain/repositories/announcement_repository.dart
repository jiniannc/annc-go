import '../entities/announcement.dart';

abstract class AnnouncementRepository {
  Future<List<Announcement>> fetchAnnouncements();
}
