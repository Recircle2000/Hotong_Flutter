import 'package:get/get.dart';

import 'package:hsro/features/notice/models/emergency_notice_model.dart';
import 'package:hsro/features/notice/repository/emergency_notice_repository.dart';

class EmergencyNoticeViewModel extends GetxController {
  EmergencyNoticeViewModel({EmergencyNoticeRepository? repository})
      : _repository = repository ?? EmergencyNoticeRepository();

  final EmergencyNoticeRepository _repository;

  // 카테고리별 최신 공지와 로딩 상태 캐시
  final RxMap<EmergencyNoticeCategory, EmergencyNotice?>
      _latestNoticeByCategory =
      <EmergencyNoticeCategory, EmergencyNotice?>{}.obs;
  final RxMap<EmergencyNoticeCategory, bool> _isLoadingByCategory =
      <EmergencyNoticeCategory, bool>{}.obs;

  EmergencyNotice? noticeFor(EmergencyNoticeCategory category) =>
      _latestNoticeByCategory[category];

  bool isLoadingFor(EmergencyNoticeCategory category) =>
      _isLoadingByCategory[category] ?? false;

  Future<void> fetchLatestNotice(
    EmergencyNoticeCategory category, {
    bool force = false,
  }) async {
    // 이미 조회한 카테고리는 force가 없으면 재사용
    if (!force && _latestNoticeByCategory.containsKey(category)) {
      return;
    }
    // 같은 카테고리 중복 요청 방지
    if (_isLoadingByCategory[category] == true) {
      return;
    }

    _isLoadingByCategory[category] = true;
    try {
      // 긴급 공지 없거나 오류가 나도 null로 정리
      final notice = await _repository.fetchLatestNotice(category);
      _latestNoticeByCategory[category] = notice;
    } catch (_) {
      _latestNoticeByCategory[category] = null;
    } finally {
      _isLoadingByCategory[category] = false;
    }
  }
}
