import 'package:flutter/material.dart';

// 데이터를 불러오는 동안 자리만 잡아 두는 회색 막대
class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 6,
  });

  static Color baseColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.12)
      : const Color(0xFFE6E8EC);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: baseColor(context),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// 자식 안의 SkeletonBox 위로 밝은 빛이 왼쪽에서 오른쪽으로 지나가게 한다.
// 기기에서 '동작 줄이기'를 켰으면 빛 없이 회색 막대만 보여준다.
class SkeletonShimmer extends StatefulWidget {
  final Widget child;

  const SkeletonShimmer({super.key, required this.child});

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    final base = SkeletonBox.baseColor(context);
    final highlight = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.22)
        : const Color(0xFFF5F6F8);
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        // srcATop: 막대가 그려진 곳에만 빛을 입히고 나머지는 그대로 둔다.
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          colors: [base, highlight, base],
          stops: const [0.35, 0.5, 0.65],
          begin: const Alignment(-1, -0.3),
          end: const Alignment(1, 0.3),
          transform: _SlidingGradientTransform(_controller.value),
        ).createShader(bounds),
        child: child,
      ),
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double progress;

  const _SlidingGradientTransform(this.progress);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    // 화면 왼쪽 밖에서 시작해 오른쪽 밖으로 빠져나가게 민다.
    return Matrix4.translationValues(bounds.width * (progress * 2 - 1), 0, 0);
  }
}
