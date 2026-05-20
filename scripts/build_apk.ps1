#Requires -Version 5.0
<#
  Windows에서 Gradle이
  "Could not move temporary workspace ... to immutable location"
  으로 실패할 때: Gradle 캐시를 프로젝트 아래 전용 폴더에 둡니다.
  (프로필·OneDrive 아래 %USERPROFILE%\.gradle 와 분리)

  사용:
    .\scripts\build_apk.ps1
    .\scripts\build_apk.ps1 --split-per-abi

  권장: Windows 보안 앱에서 이 폴더를 Defender 예외에 추가
    C:\annc_go\.gradle-project-home
#>
$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$gradleHome = Join-Path $repoRoot ".gradle-project-home"
New-Item -ItemType Directory -Force -Path $gradleHome | Out-Null

$env:GRADLE_USER_HOME = $gradleHome

Push-Location $repoRoot
try {
  flutter build apk @args
  exit $LASTEXITCODE
} finally {
  Pop-Location
}
