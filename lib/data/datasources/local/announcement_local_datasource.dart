import '../../models/announcement_model.dart';
import '../../../domain/entities/announcement.dart';

abstract class AnnouncementLocalDataSource {
  Future<List<AnnouncementModel>> readAll();
}

class InMemoryAnnouncementLocalDataSource
    implements AnnouncementLocalDataSource {
  @override
  Future<List<AnnouncementModel>> readAll() async {
    return const [
      AnnouncementModel(
        id: 'r1',
        category: AnnouncementCategory.routine,
        phaseId: 'R01',
        flightPhase: 'Preparation for departure',
        title: '도어 클로징 전 환영 안내',
        contentKR: '안녕하십니까, 탑승해 주셔서 감사합니다.',
        contentEN: 'Welcome onboard and thank you for flying with us.',
      ),
      AnnouncementModel(
        id: 'r2',
        category: AnnouncementCategory.routine,
        phaseId: 'R03',
        flightPhase: 'Welcome',
        title: '기내 안전 브리핑',
        contentKR: '안전을 위해 안전벨트를 착용해 주시기 바랍니다.',
        contentEN: 'For your safety, please fasten your seatbelt.',
      ),
      AnnouncementModel(
        id: 'r3',
        category: AnnouncementCategory.routine,
        phaseId: 'R05',
        flightPhase: 'Meal SVC',
        title: '식음료 서비스 안내',
        contentKR: '잠시 후 식음료 서비스를 시작하겠습니다.',
        contentEN: 'We will begin meal and beverage service shortly.',
      ),
      AnnouncementModel(
        id: 's1',
        category: AnnouncementCategory.situational,
        phaseId: 'S01',
        flightPhase: 'Any',
        title: '난기류 예고 안내',
        contentKR: '기체 흔들림이 예상됩니다. 착석 후 안전벨트를 착용해 주세요.',
        contentEN:
            'Turbulence is expected. Please return to your seat and fasten your seatbelt.',
      ),
      AnnouncementModel(
        id: 'e1',
        category: AnnouncementCategory.emergency,
        phaseId: 'E01',
        flightPhase: 'Any',
        title: '비상 착수 준비 안내',
        contentKR: '비상 착수에 대비하여 승무원의 지시에 따라 주십시오.',
        contentEN:
            'Prepare for emergency ditching and follow crew instructions.',
      ),
    ];
  }
}
