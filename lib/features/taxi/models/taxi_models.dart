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
        party: json['party'] is Map<String, dynamic>
            ? TaxiPartySummary.fromJson(json['party'] as Map<String, dynamic>)
            : null,
        code: json['code'] as String?,
        errorMessage: json['message'] is String
            ? json['message'] as String
            : null,
      );
}
