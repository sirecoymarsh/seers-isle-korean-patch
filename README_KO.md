# Seers Isle 비공식 한국어 패치

## 추가·변경 사항

이 패치는 Seers Isle(Nova-box, Unity 2019.4.18f1 / Mono) 스팀 PC판에 **한국어 언어 항목을 새로 추가**하는 방식입니다. 원본 파일은 하나도 덮어쓰거나 고치지 않고, 새 파일 다섯 개만 더합니다. 아래 내용은 저장소의 커밋(`85213ac`, `d70be68`), 릴리스 노트(`v1.0.2`), 설치 스크립트와 `provenance/` 기록을 근거로 정리했습니다.

### 번역 범위

- **번역 원문**: 영어판(`en-US`)을 의미 원문으로 삼아 번역했습니다(`provenance/language_contract.json`). 프랑스어판은 참고·대상이 아닙니다.
- **본문·선택지·장 제목·업적**: `localizable.strings` 전체를 번역했습니다. 원문 6,664개 항목 중 의도적으로 비어 있는 `theseer` 1개를 뺀 나머지가 모두 한국어입니다.
- **UI·메뉴**: `ui.strings` 85개 항목(옵션 메뉴, 저장 슬롯, 기록(로그) 화면, Twitch 연동 메시지 등)을 번역했습니다.
- **합계**: 고유 항목 6,749개 중 번역 대상 6,748개를 모두 번역했습니다(`provenance/audit.json`, `provenance/language_qa.json`).
- **일부러 원문을 남긴 곳**(`provenance/qa_waivers.json`):
  - 게임 제목 `Seers Isle`(튜토리얼·데모 종료 문구), 제작사 이름 `Nova-box`와 누리집 주소.
  - 런타임 언어 코드 `language = "ko"`(게임 내부가 이 값을 그대로 씀).
  - Twitch 채팅 명령어 `choose`와 구분 기호(`;`), 서비스 이름 `Twitch`. 시청자가 채팅으로 입력하는 명령어라서 번역하면 연동이 깨집니다.
- **그림 글자·영상**: 이미지 안의 글자나 영상은 손대지 않았습니다(패치가 문자열 파일과 글꼴만 추가하므로). 원판에 그런 요소가 있다면 영어로 남습니다(추정).
- **번역 방식과 검수**: 109개 묶음(packet)으로 나눠 초벌 번역한 뒤, 109개 묶음 전체를 다시 교차 검토해 199건을 고쳤습니다(독립 검토 189건, 기계적 표기 교정 2건, 반복 문장 집중 검토 8건)(`provenance/crossreview/`, `provenance/translation_progress.json`). 번역 엔진은 Codex 내부 모델이며 외부 기계번역은 쓰지 않았다고 기록돼 있습니다(`provenance/language_contract.json`).
- **용어·표기 규칙**(`provenance/style_guide.md`): 인물 이름 27개(로완, 알린, 코너, 던컨, 프레이야 등)와 세계관 용어(seer → 예언자, Sacred Flame → 성스러운 불꽃, the Tree → 성목, time knot → 시간의 매듭 등)를 표로 고정했습니다. 장 제목은 `제1장 — “절벽”` 형식, 업적 알림은 `업적 달성:`으로 통일했습니다. 따옴표 `“ ”`, 말줄임표 `…`, 게임 태그(`<ok>`, `<log>`, `<pause>`, `<i>`, `{0}`)는 그대로 보존했고, 보존 여부를 자동 검사했습니다(`protected_token_errors` 없음).

### 화면·글꼴

- **한글 글꼴 추가**: 원판 글꼴(Averia Libre / Averia Serif Libre)에는 한글이 없어서, Google Fonts의 **Gothic A1** Regular·Bold를 `SeersIsle-Korean-Regular.ttf`, `SeersIsle-Korean-Bold.ttf`라는 이름으로 넣었습니다. Windows 시스템 글꼴에는 의존하지 않습니다. 라이선스는 SIL OFL 1.1이며 전문은 `licenses/GothicA1-OFL.txt`에 있습니다.
- **글꼴 배치**(`payload/locales/ko-KR/config.json`): 기본·말풍선·인물 대사는 Regular, 굵은 글씨·인물 이름·선택지·제목은 Bold를 쓰며, 모든 역할의 글자 크기 배율은 0.9입니다.
- **한글 음절 누락 방지(16 MiB 글꼴 컨테이너)**: 이 게임은 글꼴 **파일 크기**를 보고 TextMeshPro 동적 아틀라스 크기를 정합니다. 원래 크기(약 2.2 MB)의 Gothic A1을 넣으면 1024×1024 아틀라스(91px, 여백 9px)가 잡혀 튜토리얼 무렵 가득 차 버리고, 그 뒤로 새 한글 음절이 화면에서 빠졌습니다. 그래서 글꼴 데이터는 한 바이트도 바꾸지 않고 파일 끝에 0을 채워 정확히 16 MiB(16,777,216바이트)로 만들었습니다. 그러면 게임이 최대 크기인 4096×4096 아틀라스(56px, 여백 5px)를 씁니다(`provenance/font_container_build.json`, `provenance/bug_dialog/font_runtime_fix.json`, `provenance/scripts/build_runtime_font_container.py`).
- **글자 수 확인**: 번역문에 쓰인 문자 1,098자가 두 글꼴에 모두 들어 있음을 확인했습니다(누락 0자, `provenance/font_coverage.json`).
- 해상도·와이드·전체화면 같은 그래픽 설정은 원판 그대로이며 이 패치가 바꾸지 않습니다.

### 편의 기능·단축키

