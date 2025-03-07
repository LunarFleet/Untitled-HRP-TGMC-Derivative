//Xenomorph "generic" parent, does not actually appear in game
//Many of these defines aren't referenced in the castes and so are assumed to be defaulted
//Castes are all merely subchildren of this parent
//Just about ALL the procs are tied to the parent, not to the children
//This is so they can be easily transferred between them without copypasta

/mob/living/carbon/xenomorph/Initialize(mapload)
	setup_verbs()
	. = ..()

	set_datum()
	time_of_birth = world.time
	add_inherent_verbs()
	var/datum/action/minimap/xeno/mini = new
	mini.give_action(src)
	add_abilities()

	create_reagents(1000)
	gender = NEUTER

	switch(stat)
		if(CONSCIOUS)
			GLOB.alive_xeno_list += src
			see_in_dark = xeno_caste.conscious_see_in_dark
		if(UNCONSCIOUS)
			GLOB.alive_xeno_list += src
			see_in_dark = xeno_caste.unconscious_see_in_dark
		if(DEAD)
			see_in_dark = xeno_caste.unconscious_see_in_dark

	GLOB.xeno_mob_list += src
	GLOB.round_statistics.total_xenos_created++
	SSblackbox.record_feedback("tally", "round_statistics", 1, "total_xenos_created")

	if(is_centcom_level(z) && hivenumber == XENO_HIVE_NORMAL)
		hivenumber = XENO_HIVE_ADMEME //so admins can safely spawn xenos in Thunderdome for tests.

	wound_overlay = new(null, src)
	vis_contents += wound_overlay

	set_initial_hivenumber()

	generate_nicknumber()

	generate_name()

	regenerate_icons()

	hud_set_plasma()
	med_hud_set_health()

	toggle_xeno_mobhud() //This is a verb, but fuck it, it just werks

	update_spits()

	update_action_button_icons()

	if(!job) //It might be setup on spawn.
		setup_job()

	//AddComponent(/datum/component/bump_attack)

	ADD_TRAIT(src, TRAIT_BATONIMMUNE, TRAIT_XENO)
	ADD_TRAIT(src, TRAIT_FLASHBANGIMMUNE, TRAIT_XENO)
	hive.update_tier_limits()
	if(z) //Larva are initiated in null space
		SSminimaps.add_marker(src, z, hud_flags = MINIMAP_FLAG_XENO, iconstate = xeno_caste.minimap_icon)

/mob/living/carbon/xenomorph/proc/set_datum()
	if(!caste_base_type)
		CRASH("xeno spawned without a caste_base_type set")
	if(!GLOB.xeno_caste_datums[caste_base_type])
		CRASH("error finding base type")
	if(!GLOB.xeno_caste_datums[caste_base_type][upgrade])
		CRASH("error finding datum")
	var/datum/xeno_caste/X = GLOB.xeno_caste_datums[caste_base_type][upgrade]
	if(!istype(X))
		CRASH("error with caste datum")
	xeno_caste = X

	plasma_stored = xeno_caste.plasma_max
	maxHealth = xeno_caste.max_health
	health = maxHealth
	stamina_limit = xeno_caste.max_health
	setXenoCasteSpeed(xeno_caste.speed)
	soft_armor = getArmor(arglist(xeno_caste.soft_armor))
	hard_armor = getArmor(arglist(xeno_caste.hard_armor))
	warding_aura = 0 //Resets aura for reapplying armor

/mob/living/carbon/xenomorph/set_armor_datum()
	return //Handled in set_datum()


/mob/living/carbon/xenomorph/proc/generate_nicknumber()
	//We don't have a nicknumber yet, assign one to stick with us
	if(!nicknumber || nicknumber == "Undefined")
		var/tempnumber = rand(1, 999)
		var/list/xenolist = hive.get_all_xenos(FALSE)
		while(tempnumber in xenolist)
			tempnumber = rand(1, 999)

		nicknumber = tempnumber

