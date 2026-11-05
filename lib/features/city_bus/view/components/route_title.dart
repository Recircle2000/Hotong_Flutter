import 'package:flutter/material.dart';
import 'package:hsro/features/city_bus/view/components/station_item.dart'
    show cityBusAccent;

/// 시내버스 화면 앱바 제목: 노선 번호 배지 + 기점 → 종점
///
/// [displayName]은 "순환5 (천안아산역 → 호서대학교)" 형식이다. 형식이 다르면 그대로 표시한다.
class CityBusRouteTitle extends StatelessWidget {
  const CityBusRouteTitle({super.key, required this.displayName});

  final String displayName;

  static const _titleStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);

  @override
  Widget build(BuildContext context) {
    final match = RegExp(r'^(.+?)\s*\((.+)\)$').firstMatch(displayName);
    if (match == null) {
      return Text(
        displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _titleStyle,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: cityBusAccent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            match.group(1)!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            match.group(2)!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _titleStyle,
          ),
        ),
      ],
    );
  }
}
