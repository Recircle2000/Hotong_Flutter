import 'package:flutter/material.dart';
import 'package:hsro/features/taxi/models/taxi_models.dart';
import 'package:hsro/features/taxi/widgets/taxi_theme.dart';
import 'package:hsro/shared/widgets/ios_platform_fields.dart';

/// 팟 생성 화면의 거점 선택 필드. iOS는 네이티브 메뉴, Android는 드롭다운을 쓴다.
class TaxiLocationField extends StatelessWidget {
  const TaxiLocationField({
    super.key,
    required this.label,
    required this.value,
    required this.locations,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final List<TaxiLocation> locations;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return _buildIOS(context);
    }
    return DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      icon: const Icon(Icons.expand_more_rounded),
      borderRadius: BorderRadius.circular(16),
      dropdownColor: Theme.of(context).cardColor,
      // 선택 전에는 라벨을 자리 표시 문구처럼 보여주고, 선택하면 숨긴다.
      decoration: taxiInputDecoration(
        context,
        label: label,
      ).copyWith(floatingLabelBehavior: FloatingLabelBehavior.never),
      items: locations
          .map(
            (location) => DropdownMenuItem<int>(
              value: location.id,
              child: Text(
                location.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  /// iOS는 필드 모양은 유지하고 네이티브 메뉴로 거점을 고른다.
  Widget _buildIOS(BuildContext context) {
    final selected = locations.where((l) => l.id == value).firstOrNull;
    return Stack(
      children: [
        InputDecorator(
          decoration: taxiInputDecoration(context, label: label).copyWith(
            suffixIcon: const Icon(Icons.expand_more_rounded),
            floatingLabelBehavior: FloatingLabelBehavior.never,
          ),
          isEmpty: selected == null,
          child: Text(
            selected?.name ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Positioned.fill(
          child: IOSPopupMenuOverlay(
            options: [
              for (final location in locations)
                IOSPopupMenuOption(id: location.id, title: location.name),
            ],
            selectedId: value,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