//Off-load this proc so it can be called freely
//Since Xenos change names like they change shoes, we need somewhere to hammer in all those legos
//We set their name first, then update their real_name AND their mind name
/mob/living/carbon/xenomorph/proc/generate_name()
	name = "[hive.prefix][xeno_caste.upgrade_name] [xeno_caste.display_name] ([nicknumber])"

	//Update linked data so they show up properly
	real_name = name
	if(mind)
		mind.name = name

/mob/living/carbon/xenomorph/proc/tier_as_number()
	switch(tier)
		if(XENO_TIER_ZERO)
			return 0
		if(XENO_TIER_ONE)
			return 1
		if(XENO_TIER_TWO)
			return 2
		if(XENO_TIER_THREE)
			return 3

/mob/living/carbon/xenomorph/proc/upgrade_as_number()
	switch(upgrade)
		if(XENO_UPGRADE_INVALID)
			return -1
		if(XENO_UPGRADE_ZERO)
			return 0
		if(XENO_UPGRADE_ONE)
			return 1
		if(XENO_UPGRADE_TWO)
			return 2
		if(XENO_UPGRADE_THREE)
			return 3

/mob/living/carbon/xenomorph/proc/upgrade_next()
	switch(upgrade)
		if(XENO_UPGRADE_INVALID)
			return XENO_UPGRADE_INVALID
		if(XENO_UPGRADE_ZERO)
			return XENO_UPGRADE_ONE
		if(XENO_UPGRADE_ONE)
			return XENO_UPGRADE_TWO
		if(XENO_UPGRADE_TWO)
			return XENO_UPGRADE_THREE
		if(XENO_UPGRADE_THREE)
			return XENO_UPGRADE_THREE

/mob/living/carbon/xenomorph/proc/upgrade_prev()
	switch(upgrade)
		if(XENO_UPGRADE_INVALID)
			return XENO_UPGRADE_INVALID
		if(XENO_UPGRADE_ZERO)
			return XENO_UPGRADE_ZERO
		if(XENO_UPGRADE_ONE)
			return XENO_UPGRADE_ZERO
		if(XENO_UPGRADE_TWO)
			return XENO_UPGRADE_ONE
		if(XENO_UPGRADE_THREE)
			return XENO_UPGRADE_TWO

/mob/living/carbon/xenomorph/proc/setup_job()
	var/datum/job/xenomorph/xeno_job = SSjob.type_occupations[xeno_caste.job_type]
	if(!xeno_job)
		CRASH("Unemployment has reached to a xeno, who has failed to become a [xeno_caste.job_type]")
	apply_assigned_role_to_spawn(xeno_job)


/mob/living/carbon/xenomorph/examine(mob/user)
	..()
	if(isxeno(user) && xeno_caste.caste_desc)
		to_chat(user, xeno_caste.caste_desc)

	if(stat == DEAD)
		to_chat(user, "It is DEAD. Kicked the bucket. Off to that great hive in the sky.")
	else if(stat == UNCONSCIOUS)
		to_chat(user, "It quivers a bit, but barely moves.")
	else
		var/percent = (health / maxHealth * 100)
		switch(percent)
			if(95 to 101)
				to_chat(user, "It looks quite healthy.")
			if(75 to 94)
				to_chat(user, "It looks slightly injured.")
			if(50 to 74)
				to_chat(user, "It looks injured.")
			if(25 to 49)
				to_chat(user, "It bleeds with sizzling wounds.")
			if(1 to 24)
				to_chat(user, "It is heavily injured and limping badly.")

	if(hivenumber != XENO_HIVE_NORMAL)
		var/datum/hive_status/hive = GLOB.hive_datums[hivenumber]
		to_chat(user, "It appears to belong to the [hive.prefix]hive")

	to_chat(user, "<span class='info'>[xeno_desc]</span>")

/mob/living/carbon/xenomorph/Destroy()
	if(mind) mind.name = name //Grabs the name when the xeno is getting deleted, to reference through hive status later.
	if(is_zoomed) zoom_out()

	GLOB.alive_xeno_list -= src
	GLOB.xeno_mob_list -= src
	GLOB.dead_xeno_list -= src

	var/datum/hive_status/hive_placeholder = hive
	remove_from_hive()
	hive_placeholder.update_tier_limits() //Update our tier limits.

	vis_contents -= wound_overlay
	QDEL_NULL(wound_overlay)
	return ..()


