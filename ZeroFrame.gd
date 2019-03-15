tool
extends Node

# ------------ Global Vars ------------- #

var _user_id
var _user_data_dir = "data/users/"

# --------------- Enums ---------------- #

# Login Providers
enum {
	UNKNOWN_PROVIDER
	PROVIDER_ZEROID
}

# Map from login provider to domain
var provider_domains = {
	PROVIDER_ZEROID: "zeroid.bit"
}

var ZeroFrameCore = load('res://addons/ZeroFrame/ZeroFrameCore.gd').new()

# Result is an object that contains a result and an error as either something
# or nothing (null). This type is object returned by functions. Callers should
# first check whether `error` is null or not. If non-null, an error occured
# within in the function and the error, a String, will contain details on what
# went wrong. If `error` is null and the function is expected to return a type,
# `result` will be populated.
class Result:
	var result
	var error

# ------- Login and Registration ------- #

func login(master_seed: String = "", provider: int = PROVIDER_ZEROID) -> Result:
	var res = Result.new()
	match provider:
		PROVIDER_ZEROID:
			if not ZeroFrameCore.login_zeroid(master_seed):
				res.error = "Login failed"
		_:
			res.error = "Unknown provider"

	return res

func register(username: String, provider: int = PROVIDER_ZEROID) -> Result:
	var res = Result.new()
	match provider:
		PROVIDER_ZEROID:
			res.error = ZeroFrameCore.register_zeroid(username)
		_:
			res.error = "Unknown provider"

	return res

func retrieve_master_seed() -> Result:
	var res = Result.new()
	res.result = yield(ZeroFrameCore.retrieve_master_seed(), "completed")
	if typeof(res.result) == TYPE_DICTIONARY:
		res.error = res.result["error"]
	return res

func logout(provider: int = PROVIDER_ZEROID) -> Result:
	var res = Result.new()
	res.error = ZeroFrameCore.logout()
	return res

func is_logged_in(provider: int = PROVIDER_ZEROID) -> Result:
	"""
	Returns a dictionary of:
		
		* logged_in: bool - Whether a certificate for the provider exists.
		* selected: bool - Whether the provider's certificate has been selected for this site.
		* selected_provider: int - The provider that has been selected for this site.
								   UNKNOWN_PROVIDER if no provider selected or
								   provider domain not recognized.
	"""
	var res = Result.new()
	
	# Retrieve cert data from the site
	var cert_data = yield(ZeroFrameCore.cmd("certList"), "command_completed")
	if cert_data == null:
		res.error = "Unable to retrieve certificate information"
		return res
		
	var logged_in = false
	var selected = false
	var selected_provider = UNKNOWN_PROVIDER
	
	for cert in cert_data:
		# Check if this provider even has a cert
		if cert["domain"] == provider_domains[provider]:
			logged_in = true
			
		# If this is the currently selected cert
		if cert["selected"]:
			# Check which domain it is
			for provider_enum in provider_domains:
				var domain = provider_domains[provider_enum]
				if domain == cert["domain"]:
					selected_provider = provider_enum
					
			# Check if it's the requested provider
			if cert["domain"] == provider_domains[provider]:
				selected = true

	return res

# ------------ Achievements ------------ #

# TODO: `trophies` key as a map in data.json. Key per ID. Each has `progress`, `achieved`.

func set_trophy_achieved(id: int, achieved: bool) -> Result:
	# TODO
	var res = Result.new()
	return res

func set_trophy_progress(id: int, progress: int) -> Result:
	# TODO
	var res = Result.new()
	return res

func get_all_trophies() -> Result:
	# TODO
	var res = Result.new()
	return res

func get_trophy_achieved(id: int) -> Result:
	# TODO
	var res = Result.new()
	return res

func get_trophy_progress(id: int) -> Result:
	# TODO
	var res = Result.new()
	return res

# --------------- Scores --------------- #

# TODO: `scores` key in data.json. `id` as key.

func fetch_scores(id: int, username: String = "", limit: int = 0) -> Result:
	# TODO
	var res = Result.new()
	return res

func save_score(id: int, score: float) -> Result:
	# TODO
	var res = Result.new()
	return res

# --------------- Storage -------------- #

func save_file(filepath: String, data: Array) -> Result:
	var res = Result.new()

	res.error = yield(ZeroFrameCore.cmd("fileWrite", {"inner_path": filepath, "content_base64": data}), "command_completed").result
	if res.error == "ok":
		# No error occurred
		res.error = null

	return res

func load_file(filepath: String) -> Result:
	# TODO: Non-existant filepath handling
	var res = Result.new()
	res.result = yield(ZeroFrameCore.cmd("fileGet", {"inner_path": filepath}), "command_completed").result
	return res

