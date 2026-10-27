# 민들레 (Dandelion)

> 보이지 않는 길에도, 돌아갈 곳은 있었다.

**민들레**는 사회적 약자가 매일 마주하는 길을 직접 걸어 보는 체험형 3D 프로그램입니다. Godot 엔진으로 만들고 있으며, 체험 모드를 하나씩 늘려 가는 오픈 소스 프로젝트입니다.

*Dandelion is an open-source Godot project of first-person walking experiences that let players feel the everyday barriers faced by socially vulnerable people. The UI and documentation are currently in Korean.*

## 체험 모드

| 모드 | 내용 | 상태 |
|---|---|---|
| 1. 시각장애인 보행 체험 | 흰 지팡이와 소리만으로 밤 골목을 지나 병원까지 걸어가기 | v0.1.0 프로토타입 |
| 2 이후 | 미정 | 계획 중 |

### 모드 1: 시각장애인 보행 체험

화면은 거의 검은색입니다. 지팡이 끝이 닿은 곳과 소리가 벽에 부딪혀 돌아오는 희미한 울림만 잠시 윤곽으로 드러납니다. 길에는 점자블록 위에 세워진 전동 킥보드, 머리 높이의 간판, 공사로 뜯겨 나간 점자블록, 안내음을 덮는 발전기 소음이 있습니다. 엔딩에서는 걸린 시간과 장애물에 걸리거나 머리를 부딪힌 횟수를 보여 줍니다.

자세한 조작, 감각 규칙, 조정 가능한 값은 [`Dandelion/README.md`](Dandelion/README.md)에 있습니다.

## 실행하기

**필요한 것:** [Godot 4.3 이상](https://godotengine.org/download) (표준 버전, .NET 불필요). 외부 에셋, 플러그인, 인터넷 연결은 필요하지 않습니다. Godot 3에서는 열리지 않습니다.

1. 저장소를 내려받습니다.
   ```bash
   git clone https://github.com/norussi/-_project_dandelion.git
   ```
   또는 GitHub의 **Code → Download ZIP**으로 받아 압축을 풉니다.
2. Godot 프로젝트 관리자에서 **가져오기(Import)** → `Dandelion/project.godot`을 선택합니다.
3. **F5**로 실행합니다.

헤드폰을 권장합니다. 한글이 네모로 보이면 Noto Sans KR 같은 한글 글꼴을 설치하세요.

### 기본 조작

| 입력 | 기능 |
|---|---|
| W / S, A / D | 걷기, 옆걸음 |
| 마우스 | 몸 돌리기 |
| Space / 좌클릭 | 지팡이로 세게 두드리기 |
| Q | 휴대폰 음성 보행 안내 (오차 있음) |
| Esc / R | 일시정지·도움말 / 재시작 |

## 저장소 구조

```
.
├── Dandelion/            # Godot 4 프로젝트
│   ├── project.godot
│   ├── main.tscn         # 진입 씬
│   ├── main.gd           # 월드 생성, 보행·지팡이·소리 로직
│   ├── echo.gdshader     # 촉각·청각 반향 윤곽선 셰이더
│   └── README.md         # 모드 1 상세 설명
├── CHANGELOG.md
├── CONTRIBUTING.md
├── CODE_OF_CONDUCT.md
└── LICENSE
```

## 이 체험이 아닌 것

- 실제 장애나 보행 훈련을 정확히 재현하지 않습니다. 수치는 체험을 위해 단순화한 값입니다.
- 흰 윤곽선은 촉각과 청각 정보를 화면으로 옮긴 허구적 시각화입니다. 시각장애인이 세상을 이렇게 '본다'는 뜻이 아닙니다.
- 화면에 시각장애인 캐릭터가 나오는 것과 시각장애인이 플레이할 수 있는 게임인 것은 다릅니다. 스크린리더 연동과 키 재설정은 아직 구현하지 않았습니다.

당사자의 경험과 다르거나 오해를 부를 수 있는 부분을 발견하면 꼭 알려 주세요.

## 기여하기

버그 제보, 당사자·전문가 피드백, 새 체험 모드 제안 모두 환영합니다. [CONTRIBUTING.md](CONTRIBUTING.md)를 먼저 읽어 주세요. 이 프로젝트에 참여하는 모든 사람은 [행동 강령](CODE_OF_CONDUCT.md)을 따릅니다.

## 라이선스

[MIT License](LICENSE)
