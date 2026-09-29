# herdr-ids

[English](README.md) | 한국어

[Herdr](https://herdr.dev) 사이드바에 페인·워크스페이스 ID(`w9:p1`, `w9`)를 보여 주고, 원하는 스페이스·탭·페인을 골라 그 ID를 에이전트 입력창에 넣어 주는 플러그인이에요. 예를 들어 "herdr:dev-server(w1:p2)의 테스트 결과 확인해 줘"처럼 대상을 바로 지정할 수 있어요.

```
herdr> dev                                   │ $ npm run dev
> w1:p2   api / 1 · shell / dev-server       │ server listening on :3000
  w2:t1   web / dev                          │ $
```

Herdr에는 ID를 사이드바에 표시하는 기본 토큰이 없어요. 이 플러그인은 모든 페인에 `$pane_id`, 모든 워크스페이스에 `$workspace_id`를 사용자 토큰으로 기록하고, 페인이 바뀔 때마다 최신 상태로 맞춰요.

## 필요한 것

- Herdr 0.9.1 이상 (Linux, macOS)
- `bash`, `jq`
- [`fzf`](https://github.com/junegunn/fzf) (대상 선택 팝업에 필요)

## 설정

아래 예시는 Herdr 기본 설정을 기준으로 해요. Herdr 설정 파일은 `~/.config/herdr/config.toml`이에요.

### 1. 설치

ID를 표시할 페인이 있는 머신이나 계정마다 설치하세요.

```sh
herdr plugin install devicki/herdr-ids
```

ID는 Herdr 서버가 시작될 때 기록돼요. 서버가 이미 떠 있다면 지금 한 번 직접 기록하세요.

```sh
herdr plugin action invoke devicki.ids.sync
```

### 2. 사이드바에 ID 표시

토큰은 사이드바 줄 설정에서 사용해야 화면에 보여요. 아래는 Herdr 기본 줄 설정에 토큰 두 개를 추가한 예시예요.

```toml
[ui.sidebar.agents]
rows = [
  ["state_icon", "machine", "workspace", "tab"],
  ["agent", { token = "$pane_id", dim = true }],
]

[ui.sidebar.spaces]
rows = [
  ["state_icon", "workspace", { token = "$workspace_id", dim = true }],
  ["branch", "git_status"],
]
```

이미 `rows`를 바꿔 쓰고 있다면, 원하는 줄에 `"$pane_id"`나 `{ token = "$pane_id", dim = true }`만 추가하면 돼요.

노트북에서 원격 머신에 접속해 쓰는 경우, 사이드바는 노트북 쪽 Herdr가 그려요. 그래서 이 설정은 노트북 설정 파일에 넣어야 해요. 플러그인은 원격 머신마다 설치해야 해요(1단계).

### 3. 대상 선택 팝업 단축키 지정

`prefix+i`는 Herdr 기본 단축키에서 비어 있어요. prefix는 따로 바꾸지 않았다면 `ctrl+b`예요.

```toml
[[keys.command]]
key = "prefix+i"
type = "plugin_action"
command = "devicki.ids.pick"
description = "herdr 대상 골라 입력"
```

원격 머신에서 작업한다면 그 머신의 설정 파일에 넣으세요.

### 4. 설정 다시 불러오기

```sh
herdr server reload-config
```

사이드바에 반영되지 않으면 Herdr를 재시작하세요.

## 대상 선택하기

입력 중인 페인(예: 에이전트 입력창)에서 단축키를 누르세요.

- 글자를 입력하면 ID와 `스페이스 / 탭 / 페인` 경로 전체에서 퍼지 검색해요. 커서는 지금 있는 페인에서 시작해요.
- 오른쪽에는 커서가 올라간 페인의 현재 화면이 미리보기로 보여요.
- Enter를 누르면 `herdr:dev-server(w1:p2) `가 입력창에 들어가요. 전송은 하지 않으니 이어서 요청을 마저 쓰면 돼요. Esc를 누르면 취소돼요.

자동으로 이름이 붙은 탭처럼 페인 이름이 이미 탭 제목에 들어 있으면, 같은 내용이 반복되지 않게 페인 이름 대신 에이전트 이름을 보여 줘요. 목록에는 팝업을 연 Herdr 서버의 항목만 나와요. 여러 머신을 쓰는 경우 지금 머신의 페인만 보여요.

## 세부 설정

팝업은 `$(herdr plugin config-dir devicki.ids)/pick.conf`에서 바꿀 수 있어요. 한 줄에 `키 = 값` 하나씩 쓰고, 모든 항목은 선택이에요.

```
# Enter를 눌렀을 때 입력되는 문자열. {name}과 {id}가 채워져요
template = herdr:{name}({id})
# 팝업 크기. 칸 수나 퍼센트로 지정해요
width = 90%
height = 70%
# fzf 옵션. 레이아웃, 프롬프트, 미리보기 창, 색 등 기본 모양보다 우선 적용돼요
fzf_opts = --border=rounded --color=hl:#7aa2f7 --preview-window=down,40%
```

기본 팝업 크기는 가로 90%, 세로 70%이고, 미리보기는 오른쪽 55%를 차지해요. 오른쪽 공간이 50칸보다 좁아지면 미리보기가 목록 아래로 내려가요. 미리보기를 끄려면 `fzf_opts`에 `--preview-window=hidden`을 넣으세요.

## 업데이트와 삭제

```sh
herdr plugin install devicki/herdr-ids --yes   # 다시 설치하면 최신 버전으로 바뀌어요
herdr plugin uninstall devicki.ids
```

## 동작 방식

토큰은 실행 중에만 유지되는 값이라, Herdr 서버가 시작될 때 모든 페인과 워크스페이스에 기록해요. 페인을 다른 워크스페이스로 옮기면 ID가 바뀌기 때문에, `pane.created`, `pane.moved`, `workspace.created` 이벤트 때마다 다시 맞춰요. 값이 맞지 않아 보이면 `ids: resync tokens`(`devicki.ids.sync`)를 실행하세요.

## 문제 해결

- **사이드바에 ID가 안 보여요**: 2단계 설정을 사이드바를 그리는 쪽 Herdr 설정에 넣었는지 확인하세요. 그다음 ID가 빠진 페인이 있는 머신에서 `herdr plugin action invoke devicki.ids.sync`를 실행하세요.
- **한국어·일본어·중국어 로케일에서 줄이 깨져 보여요**: 이 로케일에서 fzf는 `·`, `›`, `│` 같은 폭이 모호한 글자를 2칸으로 계산하는데, Herdr는 1칸으로 그려요. 그래서 팝업은 fzf에 `RUNEWIDTH_EASTASIAN=0`을 설정해 둘을 맞춰요. 실제로 이 글자들을 2칸으로 그리는 환경이라면 Herdr 서버 환경 변수에 `RUNEWIDTH_EASTASIAN=1`을 설정하세요.

## 개발

```sh
herdr plugin link .
./test.sh   # 임시 세션에서 서버 시작, 새 페인, 워크스페이스 간 이동, 재시작을 확인해요
```

## 라이선스

MIT
