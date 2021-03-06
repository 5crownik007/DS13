/mob
	var/moving           = FALSE

/mob/proc/SelfMove(var/direction)
	///Mobs with slow turning take a move to turn in place.
	//We will attempt to turn towards the target if our movement is off cooldown
	if (slow_turning)
		if (CheckMoveCooldown() && facedir(direction))
			return TRUE
		else if (!(dir & direction))
			return FALSE

	if(DoMove(direction, src) & MOVEMENT_HANDLED)
		return TRUE // Doesn't necessarily mean the mob physically moved

/mob/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if(air_group || (height==0))
		return TRUE

	if (mover.pass_flags & PASS_FLAG_NOMOB)
		return TRUE

	if(ismob(mover))
		var/mob/moving_mob = mover
		if ((other_mobs && moving_mob.other_mobs))
			return TRUE
		return (!mover.density || !density || (lying && !density_lying()))
	else
		return (!mover.density || !density || (lying && !density_lying()))
	return


//Sets next move time to now, so a mob can move immediately
/mob/proc/reset_move_cooldown()
	var/datum/movement_handler/mob/delay/delay = GetMovementHandler(/datum/movement_handler/mob/delay)
	if(delay)
		delay.ResetDelay()

/mob/proc/set_move_cooldown(var/timeout)
	var/datum/movement_handler/mob/delay/delay = GetMovementHandler(/datum/movement_handler/mob/delay)
	if(delay)
		delay.SetDelay(timeout)

/mob/proc/extra_move_cooldown(var/timeout)
	var/datum/movement_handler/mob/delay/delay = GetMovementHandler(/datum/movement_handler/mob/delay)
	if(delay)
		delay.AddDelay(timeout)

/mob/proc/CheckMoveCooldown()
	var/datum/movement_handler/mob/delay/delay = GetMovementHandler(/datum/movement_handler/mob/delay)
	if(delay)
		return (delay.MayMove(src) == MOVEMENT_PROCEED)

/client/proc/client_dir(input, direction=-1)
	return turn(input, direction*dir2angle(dir))

/client/Northeast()
	diagonal_action(NORTHEAST)
/client/Northwest()
	diagonal_action(NORTHWEST)
/client/Southeast()
	diagonal_action(SOUTHEAST)
/client/Southwest()
	diagonal_action(SOUTHWEST)

/client/proc/diagonal_action(direction)
	switch(client_dir(direction, 1))
		if(NORTHEAST)
			swap_hand()
			return
		if(SOUTHEAST)
			attack_self()
			return
		if(SOUTHWEST)
			if(iscarbon(usr))
				var/mob/living/carbon/C = usr
				C.toggle_throw_mode()
			else
				to_chat(usr, "<span class='warning'>This mob type cannot throw items.</span>")
			return
		if(NORTHWEST)
			mob.hotkey_drop()

/mob/proc/hotkey_drop()
	to_chat(usr, "<span class='warning'>This mob type cannot drop items.</span>")

/mob/living/carbon/hotkey_drop()
	if(!get_active_hand())
		to_chat(usr, "<span class='warning'>You have nothing to drop in your hand.</span>")
	else
		unequip_item()

//This gets called when you press the delete button.
/client/verb/delete_key_pressed()
	set hidden = 1

	if(!usr.pulling)
		to_chat(usr, "<span class='notice'>You are not pulling anything.</span>")
		return
	usr.stop_pulling()

/client/verb/swap_hand()
	set hidden = 1
	if(istype(mob, /mob/living/carbon))
		mob:swap_hand()
	if(istype(mob,/mob/living/silicon/robot))
		var/mob/living/silicon/robot/R = mob
		R.cycle_modules()
	return



/client/verb/attack_self()
	set hidden = 1
	if(mob)
		mob.mode()
	return


/client/verb/toggle_throw_mode()
	set hidden = 1
	if(!istype(mob, /mob/living/carbon))
		return
	if (!mob.stat && isturf(mob.loc) && !mob.restrained())
		mob:toggle_throw_mode()
	else
		return


/client/verb/drop_item()
	set hidden = 1
	if(!isrobot(mob) && mob.stat == CONSCIOUS && isturf(mob.loc))
		return mob.unequip_item()
	return


