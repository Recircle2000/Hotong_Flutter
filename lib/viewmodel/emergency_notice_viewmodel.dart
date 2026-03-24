import 'package:get/get.dart';

import '../models/emergency_notice_model.dart';
import '../repository/emergency_notice_repository.dart';

class EmergencyNoticeViewModel extends GetxController {
  EmergencyNoticeViewModel({EmergencyNoticeRepository? repository})
      : _repository = repository ?? EmergencyNoticeRepository();

  final EmergencyNoticeRepository _repository;

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
    if (!force && _latestNoticeByCategory.containsKey(category)) {
      return;
    }
    if (_isLoadingByCategory[category] == true) {
      return;
    }

    _isLoadingByCategory[category] = true;
    try {
      final notice = await _repository.fetchLatestNotice(category);
      _latestNoticeByCategory[category] = notice;
    } catch (_) {
      _latestNoticeByCategory[category] = null;
    } finally {
      _isLoadingByCategory[category] = false;
    }
  }
}
