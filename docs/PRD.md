# PRD: pub-star-classifier

## 1) 개요

### 1.1 제품 한줄 정의
GitHub 사용자의 Star(즐겨찾기) 레포지토리를 **언어/목적 기반 카테고리**로 자동 분류하고, 결과를 **표(Markdown)** 및 **기계가공용(JSON)** 으로 출력하는 CLI 도구.

### 1.2 배경 및 문제
- Star 레포가 늘수록 “어떤 기술/목적의 프로젝트를 저장해뒀는지” 재발견이 어렵다.
- 분류 규칙이 없으면 검색/정리가 개인의 기억에 의존한다.
- 주기적으로 업데이트(배치)하면 최신 Star 반영 및 아카이빙이 쉬워진다.

### 1.3 목표(Goals)
- GitHub Stars를 카테고리로 분류해 **일관된 형태로 내보내기(export)**.
- 실행 시 **사용자 id(= GitHub username)** 를 입력/저장/수정 가능.
- 사용자 id 및 토큰 등 민감값을 **`.env`로 관리** 가능.
  - 소스 배포(public) 시에는 **`.env.sample` 제공**.
- 배치 실행을 위해 **crontab 등록을 지원**하고,
  - 실행 시 **등록 여부**를 선택할 수 있으며
  - 등록 시 **일정(스케줄)** 을 선택할 수 있어야 함.
- public 사용을 위한 설치 경험 제공:
  - `curl -fsSL .../install.sh | bash`
  - `curl -fsSL .../uninstall.sh | bash`

### 1.4 비목표(Non-goals)
- LLM 기반 “의미 분류” (초기 버전은 키워드/휴리스틱 기반)
- GitHub OAuth 로그인 플로우 제공
- 웹 UI/대시보드 제공

## 2) 사용자 및 주요 사용 시나리오

### 2.1 대상 사용자
- GitHub Star를 많이 사용하는 개발자/리서처
- 주기적으로 Star 목록을 아카이빙하고 싶은 사용자(배치/cron)

### 2.2 시나리오
- **S1. 최초 실행(로컬 실행)**: 사용자 id 입력 → 결과 출력 → 로컬 파일로 저장.
- **S2. 재실행**: 저장된 사용자 id로 자동 실행(옵션으로 변경 가능).
- **S3. 환경변수 기반 실행**: `.env` 또는 환경변수로 사용자 id/토큰 주입.
- **S4. 배치 등록**: 실행 중 “crontab 등록할지?” 선택 → 스케줄 선택 → 등록 완료.
- **S5. 설치/삭제**: `curl | bash`로 설치 → CLI 사용 → 필요시 `uninstall.sh`로 제거.

## 3) 기능 요구사항(Functional Requirements)

### 3.1 입력/설정 관리
- **FR-1 사용자 id 입력**
  - 실행 시 사용자 id를 입력할 수 있어야 한다.
  - CLI 옵션 우선순위(높음→낮음):
    1) `--user-id`
    2) `.env`의 `PSC_USER_ID`
    3) 저장된 설정 파일(예: `~/.pub-star-classifier/config.json` 혹은 `~/.pub-star-classifier/.env`)
    4) 인터랙티브 프롬프트(tty에서만)
- **FR-2 사용자 id 저장/수정**
  - `--set-user-id <id>` 또는 인터랙티브 플로우로 저장 가능해야 한다.
- **FR-3 GitHub Token(선택)**
  - `PSC_GITHUB_TOKEN`(또는 `GITHUB_TOKEN`) 지원.
  - 토큰이 없을 경우에도 동작하되, GitHub API rate limit에 유의하도록 안내한다.
- **FR-4 .env 관리**
  - `.env`를 읽어 설정을 로드할 수 있어야 한다(현재 작업 디렉토리 우선).
  - public 배포에는 `.env.sample`를 제공한다.

### 3.2 분류/출력
- **FR-5 카테고리 분류**
  - 최소 10개 내외의 카테고리를 제공한다(예: 시스템 인프라, 웹 프레임워크, 데이터베이스, 머신러닝/AI, DevOps/클라우드, 프론트엔드 UI, 네트워킹/보안, 빅데이터 처리, 모바일 개발, 유틸리티/도구).
  - 초기 버전은 키워드 매칭 + 언어 기반 보정으로 분류한다.
