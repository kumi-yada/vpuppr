class_name OpenSeeFace
extends AbstractTracker

const MAX_TRACKER_FPS: int = 144

const RUN_FACE_TRACKER_TEXT := "Run tracker"
const STOP_FACE_TRACKER_TEXT := "Stop tracker"

var logger := Logger.create("OpenSeeFace")

# In theory we only need to receive data from tracker exactly FPS times per 
# second, because that is the number of times that data will be sent.
# However for low fps this will result in lagging behind, if the moment of 
# sending to receiving data is not very close to each other.
# As we limit the fps to 144, we can just poll every 1/144 seconds. At that
# FPS there should be no perceivable lag while still keeping the CPU usage
# at a low level when the receiver is started.
var server_poll_interval: float = 1.0 / MAX_TRACKER_FPS

var max_fit_3d_error: float = 100.0

var server: UDPServer
var connection: PacketPeerUDP # Must be taken when running the server

var receive_thread: Thread # Must be created when starting tracking

var reception_counter: float = 0.0
var stop_reception := false

var face_tracker_pid: int = -1

var updated_time: float = 0.0

#-----------------------------------------------------------------------------#
# Builtin functions                                                           #
#-----------------------------------------------------------------------------#

#func _init() -> void:
	#if _start_tracker():
		#start_receiver()

#-----------------------------------------------------------------------------#
# Connections                                                                 #
#-----------------------------------------------------------------------------#

#-----------------------------------------------------------------------------#
# Private functions                                                           #
#-----------------------------------------------------------------------------#

#func _start_tracker() -> bool:
	#return false
	# If the tracker should be launched, launch it
	# Otherwise assume that the user launched a tracker manually already
	#var should_launch = AM.cm.get_data("open_see_face_should_launch_tracker")
	#if typeof(should_launch) == TYPE_NIL:
		#logger.error("No data found for open_see_face_should_launch_tracker")
		#return false
#
	## Settings could be messed up, so do this before anything else.
	#if not should_launch:
		#logger.info("Assuming face tracker was manually launched.")
		#return true
#
	#var fps = AM.cm.get_data("open_see_face_tracker_fps")
	#if typeof(fps) == TYPE_NIL:
		#logger.error("No data found for open_see_face_tracker_fps")
		#return false
#
	#var address = AM.cm.get_data("open_see_face_address")
	#if typeof(address) == TYPE_NIL:
		#logger.error("No data found for open_see_face_address")
		#return false
#
	#var port = AM.cm.get_data("open_see_face_port")
	#if typeof(port) == TYPE_NIL:
		#logger.error("No data found for open_see_face_port")
		#return false
#
	#var camera_index = AM.cm.get_data("open_see_face_camera_index")
	#if typeof(camera_index) == TYPE_NIL:
		#logger.error("No data found for open_see_face_camera_index")
		#return false
#
	#var ml_model = AM.cm.get_data("open_see_face_model")
	#if typeof(ml_model) == TYPE_NIL:
		#logger.error("No data found for open_see_face_model")
		#return false
	#
	#logger.info("Starting face tracker")
	#
	#if fps > MAX_TRACKER_FPS:
		#logger.info("Face tracker fps is greater than %s. This is a bad idea." % MAX_TRACKER_FPS)
		#logger.info("Declining to start face tracker.")
		#return false
#
	#var res = Safely.wrap(AM.em.get_context("OpenSeeFace"))
	#if res.is_err():
		#logger.error(res)
		#return false
#
	#var context_path: String = res.unwrap()
#
	#var pid: int = OS.execute(
		#"%s/OpenSeeFace/facetracker%s" % [
			#context_path,
			#".exe" if OS.get_name().to_lower() == "windows" else ""
		#],
		#[
			#"--capture", camera_index,
			#"--fps", str(fps),
			#"--visualize", "0",
			#"--silent", "1",
			#"--pnp-points", "0",
			#"--discard-after", "0",
			#"--scan-every", "0",
			#"--no-3d-adapt", "1",
			#"--max-feature-updates", "900",
			#"--ip", address,
			#"--port", str(port),
			#"--model", str(ml_model)
		#],
		#false
	#)
