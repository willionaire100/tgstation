/datum/job/geeker
	title = JOB_GEEKER
	description = "Prototype, tune, and catalog the station's burgeoning vape technology."
	department_head = list(JOB_RESEARCH_DIRECTOR)
	faction = FACTION_STATION
	total_positions = 2
	spawn_positions = 1
	supervisors = SUPERVISOR_RD
	exp_requirements = 60
	exp_required_type = EXP_TYPE_CREW
	exp_granted_type = EXP_TYPE_CREW
	config_tag = "GEEKER"

	outfit = /datum/outfit/job/geeker
	plasmaman_outfit = /datum/outfit/plasmaman/science
	departments_list = list(
		/datum/job_department/science,
		)

	paycheck = PAYCHECK_CREW
	paycheck_department = ACCOUNT_SCI

	display_order = JOB_DISPLAY_ORDER_GEEKER
	bounty_types = CIV_JOB_SCI

	alternate_titles = list(
		"Vapor Technician",
		"Cloud Artisan",
	)

	mail_goodies = list(
		/obj/item/storage/box/vape_kit = 12,
		/obj/item/vape_component/capacitor/bluespace = 4,
		/obj/item/vape_component/addon/turbofan = 6,
	)

	family_heirlooms = list(
		/obj/item/clothing/accessory/pocketprotector/full,
	)

	rpg_title = "Cloudwright"
	job_flags = STATION_JOB_FLAGS
	job_tone = "huff"

/datum/job/geeker/get_default_roundstart_spawn_point()
	var/obj/effect/landmark/start/selected
	for(var/obj/effect/landmark/start/spawn_point as anything in GLOB.start_landmarks_list)
		if(spawn_point.name != title)
			continue
		selected = spawn_point
		if(spawn_point.used)
			continue
		spawn_point.used = TRUE
		return spawn_point
	if(selected)
		return selected

	for(var/obj/effect/landmark/start/science_spawn as anything in GLOB.start_landmarks_list)
		if(science_spawn.name != JOB_SCIENTIST)
			continue
		selected = science_spawn
		if(science_spawn.used)
			continue
		science_spawn.used = TRUE
		var/static/notified = FALSE
		if(!notified)
			notified = TRUE
			log_mapping("Job [title] ([type]) is sharing Scientist's start landmark; dedicated spawn not found.")
		return science_spawn
	return selected

/datum/outfit/job/geeker
	name = "Geeker"
	jobtype = /datum/job/geeker

	id_trim = /datum/id_trim/job/geeker
	uniform = /obj/item/clothing/under/rank/rnd/scientist
	suit = /obj/item/clothing/suit/toggle/labcoat/science
	belt = /obj/item/storage/belt/utility/full
	ears = /obj/item/radio/headset/headset_sci
	shoes = /obj/item/clothing/shoes/sneakers/black
	neck = /obj/item/clothing/accessory/pocketprotector
	head = /obj/item/clothing/head/soft/purple
	l_pocket = /obj/item/vape/frame
	r_pocket = /obj/item/multitool

	backpack = /obj/item/storage/backpack/science
	satchel = /obj/item/storage/backpack/satchel/science
	duffelbag = /obj/item/storage/backpack/duffelbag/science
	messenger = /obj/item/storage/backpack/messenger/science

	backpack_contents = list(
		/obj/item/storage/box/vape_kit = 1,
		/obj/item/screwdriver = 1,
	)

/datum/outfit/job/geeker/post_equip(mob/living/carbon/human/equipped, visuals_only)
	. = ..()
	if(visuals_only)
		return
	var/obj/item/vape/frame/frame = equipped.get_item_by_slot(ITEM_SLOT_LPOCKET)
	if(frame)
		frame.name = "calibrated vape chassis"
	var/obj/item/storage/belt/utility/toolbelt = equipped.get_item_by_slot(ITEM_SLOT_BELT)
	if(toolbelt)
		toolbelt.name = "geeker's utility rig"
