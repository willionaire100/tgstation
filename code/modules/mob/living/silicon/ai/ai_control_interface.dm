/datum/ai_control_link
	/// AI owning this control link.
	var/mob/living/silicon/ai/owner
	/// Currently active control mode.
	var/control_mode = AI_CONTROL_MODE_PLAYER
	/// Map of control mode identifiers to driver instances.
	var/list/datum/ai_control_driver/drivers
	/// Does the link currently allow requests that originate from an automated driver?
	var/allow_driver_output = FALSE

/datum/ai_control_link/New(mob/living/silicon/ai/new_owner)
	. = ..()
	if(isnull(new_owner))
		qdel(src)
		return
	owner = new_owner
	initialize_drivers()
	switch_to_mode(control_mode)

/datum/ai_control_link/Destroy()
	if(drivers)
		for(var/datum/ai_control_driver/driver as anything in drivers)
			if(driver)
				driver.on_detach()
	LAZYCLEARLIST(drivers)
	owner = null
	return ..()

/datum/ai_control_link/proc/initialize_drivers()
	if(drivers)
		return
	drivers = list(
		AI_CONTROL_MODE_PLAYER = new /datum/ai_control_driver/player(src),
		AI_CONTROL_MODE_LLM = new /datum/ai_control_driver/llm(src),
		AI_CONTROL_MODE_FALLBACK = new /datum/ai_control_driver/player(src), // Fallback uses player defaults for now.
	)

/datum/ai_control_link/proc/switch_to_mode(new_mode)
	if(control_mode == new_mode)
		return TRUE
	var/datum/ai_control_driver/next_driver = drivers[new_mode]
	if(!next_driver)
		CRASH("Attempted to switch AI control link to invalid mode '[new_mode]'")
	var/datum/ai_control_driver/current_driver = drivers[control_mode]
	if(current_driver)
		current_driver.on_detach()
	control_mode = new_mode
	next_driver.on_attach()
	return TRUE

/datum/ai_control_link/proc/get_active_driver()
	return drivers[control_mode]

/datum/ai_control_link/proc/get_driver(mode_identifier)
	if(!drivers)
		return null
	return drivers[mode_identifier]

/datum/ai_control_link/proc/get_modes()
	if(!drivers)
		return list()
	var/list/mode_names = list()
	for(var/mode in drivers)
		mode_names += mode
	return mode_names

/datum/ai_control_link/proc/has_mode(mode)
	if(!drivers)
		return FALSE
	return !isnull(drivers[mode])

/datum/ai_control_link/proc/on_ai_initialized()
	if(SSai_llm && owner)
		SSai_llm.ensure_session(owner)
	var/datum/ai_control_driver/driver = get_active_driver()
	if(driver)
		driver.on_ai_initialized()

/datum/ai_control_link/proc/on_ai_destroyed()
	if(SSai_llm && owner)
		SSai_llm.end_session(owner)
	var/datum/ai_control_driver/driver = get_active_driver()
	if(driver)
		driver.on_ai_destroyed()

/datum/ai_control_link/proc/emit_event(event_type, list/payload)
	if(SSai_llm && owner)
		SSai_llm.record_event(owner, event_type, payload)
	var/datum/ai_control_driver/driver = get_active_driver()
	if(!driver)
		return
	driver.handle_event(event_type, payload)

/datum/ai_control_link/proc/request_instruction(instruction_type, list/payload)
	if(!allow_driver_output)
		return
	var/datum/ai_control_driver/driver = get_active_driver()
	if(driver)
		driver.handle_instruction(instruction_type, payload)

/datum/ai_control_link/proc/set_allow_driver_output(state)
	allow_driver_output = state

/datum/ai_control_driver
	/// Owning link.
	var/datum/ai_control_link/link

/datum/ai_control_driver/New(datum/ai_control_link/new_link)
	link = new_link

/datum/ai_control_driver/proc/on_attach()
	return

/datum/ai_control_driver/proc/on_detach()
	return

/datum/ai_control_driver/proc/on_ai_initialized()
	return

/datum/ai_control_driver/proc/on_ai_destroyed()
	return

/datum/ai_control_driver/proc/handle_event(event_type, list/payload)
	return

/datum/ai_control_driver/proc/handle_instruction(instruction_type, list/payload)
	return

/datum/ai_control_driver/player

