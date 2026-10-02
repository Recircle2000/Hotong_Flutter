import 'package:intl/intl.dart';

class TaxiLocation {
  const TaxiLocation({
    required this.id,
    required this.name,
    required this.category,
    required this.sortOrder,
    required this.isActive,
  });

  final int id;
  final String name;
  final String category;
  final int sortOrder;
  final bool isActive;

  factory TaxiLocation.fromJson(Map<String, dynamic> json) => TaxiLocation(
    id: json['id'] as int,
    name: json['name'] as String,
    category: json['category'] as String,
    sortOrder: json['sort_order'] as int,
    isActive: json['is_active'] as bool,
  );
}

class TaxiMember {
  const TaxiMember({
    required this.label,
    required this.isOwner,
    required this.isMe,
    required this.joinedAt,
  });

  final String label;
  final bool isOwner;
  final bool isMe;
  final DateTime joinedAt;

  factory TaxiMember.fromJson(Map<String, dynamic> json) => TaxiMember(
    label: json['label'] as String,
    isOwner: json['is_owner'] as bool,
    isMe: json['is_me'] as bool,
    joinedAt: DateTime.parse(json['joined_at'] as String).toLocal(),
  );
}

class TaxiPartySummary {
  const TaxiPartySummary({
    required this.id,
    required this.meetingCode,
    required this.departureLocation,
    required this.destinationLocation,
    required this.departureSummary,
    required this.destinationSummary,
    required this.departureAt,
    required this.maxMembers,
    required this.currentMembers,
    required this.remainingSeats,
    required this.status,
    required this.recruitmentStatus,
    required this.chatStatus,
    required this.chatWritableUntil,
    required this.chatVisibleUntil,
    required this.isOwner,
    required this.isMember,
    required this.unreadCount,
  });

  final String id;
  final String? meetingCode;
  final TaxiLocation departureLocation;
  final TaxiLocation destinationLocation;
  final String departureSummary;
  final String? destinationSummary;
  final DateTime departureAt;
  final int maxMembers;
  final int currentMembers;
  final int remainingSeats;
  final String status;
  final String recruitmentStatus;
  final String chatStatus;
  final DateTime chatWritableUntil;
  final DateTime chatVisibleUntil;
  final bool isOwner;
  final bool isMember;
  final int unreadCount;

  TaxiPartySummary copyWith({int? unreadCount}) => TaxiPartySummary(
    id: id,
    meetingCode: meetingCode,
    departureLocation: departureLocation,
    destinationLocation: destinationLocation,
    departureSummary: departureSummary,
    destinationSummary: destinationSummary,
    departureAt: departureAt,
    maxMembers: maxMembers,
    currentMembers: currentMembers,
    remainingSeats: remainingSeats,
    status: status,
    recruitmentStatus: recruitmentStatus,
    chatStatus: chatStatus,
    chatWritableUntil: chatWritableUntil,
    chatVisibleUntil: chatVisibleUntil,
    isOwner: isOwner,
    isMember: isMember,
    unreadCount: unreadCount ?? this.unreadCount,
  );

  /// 안 읽음 수를 빼고 화면에 보이는 상태가 같은지. 같으면 상세를 다시 받을 필요가 없다.
  bool sameStateAs(TaxiPartySummary other) =>
      currentMembers == other.currentMembers &&
      maxMembers == other.maxMembers &&
      status == other.status &&
      recruitmentStatus == other.recruitmentStatus &&
      chatStatus == other.chatStatus &&
      departureAt == other.departureAt &&
      chatWritableUntil == other.chatWritableUntil &&
      chatVisibleUntil == other.chatVisibleUntil &&
      departureLocation.id == other.departureLocation.id &&
      destinationLocation.id == other.destinationLocation.id &&
      departureSummary == other.departureSummary &&
      destinationSummary == other.destinationSummary &&
      meetingCode == other.meetingCode &&
      isMember == other.isMember &&
      isOwner == other.isOwner;

  factory TaxiPartySummary.fromJson(Map<String, dynamic> json) {
    final departureAt = DateTime.parse(
      json['departure_at'] as String,
    ).toLocal();
    final legacyStatus = json['status'] as String;
    return TaxiPartySummary(
      id: json['id'] as String,
      meetingCode: json['meeting_code'] as String?,
      departureLocation: TaxiLocation.fromJson(
        json['departure_location'] as Map<String, dynamic>,
      ),
      destinationLocation: TaxiLocation.fromJson(
        json['destination_location'] as Map<String, dynamic>,
      ),
      departureSummary: json['departure_summary'] as String,
      destinationSummary: json['destination_summary'] as String?,
      departureAt: departureAt,
      maxMembers: json['max_members'] as int,
      currentMembers: json['current_members'] as int,
      remainingSeats: json['remaining_seats'] as int,
      status: legacyStatus,
      recruitmentStatus:
          json['recruitment_status'] as String? ??
          switch (legacyStatus) {
            'cancelled' => 'cancelled',
            'in_progress' || 'completed' => 'ended',
            _ => legacyStatus,
          },
      chatStatus:
          json['chat_status'] as String? ??
          (legacyStatus == 'cancelled' || legacyStatus == 'completed'
              ? 'read_only'
              : 'writable'),
      chatWritableUntil: json['chat_writable_until'] == null
          ? departureAt.add(const Duration(hours: 3))
          : DateTime.parse(json['chat_writable_until'] as String).toLocal(),
      chatVisibleUntil: json['chat_visible_until'] == null
          ? departureAt.add(const Duration(hours: 48))
          : DateTime.parse(json['chat_visible_until'] as String).toLocal(),
      isOwner: json['is_owner'] as bool,
      isMember: json['is_member'] as bool,
      unreadCount: json['unread_count'] as int,
    );
  }
}

