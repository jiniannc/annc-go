import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Android 태블릿 하단 작업표시줄/내비게이션 바를 숨김 — 상태 바만 유지.
  // (하단 스와이프 시 일시적으로 다시 나타날 수 있음 · 기기/OS마다 차이 있음.)
  // 완전 제거 불가능한 레이어분할·덱스ktop 모드는 기기 설정을 안내해야 함.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: <SystemUiOverlay>[SystemUiOverlay.top],
    );
  }

  runApp(const ProviderScope(child: AnncGoApp()));
}
