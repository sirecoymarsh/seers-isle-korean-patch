# Seers Isle 비공식 한국어 패치

## v1.0.2 수정

- 한국어 선택 시 배경만 보이고 대화창이 열리지 않던 문제를 수정했습니다.
- v1.0.1 글꼴에서 진행할수록 한글 음절이 군데군데 사라지던 문제를 추가로 수정했습니다.
- 게임이 글꼴 파일 크기로 TextMeshPro 동적 아틀라스 크기를 정하는 구조라서, 원본 Gothic A1은 1024×1024 아틀라스가 가득 찬 뒤 새로운 한글 음절을 표시하지 못했습니다.
- 글꼴 표와 글리프는 바꾸지 않고 컨테이너를 정확히 16 MiB로 구성하여 게임이 4096×4096 아틀라스를 사용하게 했습니다.
- 한국어 로캘과 내부 언어 토큰은 원래 설계대로 각각 `ko-KR`과 `ko`를 유지합니다.
- Gothic A1 Regular/Bold의 한글 표시를 사용자 실플레이로 검증했습니다.

## 범위

- 영어 원문을 기준으로 한 `ko-KR` 언어 항목을 새로 추가합니다.
- 영어(`en-US`)와 프랑스어(`fr-FR`) 파일은 수정하지 않습니다.
- 게임 DLL과 실행 파일은 수정하지 않습니다.
- 번역 문자열 6,748개와 원문의 의도적인 빈 항목 1개를 다룹니다.

## 설치

1. 게임을 완전히 종료합니다.
2. PowerShell에서 이 폴더로 이동합니다.
3. 다음 명령을 실행합니다.

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Install-SeersIsle-Korean.ps1
```

게임 위치가 기본값과 다르면 다음처럼 지정합니다.

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Install-SeersIsle-Korean.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Seers Isle"
```

설치기는 원본 게임과 패키지의 SHA-256을 모두 검사한 뒤 다섯 개의 새 파일만 추가합니다. 글꼴은 패키지에 포함된 런타임 호환 Gothic A1을 사용하므로 Windows 시스템 글꼴에 의존하지 않습니다.

Gothic A1은 SIL Open Font License 1.1로 배포됩니다. 라이선스 전문은 `licenses\GothicA1-OFL.txt`에 포함되어 있습니다.

게임의 **Options → Language**에서 **한국어**를 선택합니다.

## 검증

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Verify-SeersIsle-Korean.ps1 -ExpectedState Installed
```

## 복원

게임을 종료한 뒤 다음 명령을 실행합니다.

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Restore-SeersIsle-Korean.ps1
```

복원 후 확인:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Verify-SeersIsle-Korean.ps1 -ExpectedState Restored
```

백업은 게임 및 패치 폴더 바깥의 `%LOCALAPPDATA%\SeersIsleKoreanPatch\backups`에 보존됩니다.

## 설치 파일

추가되는 경로는 다음 다섯 개뿐입니다.

- `Seers-Isle_Data\StreamingAssets\locales\ko-KR\config.json`
- `Seers-Isle_Data\StreamingAssets\locales\ko-KR\localizable.strings`
- `Seers-Isle_Data\StreamingAssets\locales\ko-KR\ui.strings`
- `Seers-Isle_Data\StreamingAssets\fonts\SeersIsle-Korean-Regular.ttf`
- `Seers-Isle_Data\StreamingAssets\fonts\SeersIsle-Korean-Bold.ttf`