//This proc should never be overridden elsewhere at /atom/movable to keep directions sane.
/atom/movable/Move(newloc, direct)
	if (direct & (direct - 1))
		src.mid_diag_move = TRUE

		var/vert_dir = SOUTH
		if (direct & 1)
			vert_dir = NORTH

		var/hor_dir = WEST
		if (direct & 4)
			hor_dir = EAST

		if (step(src, vert_dir))
			src.mid_diag_move = FALSE
			step(src, hor_dir)
		else if (step(src, hor_dir))
			src.mid_diag_move = FALSE
			step(src, vert_dir)

		src.mid_diag_move = FALSE // In case diagonal movement does not actually happen
	else
		var/atom/A = src.loc

		. = ..()
		if(direct != get_visual_dir())
			set_dir(direct)

		//This is an actual speed in metres per second
		var/last_move_delta = world.time - src.l_move_time
		if (last_move_delta)
			src.move_speed = 10 / last_move_delta
		else
			move_speed = 0

		src.l_move_time = world.time
		src.m_flag = 1
		if ((A != src.loc && A && A.z == src.z))
			src.last_move = get_dir(A, src.loc)

/client/Move(n, direction)
	if(!mob)
		return // Moved here to avoid nullrefs below
	return mob.SelfMove(direction)

// Checks whether this mob is allowed to move in space
// Return 1 for movement, 0 for none,
// -1 to allow movement but with a chance of slipping
/mob/proc/Allow_Spacemove(var/check_drift = 0)
	if(!Check_Dense_Object()) //Nothing to push off of so end here
		return 0

	if(restrained()) //Check to see if we can do things
		return 0

	return -1

//Checks if a mob has solid ground to stand on
//If there's no gravity then there's no up or down so naturally you can't stand on anything.
//For the same reason lattices in space don't count - those are things you grip, presumably.
/mob/proc/check_solid_ground()
	if(istype(loc, /turf/space))
		return 0

	if(!lastarea)
		lastarea = get_area(src)
	if(!lastarea || !lastarea.has_gravity)
		return 0

	return 1

/mob/proc/Check_Dense_Object() //checks for anything to push off or grip in the vicinity. also handles magboots on gravity-less floors tiles

	var/shoegrip = Check_Shoegrip()

	for(var/turf/simulated/T in trange(1,src)) //we only care for non-space turfs
		if(T.density)	//walls work
			return 1
		else
			var/area/A = T.loc
			if(A.has_gravity || shoegrip)
				return 1

	for(var/obj/O in orange(1, src))
		if(istype(O, /obj/structure/lattice))
			return 1
		if(O && O.density && O.anchored)
			return 1

	return 0

/mob/proc/Check_Shoegrip()
	return 0

//return 1 if slipped, 0 otherwise
/mob/proc/handle_spaceslipping()
	if(prob(skill_fail_chance(SKILL_EVA, slip_chance(10), SKILL_EXPERT)))
		to_chat(src, "<span class='warning'>You slipped!</span>")
		src.inertia_dir = src.last_move
		step(src, src.inertia_dir)
		return 1
	return 0

/mob/proc/slip_chance(var/prob_slip = 10)
	if(stat)
		return 0
	if(buckled)
		return 0
	if(Check_Shoegrip())
		return 0
	if(MOVING_DELIBERATELY(src))
		prob_slip *= 0.5
	return prob_slip

#define DO_MOVE(this_dir) var/final_dir = turn(this_dir, -dir2angle(dir)); Move(get_step(mob, final_dir), final_dir);

/mob/proc/check_slipmove()
	return

/client/verb/moveup()
	set name = ".moveup"
	set instant = 1
	DO_MOVE(NORTH)

/client/verb/movedown()
	set name = ".movedown"
	set instant = 1
	DO_MOVE(SOUTH)

/client/verb/moveright()
	set name = ".moveright"
	set instant = 1
	DO_MOVE(EAST)

/client/verb/moveleft()
	set name = ".moveleft"
	set instant = 1
	DO_MOVE(WEST)

#undef DO_MOVE


/mob/proc/set_move_intent(var/decl/move_intent/M)
	move_intent = M