#
	#if pid <= 0:
		#logger.error("Failed to start tracker")
		#return false
#
	#face_tracker_pid = pid
#
	#logger.info("Face tracker started, PID is %s." % face_tracker_pid)
	## TODO add in logger toast notification
	## logger.notify("Press spacebar to recenter the model if it's not looking correct!")
#
	#return true

# func _stop_tracker() -> void:
# 	logger.info("Stopping face tracker")

# 	if face_tracker_pid >= 0:
# 		match OS.get_name().to_lower():
# 			"windows", "osx", "x11":
# 				OS.kill(face_tracker_pid)
# 			_:
# 				logger.info("Unhandled os type %s" % OS.get_name())
# 				return
		
# 		logger.info("Face tracker stopped, PID was %s." % face_tracker_pid)
# 		face_tracker_pid = -1
# 	else:
# 		logger.info("Tracker is not started")

func _receive() -> void:
	server.poll()
	if connection != null:
		var packet := connection.get_packet()
		if(packet.size() < 1 or packet.size() % OpenSeeFaceParser.PACKET_FRAME_SIZE != 0):
			return
		data_received.emit(packet)
		
	elif server.is_connection_available():
		connection = server.take_connection()

func _perform_reception() -> void:
	while not stop_reception:
		_receive()
		await Engine.get_main_loop().create_timer(server_poll_interval).timeout

func _start_receiver(address: String, port: int) -> void:
	logger.info("Listening for data at %s:%d" % [address, port])

	server = UDPServer.new()
	server.listen(port, address)

	stop_reception = false

	receive_thread = Thread.new()
	receive_thread.start(func(): _perform_reception())

func _stop_receiver() -> void:
	if stop_reception:
		return

	stop_reception = true

	if receive_thread != null and receive_thread.is_alive():
		receive_thread.wait_to_finish()
		receive_thread = null
	
	if server != null and server.is_listening():
		if connection != null and connection.is_socket_connected():
			connection.close()
			connection = null
		server.stop()
		server = null


#-----------------------------------------------------------------------------#
# Public functions                                                            #
#-----------------------------------------------------------------------------#

# func set_offsets() -> void:
# 	var data: OSFData = data_map.get(0, null)
# 	if data == null:
# 		return

	# stored_offsets.translation_offset = data.translation
	# stored_offsets.rotation_offset = data.rotation
	# stored_offsets.left_eye_gaze_offset = data.left_gaze.get_euler()
	# stored_offsets.right_eye_gaze_offset = data.right_gaze.get_euler()

# func has_data() -> bool:
# 	return not data_map.empty()

# func apply(data: InterpolationData, _model: PuppetTrait) -> void:
# 	var osf_data: OSFData = data_map.get(0, null)
# 	if osf_data == null or osf_data.fit_3d_error > 100.0:
# 		return

# 	data.bone_translation.target_value = stored_offsets.translation_offset - osf_data.translation
# 	data.bone_rotation.target_value = stored_offsets.rotation_offset - osf_data.rotation

# 	# TODO normalize bad x/y values, something is wrong with my conversion
# 	data.left_gaze.target_value = stored_offsets.left_eye_gaze_offset - osf_data.left_gaze.get_euler()
# 	data.right_gaze.target_value = stored_offsets.right_eye_gaze_offset - osf_data.right_gaze.get_euler()

# 	data.left_blink.target_value = osf_data.left_eye_open
# 	data.right_blink.target_value = osf_data.right_eye_open

# 	data.mouth_open.target_value = osf_data.features.mouth_open
# 	data.mouth_wide.target_value = osf_data.features.mouth_wide

## Get the name of the tracker.
static func get_name() -> StringName:
	return &"OpenSeeFace"

## Get the type of the tracker.
static func get_type() -> Trackers:
	return Trackers.OPEN_SEE_FACE

## Start the tracker.
static func start(data: Resource) -> AbstractTracker:
	var tracker = OpenSeeFace.new()
	tracker._start_receiver(data.address, data.port)
	return tracker

## Stop the tracker.
func stop() -> Error:
	_stop_receiver()
	return OK