class TaxiPartyDetail extends TaxiPartySummary {
  const TaxiPartyDetail({
    required super.id,
    required super.meetingCode,
    required super.departureLocation,
    required super.destinationLocation,
    required super.departureSummary,
    required super.destinationSummary,
    required super.departureAt,
    required super.maxMembers,
    required super.currentMembers,
    required super.remainingSeats,
    required super.status,
    required super.recruitmentStatus,
    required super.chatStatus,
    required super.chatWritableUntil,
    required super.chatVisibleUntil,
    required super.isOwner,
    required super.isMember,
    required super.unreadCount,
    required this.memberNote,
    required this.members,
    required this.cancellationReason,
    required this.createdAt,
  });

  final String? memberNote;
  final List<TaxiMember> members;
  final String? cancellationReason;
  final DateTime createdAt;

  @override
  TaxiPartyDetail copyWith({int? unreadCount}) => TaxiPartyDetail(
    id: id,
    meetingCode: meetingCode,
    departureLocation: departureLocation,
    destinationLocation: destinationLocation,
    departureSummary: departureSummary,
    destinationSummary: destinationSummary,
    departureAt: departureAt,
    maxMembers: maxMembers,
    currentMembers: currentMembers,
    remainingSeats: remainingSeats,
    status: status,
    recruitmentStatus: recruitmentStatus,
    chatStatus: chatStatus,
    chatWritableUntil: chatWritableUntil,
    chatVisibleUntil: chatVisibleUntil,
    isOwner: isOwner,
    isMember: isMember,
    unreadCount: unreadCount ?? this.unreadCount,
    memberNote: memberNote,
    members: members,
    cancellationReason: cancellationReason,
    createdAt: createdAt,
  );

