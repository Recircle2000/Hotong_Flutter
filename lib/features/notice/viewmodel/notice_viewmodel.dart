import 'package:flutter/painting.dart';
import 'package:get/get.dart';

import 'package:hsro/features/notice/models/notice_model.dart';
import 'package:hsro/features/notice/repository/notice_repository.dart';

class NoticeViewModel extends GetxController {
  NoticeViewModel({NoticeRepository? noticeRepository})
      : _noticeRepository = noticeRepository ?? NoticeRepository();

  final NoticeRepository _noticeRepository;

  // 홈 화면 최신 공지와 목록 화면 상태
  final notice = Rxn<Notice>();
  final isLoading = false.obs;
  final error = ''.obs;
  final allNotices = <Notice>[].obs;
  final filteredNotices = <Notice>[].obs;
  final selectedFilter = '전체'.obs;

  // 목록 화면 필터 옵션
  final filterOptions = ['전체', '앱', '업데이트', '셔틀버스', '시내버스'];

  @override
  void onInit() {
    super.onInit();
    // 홈 진입 시 최신 공지 먼저 조회
    fetchLatestNotice();
  }

  void changeFilter(String filter) {
    // 선택한 필터 저장 후 목록 재구성
    selectedFilter.value = filter;
    _applyFilter();
  }

  void _applyFilter() {
    // 전체 선택 시 원본 목록 그대로 사용
    if (selectedFilter.value == '전체') {
      filteredNotices.value = List.from(allNotices);
      return;
    }

    // 선택한 카테고리에 맞는 공지만 필터링
    final noticeType = _getNoticeTypeFromFilter(selectedFilter.value);
    filteredNotices.value =
        allNotices.where((item) => item.noticeType == noticeType).toList();
  }

  String _getNoticeTypeFromFilter(String filter) {
    // 화면 필터 문자열을 API notice_type 값으로 변환
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
    // notice_type 값을 사용자 표시용 한글명으로 변환
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
    // 공지 카테고리별 뱃지 색상 반환
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
      // 공지 목록 조회
      isLoading.value = true;
      error.value = '';

      allNotices.value = await _noticeRepository.fetchAllNotices();
      _applyFilter();
    } catch (_) {
      // 목록 화면에서는 공통 오류 문구 사용
      error.value = '네트워크 오류가 발생했습니다';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchLatestNotice() async {
    try {
      // 홈 화면 상단용 최신 공지 조회
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