- **FR-6 출력 포맷**
  - 기본 출력: 카테고리별 Top N(기본 3개) 레포를 Markdown 표로 출력.
  - 옵션 출력: 전체 레포 리스트를 JSON으로 저장/출력할 수 있어야 한다.
  - 출력 경로(옵션): `--out <dir>`로 결과 파일 저장 위치 지정.

### 3.3 배치(crontab) 지원
- **FR-7 crontab 등록**
  - 실행 시 “crontab 등록 여부”를 선택할 수 있어야 한다(옵션 및 인터랙티브).
  - 스케줄을 선택할 수 있어야 한다:
    - 예: 매일 09:00, 매주 월요일 09:00, 매시간, 커스텀 cron 표현식 등
  - 중복 등록 방지(이미 등록되어 있으면 갱신/유지 선택 또는 안전하게 교체).
- **FR-8 배치 실행 모드**
  - `--non-interactive` 모드에서 프롬프트 없이 실행 가능해야 한다.
  - cron 실행 시에도 실패하지 않도록 **절대경로 기반 실행**을 지원해야 한다.

### 3.4 설치/삭제 스크립트
- **FR-9 설치**
  - `install.sh`는 다음을 수행한다:
    - 사용자 홈에 설치(예: `~/.local/bin/pub-star-classifier`)
    - 설정 디렉토리 생성(예: `~/.pub-star-classifier/`)
    - `.env.sample`를 참조해 사용자가 `.env`를 만들도록 안내
    - 필요 시(선택) 설치 직후 간단한 smoke 실행 안내
  - 설치는 “curl 파이프 실행”을 지원해야 한다.
- **FR-10 삭제**
  - `uninstall.sh`는 다음을 수행한다:
    - 설치된 실행 파일 제거
    - (옵션) 설정 디렉토리/크론탭 항목 제거 여부를 선택
  - 삭제 역시 “curl 파이프 실행”을 지원해야 한다.

## 4) 비기능 요구사항(Non-functional Requirements)
- **NFR-1 안전성**
  - `.env`는 git에 커밋되지 않아야 한다.
  - 토큰/민감정보를 콘솔에 그대로 출력하지 않는다.
- **NFR-2 휴대성**
  - macOS/Linux에서 동작.
  - 가능한 표준 도구(예: `python3`, `curl`, `crontab`)만 사용.
- **NFR-3 가독성**
  - 설치/실행/배치 등록 흐름을 문서로 안내한다.

## 5) 인터페이스(초기 CLI 제안)

### 5.1 기본 실행
- `pub-star-classifier`
  - 설정된 사용자 id로 실행(없으면 입력 유도)

### 5.2 옵션(초기)
- `--user-id <id>`: 이번 실행에만 사용자 id 지정
- `--set-user-id <id>`: 사용자 id 저장
- `--out <dir>`: 결과 저장 디렉토리
- `--format md|json|both`: 출력 형식
- `--top <n>`: 카테고리별 Top N
- `--install-cron`: crontab 등록 플로우 실행(옵션으로 schedule 선택)
- `--cron <expr>`: cron 표현식 직접 지정
- `--non-interactive`: 프롬프트 없이 실패/기본값 처리

## 6) 환경변수/파일 규격

### 6.1 `.env` 키
- `PSC_USER_ID`: GitHub username
- `PSC_GITHUB_TOKEN`: GitHub token (선택)
- `PSC_OUT_DIR`: 기본 출력 디렉토리(선택)

### 6.2 설정 저장 위치(초기)
- `~/.pub-star-classifier/config.json` (또는 `~/.pub-star-classifier/.env`)
- 출력 기본 위치(예): `~/.pub-star-classifier/output/`

## 7) 설치/삭제(문서에 포함할 커맨드)

아래 URL은 “public 배포 시” raw 파일 URL로 교체한다.

- 설치:

```bash
curl -fsSL https://example.com/pub-star-classifier/install.sh | bash
```

- 삭제:

```bash
curl -fsSL https://example.com/pub-star-classifier/uninstall.sh | bash
```

## 8) 성공 지표(초기)
- 최초 실행에서 2분 내로 “사용자 id 설정 → 결과 출력” 완료
- cron 등록 후 다음 스케줄에 자동 실행 및 결과 파일 생성 확인