/datum/ai_control_driver/player/on_attach()
	if(link)
		link.set_allow_driver_output(FALSE)

/datum/ai_control_driver/llm
	/// When TRUE the driver is actively requesting output from downstream systems.
	var/actively_listening = FALSE

/datum/ai_control_driver/llm/on_attach()
	refresh_active_state()

/datum/ai_control_driver/llm/on_detach()
	actively_listening = FALSE
	if(link)
		link.set_allow_driver_output(FALSE)

/datum/ai_control_driver/llm/on_ai_initialized()
	refresh_active_state()

/datum/ai_control_driver/llm/on_ai_destroyed()
	actively_listening = FALSE

/datum/ai_control_driver/llm/proc/refresh_active_state()
	update_active_state()

/datum/ai_control_driver/llm/proc/update_active_state()
	if(!link)
		actively_listening = FALSE
		return
	var/mob/living/silicon/ai/ai = get_ai()
	if(!istype(ai))
		link.set_allow_driver_output(FALSE)
		actively_listening = FALSE
		return
	if(SSai_llm && SSai_llm.is_enabled())
		link.set_allow_driver_output(TRUE)
		actively_listening = TRUE
	else
		link.set_allow_driver_output(FALSE)
		actively_listening = FALSE

/datum/ai_control_driver/llm/proc/get_ai()
	if(!link)
		return null
	var/mob/living/silicon/ai/ai = link.owner
	if(!istype(ai))
		return null
	return ai

/datum/ai_control_driver/llm/handle_instruction(instruction_type, list/payload)
	var/mob/living/silicon/ai/ai = get_ai()
	if(!ai)
		return
	if(!islist(payload))
		if(isnull(payload))
			payload = list()
		else
			payload = list("message" = payload)

	switch(instruction_type)
		if(AI_CONTROL_INSTRUCTION_SAY)
			perform_say(ai, payload)
		if(AI_CONTROL_INSTRUCTION_RADIO)
			if(!payload["channel"])
				payload["channel"] = "common"
			perform_say(ai, payload)
		if(AI_CONTROL_INSTRUCTION_DO)
			handle_action_request(ai, payload)

/datum/ai_control_driver/llm/proc/perform_say(mob/living/silicon/ai/ai, list/payload)
	var/message = sanitize_text(payload["message"], "")
	message = trim(message)
	if(!length(message))
		return

	var/channel_prefix = resolve_channel_prefix(payload["channel"])
	if(channel_prefix && (!length(message) || !(message[1] in list(";", ":", ","))))
		message = "[channel_prefix][message]"

	var/forced_value = payload["forced"]
	var/forced = null
	if(istext(forced_value))
		forced = forced_value
	else if(extract_boolean(forced_value))
		forced = "AI LLM Bridge"

	var/ignore_spam = extract_boolean(payload["ignore_spam"])
	var/filterproof = extract_boolean(payload["filterproof"])

	ai.say(message, ignore_spam = ignore_spam, filterproof = filterproof, forced = forced)

/datum/ai_control_driver/llm/proc/handle_action_request(mob/living/silicon/ai/ai, list/payload)
	// Placeholder for future extended action support.
	if(!payload)
		return
	try
		log_world("AI-LLM: Unsupported action request for [ai]: [json_encode(payload)]")
	catch
		log_world("AI-LLM: Unsupported action request for [ai].")

/datum/ai_control_driver/llm/proc/resolve_channel_prefix(channel)
	if(isnull(channel))
		return null
	if(istext(channel))
		var/trimmed = trim(channel)
		if(!length(trimmed))
			return null
		if(trimmed[1] in list(";", ":"))
			return trimmed
		var/static/list/channel_map = list(
			"common" = ";",
			"general" = ";",
			"ai" = ":o",
			"ai_private" = ":o",
			"command" = ":c",
			"security" = ":s",
			"engineering" = ":e",
			"supply" = ":u",
			"service" = ":v",
			"medical" = ":m",
			"science" = ":n",
			"research" = ":n",
			"holopad" = ":h",
			"binary" = ":b"
		)
		return channel_map[lowertext(trimmed)]
	return null

/datum/ai_control_driver/llm/proc/extract_boolean(value)
	if(isnull(value))
		return FALSE
	if(isnum(value))
		return value != 0
	if(istext(value))
		var/lowered = lowertext(trim(value))
		return lowered in list("1", "true", "yes", "y")
	return !!value
