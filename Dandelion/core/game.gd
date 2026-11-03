extends Node
## 체험(스테이지) 목록과 화면 전환을 맡는다.
## 새 체험을 추가할 때는 STAGES에 항목 하나를 넣고 available을 true로 바꾸면
## 모드 선택 화면에 카드가 자동으로 생긴다.

const MAIN_MENU := "res://menu/main_menu.tscn"
const GITHUB_URL := "https://github.com/norussi/-_project_dandelion"
const VERSION := "0.2.0"

const STAGES := [
	{
		"id": "visual_walk",
		"title": "시각장애 보행",
		"subtitle": "흰 지팡이로 병원 503호까지",
		"description": "밤 11시 47분, 병원에서 걸려 온 전화. 흰 지팡이와 소리에 의지해 공사 중인 골목과 큰길 횡단보도를 지나, 엘리베이터를 타고 503호까지 걸어갑니다.",
		"tags": ["1인칭 3D", "헤드폰 권장"],
		"scene": "res://stages/visual_walk/visual_walk.tscn",
		"preview": "cane",
		"available": true,
	},
	{
		"id": "coming_soon",
		"title": "새로운 체험",
		"subtitle": "준비 중",
		"description": "추후 업데이트에 추가할 예정입니다.",
		"tags": ["다음 예정: 재난 상황(화재)"],
		"scene": "",
		"preview": "soon",
		"available": false,
	},
]

## 모드 선택 화면에서 돌아올 때 그 화면을 바로 열어 줄지
var return_to_mode_select := false


func start_stage(id: String) -> void:
	for stage in STAGES:
		if stage["id"] == id and stage["available"]:
			_leave_scene()
			get_tree().change_scene_to_file(stage["scene"])
			return
	push_warning("알 수 없거나 아직 준비되지 않은 체험: %s" % id)


func goto_main_menu(open_mode_select := false) -> void:
	return_to_mode_select = open_mode_select
	_leave_scene()
	get_tree().change_scene_to_file(MAIN_MENU)


func open_github() -> void:
	OS.shell_open(GITHUB_URL)


func _leave_scene() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Settings.stop_speaking()
