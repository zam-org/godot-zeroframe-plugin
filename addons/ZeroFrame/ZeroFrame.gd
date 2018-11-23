extends Node

export var site_address = "1HeLLo4uzjaLetFx6NH3PMwFP3qbRbTf3D"
export var _daemon_address = "127.0.0.1"
export var _daemon_port = 43110

# Emitted when a websocket connection to a ZeroNet site completed successfully
signal site_connected

# Emitted when a command completes successfully. Returns cmd ID and response data
signal command_completed(response)

# Emitted when a site notification is received
signal notification_received(notification)

var _ws_client = WebSocketClient.new()
var _wrapper_key = ""
var _wrapper_key_regex = RegEx.new()

# Called when the node enters the scene tree for the first time.
func _init():
	# Regex for finding wrapper_key of ZeroNet site
	_wrapper_key_regex.compile('wrapper_key = "(.*?)"')
	
	# Websocket client Signals
	_ws_client.connect("connection_established", self, "_ws_connection_established")
	_ws_client.connect("connection_succeeded", self, "_ws_connection_established")
	_ws_client.connect("connection_error", self, "_ws_connection_error")
	_ws_client.connect("data_received", self, "_ws_data_received")
	_ws_client.connect("server_close_request", self, "_ws_server_close_request")
	
	_be_external_program()
	
func _process(delta):
	if _ws_client.get_connection_status() != NetworkedMultiplayerPeer.CONNECTION_DISCONNECTED:
		_ws_client.poll()
		if _ws_client.get_peer(1).get_available_packet_count() > 0:
			var response = JSON.parse(_ws_client.get_peer(1).get_packet().get_string_from_utf8()).result
			if typeof(response) != TYPE_DICTIONARY:
				return
			
			# Check if this is a response to a command or a site notification
			if response["cmd"] == "notification":
				emit_signal("notification_received", response)
			elif response["cmd"] == "response":
				emit_signal("command_completed", response["result"])
			else:
				print("Unknown websocket data received:", response)

func _make_http_request(host, port, path):
	var err = 0
	var http = HTTPClient.new() # Create the Client
	
	err = http.connect_to_host(host, port) # Connect to host/port
	assert(err == OK) # Make sure connection was OK
	
	# Wait until resolved and connected
	while http.get_status() == HTTPClient.STATUS_CONNECTING or http.get_status() == HTTPClient.STATUS_RESOLVING:
		http.poll()
		OS.delay_msec(500)
	
	assert(http.get_status() == HTTPClient.STATUS_CONNECTED) # Could not connect
	
	# Some headers
	var headers = [
		"User-Agent: Pirulo/1.0 (Godot)",
		"Accept: text/html"
	]
	
	err = http.request(HTTPClient.METHOD_GET, path, headers) # Request a page from the site (this one was chunked..)
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
	
# Retrieve the wrapper_key of a ZeroNet website
func get_wrapper_key(site_address):
	# Get webpage text containing wrapper key
	var text = _make_http_request(_daemon_address, _daemon_port, "/" + site_address)
	
    # Parse text and grab wrapper key
	var matches = _wrapper_key_regex.search(text)
	
	# Check that we got a match on the wrapper_key
	if matches.get_group_count() == 0:
		return ""
		
	# Return the wrapper_key
	return matches.get_string(1)
	
# Send a command to the ZeroNet daemon
func cmd(command, parameters) -> Object:
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
func use_site(site_address) -> Object:
	# Get wrapper key of the site
	_wrapper_key = get_wrapper_key(site_address)
	
	# Open up WebSocket connection to the daemon
	var ws_url = "ws://" + _zeronet_daemon_address + ":" \
		+ str(_zeronet_daemon_port) \
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
	# Open a connection to a ZeroNet site
	yield(use_site(site_address), "site_connected")
	
	# Send siteInfo command to retrieve information about the site
	var response = yield(cmd("siteInfo", {}), "command_completed")
	print("Site information: ", response)
	
	# Store some data on the site
	var data = Marshalls.utf8_to_base64(JSON.print({"score": 500}))
	response = yield(cmd("fileWrite", {"inner_path": "data/user/data.json", "content_base64": data}), "command_completed")
	print("Store response: ", response)
	
	# TODO: Publish the data (Needs cert)
	
	# Retrieve that data
	response = yield(cmd("fileGet", {"inner_path": "data/user/data.json"}), "command_completed")
	print(JSON.parse(response).result)