import 'package:flutter/material.dart';

class UiConstants {
  UiConstants._();

  static const double minTouchTarget = 48;
  static const double pagePadding = 20;
  static const double sectionGap = 16;
  static const double cardRadius = 22;
  static const Duration softAnimation = Duration(milliseconds: 260);

  /// 상단 안전영역 + 바깥 탭으로 닫기 영역 (Situational 허브·퀵 모달 공통).
  static const double quickModalSheetTopReserveGap = 56;

  /// [quickModalSheetTopReserveGap] 아래부터 화면 하단까지 — Situational 허브와 동일.
  static double quickModalSheetBodyHeight(
    BuildContext context, {
    double? screenHeight,
  }) {
    final mq = MediaQuery.of(context);
    final h = screenHeight ?? mq.size.height;
    return h - mq.viewPadding.top - quickModalSheetTopReserveGap;
  }

  /// 바텀시트 상단 코너 (두 모달 공통).
  static const double quickModalSheetTopCornerRadius = 28;

  /// 모달 바텀시트 슬라이드 진입·퇴장. Material 기본 = 터뷸런스 시트 기준값.
  static AnimationStyle get quickModalSheetAnimationStyle => AnimationStyle(
    duration: const Duration(milliseconds: 250),
    reverseDuration: const Duration(milliseconds: 200),
  );

  static const Color warmWhite = Color(0xFFF3F7FD);
  static const Color warmSurface = Color(0xFFF8FBFF);
  static const Color navyInk = Color(0xFF1A2A40);
  static const Color navyMuted = Color(0xFF5B6678);
  static const Color goOrange = Color(0xFF5C88FF);

  static const Color glassWhite = Color(0xCCFFFFFF);
  static const Color glassBorder = Color(0x80FFFFFF);

  /// Situational 전용 팔레트.
  ///
  /// 카드 / 인라인 토큰 / 활성 sub-tab 등 baseline 강조에는 차분한 deep navy 를
  /// 베이스로 잡고, 작고 의미 있는 포인트(eyebrow dot, "필요시" 배지, 즐겨찾기
  /// 카운터 등) 에만 따뜻한 [situationalOrange] 를 점적으로 사용한다.
  static const Color situationalNavy = Color(0xFF243D6B);
  static const Color situationalOrange = Color(0xFFFF7A3D);
}
