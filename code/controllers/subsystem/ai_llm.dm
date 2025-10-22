SUBSYSTEM_DEF(ai_llm)
	name = "AI LLM Bridge"
	flags = SS_NO_FIRE
	runlevels = RUNLEVEL_LOBBY | RUNLEVELS_DEFAULT

	/// Active AI LLM sessions keyed by AI reference string.
	var/list/datum/ai_llm_session/sessions
	/// Whether the bridge is enabled via configuration.
	var/enabled = FALSE
	/// Base URL for the bridge service.
	var/base_url = ""
	/// Optional API key for bridge authentication.
	var/api_key = ""
	/// Timeout (in seconds) for outbound HTTP requests.
	var/request_timeout = 5

/datum/controller/subsystem/ai_llm/Initialize()
	. = ..()
	if(. == SS_INIT_SUCCESS)
		sessions = list()
	return .

/datum/controller/subsystem/ai_llm/OnConfigLoad()
	enabled = !!CONFIG_GET(flag/ai_llm_bridge_enabled)
	base_url = trim(CONFIG_GET(string/ai_llm_bridge_base_url))
	if(length(base_url) && base_url[length(base_url)] == "/")
		base_url = copytext(base_url, 1, length(base_url))
	api_key = CONFIG_GET(string/ai_llm_bridge_api_key)
	request_timeout = CONFIG_GET(number/ai_llm_bridge_timeout)
	if(!isnum(request_timeout) || request_timeout <= 0)
		request_timeout = 5

	if(GLOB.ai_list && length(GLOB.ai_list))
		for(var/mob/living/silicon/ai/ai as anything in GLOB.ai_list)
			var/datum/ai_control_link/link = ai.control_link
			if(!link)
				continue
			var/datum/ai_control_driver/llm/driver = link.get_driver(AI_CONTROL_MODE_LLM)
			if(istype(driver))
				driver.refresh_active_state()

/datum/controller/subsystem/ai_llm/Recover()
	. = ..()
	if(!isnull(SSai_llm))
		sessions = SSai_llm.sessions

/datum/controller/subsystem/ai_llm/Shutdown()
	. = ..()
	terminate_all_sessions()

/datum/controller/subsystem/ai_llm/proc/terminate_all_sessions()
	if(!sessions)
		return
	for(var/session_key in sessions)
		var/datum/ai_llm_session/session = sessions[session_key]
		QDEL_NULL(session)
	LAZYCLEARLIST(sessions)

/datum/controller/subsystem/ai_llm/proc/get_session(mob/living/silicon/ai/ai)
	if(!ai || !sessions)
		return null
	return sessions[REF(ai)]

/datum/controller/subsystem/ai_llm/proc/ensure_session(mob/living/silicon/ai/ai)
	if(!ai)
		return null
	var/session_key = REF(ai)
	if(!sessions)
		sessions = list()
	var/datum/ai_llm_session/session = sessions[session_key]
	if(isnull(session))
		session = new(ai)
		sessions[session_key] = session
	return session

/datum/controller/subsystem/ai_llm/proc/end_session(mob/living/silicon/ai/ai)
	if(!ai || !sessions)
		return
	var/session_key = REF(ai)
	var/datum/ai_llm_session/session = sessions[session_key]
	if(!session)
		return
	QDEL_NULL(session)
	sessions -= session_key

/datum/controller/subsystem/ai_llm/proc/record_event(mob/living/silicon/ai/ai, event_type, list/payload)
	var/datum/ai_llm_session/session = ensure_session(ai)
	if(session)
		session.record_event(event_type, payload)
	if(!should_forward_to_bridge(ai))
		return
	var/portable_payload = clone_for_transport(payload)
	INVOKE_ASYNC(src, PROC_REF(send_event_to_bridge), session, event_type, portable_payload)

/datum/controller/subsystem/ai_llm/proc/is_enabled()
	return enabled && length(base_url)

