extends SceneTree
func ticks(n: int) -> void:
    for i in n:
        await physics_frame
func _initialize() -> void:
    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    await ticks(5)
    root.get_node("GameClock").set_process(false)
    main.player.global_position = Vector2(100, 100)
    var vil = main.village
    vil.quota = {"woodcutter": 1, "miner": 0, "farmer": 0, "soldier": 0}
    vil.assign_jobs()
    var v = null
    for x in vil.villagers():
        if x.job == "woodcutter": v = x
    var last_carry = 0
    var hit_frames = {}
    var work_ticks = 0
    for t in 60 * 40:
        await physics_frame
        if v.state == 2:   # WORKING
            work_ticks += 1
        if v.carry > last_carry:
            var f = v.anim.frame_index()
            hit_frames[f] = hit_frames.get(f, 0) + 1
        last_carry = v.carry
    print("SYNC frame saat pukulan mengenai (14 raise,15 swing,16 low=benturan,17 rest): ", hit_frames)
    print("SYNC dipakai kerja ", work_ticks, " tick; clip=", v.anim.clip)
    # lari saat kabur malam: pastikan pekerja berada jauh dari keep dulu
    var keep_pos = Vector2(520, 500)
    v._release()
    v.position = Vector2(300, 700)
    v.state = 0
    await ticks(3)
    print("SYNC sebelum malam: state=", v.state, " dist ke keep=", int(v.position.distance_to(keep_pos)))
    var clock = root.get_node("GameClock"); clock.set_process(true); clock.time_of_day = 0.65
    await ticks(2); clock.set_process(false)
    var seen = {}
    var log = []
    for t in 60 * 8:
        await physics_frame
        seen[v.anim.clip] = seen.get(v.anim.clip, 0) + 1
        if t % 45 == 0: log.append([v.state, v.anim.clip, int(v.position.distance_to(keep_pos))])
    print("SYNC klip saat kabur: ", seen)
    print("SYNC jejak (state, klip, jarak): ", log)
    quit()
