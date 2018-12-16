extends Node

var _site_address = "1HeLLo4uzjaLetFx6NH3PMwFP3qbRbTf3D"
var _daemon_address = "127.0.0.1"
var _daemon_port = 43110

var ca_addresses = {
	"zeroid": "zeroid.bit"
}

# Emitted when a websocket connection to a ZeroNet site completed successfully
signal site_connected

# Emitted when a command completes successfully. Returns cmd ID and response data
signal command_completed(response, type)
# Emitted when a site notification is received
signal notification_received(notification)
# Emitted when the site files have been externally updated
signal site_updated(message)

var _ws_client 
var _wrapper_key = ""
var _wrapper_key_regex = RegEx.new()

# Called when the node enters the scene tree for the first time.
func _init():
	_site_address = zf_settings._site_address
	_daemon_address = zf_settings._daemon_address
	_daemon_port = zf_settings._daemon_port
	
	# Regex for finding wrapper_key of ZeroNet site
	_wrapper_key_regex.compile('wrapper_key = "(.*?)"')
	
	# Create WebSocket client
	_ws_client = new_ws_client()
	
	_be_external_program()
	
func _process(delta):
	if _ws_client.get_connection_status() != NetworkedMultiplayerPeer.CONNECTION_DISCONNECTED:
		_ws_client.poll()
		if _ws_client.get_peer(1).get_available_packet_count() > 0:
			var response = JSON.parse(_ws_client.get_peer(1).get_packet().get_string_from_utf8()).result
			if typeof(response) != TYPE_DICTIONARY:
				return
			
			# Check if this is a response to a command or a site notification
			var type = response["cmd"]
			match type:
				"notification":
					emit_signal("notification_received", response)
				"response":
					emit_signal("command_completed", {"result": response["result"], "type": type})
				"confirm":
					emit_signal("command_completed", {"result": response["params"], "type": type})
				"setSiteInfo":
					emit_signal("site_updated", response)
				_:
					print("Unknown websocket data received:", response)
				
func new_ws_client():
	_ws_client = WebSocketClient.new()
	
	# Websocket client signals
	_ws_client.connect("connection_established", self, "_ws_connection_established")
	_ws_client.connect("connection_succeeded", self, "_ws_connection_established")
	_ws_client.connect("connection_error", self, "_ws_connection_error")
	_ws_client.connect("server_close_request", self, "_ws_server_close_request")
	
	return _ws_client
	
# Searches through dictionary of users for an auth address
# Helper function for _get_zeroid_cert
func _search_zeroid_users(users, auth_address):
	for username in users:
		var cert = users[username]
		
		# Old user type
		if cert.begins_with("@"):
			var info = cert.replace("@", "").split(",")
			var cert_file_id = info[0]
			var auth_address_pre = info[1]
			
			# Quick way to narrow down user match
			if auth_address.begins_with(auth_address_pre):
				var cert_filename = "certs_%s.json" % cert_file_id
				var response = yield(
					cmd("fileGet", {"inner_path": cert_filename}),
					"command_completed"
				)
				
				cert = JSON.parse(response.result)["certs"][username]
				info = cert.split(",")
				var found_auth_address = info[1]
				
				if found_auth_address == auth_address:
					return cert
		else:
			# New user type
			var info = cert.split(",")
			var found_auth_address = info[1]
			
			if found_auth_address == auth_address:
				return cert
	
	# Did not find cert belonging to auth_address
	return ""
				
# Retrieve the cert information of a ZeroID user given their auth_address
func _get_zeroid_cert(auth_address):
	# Get set of archived ZeroID users
	var response = yield(
		cmd("fileGet", {"inner_path": "data/users_archive.json"}),
		"command_completed"
	)
	var users_json = response.result
	
	var users = JSON.parse(users_json).result["users"]
	
	# Get set of latest ZeroID users
	response = yield(
		cmd("fileGet", {"inner_path": "data/users.json"}),
		"command_completed"
	)
	users_json = response.result
	
	var new_users = JSON.parse(users_json).result["users"]
	
	# Combine latest and archived user sets together
	for user in new_users:
		var content = new_users[user]
		users[user] = content
		
	return _search_zeroid_users(users, auth_address)
				
func _solve_zeroid_challenge(challenge):
	# Registering with ZeroID requires both connecting to a
	# centralized server and completing a challenge/response process.
	# A challenge is sent in the form `x*y` to the client, and it
	# must respond with the correct product to be granted a certificate.
	# We carry these steps out in this function
	var numbers = challenge.split("*")
	var num1 = numbers[0].to_int()
	var num2 = numbers[1].to_int()
	
	return num1 * num2
	
