# iPhone 설치 방법 (Flutter / annc_go)

iOS에서는 Google Play처럼 “서명 없이 APK만 설치”가 **불가능**합니다. 아래 중 하나가 필요합니다.

## 1) Mac에서 USB로 바로 깔기 (가장 간단히 시험할 때)

1. Apple ID로 **개발자 약관**만 동의해 두어도(무료) 자기 폰까지는 제한적으로 설치 가능하지만, **팀 계정 연동·기기 신뢰·7일 재서명** 이슈가 있어 업무용이면 **Apple Developer Program**(유료) 권장.
2. Mac에 Xcode 설치 후 저장소에서:
   ```bash
   flutter pub get
   cd ios && pod install && cd ..
   open ios/Runner.xcworkspace
   ```
3. Xcode에서 **Runner** 타깃 선택 → **Signing & Capabilities** 에서 본인 **Team** 지정 → 본인 iPhone 선택 후 **Run (▶)**.

## 2) GitHub Actions로 IPA 받아서 설치 (Ad hoc 등)

워크플로 **`Build iOS IPA`** 는 저장소 Secrets가 채워졌을 때만 성공합니다.  
IPA는 특정 기기 UDID가 등록된 **Ad hoc** / **Enterprise** 같은 프로파일과 맞아야 설치됩니다.

### 필요한 Repository secrets

| 이름 | 설명 |
|------|------|
| `IOS_CERTIFICATE_BASE64` | 배포용 **.p12** 를 Base64 로 인코딩한 문자열 (`base64 certificate.p12` 등) |
| `IOS_CERTIFICATE_PASSWORD` | 위 p12 파일 비밀번호 |
| `IOS_PROVISION_PROFILE_BASE64` | **.mobileprovision** 파일을 Base64 인코딩한 문자열 |
| `IOS_KEYCHAIN_PASSWORD` | CI용 임시 키체인 비번 (임의 문자열, 외부에 노출 안 됨) |

### 애플 개발자 쪽에서 준비할 것

- **발급·받기** 용 인증서(보통 Distribution)와 **Ad hoc(또는 배포 목적)** 프로비저닝 프로파일  
- 앱 번들 ID: **`com.example.anncGo`** (Xcode 프로젝트와 동일해야 함)  
- Ad hoc 라면 IPA를 깔려는 **기기 UDID 등록**

Actions에서 **Artifacts** 에 올라온 `.ipa` 는 **Apple Configurator · Xcode Organizer · 회사 MDM** 등으로 기기에 올립니다.

## 3) TestFlight (스토어 없이 초대 테스트)

유료 프로그램 + App Store Connect 설정 후 `flutter build ipa` → Transporter 업로드 → 테스트 그룅 초대.  
빌드 파이프라인은 회사 정책에 맞게 별도 구성하면 됩니다.

---

**요약**: 코드만으로 “항상 아이폰에 설치”를 보장할 수는 없고, **애플 계정 + 서명 + (Ad hoc 시) UDID/TestFlight 등 정책**이 맞아야 합니다.
