extends TrackingGui

@onready var port := %Port
@onready var address: LineEdit = %Address

#-----------------------------------------------------------------------------#
# Builtin functions
#-----------------------------------------------------------------------------#

func _ready() -> void:
	address.text_changed.connect(func(text: String):
		property_changed.emit(Trackers.OPEN_SEE_FACE, &"address", text)
	)
	port.text_changed.connect(func(text: String) -> void:
		if not text.is_valid_int():
			return
		property_changed.emit(Trackers.OPEN_SEE_FACE, &"port", text.to_int())
	)
	
	start.pressed.connect(func() -> void:
		started.emit(Trackers.OPEN_SEE_FACE)
	)

#-----------------------------------------------------------------------------#
# Private functions
#-----------------------------------------------------------------------------#

#-----------------------------------------------------------------------------#
# Public functions
#-----------------------------------------------------------------------------#

func get_type() -> Trackers:
	return Trackers.OPEN_SEE_FACE
