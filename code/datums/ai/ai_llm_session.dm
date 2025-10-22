/datum/ai_llm_session
	/// AI owning this session.
	var/mob/living/silicon/ai/owner
	/// World.time at creation.
	var/started_at = 0
	/// Generated identifier linking session to the AI reference.
	var/session_id
	/// Rolling log of structured events recorded for the AI.
	var/list/event_log = list()
	/// Cached metadata about the AI's laws at the time the session was created.
	var/list/law_snapshot

/datum/ai_llm_session/New(mob/living/silicon/ai/new_owner)
	. = ..()
	if(isnull(new_owner))
		qdel(src)
		return
	owner = new_owner
	session_id = REF(owner)
	started_at = world.time
	if(owner && owner.laws)
		law_snapshot = owner.laws.get_law_list(TRUE)

/datum/ai_llm_session/Destroy()
	owner = null
	LAZYCLEARLIST(event_log)
	law_snapshot = null
	return ..()

/datum/ai_llm_session/proc/record_event(event_type, list/payload)
	if(isnull(event_type))
		return
	var/store_payload = null
	if(islist(payload))
		store_payload = payload.Copy()
	else
		store_payload = payload
	var/list/entry = list(
		"type" = event_type,
		"timestamp" = world.time,
		"payload" = store_payload,
	)
	event_log += list(entry)
	prune_log()

/datum/ai_llm_session/proc/prune_log()
	var/max_entries = 100
	if(length(event_log) <= max_entries)
		return
	var/shift_amount = length(event_log) - max_entries
	event_log.Cut(1, shift_amount + 1)

/datum/ai_llm_session/proc/refresh_law_snapshot()
	if(owner && owner.laws)
		law_snapshot = owner.laws.get_law_list(TRUE)
