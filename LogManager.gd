extends Node

func _ready():
    var session_id = Time.get_unix_time_from_system()
    print("\n" + "=".repeat(40))
    print("--- ANTIGRAVITY_SESSION_START: ", session_id, " ---")
    print("DATE: ", Time.get_datetime_string_from_system())
    print("=".repeat(40) + "\n")
