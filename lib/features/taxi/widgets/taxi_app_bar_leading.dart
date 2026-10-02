import 'package:flutter/material.dart';

/// 택시팟 화면 앱바 왼쪽의 뒤로가기 + 홈 버튼 묶음.
///
/// 홈 버튼은 택시팟 화면을 모두 닫고 앱 홈 메뉴로 바로 돌아간다.
/// [AppBar.leadingWidth]에 [width]를 같이 넘겨야 두 버튼이 잘리지 않는다.
class TaxiAppBarLeading extends StatelessWidget {
  const TaxiAppBarLeading({super.key, this.back, this.enabled = true});

  static const double width = 96;

  /// null이면 플랫폼 기본 [BackButton]을 쓴다.
  final Widget? back;

  /// 저장 중처럼 화면을 떠나면 안 될 때 false로 둔다.
  final bool enabled;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      back ?? const BackButton(),
      IconButton(
        tooltip: '홈으로',
        onPressed: enabled
            ? () => Navigator.of(context).popUntil((route) => route.isFirst)
            : null,
        icon: const Icon(Icons.home_outlined),
      ),
    ],
  );
}