- 원판에 없던 편의 기능이나 새 단축키는 추가하지 않았습니다. 게임 실행 파일과 DLL을 고치지 않는 순수 언어 추가 패치입니다.
- 언어는 게임의 **Options → Language**에서 **한국어**를 고르면 바뀝니다. 게임은 `locales` 폴더 아래의 언어 폴더를 스스로 찾아 선택 목록에 넣으므로(`provenance/audit.json`), 별도 실행기 없이 목록에 나타납니다.

### 버그 수정

- **한국어 선택 시 대화창이 열리지 않던 문제**(v1.0.2에서 수정): 이전 판에서는 한국어를 고르면 배경만 보이고 대화창이 뜨지 않았습니다. v1.0.2에서 로캘 폴더 `ko-KR`과 내부 언어 값 `ko`를 원래 설계대로 맞춰 해결했습니다. 정확한 원인은 저장소에 기록이 없어, 이전 판이 언어 값이나 설정 파일을 다르게 썼던 것으로 보입니다(추정).
- **진행할수록 한글 음절이 군데군데 사라지던 문제**(v1.0.1 글꼴의 문제, v1.0.2에서 수정): 위 「한글 음절 누락 방지」 참고. 사용자가 보고한 화면 3장이 `provenance/bug_dialog/user_reported_font_dropout/`에 남아 있고, 수정 후 사용자가 직접 플레이해 정상 표시를 확인했습니다(2026-07-25).
- 원판 자체의 버그를 고친 것은 없습니다.

### 설치·제거 방식

- **지원 판본**: 스팀 PC판(앱 ID 738650, 빌드 20286232)만 확인했습니다. 설치기는 `Seers-Isle.exe`, `Nova-Box.Teckel.Runtime.dll`, 영어·프랑스어 언어 파일, 원판 글꼴 4개의 크기와 SHA-256이 기록과 같은지 먼저 검사하고, 다르면 아무것도 쓰지 않고 멈춥니다(`install_manifest.json`). GOG 등 다른 판은 해시가 다르면 설치가 거부됩니다.
- **설치**(`Install-SeersIsle-Korean.ps1`): 게임이 실행 중이면 멈추고, 패키지 파일 자체의 해시(`install_manifest.sha256`)도 검사합니다. 파일은 게임 폴더 안 임시 폴더에 먼저 복사해 해시를 다시 확인한 뒤 옮깁니다. 같은 경로에 알 수 없는 파일이 이미 있으면 덮어쓰지 않고 멈추며, 이미 설치돼 있으면 다시 쓰지 않습니다. 기본 게임 경로는 `C:\Program Files (x86)\Steam\steamapps\common\Seers Isle`이고 `-GameRoot`로 바꿀 수 있습니다.
- **백업**: 게임·패치 폴더 바깥인 `%LOCALAPPDATA%\SeersIsleKoreanPatch\backups`에 설치 기록(`backup_manifest.json`, `install_journal.log`, `current.json`)을 남깁니다. 심볼릭 링크 같은 재분석 지점을 거치는 경로는 거부합니다.
- **제거**(`Restore-SeersIsle-Korean.ps1`): 기록된 백업을 기준으로 추가한 다섯 파일을 지워 원래 상태로 돌립니다. `-BackupPath`로 특정 백업을 고를 수 있습니다.
- **검증**(`Verify-SeersIsle-Korean.ps1`): `-ExpectedState Installed`는 다섯 파일의 크기·해시를, `-ExpectedState Restored`는 다섯 파일이 모두 없는지를 확인합니다.
- **배포 파일 검증**: 릴리스 압축 파일 `Seers-Isle-Korean-Patch-v1.0.2.zip`의 SHA-256은 `28aff2463796086d4d83e3661d7822d064d3c3470ab575eaf46c095c8a04f3d3`입니다(`RELEASE_SHA256SUMS.txt`).

### 판(버전)별 변경 기록

- **v1.0.0 / v1.0.1** (날짜 미상, 이 저장소에는 없음): README가 「v1.0.1 글꼴」을 언급하므로 이전 판이 있었던 것은 확실하지만, 공개 릴리스와 커밋은 남아 있지 않습니다. 이 판에서는 원래 크기의 Gothic A1을 써서 한글 음절 누락이 있었고, 대화창이 열리지 않는 문제도 이 무렵 판의 문제였습니다(추정).
- **v1.0.2** (2026-07-26, 커밋 `85213ac`, 릴리스 `v1.0.2`): 저장소 첫 공개. 대화창 문제와 한글 음절 누락 수정, 16 MiB 글꼴 컨테이너, 설치·검증·복원 스크립트와 SHA-256 매니페스트, 번역 검수 기록(`provenance/`) 포함.
- **2026-08-03** (커밋 `d70be68`): 제3자 자산 권리 고지(`ASSET_NOTICE.md`) 추가. 패치 내용 변화는 없습니다.

### 알려진 문제

- 사용자 실플레이 검증은 한글 표시가 잘 된다는 수준까지이며, 장면별 문제가 있으면 일반 플레이 중에 모으기로 했습니다(`provenance/bug_dialog/font_runtime_fix.json`의 `scope_limit`). 모든 분기·엔딩을 끝까지 확인했다는 기록은 없습니다.
- 스팀 빌드 20286232 외의 판(게임 업데이트 후, GOG 등)은 해시 검사에서 막힙니다. 게임이 업데이트되면 패치도 다시 맞춰야 합니다.
- 긴 한국어 문장이 버튼·패널 밖으로 넘치는지 전수 확인했다는 기록은 없습니다(추정).

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
