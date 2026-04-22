# pub-star-classifier

GitHub Stars(즐겨찾기) 레포지토리를 카테고리로 분류해 Markdown/JSON으로 내보내는 CLI입니다.

## 설치(공개 배포 시)

아래 URL은 실제 public 배포 시 raw URL로 교체하세요.

```bash
curl -fsSL https://raw.githubusercontent.com/WisemanLim/pub-star-classifier/refs/heads/main/install.sh | bash
```

삭제:

```bash
curl -fsSL https://raw.githubusercontent.com/WisemanLim/pub-star-classifier/refs/heads/main/uninstall.sh | bash
```

## 로컬 실행(install.sh 없이 `git clone`으로)

### 준비물
- `python3` (macOS 기본 탑재)

### 실행 방법

```bash
git clone <THIS_REPO_URL>
cd pub-star-classifier

# 1) 환경설정(.env) 준비
cp .env.sample .env
# .env를 열어 PSC_USER_ID 등을 채웁니다.

# 2) 실행(파이썬으로 직접)
python3 bin/pub-star-classifier --format md --top 3
```

### (선택) `pub-star-classifier`로 실행하고 싶다면

```bash
chmod +x bin/pub-star-classifier
./bin/pub-star-classifier --format md --top 3
```

또는 PATH에 심볼릭 링크를 걸 수 있습니다(예: `~/.local/bin`):

```bash
mkdir -p ~/.local/bin
ln -sf "$(pwd)/bin/pub-star-classifier" ~/.local/bin/pub-star-classifier
pub-star-classifier --help
```

## 빠른 시작

```bash
pub-star-classifier --set-user-id <github-username>
pub-star-classifier --format md --top 3
```

## `.env.sample` 값 채우는 방법(초급 가이드)

이 프로젝트는 `.env.sample`에 있는 키들을 `.env`에 채워 넣어서 실행할 수 있습니다.

### `PSC_USER_ID` (필수)
- **무엇인가요**: GitHub 사용자명(username)입니다.
- **어떻게 얻나요**
  - GitHub 프로필 URL에서 확인합니다.
    - 예: `https://github.com/WisemanLim` → `WisemanLim`
  - 또는 GitHub 화면 오른쪽 위 프로필 메뉴에서 “Your profile”로 들어가 주소창의 경로를 확인합니다.

### `PSC_GITHUB_TOKEN` (선택, 권장)
- **무엇인가요**: GitHub API 호출 제한(rate limit)을 완화하기 위한 Personal Access Token(PAT)입니다.
- **언제 필요하나요**
  - Star가 많거나(요청이 많음), 연속 실행/배치(cron)로 자주 돌리면 토큰이 있으면 훨씬 안정적입니다.
- **어떻게 만들까요(가장 쉬운 경로)**
  - GitHub → **Settings** → **Developer settings** → **Personal access tokens**
  - 가능하면 **Fine-grained token**을 권장합니다.
    - Resource owner: 본인 계정
    - Repository access: **Public Repositories(읽기)** 수준으로 시작
    - Permissions: 최소 권한(읽기)만 부여
  - 발급 후 표시되는 토큰 문자열을 `PSC_GITHUB_TOKEN`에 붙여넣습니다.
- **주의**
  - 토큰은 **비밀번호처럼 취급**하세요(공유/커밋 금지).

### `PSC_OUT_DIR` (선택)
- **무엇인가요**: 결과(Markdown/JSON) 파일을 저장할 디렉토리입니다.
- **예시**
  - `PSC_OUT_DIR=./output`
  - `PSC_OUT_DIR=/Users/<you>/Documents/pub-star-classifier-output`

### `GEMINI_API_KEY` (선택)
- **무엇인가요**: 프로젝트 설명이 5,000자 이상일 때 내용을 자동으로 짧게 요약(1~2줄)해 주는 Google Gemini API 키입니다. (지정하지 않으면 내용이 잘리고 `...`이 붙습니다.)
- **어떻게 얻나요**
  - [Google AI Studio](https://aistudio.google.com/)에서 무료로 발급받을 수 있습니다.

### `.env` 만들기 예시

```bash
cp .env.sample .env
```

그 다음 `.env`를 열어 아래처럼 채웁니다.

```bash
PSC_USER_ID=WisemanLim
PSC_GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
PSC_OUT_DIR=./output
GEMINI_API_KEY=AIzaSy...
```

배치 등록:

```bash
pub-star-classifier --install-cron
```
