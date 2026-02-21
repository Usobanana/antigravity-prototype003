extends Node

# BGM & SE Player references
var bgm_player: AudioStreamPlayer
var se_players = []
const MAX_SE_PLAYERS = 10

# Preload default sound placeholders if needed, or we just dynamically play empty streams for now.

func _ready():
	print("AudioManager initialized.")
	
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Master"
	add_child(bgm_player)
	
	for i in range(MAX_SE_PLAYERS):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		se_players.append(p)

# --- BGM ---

func play_bgm(type: String):
	# 例として、引数に応じてBGMを切り替える（プレースホルダー）
	# res://assets/audio/bgm_home.ogg などをロードする想定
	# 今回はファイルがない前提なのでprintだけ残すか、AudioStreamGenerator等を割り当てる
	print("[AudioManager] Playing BGM:", type)

func stop_bgm():
	bgm_player.stop()

# --- SE ---

func play_se(type: String, pitch: float = 1.0):
	# print("[AudioManager] Playing SE:", type, " | Pitch:", pitch)
	
	var stream = null
	
	# 必要に応じてリロード音、射撃音などをロード
	# match type:
	# 	"fire": stream = preload("res://assets/audio/fire.wav")
	# ...
	
	# リソースがなければ、テスト用に動的生成したノイズを鳴らす
	if not stream:
		stream = _get_placeholder_stream(type)
	
	for p in se_players:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = pitch
			p.play()
			return
	
	# 全て再生中なら一番古いものを止めて上書きするフォールバック
	var p = se_players[0]
	p.stream = stream
	p.pitch_scale = pitch
	p.play()

var placeholder_streams = {}

func _get_placeholder_stream(type: String) -> AudioStreamWAV:
	if placeholder_streams.has(type):
		return placeholder_streams[type]
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 11025
	
	var data = PackedByteArray()
	var length = int(11025 * 0.1) # 0.1秒
	
	if type == "footstep":
		length = int(11025 * 0.08)
	elif type == "hit":
		length = int(11025 * 0.15)
		
	data.resize(length)
	for i in range(length):
		var noise_val = (randi() % 256) - 128
		var envelope = 1.0 - (float(i) / float(length))
		var b = int(noise_val * envelope)
		if b < 0: b += 256 # 2の補数表現として保存
		data[i] = b

	stream.data = data
	placeholder_streams[type] = stream
	return stream