/datum/controller/subsystem/ai_llm/proc/should_forward_to_bridge(mob/living/silicon/ai/ai)
	if(!is_enabled())
		return FALSE
	if(!istype(ai))
		return FALSE
	if(ai.get_control_mode() != AI_CONTROL_MODE_LLM)
		return FALSE
	var/datum/ai_control_link/link = ai.control_link
	if(!link)
		return FALSE
	var/datum/ai_control_driver/llm/driver = link.get_active_driver()
	if(!istype(driver))
		return FALSE
	return driver.actively_listening

/datum/controller/subsystem/ai_llm/proc/clone_for_transport(value)
	if(isnull(value))
		return null
	if(islist(value))
		try
			return json_decode(json_encode(value))
		catch
			log_world("AI-LLM: Failed to serialise payload for transport.")
			return null
	return value

/datum/controller/subsystem/ai_llm/proc/send_event_to_bridge(datum/ai_llm_session/session, event_type, payload)
	if(!is_enabled())
		return
	if(QDELETED(session))
		return
	var/mob/living/silicon/ai/ai = session.owner
	if(!istype(ai))
		return

	var/list/event_payload = list(
		"type" = event_type,
		"timestamp" = world.time,
		"payload" = clone_for_transport(payload),
	)

	var/list/body = list(
		"session_id" = session.session_id,
		"ai_ref" = REF(ai),
		"event" = event_payload,
		"laws" = clone_for_transport(session.law_snapshot),
		"metadata" = list(
			"name" = ai.name,
			"real_name" = ai.real_name,
			"job" = ai.job,
			"control_mode" = ai.get_control_mode(),
		),
	)

	var/json_body
	try
		json_body = json_encode(body)
	catch
		log_world("AI-LLM: Failed to encode bridge payload for [ai].")
		return

	var/list/headers = list(
		"Content-Type" = "application/json",
	)
	var/auth_header = build_auth_header()
	if(length(auth_header))
		headers["Authorization"] = auth_header

	var/url = "[base_url]/sessions/[url_encode(session.session_id)]/events"
	var/datum/http_request/request = new()
	request.prepare(RUSTG_HTTP_METHOD_POST, url, json_body, headers, null, request_timeout)
	request.execute_blocking()

	var/datum/http_response/response = request.into_response()
	if(response.errored)
		log_world("AI-LLM: HTTP error while forwarding event for [ai]: [response.error]")
		return
	if(!response.status_code || response.status_code < 200 || response.status_code >= 300)
		log_world("AI-LLM: Bridge returned status [response.status_code] for [ai].")
		return
	if(!length(response.body))
		return

	var/list/data
	try
		data = json_decode(response.body)
	catch
		log_world("AI-LLM: Failed to decode response body for [ai].")
		return
	if(!islist(data))
		return

	process_bridge_response(ai, data)

/datum/controller/subsystem/ai_llm/proc/build_auth_header()
	if(!length(api_key))
		return ""
	var/static/regex/bearer_prefix = regex("^Bearer ", "i")
	if(bearer_prefix.Find(api_key))
		return api_key
	return "Bearer [api_key]"

/datum/controller/subsystem/ai_llm/proc/process_bridge_response(mob/living/silicon/ai/ai, list/data)
	if(!istype(ai))
		return
	var/list/actions = data["actions"]
	if(!islist(actions) || !length(actions))
		return
	dispatch_instructions(ai, actions)

/datum/controller/subsystem/ai_llm/proc/dispatch_instructions(mob/living/silicon/ai/ai, list/actions)
	if(!istype(ai))
		return
	var/datum/ai_control_link/link = ai.control_link
	if(!link)
		return
	for(var/entry in actions)
		if(!islist(entry))
			continue
		var/list/action = entry
		var/action_type = action["type"]
		if(!istext(action_type))
			continue
		var/list/payload = action["payload"]
		if(!islist(payload))
			if(isnull(payload))
				payload = list()
			else
				payload = list("message" = payload)
		var/instruction
		switch(lowertext(action_type))
			if("say")
				instruction = AI_CONTROL_INSTRUCTION_SAY
			if("radio")
				instruction = AI_CONTROL_INSTRUCTION_RADIO
			if("do")
				instruction = AI_CONTROL_INSTRUCTION_DO
		if(!instruction)
			continue
		link.request_instruction(instruction, payload)
