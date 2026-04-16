import 'package:flutter/material.dart';
import 'dart:async';

// 자동 스크롤 텍스트 위젯
class AutoScrollText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double height;
  final Duration pauseDuration;
  final Duration scrollDuration;

  AutoScrollText({
    required this.text,
    required this.style,
    this.height = 20,
    this.pauseDuration = const Duration(seconds: 1),
    this.scrollDuration = const Duration(seconds: 2),
  });

  @override
  _AutoScrollTextState createState() => _AutoScrollTextState();
}

class _AutoScrollTextState extends State<AutoScrollText> {
  late ScrollController _scrollController;
  Timer? _timer;
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScrolling();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startScrolling() {
    // 스크롤할 필요가 없는 경우는 타이머 설정 안함
    if (!_hasOverflow()) {
      return;
    }

    // 일정 시간 후에 스크롤 시작
    _timer = Timer(widget.pauseDuration, () {
      if (_scrollController.hasClients && mounted) {
        setState(() {
          _isScrolling = true;
        });

        // 오른쪽 끝까지 스크롤
        _scrollController
            .animateTo(
          _scrollController.position.maxScrollExtent,
          duration: widget.scrollDuration,
          curve: Curves.linear,
        )
            .then((_) {
          // 스크롤이 끝나면 다시 처음으로 돌아가기 전에 잠시 멈춤
          if (mounted) {
            setState(() {
              _isScrolling = false;
            });

            _timer = Timer(widget.pauseDuration, () {
              if (_scrollController.hasClients && mounted) {
                // 처음으로 돌아가기
                _scrollController
                    .animateTo(
                  0,
                  duration: Duration(microseconds: 1), // 0.5초
                  curve: Curves.easeInOut,
                )
                    .then((_) {
                  if (mounted) {
                    // 다시 시작
                    _startScrolling();
                  }
                });
              }
            });
          }
        });
      }
    });
  }

  bool _hasOverflow() {
    if (!_scrollController.hasClients) {
      return false;
    }
    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    return maxScrollExtent > 0;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Align(
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          controller: _scrollController,
          physics: NeverScrollableScrollPhysics(), // 사용자 스크롤 비활성화
          child: Text(
            widget.text,
            style: widget.style,
          ),
        ),
      ),
    );
  }
}
