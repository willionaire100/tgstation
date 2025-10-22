# Geeker Field Manual

This document gives a quick orientation to the Geeker role, the hardware you start with, and how to expand into full modular vape production.

## Role Overview

Geekers are R&D specialists embedded in the Science department. Your mandate is to prototype, reverse engineer, and deploy experimental vaporizers for station wide reagent delivery. Expect to spend most of your shift in R&D, chemistry, and the lab spaces adjoining Tech Storage.

Primary goals:

- Unlock the Vaporworks research line and keep Science supplied with new modules.
- Fabricate modular vape chassis and supporting components for field testing.
- Coordinate with Chemistry and Xenobiology to source exotic reagents once hardware is ready.

## Starting Loadout

You spawn in Science with the following key gear:

| Slot | Item | Notes |
| --- | --- | --- |

| L pocket | Calibrated vape chassis | Empty modular frame pre-tuned for the job. |
| Backpack | Vape kit box | Contains spare chassis components for immediate assembly. |
| Belt | Geeker s utility rig | Stock toolbelt renamed on spawn; keep it stocked for R&D work. |

The vape kit box (`/obj/item/storage/box/vape_kit`) ships with:

- 1x modular vape chassis
- 1x nichrome coil cartridge
- 1x starter capacitor bank
- 1x afterburner manifold
- 1x bluespace vortex coil
- 1x bluespace capacitor lattice
- 1x turbofan diffuser
- 1x quantum condensate loop

## Research Roadmap

Two techweb nodes drive the vape program. Both were added under Science research:

1. **Vaporworks** (`TECHWEB_NODE_VAPORWORKS`)
   - Prerequisites: Fundamental Science + Chem Synthesis.
   - Unlocks the chassis, nichrome coil, starter capacitor, afterburner manifold, and turbofan diffuser designs.

2. **Exotic Vaporworks** (`TECHWEB_NODE_VAPORWORKS_EXOTIC`)
   - Prerequisites: Applied Bluespace.
   - Unlocks bluespace coils, bluespace capacitors, and the quantum condensate loop.

Use the R&D console to rush these nodes early. All new designs live in `Misc -> Equipment -> Science` on the protolathe once researched.

## Fabrication Checklist

1. **Run R&D**
   - Complete basic R&D setup, sync with RD server, and research the nodes above.
   - Slot the Vaporworks disk into a local Protolathe if you plan to print outside main R&D.

2. **Print Components**
   - Use the protolathe to fabricate: chassis, coils, capacitors, and any addons you need.
   - Keep extra nichrome coils and starter capacitors available for department use.

3. **Assemble Frames**
   - Load the chassis with components in this order for clarity: coil, capacitor, optional addon.
   - Use a crowbar to remove modules in reverse install order if you need to swap parts.
   - Click the frame in-hand after mandatory slots (coil + capacitor) are filled to finish the build. The frame closes into a modular vape with the installed profile.

4. **Tune Modular Vapes**
   - Screwdriver toggles the maintenance hatch to allow part swapping post-assembly.
   - Component effects:
     - Coils adjust drag time and cloud size.
     - Capacitors change reagent reservoir size and efficiency.
     - Addons grant special behavior (afterburner heat, turbofan spread, quantum endurance).

5. **Load Reagents**
   - Fill the completed vape through chemistry glassware or direct injectors. Capacity is driven by the installed capacitor and quantum addon.

## Sourcing Additional Parts

Beyond the starter kit, all components are fabricated through Science protolathes once the node unlocks. Grab plastic, glass, metals, and bluespace crystals from R&D storage to cover material costs. For plasma requirements (afterburner) coordinate with Engineering or Mining.

## Field Ops Tips

- Pair with Chemistry to prep mixed cartridges; the modular vape handles reagent multiphase clouds well.
- Keep spare parts in Science lockers so other staff can assemble repair kits during emergencies.
- Test new reagent profiles in the gas testing chamber before distributing station wide.

Stay curious, log your prototypes, and share breakthrough builds with the research team. Happy hacking.
