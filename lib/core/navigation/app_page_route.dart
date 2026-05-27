import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

/// 앱 표준 페이지 전환. Material 기본 슬라이드 대신 Material You "shared axis"
/// 트랜지션을 사용해 *연속성 있는* 화면 이동 인상을 만든다.
///
/// 기본은 [SharedAxisTransitionType.vertical] — 셋업·로그인·전체화면 같이
/// 같은 흐름 안의 *단계 이동*에 적합. 화면이 위로 fade-up 되며 다음 화면이
/// 아래에서 올라온다. fillColor 는 [Theme.of] 의 surface 컬러를 자동으로
/// 사용한다.
///
/// 사용 예:
/// ```dart
/// Navigator.of(context).pushReplacement(
///   appSharedAxisRoute<void>(
///     builder: (_) => const HomeScreen(),
///   ),
/// );
/// ```
PageRoute<T> appSharedAxisRoute<T>({
  required WidgetBuilder builder,
  SharedAxisTransitionType type = SharedAxisTransitionType.vertical,
  Duration duration = const Duration(milliseconds: 360),
  Duration reverseDuration = const Duration(milliseconds: 280),
  bool fullscreenDialog = false,
}) {
  return PageRouteBuilder<T>(
    fullscreenDialog: fullscreenDialog,
    transitionDuration: duration,
    reverseTransitionDuration: reverseDuration,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        transitionType: type,
        fillColor: Theme.of(context).colorScheme.surface,
        child: child,
      );
    },
  );
}

/// Fade-through 트랜지션. 화면 *내용은 바뀌지만 위계는 동일* 한 컨텍스트에
/// 어울린다. 예: 같은 위계의 탭/세그먼트 사이 이동, 동일 라우트의 콘텐츠 교체.
PageRoute<T> appFadeThroughRoute<T>({
  required WidgetBuilder builder,
  Duration duration = const Duration(milliseconds: 320),
  Duration reverseDuration = const Duration(milliseconds: 220),
  bool fullscreenDialog = false,
}) {
  return PageRouteBuilder<T>(
    fullscreenDialog: fullscreenDialog,
    transitionDuration: duration,
    reverseTransitionDuration: reverseDuration,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeThroughTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        fillColor: Theme.of(context).colorScheme.surface,
        child: child,
      );
    },
  );
}