# Registers with the ZeroID certificate authority.
# Registration uses a centralized server and is IP
# rate-limited.
#
# Registration requires completing a challenge/response process.
# Once complete, ZeroID will sign your cert and insert it into
# ZeroID's site files. It is then up to the client to listen for
# this update and find their new cert, then add it to their zeronet
# daemon using the `certAdd` command.
#
# Be aware that this will disrupt any existing site websocket
# connection, which will need to be re-established if necessary
# TODO: Ability to connect to multiple zites at once?
func register_zeroid(username):
	print("Registering user...")
	# Set ZeroID as the site to use
	yield(use_site(ca_addresses["zeroid"]), "site_connected")
	
	print("Connected to ZeroID")
	
	# Retrieve information from siteInfo
	var response = yield(cmd("siteInfo", {}), "command_completed")
	var site_info = response.result
	
	# Retrieve current public key/auth address
	var auth_address = site_info["auth_address"]
	print("Got auth address:", auth_address)
	
	# Check if this auth_address has already been registered
	var cert = yield(_get_zeroid_cert(auth_address), "completed")
	if cert != "":
		# This user has already been registered
		var info = cert.split(",")
		var auth_type = info[0]
		var cert_sign = info[2]
		
		# Add cert to the client
		response = yield(cmd("certAdd", {
			"domain": ca_addresses["zeroid"],
			"auth_type": auth_type,
			"auth_user_name": username,
			"cert": cert_sign,
		}), "command_completed")
		
		# Why does this just return and hang???
		print("This user already exists:", response)
		
		if response.type == "confirm":
			# We already have a cert for this registrar
			# TODO: Replace existing cert
			return null
		else:
			if response.result == "OK":
				return null
			else:
				return response.result
	
	# Set up registration data to send to challenge server
	var registration_data = {
		"auth_address": auth_address,
		"user_name": username,
	}
	print("Registering (1/2) with: ", JSON.print(registration_data))

	# Get challenge
	var response_json = _make_http_request("zeroid.qc.to",
										   80,
										   "/ZeroID/request.php",
										   registration_data,
										   HTTPClient.METHOD_POST)
										
	response = JSON.parse(response_json)
	if response.error != OK:
		# Received an error instead of data
		# Give up and return error
		return response_json
		
	response = response.result

	# Response is in the form {"work_id":xxx,"work_task":"y*z"}
	# Add work_id and task solution to registration data and send
	# back to host
	registration_data["work_id"] = response["work_id"]
	registration_data["work_solution"] = _solve_zeroid_challenge(response["work_task"])
	print("Registering (2/2) with: ", JSON.print(registration_data))
	#return "faking end"
	# Send challenge solution
	response = _make_http_request("zeroid.qc.to",
								  80,
								  "/ZeroID/solution.php",
								  registration_data,
								  HTTPClient.METHOD_POST)
	
	# Ensure registration was successful
	if response != "OK":
		# Not successful, return reason
		return response
		
	# Wait for notification of site update
	print("Waiting for site updated")
	print("Site updated: ", yield(self, "site_updated"))
	print("Updated!")
	
	# Retrieve cert information from ZeroID site files
	cert = _get_zeroid_cert(auth_address)
	
	var info = cert.split(",")
	var auth_type = info[0]
	var cert_sign = info[2]
	
	# Add cert to the client
	response = yield(cmd("certAdd", {
		"domain": ca_addresses["zeroid"],
		"auth_type": auth_type,
		"auth_user_name": username,
		"cert": cert_sign,
	}), "command_completed")

	# Registration completed and new cert added to client
	match response.type:
		"confirm":
			# We already have a cert for this registrar
			# TODO: Replace existing cert
			return null
		"response":
			if response == "OK":
				return null
			else:
				return response

