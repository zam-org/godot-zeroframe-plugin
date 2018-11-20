extends Node

var _zeronetDaemonAddress = "http://127.0.0.1:43110/"
var _siteAddress = "1HeLLo4uzjaLetFx6NH3PMwFP3qbRbTf3D"

# Called when the node enters the scene tree for the first time.
func _ready():
	$HTTPRequest.request(_zeronetDaemonAddress + _siteAddress)

func _on_HTTPRequest_request_completed( result, response_code, headers, body ):
    var json = JSON.parse(body.get_string_from_utf8())
    print(json.result)