/mob/living/carbon/xenomorph/slip(slip_source_name, stun_level, weaken_level, run_only, override_noslip, slide_steps)
	return FALSE

/mob/living/carbon/xenomorph/start_pulling(atom/movable/AM, suppress_message = TRUE, bypass_crit_delay = FALSE)
	if(!isliving(AM))
		return FALSE
	if(!Adjacent(AM)) //Logic!
		return FALSE
	if(status_flags & INCORPOREAL || AM.status_flags & INCORPOREAL) //Incorporeal things can't grab or be grabbed.
		return FALSE
	var/mob/living/L = AM
	if(L.buckled)
		return FALSE //to stop xeno from pulling marines on roller beds.
	if(ishuman(L))
		if(L.stat == DEAD && (SSticker.mode?.flags_round_type & MODE_DEAD_GRAB_FORBIDDEN)) //Can't drag dead human bodies in distress
			to_chat(usr,"<span class='xenowarning'>This looks gross, better not touch it</span>")
			return FALSE
		do_attack_animation(L, ATTACK_EFFECT_GRAB)
		pull_speed += XENO_DEADHUMAN_DRAG_SLOWDOWN
	SEND_SIGNAL(src, COMSIG_XENOMORPH_GRAB)
	return ..()

/mob/living/carbon/xenomorph/stop_pulling()
	if(ishuman(pulling))
		pull_speed -= XENO_DEADHUMAN_DRAG_SLOWDOWN
	return ..()

/mob/living/carbon/xenomorph/pull_response(mob/puller)
	return TRUE
	/*if(stat != CONSCIOUS) // If the Xeno is unconscious, don't fight back against a grab/pull
		return TRUE
	if(!ishuman(puller))
		return TRUE
	var/mob/living/carbon/human/H = puller
	H.Paralyze(rand(xeno_caste.tacklemin,xeno_caste.tacklemax) * 20)
	playsound(H.loc, 'sound/weapons/pierce.ogg', 25, 1)
	H.visible_message("<span class='warning'>[H] tried to pull [src] but instead gets a tail swipe to the head!</span>")
	H.stop_pulling()
	return FALSE*/

/mob/living/carbon/xenomorph/resist_grab()
	if(pulledby.grab_state)
		visible_message("<span class='danger'>[src] has broken free of [pulledby]'s grip!</span>", null, null, 5)
	pulledby.stop_pulling()
	. = 1



/mob/living/carbon/xenomorph/prepare_huds()
	..()
	//updating all the mob's hud images
	med_hud_set_health()
	hud_set_plasma()
	hud_set_pheromone()
	//and display them
	add_to_all_mob_huds()

	var/datum/atom_hud/hud_to_add = GLOB.huds[DATA_HUD_XENO_INFECTION]
	hud_to_add.add_hud_to(src)

	hud_to_add = GLOB.huds[DATA_HUD_BASIC]
	hud_to_add.add_hud_to(src)

	hud_to_add = GLOB.huds[DATA_HUD_XENO_REAGENTS]
	hud_to_add.add_hud_to(src)
	hud_to_add = GLOB.huds[DATA_HUD_XENO_TACTICAL] //Allows us to see xeno tactical elements clearly via HUD elements
	hud_to_add.add_hud_to(src)


/mob/living/carbon/xenomorph/point_to_atom(atom/A, turf/T)
	//xeno leader get a bit arrow and less cooldown
	if(queen_chosen_lead || isxenoqueen(src))
		TIMER_COOLDOWN_START(src, COOLDOWN_POINT, 1 SECONDS)
		new /obj/effect/overlay/temp/point/big(T)
	else
		TIMER_COOLDOWN_START(src, COOLDOWN_POINT, 5 SECONDS)
		new /obj/effect/overlay/temp/point(T)
	visible_message("<b>[src]</b> points to [A]")
	return 1

/mob/living/carbon/xenomorph/get_permeability_protection()
	return XENO_PERM_COEFF

