import '../../domain/entities/announcement.dart';
import '../../domain/repositories/announcement_repository.dart';
import '../datasources/local/announcement_local_datasource.dart';

class AnnouncementRepositoryImpl implements AnnouncementRepository {
  AnnouncementRepositoryImpl(this.localDataSource);

  final AnnouncementLocalDataSource localDataSource;

  @override
  Future<List<Announcement>> fetchAnnouncements() {
    return localDataSource.readAll();
  }
}
