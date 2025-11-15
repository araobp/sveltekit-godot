extends Node3D

@export var api_servers: Array[String]
@export var video_stream_player: VideoStreamPlayer = null
@export var default_ld_content: String = "germany"
@export var for_github_page: bool = false
@export var displays: Node3D = null

const HEADERS = [
	"Content-Type: application/json"
]

const CONTENTS = [
	["BrandenburgerGate", "Brandenburger Tor"],
	["CologneCathedral", "Kölner Dom"],
	["FrankfurtRoemer", "Frankfurter Römer"],
	["HeidelbergCastle", "Schloss Heidelberg"],
	["MunichNewTownHall", "Neues Rathaus (München)"],
	["Neuschwanstein", "Schloss Neuschwanstein"],
	["Rothenberg", "Rothenburg ob der Tauber"]	
]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if for_github_page:
		_play_video(default_ld_content)

		var i = 0
		
		# Set contents to the displays
		for display in displays.get_children():
			display.setContent(CONTENTS[i][0], CONTENTS[i][1])
			i += 1


const TIMER = 5.0;
var accumulator = 0.0;

func _process(delta: float) -> void:
	if for_github_page:
		return
		
	accumulator += delta
	if accumulator > TIMER:	
		accumulator = 0.0
		await _update_content()
		
var current_ld_content = null

func _update_content():
	for api_server in api_servers:
		var api = "{api_server}/large_display".format({"api_server": api_server})
		$HTTPRequest.request(
			api,
			HEADERS,
			HTTPClient.METHOD_GET
		)
		var res = await $HTTPRequest.request_completed
			
		if res[0] == OK:
			var body = res[3]
			var json = JSON.parse_string(body.get_string_from_utf8())
			_play_video(json["ld_content"])
			break

func _play_video(ld_content):
		
	if current_ld_content != ld_content:
		if video_stream_player.is_playing():
			video_stream_player.stop()
		
		var video_stream = VideoStreamTheora.new()	
		#video_stream.file = file_path
		video_stream.file = "res://LD_Contents/{ld_content}.ogv".format({"ld_content": ld_content})

		# Assign the stream to the VideoStreamPlayer and play
		video_stream_player.stream = video_stream
		video_stream_player.play()
		print("Playing video.")
		current_ld_content = ld_content
		
