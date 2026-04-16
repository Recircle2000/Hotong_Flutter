class Notice {
  // 일반 공지 데이터 모델
  final int id;
  final String title;
  final String content;
  final String noticeType;
  final DateTime createdAt;

  Notice({
    required this.id,
    required this.title,
    required this.content,
    required this.noticeType,
    required this.createdAt,
  });

  factory Notice.fromJson(Map<String, dynamic> json) {
    // 서버 응답을 공지 모델로 변환
    return Notice(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      // notice_type 누락 시 기본값은 App
      noticeType: json['notice_type'] ?? 'App',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
