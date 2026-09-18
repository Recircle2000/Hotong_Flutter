import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';

class TaxiTabBar extends StatelessWidget {
  const TaxiTabBar({
    super.key,
    required this.index,
    required this.onSelected,
    required this.unread,
    this.enabled = true,
  });
  final int index;
  final ValueChanged<int> onSelected;
  final int unread;
  final bool enabled;

  static const labels = ['팟 생성', '팟 검색', '현재팟', '내정보'];
  static const icons = [
    Icons.add_circle_outline,
    Icons.search,
    Icons.local_taxi_outlined,
    Icons.person_outline,
  ];
  static const symbols = [
    'plus.circle',
    'magnifyingglass',
    'car.side',
    'person.crop.circle',
  ];

  @override
  Widget build(BuildContext context) {
    final badge = unread > 99 ? '99+' : '$unread';
    void select(int next) {
      if (enabled) onSelected(next);
    }

    Widget icon(int item) => Badge(
      isLabelVisible: item == 2 && unread > 0,
      label: Text(badge),
      child: Icon(icons[item]),
    );
    Widget bar;
    if (NativeLiquidGlassUtils.supportsLiquidGlass) {
      bar = SafeArea(
        top: false,
        // UITabBarController owns the home-indicator inset. Padding its platform
        // view again lifts the floating bar above its native bottom position.
        // Retain only the horizontal safe area for landscape devices.
        bottom: false,
        child: LiquidGlassTabBar(
          currentIndex: index,
          onTabSelected: select,
          iconSize: 24,
          selectedItemColor: const Color(0xFFF5A623),
          items: List.generate(
            4,
            (item) => LiquidGlassTabItem(
              label: labels[item],
              icon: NativeLiquidGlassIcon.sfSymbol(symbols[item]),
              iosBadgeValue: item == 2 && unread > 0 ? badge : null,
            ),
          ),
        ),
      );
    } else if (Theme.of(context).platform == TargetPlatform.iOS) {
      bar = CupertinoTabBar(
        currentIndex: index,
        onTap: select,
        activeColor: const Color(0xFFF5A623),
        backgroundColor: Theme.of(context).colorScheme.surface,
        items: List.generate(
          4,
          (item) =>
              BottomNavigationBarItem(icon: icon(item), label: labels[item]),
        ),
      );
    } else {
      bar = NavigationBar(
        selectedIndex: index,
        onDestinationSelected: select,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: const Color(0xFFF5A623).withValues(alpha: .22),
        destinations: List.generate(
          4,
          (item) =>
              NavigationDestination(icon: icon(item), label: labels[item]),
        ),
      );
    }
    return IgnorePointer(ignoring: !enabled, child: bar);
  }
}