  factory TaxiPartyDetail.fromJson(Map<String, dynamic> json) {
    final summary = TaxiPartySummary.fromJson(json);
    return TaxiPartyDetail(
      id: summary.id,
      meetingCode: summary.meetingCode,
      departureLocation: summary.departureLocation,
      destinationLocation: summary.destinationLocation,
      departureSummary: summary.departureSummary,
      destinationSummary: summary.destinationSummary,
      departureAt: summary.departureAt,
      maxMembers: summary.maxMembers,
      currentMembers: summary.currentMembers,
      remainingSeats: summary.remainingSeats,
      status: summary.status,
      recruitmentStatus: summary.recruitmentStatus,
      chatStatus: summary.chatStatus,
      chatWritableUntil: summary.chatWritableUntil,
      chatVisibleUntil: summary.chatVisibleUntil,
      isOwner: summary.isOwner,
      isMember: summary.isMember,
      unreadCount: summary.unreadCount,
      memberNote: json['member_note'] as String?,
      members: (json['members'] as List<dynamic>)
          .map((item) => TaxiMember.fromJson(item as Map<String, dynamic>))
          .toList(),
      cancellationReason: json['cancellation_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}

class TaxiMessage {
  const TaxiMessage({
    required this.id,
    required this.partyId,
    required this.messageType,
    required this.senderLabel,
    required this.isMine,
    required this.content,
    required this.createdAt,
  });

  final int id;
  final String partyId;
  final String messageType;
  final String? senderLabel;
  final bool isMine;
  final String content;
  final DateTime createdAt;

  bool get isSystem => messageType == 'system';

  factory TaxiMessage.fromJson(Map<String, dynamic> json) => TaxiMessage(
    id: json['id'] as int,
    partyId: json['party_id'] as String,
    messageType: json['message_type'] as String,
    senderLabel: json['sender_label'] as String?,
    isMine: json['is_mine'] as bool,
    content: json['content'] as String,
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
  );
}

class TaxiRealtimeEvent {
  const TaxiRealtimeEvent({
    required this.type,
    this.partyId,
    this.message,
    this.party,
    this.code,
    this.errorMessage,
  });

  final String type;
  final String? partyId;
  final TaxiMessage? message;
  final TaxiPartySummary? party;
  final String? code;
  final String? errorMessage;

  factory TaxiRealtimeEvent.fromJson(Map<String, dynamic> json) =>
      TaxiRealtimeEvent(
        type: json['type'] as String? ?? 'unknown',
        partyId: json['party_id'] as String?,
        message: json['message'] is Map<String, dynamic>
            ? TaxiMessage.fromJson(json['message'] as Map<String, dynamic>)
            : null,
        // 팟 변경 알림에는 참여자 목록까지 담긴 상세가 온다.
        party: switch (json['party']) {
          final Map<String, dynamic> party when party['members'] is List =>
            TaxiPartyDetail.fromJson(party),
          final Map<String, dynamic> party => TaxiPartySummary.fromJson(party),
          _ => null,
        },
        code: json['code'] as String?,
        errorMessage: json['message'] is String
            ? json['message'] as String
            : null,
      );
}

/// 택시팟 참여자 신고 사유. [code]는 서버 값이다.
enum TaxiReportReason {
  noShow('no_show', '노쇼', '약속 장소에 나타나지 않았어요'),
  abuse('abuse', '욕설·비매너', '불쾌한 말이나 행동을 했어요'),
  payment('payment', '정산 문제', '택시비를 보내지 않거나 다르게 요구했어요'),
  other('other', '기타', '');

  const TaxiReportReason(this.code, this.label, this.description);

  final String code;
  final String label;
  final String description;
}

/// 관리자가 부과한 택시팟 제재. 경고는 이용 제한이 없다.
class TaxiSanction {
  const TaxiSanction({
    required this.id,
    required this.level,
    required this.reason,
    required this.startsAt,
    required this.endsAt,
  });

  final int id;

  /// warning, suspend_3d, suspend_7d, permanent
  final String level;
  final String reason;
  final DateTime startsAt;
  final DateTime? endsAt;

  bool get isWarning => level == 'warning';
  bool get isPermanent => level == 'permanent';

  String get levelLabel => switch (level) {
    'warning' => '경고',
    'suspend_3d' => '3일 이용 정지',
    'suspend_7d' => '7일 이용 정지',
    _ => '영구 이용 정지',
  };

  /// 정지 기간 안내. 경고는 null이다.
  String? get periodLabel {
    if (isWarning) return null;
    final ends = endsAt;
    if (ends == null) return '영구';
    return '${DateFormat('M월 d일 HH:mm', 'ko').format(ends)}까지';
  }

  factory TaxiSanction.fromJson(Map<String, dynamic> json) => TaxiSanction(
    id: json['id'] as int,
    level: json['level'] as String,
    reason: json['reason'] as String,
    startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
    endsAt: json['ends_at'] == null
        ? null
        : DateTime.parse(json['ends_at'] as String).toLocal(),
  );
}

class TaxiRestriction {
  const TaxiRestriction({this.userKey, this.suspension, this.notice});

  /// 이의제기 때 알려줄 내 고유번호 6자리. 관리자 화면의 익명 ID와 같다.
  final String? userKey;

  /// 지금 적용 중인 이용 정지
  final TaxiSanction? suspension;

  /// 아직 확인하지 않은 제재 안내(경고 포함)
  final TaxiSanction? notice;

  factory TaxiRestriction.fromJson(Map<String, dynamic> json) =>
      TaxiRestriction(
        userKey: json['user_key'] as String?,
        suspension: json['suspension'] is Map<String, dynamic>
            ? TaxiSanction.fromJson(json['suspension'] as Map<String, dynamic>)
            : null,
        notice: json['notice'] is Map<String, dynamic>
            ? TaxiSanction.fromJson(json['notice'] as Map<String, dynamic>)
            : null,
      );
}

/// 택시 화면에 들어오거나 돌아올 때 한 번에 받는 데이터.
class TaxiHome {
  const TaxiHome({
    required this.parties,
    required this.myParties,
    required this.recentChats,
    required this.restriction,
    this.locations,
    this.history,
  });

  /// 요청했을 때만 온다.
  final List<TaxiLocation>? locations;
  final List<TaxiPartySummary> parties;

  /// 출발 전인 내 팟. 참여자 목록까지 담겨 현재팟 화면이 바로 그릴 수 있다.
  final List<TaxiPartyDetail> myParties;
  final List<TaxiPartySummary> recentChats;

  /// 요청했을 때만 온다.
  final List<TaxiPartySummary>? history;
  final TaxiRestriction restriction;

  factory TaxiHome.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(Object? raw, T Function(Map<String, dynamic>) parse) =>
        (raw as List<dynamic>)
            .map((item) => parse(item as Map<String, dynamic>))
            .toList();
    final parties = json['parties'] as Map<String, dynamic>;
    return TaxiHome(
      locations: json['locations'] == null
          ? null
          : list(json['locations'], TaxiLocation.fromJson),
      parties: list(parties['items'], TaxiPartySummary.fromJson),
      myParties: list(json['my_parties'], TaxiPartyDetail.fromJson),
      recentChats: list(json['recent_chats'], TaxiPartySummary.fromJson),
      history: json['history'] == null
          ? null
          : list(json['history'], TaxiPartySummary.fromJson),
      restriction: TaxiRestriction.fromJson(
        json['restriction'] as Map<String, dynamic>,
      ),
    );
  }
}
