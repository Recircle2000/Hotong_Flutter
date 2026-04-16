enum EmergencyNoticeCategory {
  // API에서 사용하는 긴급 공지 카테고리 값
  shuttle('shuttle'),
  asanCitybus('asan_citybus'),
  cheonanCitybus('cheonan_citybus'),
  subway('subway');

  const EmergencyNoticeCategory(this.apiValue);

  final String apiValue;
}

class EmergencyNotice {
  // 긴급 공지 데이터 모델
  final int id;
  final String category;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime endAt;

  const EmergencyNotice({
    required this.id,
    required this.category,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.endAt,
  });

  factory EmergencyNotice.fromJson(Map<String, dynamic> json) {
    // 서버 응답을 긴급 공지 모델로 변환
    return EmergencyNotice(
      id: json['id'] as int,
      category: json['category'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      endAt: DateTime.parse(json['end_at'] as String),
    );
  }
}