# Make a http/s request to a host. 
# payload is a string that will be sent in the request
func _make_http_request(host, port, path, payload, method_type=HTTPClient.METHOD_GET):
	var err = 0
	var http = HTTPClient.new() # Create the Client
	
	err = http.connect_to_host(host, port, port == 443) # Connect to host/port
	assert(err == OK) # Make sure connection was OK
	
	# Wait until resolved and connected
	while http.get_status() == HTTPClient.STATUS_CONNECTING or http.get_status() == HTTPClient.STATUS_RESOLVING:
		http.poll()
		OS.delay_msec(300)
	
	assert(http.get_status() == HTTPClient.STATUS_CONNECTED) # Could not connect
	
	# Different headers for POST vs. GET
	var headers = ["User-Agent: Pirulo/1.0 (Godot)"]
	if method_type == HTTPClient.METHOD_GET:
		headers.append("Accept: text/html")
	elif method_type == HTTPClient.METHOD_POST:
		headers.append("Accept: */*")
		headers.append("Content-Type: application/x-www-form-urlencoded; charset=UTF-8")
		payload = http.query_string_from_dict(payload)
	
	# Request a page from the site (this one was chunked..)
	err = http.request(method_type, path, headers, payload) 
	assert(err == OK) # Make sure all is OK
	
	while http.get_status() == HTTPClient.STATUS_REQUESTING:
	    # Keep polling until the request is going on
		http.poll()
		OS.delay_msec(500)
	
	assert(http.get_status() == HTTPClient.STATUS_BODY or http.get_status() == HTTPClient.STATUS_CONNECTED) # Make sure request finished well.
	
	if http.has_response():
		# If there is a response..
		
		headers = http.get_response_headers_as_dictionary() # Get response headers
	
		# Getting the HTTP Body
		var rb = PoolByteArray() # Array that will hold the data
	
		while http.get_status() == HTTPClient.STATUS_BODY:
	        # While there is body left to be read
			http.poll()
			var chunk = http.read_response_body_chunk() # Get a chunk
			if chunk.size() == 0:
	            # Got nothing, wait for buffers to fill a bit
				OS.delay_usec(1000)
			else:
				rb = rb + chunk # Append to read buffer
		
		return rb.get_string_from_ascii()
		
# Get available certs that the current site supports
func get_available_certs():
	# TODO: Get certs through selectCert. HTML processing for now
	pass
	
# Select a cert given by get_available_certs
func select_cert(id):
	# TODO: Send a response from _ws_client with the chosen cert
	pass
	
# Retrieve the wrapper_key of a ZeroNet website
func get_wrapper_key(site_address):
	# Get webpage text containing wrapper key
	var text = _make_http_request(_daemon_address, _daemon_port, "/" + site_address, "")
	
    # Parse text and grab wrapper key
	var matches = _wrapper_key_regex.search(text)
	
	# Check that we got a match on the wrapper_key
	if matches == null or matches.get_group_count() == 0:
		return ""
		
	# Return the wrapper_key
	return matches.get_string(1)
	
# Send a command to the ZeroNet daemon
func cmd(command, parameters):
	# Send command with arguments to ZeroNet daemon over websocket
	var contents = JSON.print({"cmd": command, "params": parameters, "id": 1000001})
	print("Sending command:", contents)
	_ws_client.get_peer(1).put_packet(contents.to_utf8())
	
	return self
	
# Set custom zeronet daemon host address and port
func set_daemon_address(host, port):
	_daemon_address = host
	_daemon_port = port
	
# Use this site for future commands
func use_site(site_address):
	# Remove any previous websocket connection
	_ws_client.disconnect_from_host()
	
	_ws_client = new_ws_client()
	
	# Keep track of new address
	_site_address = site_address
	
	# Get wrapper key of the site
	_wrapper_key = get_wrapper_key(site_address)
	
	if _wrapper_key == "":
		print("Unable to connect to ZeroNet")
		return null
	
	# Open up WebSocket connection to the daemon
	var ws_url = "ws://" + _daemon_address + ":" \
		+ str(_daemon_port) \
		+ "/Websocket?wrapper_key=%s" % _wrapper_key
		
	_ws_client.connect_to_url(ws_url)
	
	return self
	
func _ws_connection_established(protocol):
	print("Connection established with protocol %s!" % protocol)
	# Set sending websocket data as text, which ZeroNet prefers, rather than binary
	_ws_client.get_peer(1).set_write_mode(WebSocketPeer.WRITE_MODE_TEXT)
	
	emit_signal("site_connected")
	
func _ws_connection_error():
	print("Websocket connection failed!")
	
func _ws_server_close_request(error, reason):
	print("Server issued close request!", error, reason)

# Herp derp!
func _be_external_program():
	var site_address = "1vcpDyMSZWDMmsD81Z6zApFStPvr2j728"
	var username = "tespusper7"
	var error = yield(register_zeroid(username), "completed")
	if error == null:
		print("Successful!")
	else:
		print("Unable to successfully register: ", error)
		return
	
	# Open a connection to a ZeroNet site
	yield(use_site(site_address), "site_connected")
	
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
	