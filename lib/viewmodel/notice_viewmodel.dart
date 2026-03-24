import 'package:flutter/painting.dart';
import 'package:get/get.dart';

import '../models/notice_model.dart';
import '../repository/notice_repository.dart';

class NoticeViewModel extends GetxController {
  NoticeViewModel({NoticeRepository? noticeRepository})
      : _noticeRepository = noticeRepository ?? NoticeRepository();

  final NoticeRepository _noticeRepository;

  final notice = Rxn<Notice>();
  final isLoading = false.obs;
  final error = ''.obs;
  final allNotices = <Notice>[].obs;
  final filteredNotices = <Notice>[].obs;
  final selectedFilter = '전체'.obs;

  final filterOptions = ['전체', '앱', '업데이트', '셔틀버스', '시내버스'];

  @override
  void onInit() {
    super.onInit();
    fetchLatestNotice();
  }

  void changeFilter(String filter) {
    selectedFilter.value = filter;
    _applyFilter();
  }

  void _applyFilter() {
    if (selectedFilter.value == '전체') {
      filteredNotices.value = List.from(allNotices);
      return;
    }

    final noticeType = _getNoticeTypeFromFilter(selectedFilter.value);
    filteredNotices.value =
        allNotices.where((item) => item.noticeType == noticeType).toList();
  }

  String _getNoticeTypeFromFilter(String filter) {
    switch (filter) {
      case '앱':
        return 'App';
      case '업데이트':
        return 'update';
      case '셔틀버스':
        return 'shuttle';
      case '시내버스':
        return 'citybus';
      default:
        return 'App';
    }
  }

  String getNoticeTypeDisplayName(String noticeType) {
    switch (noticeType) {
      case 'App':
        return '앱';
      case 'update':
        return '업데이트';
      case 'shuttle':
        return '셔틀버스';
      case 'citybus':
        return '시내버스';
      default:
        return '앱';
    }
  }

  Color getNoticeTypeColor(String noticeType) {
    switch (noticeType) {
      case 'App':
        return const Color(0xFF9E9E9E);
      case 'update':
        return const Color(0xFFFF9800);
      case 'shuttle':
        return const Color(0xFFB83227);
      case 'citybus':
        return const Color(0xFF2196F3);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  Future<void> fetchAllNotices() async {
    try {
      isLoading.value = true;
      error.value = '';

      allNotices.value = await _noticeRepository.fetchAllNotices();
      _applyFilter();
    } catch (_) {
      error.value = '네트워크 오류가 발생했습니다';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchLatestNotice() async {
    try {
      isLoading.value = true;
      error.value = '';
      notice.value = await _noticeRepository.fetchLatestNotice();
    } catch (e) {
      error.value = '오류: $e';
    } finally {
      isLoading.value = false;
    }
  }
}