/mob/living/carbon/xenomorph/get_eye_protection()
	return 2

/mob/living/carbon/xenomorph/need_breathe()
	return FALSE

/mob/living/carbon/xenomorph/vomit()
	return

/mob/living/carbon/xenomorph/reagent_check(datum/reagent/R) //For the time being they can't metabolize chemicals.
	return TRUE

/mob/living/carbon/xenomorph/update_tracking(mob/living/carbon/xenomorph/X) //X is unused, but we keep that function so it can be called with marines one
	if(!hud_used?.locate_leader)
		return
	var/obj/screen/LL_dir = hud_used.locate_leader
	if(!tracked)
		if(hive.living_xeno_ruler)
			tracked = hive.living_xeno_ruler
		else
			LL_dir.icon_state = "trackoff"
			return

	if(isxeno(tracked))
		var/mob/living/carbon/xenomorph/xeno_tracked = tracked
		if(QDELETED(xeno_tracked))
			tracked = null
			return
		if(xeno_tracked == src) // No need to track ourselves
			LL_dir.icon_state = "trackoff"
			return
		if(xeno_tracked.z != z || get_dist(src, xeno_tracked) < 1)
			LL_dir.icon_state = "trackondirect"
			return
		var/area/A = get_area(loc)
		var/area/QA = get_area(xeno_tracked.loc)
		if(A.fake_zlevel == QA.fake_zlevel)
			LL_dir.icon_state = "trackon"
			LL_dir.setDir(get_dir(src, xeno_tracked))
			return

		LL_dir.icon_state = "trackondirect"
		return

	if(isresinsilo(tracked))
		var/mob/living/carbon/xenomorph/silo_tracked = tracked
		if(QDELETED(silo_tracked))
			tracked = null
			return
		if(silo_tracked.z != z || get_dist(src, silo_tracked) < 1)
			LL_dir.icon_state = "trackondirect"
			return

		var/area/A = get_area(loc)
		var/area/QA = get_area(silo_tracked.loc)
		if(A.fake_zlevel == QA.fake_zlevel)
			LL_dir.icon_state = "trackon"
			LL_dir.setDir(get_dir(src, silo_tracked))
			return
		LL_dir.icon_state = "trackondirect"
		return

	if(istype(tracked, /obj/machinery/nuclearbomb))
		var/obj/machinery/nuclearbomb/nuke_tracked = tracked
		if(QDELETED(nuke_tracked))
			tracked = null
			return
		if(!nuke_tracked.timer_enabled)
			LL_dir.icon_state = "trackoff"
			return
		if(nuke_tracked.z != z || get_dist(src, nuke_tracked) < 1)
			LL_dir.icon_state = "trackondirect"
			return
		var/area/A = get_area(loc)
		var/area/QA = get_area(nuke_tracked.loc)
		if(A.fake_zlevel == QA.fake_zlevel)
			LL_dir.icon_state = "trackon"
			LL_dir.setDir(get_dir(src, nuke_tracked))
			return

		LL_dir.icon_state = "trackondirect"
		return


/mob/living/carbon/xenomorph/clear_leader_tracking()
	if(!hud_used?.locate_leader)
		return

	var/obj/screen/LL_dir = hud_used.locate_leader
	LL_dir.icon_state = "trackoff"


/mob/living/carbon/xenomorph/Moved(atom/newloc, direct)
	if(is_zoomed)
		zoom_out()
	return ..()

/mob/living/carbon/xenomorph/ghostize(can_reenter_corpse)
	. = ..()
	if(!. || can_reenter_corpse)
		return
	set_afk_status(MOB_RECENTLY_DISCONNECTED, 5 SECONDS)

/mob/living/carbon/xenomorph/set_stat(new_stat)
	. = ..()
	if(isnull(.))
		return
	switch(stat)
		if(UNCONSCIOUS)
			see_in_dark = xeno_caste.unconscious_see_in_dark
		if(DEAD, CONSCIOUS)
			if(. == UNCONSCIOUS)
				see_in_dark = xeno_caste.conscious_see_in_dark
