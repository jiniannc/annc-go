# ANNC GO Google Sheets 템플릿 가이드

아래 규칙으로 시트를 구성하면 앱에서 안정적으로 동기화/노출됩니다.

## 1) 탭 이름 (단일 스프레드시트 URL 모드)

- `Announcements`
- `Route_Master`
- `Airports_Master`
- `Aircraft_Master`
- `Delay_Reasons(routine)`

## 2) Announcements 필수 컬럼

- `Phase`
- `PhaseID`
- `Order`
- `Title`
- `Content_KO`
- `Content_EN`
- `Condition_Tag`
- `Option` (선택 낭독 여부)
- `Audio_JP` (선택, 일본어 음성 파일 링크)
- `Audio_CN` (선택, 중국어 음성 파일 링크)

### Condition_Tag 권장 규칙

- 일반 조건
  - `is_codeshare`
  - `is_notcodeshare`
  - `is_military`
  - `is_guam`
  - `is_delayed`
  - `has_footrest`
  - `has_isps`
  - `has_wifi`
- 특별 환영
  - `is_specialwelcome_vip`
  - `is_specialwelcome_honeymoon`
  - `is_specialwelcome_birthday`

참고:
- 앱은 대소문자/공백/하이픈 차이를 정규화하지만, 시트에서는 위 snake_case를 권장합니다.
- 특별 환영 드롭다운은 `Condition_Tag`가 `is_specialwelcome_`로 시작하는 Welcome 행에서 자동 생성됩니다.

## 3) Welcome 특별 인사 작성 예시

예시 행:

- `Phase`: `Welcome`
- `PhaseID`: `R03`
- `Order`: `10`
- `Title`: `환영 인사 (VIP)`
- `Content_KO`: `존경하는 VIP 고객님, ...`
- `Content_EN`: `Dear valued VIP guest, ...`
- `Condition_Tag`: `is_specialwelcome_vip`

Setup에서 `VIP`를 선택하면 위 조건 태그에 해당하는 방송문만 노출됩니다.

## 4) 출발/도착 토큰 표준

문안 템플릿에서 아래 토큰을 권장합니다.

- 출발지 토큰
  - `{origin_city_ko}`, `{origin_city_en}`
  - `{origin_airport_ko}`, `{origin_airport_en}`
- 도착지 토큰
  - `{dest_city_ko}`, `{dest_city_en}`
  - `{dest_airport_ko}`, `{dest_airport_en}`
- 별칭(호환)
  - `{origin_ko}`, `{origin_en}`
  - `{dest}`, `{dest_ko}`, `{dest_en}`

## 5) Option 컬럼 권장 규칙

- 기본값: `required`
- 선택 낭독: `optional`

운영 예시:
- 안전/규정 고지: `required`
- 상황형 부가 멘트, 프로모션 멘트: `optional`

앱에서는 `optional` 항목을 "옵션 멘트"로 묶어 토글형으로 노출하는 방식을 권장합니다.

## 5-1) Audio 컬럼 권장 규칙

- Dropbox 직접 다운로드 링크 권장 (`dl=1`)
- 한 `PhaseID` 내에서 언어별 오디오 파일은 1개만 운영하는 것을 권장
- 같은 `PhaseID`를 가진 여러 행에 링크가 있어도 앱은 언어별 첫 링크만 사용

## 6) Setup 연동 포인트

- 출발/도착 3-letter IATA 코드 입력
- 비행시간(시간/분 선택) 입력
- 특별 환영 선택값 -> `specialWelcomeTag`로 저장
- 방송 필터링 시 `Condition_Tag`와 `specialWelcomeTag`를 매칭

## 7) 공항/기재 마스터 키

- `Airports_Master`: `IATA_Code` (예: `ICN`, `NRT`)
- `Aircraft_Master`: `HL_No (기번)` (예: `HL7719`)

위 키를 기준으로 방송 변수 치환과 조건 필터링이 동작합니다.
