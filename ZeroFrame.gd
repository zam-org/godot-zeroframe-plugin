tool
extends Node

const ZeroFrameCore = preload("ZeroFrameCore.gd")

# --------------- Enums ---------------- #

# Login Providers
enum {
    PROVIDER_ZEROID
}

# Result is an object that contains a result and an error as either something
# or nothing (null). This type is object returned by functions. Callers should
# first check whether `error` is null or not. If non-null, an error occured
# within in the function and the error, a String, will contain details on what
# went wrong. If `error` is null and the function is expected to return a type,
# `result` will be populated.
class Result:
    var result
    var error: String

# ------- Login and Registration ------- #

func login(username: String, private_key: String = "", provider: int = PROVIDER_ZEROID) -> Result:
    pass

func register(username: String, provider: int = PROVIDER_ZEROID) -> Result:
    pass

func get_private_key(username: String, provider: int = PROVIDER_ZEROID) -> Result:
    pass

func logout(provider: int = PROVIDER_ZEROID) -> Result:
    pass

func is_logged_in(provider: int = PROVIDER_ZEROID) -> Result:
    pass

# ------------ Achievements ------------ #

func set_trophy_achieved(id: int, achieved: bool) -> Result:
    pass

func set_trophy_progress(id: int, progress: int) -> Result:
    pass

func get_all_trophies() -> Result:
    pass

func get_trophy_achieved(id: int) -> Result:
    pass

func get_trophy_progress(id: int) -> Result:
    pass

# --------------- Scores --------------- #

func fetch_scores(id: int, username: String = null, limit: int = 0) -> Result:
    pass

func save_score(id: int, score: float) -> Result:
    pass

# --------------- Storage -------------- #

func save_file(filepath: String, file: Array) -> Result:
    pass

func load_file(filepath: String) -> Result:
    pass

func remove_file(filepath: String) -> Result:
    pass

func save_data(key: String, data) -> Result:
    pass

func get_data(key: String, username: String = null) -> Result:
    pass

func remove_data(key: String) -> Result:
    pass

# ---------------- Misc ---------------- #

# TODO: Return a Result?
func cmd(command: String, parameters: Array):
    return ZeroFrameCore.cmd(command, parameters)

# TODO: Return a Result?
func sql(query: String):
    """Run a function against the site DB"""
    return ZeroFrameCore.cmd("dbQuery", query)


func _be_external_program():
	var site_address = "1vcpDyMSZWDMmsD81Z6zApFStPvr2j728"
	var username = "tespusper7"
	var error = yield(ZeroFrameCore.register_zeroid(username), "completed")
	if error == null:
		print("Successful!")
	else:
		print("Unable to successfully register: ", error)
		return

	# Open a connection to a ZeroNet site
	if not yield(use_site(site_address), "site_connected"):
		print("Unable to connect to site")
		return

	# Get available users
	#var users = get_users()

	# Send siteInfo command to retrieve information about the site
	var site_info = yield(cmd("siteInfo", {}), "command_completed").result

	# Store some data on the site
	var inner_path = "data/%s/data.json" % site_info["auth_address"]
	var data = Marshalls.utf8_to_base64(JSON.print({"score": 500}))
	var response = yield(cmd("fileWrite", {"inner_path": inner_path, "content_base64": data}), "command_completed")
	print("Store response: ", response)

	# Publish the data to peers
	response = yield(cmd("sitePublish", {"sign": true}), "command_completed")

	# Retrieve that data
	response = yield(cmd("fileGet", {"inner_path": inner_path}), "command_completed")
	var user_data = JSON.parse(response.result)
	print(user_data.result)