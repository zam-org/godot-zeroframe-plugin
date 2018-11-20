extends CanvasLayer

var _zeronet_daemon_address = "127.0.0.1"
var _zeronet_daemon_port = 43110

var _ws_client = WebSocketClient.new()

var _wrapper_key_regex = RegEx.new()
var _wrapper_key = ""

# Called when the node enters the scene tree for the first time.
func _init():
	# Regex for finding wrapper_key of ZeroNet site
	_wrapper_key_regex.compile('wrapper_key = "(.*?)"')
	
	# Websocket client Signals
	_ws_client.connect("connection_established", self, "_ws_connection_established")
	_ws_client.connect("connection_succeeded", self, "_ws_connection_established")
	_ws_client.connect("connection_error", self, "_ws_connection_error")
	
	_be_external_program()

func _make_request(host, port, path):
	var err = 0
	var http = HTTPClient.new() # Create the Client
	
	err = http.connect_to_host(host, _zeronet_daemon_port) # Connect to host/port
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
	var text = _make_request(_zeronet_daemon_address, _zeronet_daemon_port, "/" + site_address)
	
    # Parse text and grab wrapper key
	var matches = _wrapper_key_regex.search(text)
	
	# Check we got a match on the wrapper_key
	if matches.get_group_count() == 0:
		return ""
		
	# Return the wrapper_key
	return matches.get_string(1)
	
# Send a command to the ZeroNet daemon
func cmd(command, parameters):
	# Send command with arguments to ZeroNet daemon over websocket
	var contents = JSON.print({"cmd": command, "params": parameters, "id": 1000001})
	print(contents)
	#_ws_client.put_packet(contents)
	
# Set custom zeronet daemon host address and port
func set_daemon_address(host, port):
	_zeronet_daemon_address = host
	_zeronet_daemon_port = port
	
# Use this site for future commands
func use_site(site_address):
	# Get wrapper key of the site
	_wrapper_key = get_wrapper_key(site_address)
	
	# Open up WebSocket connection to the daemon
	var ws_url = "ws://" + _zeronet_daemon_address + ":" \
		+ str(_zeronet_daemon_port) \
		+ "/Websocket?wrapper_key=%s" % _wrapper_key
		
	print(ws_url)
	_ws_client.connect_to_url(ws_url)
	
func _ws_connection_established(protocol):
	print("Connection established with protocol %s!" % protocol)
	
func _ws_connection_error():
	print("Websocket connection failed")

# Herp derp!
func _be_external_program():
	use_site('1HeLLo4uzjaLetFx6NH3PMwFP3qbRbTf3D')
	var site_info = cmd('siteInfo', {}) #Signal?