func remove_file(filepath: String) -> Result:
	var res = Result.new()

	res.error = yield(ZeroFrameCore.cmd("fileDelete", {"inner_path": filepath}), "command_completed").result
	if res.error == "ok":
		# No error occurred
		res.error = null

	return res

func save_data(key: String, data) -> Result:
	var res = Result.new()
	var data_filepath = _user_data_dir + _user_id + "/data.json"
	var content_filepath = _user_data_dir + _user_id + "/content.json"
	
	# Retrieve the current user data
	var user_data = yield(ZeroFrameCore.cmd("fileGet", {"inner_path": data_filepath}), "command_completed").result
	
	# Account for empty data.json
	if user_data == null:
		user_data = {}
	
	# Add new data to current user data
	user_data[key] = data
	
	# Encode the user data to a JSON string
	user_data = JSON.print(user_data, "  ")
	
	# Convert JSON to base64
	user_data = Marshalls.utf8_to_base64(user_data)

	# Save user data to ZeroNet
	res.error = yield(ZeroFrameCore.cmd("fileWrite", {"inner_path": data_filepath, "content_base64": user_data}), "command_completed").result
	if res.error != "ok":
		return res
		
	# Sign and publish changes
	res.error = yield(ZeroFrameCore.cmd("sitePublish", {"inner_path": content_filepath}), "command_completed")
	if res.error == "ok":
		# No error
		res.error = null

	return res

func get_data(key: String, username: String = "") -> Result:
	# TODO: Handle incorrect filepath
	if username == "":
		# Use current user if username not provided
		username = _user_id

	var data_filepath = _user_data_dir + username + "/data.json"
	var res = Result.new()
	res.result = yield(ZeroFrameCore.cmd("fileGet", {"inner_path": data_filepath}), "command_completed").result
	
	# Account for empty data.json file
	if res.result == null:
		# Return null
		return res
	
	# Return requested key data
	res.result = res.result[key]
		
	return res

func remove_data(key: String) -> Result:
	# TODO: How to remove a key from a godot dict
	var res = Result.new()

	# Get the current user data
	var r = get_data(key)
	if r.error:
		res.error = r.error
		return res

	# Remove contents under 'key'
	var data = r.result
	data.erase(key)

	# Save back to user data
	r = save_data(key, data)
	if r.error:
		res.error = r.error
		return res

	return res

# ---------- Daemon Management --------- #

func start_zeronet():
	"""Start an internal ZeroNet daemon"""
	var res = Result.new()
	res.error = ZeroFrameCore.start_zeronet()
	return res

func stop_zeronet():
	"""Stop an internal ZeroNet daemon"""
	var res = Result.new()
	res.error = ZeroFrameCore.stop_zeronet()
	return res

# Ensure ZeroNet is stopped if the game is exited
func _exit_tree():
	ZeroFrameCore.stop_zeronet()

# ---------------- Misc ---------------- #

func connect_to_site(site_address: String) -> Result:
	"""Connect to a ZeroNet site"""
	var res = Result.new()
	if not yield(ZeroFrameCore.use_site(site_address), "site_connected"):
		res.error = "Unable to connect to site"
		
	return res

func connected() -> Result:
	"""Check if connected to any sites"""
	var res = Result.new()
	res.result = ZeroFrameCore._site_connected
	return res

#
#func _be_external_program():
#	var site_address = "1vcpDyMSZWDMmsD81Z6zApFStPvr2j728"
#	var username = "tespusper7"
#	var error = yield(ZeroFrameCore.register_zeroid(username), "completed")
#	if error == null:
#		print("Successful!")
#	else:
#		print("Unable to successfully register: ", error)
#		return
#
#	# Open a connection to a ZeroNet site
#	if not yield(ZeroFrameCore.use_site(site_address), "site_connected"):
#		print("Unable to connect to site")
#		return
#
#	# Get available users
#	#var users = get_users()
#
#	# Send siteInfo command to retrieve information about the site
#	var site_info = yield(ZeroFrameCore.cmd("siteInfo", {}), "command_completed").result
#
#	# Store some data on the site
#	var inner_path = "data/%s/data.json" % site_info["auth_address"]
#	var data = Marshalls.utf8_to_base64(JSON.print({"score": 500}))
#	var response = yield(cmd("fileWrite", {"inner_path": inner_path, "content_base64": data}), "command_completed")
#	print("Store response: ", response)
#
#	# Publish the data to peers
#	response = yield(cmd("sitePublish", {"sign": true}), "command_completed")
#
#	# Retrieve that data
#	response = yield(cmd("fileGet", {"inner_path": inner_path}), "command_completed")
#	var user_data = JSON.parse(response.result)
#	print(user_data.result)