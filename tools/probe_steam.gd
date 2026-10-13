extends SceneTree
func _init():
	for c in ["Steam", "SteamMultiplayerPeer", "SteamPeer"]:
		print(c, " exists=", ClassDB.class_exists(c))
	if ClassDB.class_exists("SteamMultiplayerPeer"):
		for m in ClassDB.class_get_method_list("SteamMultiplayerPeer", true):
			print("  M ", m.name, " ", m.args.map(func(a): return a.name))
		for s in ClassDB.class_get_signal_list("SteamMultiplayerPeer", true):
			print("  S ", s.name)
	quit()
