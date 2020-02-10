/*
	A nest node acts as an additional spawnpoint for necromorphs, allowing new ones to be created around it rather than at the marker.

	It is very precious and should be well protected
*/
/obj/structure/corruption_node/nest
	name = "Nest"
	desc = "A wretched hive."
	icon_state = "nest"
	icon = 'icons/effects/corruption64.dmi'
	density = TRUE //Chunky
	pixel_x = -16
	pixel_y = -16

	biomass = 30
	biomass_reclamation = 0.3
	reclamation_time = 5 MINUTES

	var/light_colour = "#FFFF00"
	scale = 1.4


/obj/structure/corruption_node/nest/Initialize()
	//Add ourselves as a possible spawnpoint for the marker
	.=..()
	if (!dummy)
		if (SSnecromorph.marker)
			SSnecromorph.marker.add_spawnpoint(src)

		set_light(1, 1, 6, 2, light_colour)



/obj/structure/corruption_node/nest/Destroy()

	if (!dummy)
		if (SSnecromorph.marker)
			SSnecromorph.marker.remove_spawnpoint(src)
	.=..()


/obj/structure/corruption_node/nest/get_blurb()
	. = "The nest node is vital for a forward base, as it provides an additional spawnpoint, allowing the marker to create new necromorphs at its location, thus cutting down travel times. It refunds less of its biomass than other nodes when destroyed though, so protect it well."
