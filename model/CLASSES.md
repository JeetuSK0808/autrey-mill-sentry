# Classes: what the scanner knows and why

Generated 2026-10-12 from `tools/fetch_inat.py survey` (counts are iNaturalist research-grade observations with CC0/CC-BY/CC-BY-NC photos; GA = Georgia place 23, SE = AL, SC, NC, TN, FL).
Invasive status was checked against the Georgia Invasive Species Council plant list (formerly GA-EPPC), https://gainvasivespeciescouncil.org/list/invasive-plants/ (fetched 2026-10-12, saved in `data/raw/gisc_invasive_plants.html`).

## Tier 1: tuned (14). Can be `.confirmedInvasive`

Twelve of the 14 species the preserve itself listed in its 2012 volunteer post (Patch, 25 Sep 2012, byline Autrey Mill Nature Preserve and Heritage Center) that are also on the GISC list, plus the three most widespread north Georgia forest invasives (Japanese stiltgrass, kudzu, nandina). The two preserve-listed species left out: **crabapple (Malus sp.)** is not on the GISC list and could be the native southern crabapple, and **mondo grass (Ophiopogon japonicus)** is not on the GISC list. Neither is treated as invasive by the app.

| Label | Species | Preserve-listed | GA | SE |
|---|---|---|---|---|
| ligustrum_sinense | Ligustrum sinense | yes | 2643 | 8910 |
| mahonia_bealei | Mahonia bealei | yes | 2103 | 4590 |
| lonicera_japonica | Lonicera japonica | yes | 2159 | 9183 |
| wisteria_sinensis | Wisteria sinensis | yes | 332 | 573 |
| vinca_minor | Vinca minor | yes | 344 | 2695 |
| elaeagnus_umbellata | Elaeagnus umbellata | yes | 532 | 2326 |
| elaeagnus_pungens | Elaeagnus pungens | yes | 1111 | 1847 |
| rosa_multiflora | Rosa multiflora | yes | 698 | 5501 |
| hedera_helix | Hedera helix | yes | 1397 | 3963 |
| albizia_julibrissin | Albizia julibrissin | yes | 1729 | 6955 |
| paulownia_tomentosa | Paulownia tomentosa | yes | 744 | 2464 |
| microstegium_vimineum | Microstegium vimineum | no | 1004 | 4893 |
| pueraria_montana | Pueraria montana | no | 1531 | 5225 |
| nandina_domestica | Nandina domestica | no | 1887 | 5723 |

Bull thistle (*Cirsium vulgare*) is preserve-listed and on the GISC list but is trained as Tier 2 for now: it is a sun-loving biennial of disturbed ground rather than a forest invader, and nothing in the first field test should hinge on it. Promote it after field testing if staff want it.

## Native look-alikes (14). Never reported

| Label | Species | Confused with | GA | SE |
|---|---|---|---|---|
| lonicera_sempervirens | Lonicera sempervirens | Japanese honeysuckle | 470 | 2672 |
| wisteria_frutescens | Wisteria frutescens | Chinese wisteria | 76 | 172 |
| viburnum_acerifolium | Viburnum acerifolium | Chinese privet | 437 | 2339 |
| viburnum_dentatum | Viburnum dentatum | Chinese privet | 20 | 77 |
| ilex_opaca | Ilex opaca | leatherleaf mahonia | 2083 | 10204 |
| toxicodendron_radicans | Toxicodendron radicans | English ivy (and safety) | 2370 | 10667 |
| parthenocissus_quinquefolia | Parthenocissus quinquefolia | English ivy | 2964 | 10992 |
| vitis_rotundifolia | Vitis rotundifolia | kudzu | 3152 | 6443 |
| rosa_carolina | Rosa carolina | multiflora rose | 65 | 683 |
| rubus_argutus | Rubus argutus | multiflora rose | 12 | 17 |
| mitchella_repens | Mitchella repens | periwinkle | 1177 | 8177 |
| catalpa_bignonioides | Catalpa bignonioides | princess tree | 52 | 156 |
| chasmanthium_latifolium | Chasmanthium latifolium | stiltgrass | 710 | 2667 |
| smilax_rotundifolia | Smilax rotundifolia | honeysuckle tangles | 472 | 2356 |

Thin natives (Rubus argutus, Viburnum dentatum, Catalpa, Rosa carolina, Wisteria frutescens) fall back to US-wide photos during download.

## Tier 2: broad coverage. Always `.possibleInvasive` (needs expert review)

Every other GISC plant-list species with at least 80 licensed GA+SE photos: 84 species included.

| Label | Species | GA | SE | Included |
|---|---|---|---|---|
| achyranthes_japonica | Achyranthes japonica | 452 | 104 | yes |
| ailanthus_altissima | Ailanthus altissima | 346 | 2905 | yes |
| ajuga_reptans | Ajuga reptans | 250 | 1552 | yes |
| akebia_quinata | Akebia quinata | 64 | 96 | yes |
| alliaria_petiolata | Alliaria petiolata | 26 | 1448 | yes |
| allium_vineale | Allium vineale | 376 | 1483 | yes |
| alternanthera_philoxeroides | Alternanthera philoxeroides | 230 | 733 | yes |
| alternanthera_sessilis | Alternanthera sessilis | 2 | 6 | no (<80) |
| alysicarpus_vaginalis | Alysicarpus vaginalis | 0 | 5 | no (<80) |
| ampelopsis_glandulosa | Ampelopsis glandulosa | 526 | 1451 | yes |
| anthoxanthum_odoratum | Anthoxanthum odoratum | 38 | 390 | yes |
| ardisia_crenata | Ardisia crenata | 150 | 155 | yes |
| artemisia_vulgaris | Artemisia vulgaris | 59 | 597 | yes |
| arthraxon_hispidus | Arthraxon hispidus | 13 | 169 | yes |
| arundo_donax | Arundo donax | 16 | 131 | yes |
| berberis_thunbergii | Berberis thunbergii | 57 | 827 | yes |
| bidens_pilosa | Bidens pilosa | 1 | 0 | no (<80) |
| bromus_secalinus | Bromus secalinus | 0 | 2 | no (<80) |
| bromus_tectorum | Bromus tectorum | 3 | 26 | no (<80) |
| broussonetia_papyrifera | Broussonetia papyrifera | 164 | 943 | yes |
| buddleja_davidii | Buddleja davidii | 244 | 879 | yes |
| carduus_nutans | Carduus nutans | 467 | 1305 | yes |
| celastrus_orbiculatus | Celastrus orbiculatus | 97 | 1135 | yes |
| centaurea_cyanus | Centaurea cyanus | 144 | 800 | yes |
| cinnamomum_camphora | Cinnamomum camphora | 0 | 0 | no (<80) |
| cirsium_vulgare | Cirsium vulgare | 130 | 811 | yes |
| citrus_trifoliata | Citrus trifoliata | 381 | 1214 | yes |
| clematis_terniflora | Clematis terniflora | 518 | 1394 | yes |
| colocasia_esculenta | Colocasia esculenta | 248 | 547 | yes |
| commelina_benghalensis | Commelina benghalensis | 15 | 9 | no (<80) |
| crotalaria_lanceolata | Crotalaria lanceolata | 16 | 31 | no (<80) |
| crotalaria_pallida | Crotalaria pallida | 3 | 30 | no (<80) |
| crotalaria_spectabilis | Crotalaria spectabilis | 210 | 412 | yes |
| cytisus_scoparius | Cytisus scoparius | 8 | 35 | no (<80) |
| daucus_carota | Daucus carota | 422 | 3379 | yes |
| dioscorea_alata | Dioscorea alata | 1 | 0 | no (<80) |
| dioscorea_bulbifera | Dioscorea bulbifera | 9 | 42 | no (<80) |
| dioscorea_polystachya | Dioscorea polystachya | 365 | 1022 | yes |
| dryopteris_erythrosora | Dryopteris erythrosora | 920 | 911 | yes |
| eichhornia_crassipes | Eichhornia crassipes | 304 | 502 | yes |
| euonymus_alatus | Euonymus alatus | 129 | 1151 | yes |
| euonymus_fortunei | Euonymus fortunei | 272 | 1974 | yes |
| fatoua_villosa | Fatoua villosa | 300 | 635 | yes |
| firmiana_simplex | Firmiana simplex | 89 | 374 | yes |
| hemerocallis_fulva | Hemerocallis fulva | 173 | 735 | yes |
| hibiscus_syriacus | Hibiscus syriacus | 588 | 1700 | yes |
| ilex_cornuta | Ilex cornuta | 1233 | 2447 | yes |
| ilex_crenata | Ilex crenata | 41 | 71 | yes |
| imperata_cylindrica | Imperata cylindrica | 7 | 189 | yes |
| indigofera_hirsuta | Indigofera hirsuta | 28 | 20 | no (<80) |
| ipomoea_coccinea | Ipomoea coccinea | 363 | 984 | yes |
| ipomoea_purpurea | Ipomoea purpurea | 277 | 1401 | yes |
| jacquemontia_tamnifolia | Jacquemontia tamnifolia | 536 | 884 | yes |
| kummerowia_stipulacea | Kummerowia stipulacea | 6 | 82 | yes |
| kummerowia_striata | Kummerowia striata | 217 | 909 | yes |
| lantana_camara | Lantana camara | 17 | 14 | no (<80) |
| lespedeza_bicolor | Lespedeza bicolor | 156 | 1144 | yes |
| lespedeza_cuneata | Lespedeza cuneata | 979 | 4966 | yes |
| lespedeza_thunbergii | Lespedeza thunbergii | 0 | 3 | no (<80) |
| leucanthemum_vulgare | Leucanthemum vulgare | 518 | 2365 | yes |
| ligustrum_japonicum | Ligustrum japonicum | 39 | 128 | yes |
| ligustrum_lucidum | Ligustrum lucidum | 320 | 1677 | yes |
| liriope_muscari | Liriope muscari | 230 | 306 | yes |
| liriope_spicata | Liriope spicata | 22 | 58 | yes |
| lonicera_fragrantissima | Lonicera fragrantissima | 87 | 875 | yes |
| lonicera_maackii | Lonicera maackii | 861 | 4226 | yes |
| lygodium_japonicum | Lygodium japonicum | 680 | 1594 | yes |
| lygodium_microphyllum | Lygodium microphyllum | 0 | 2 | no (<80) |
| melia_azedarach | Melia azedarach | 611 | 1313 | yes |
| melinis_repens | Melinis repens | 0 | 6 | no (<80) |
| mentha_piperita | Mentha x piperita | 2 | 9 | no (<80) |
| miscanthus_sinensis | Miscanthus sinensis | 42 | 277 | yes |
| morus_alba | Morus alba | 188 | 347 | yes |
| mosla_dianthera | Mosla dianthera | 0 | 2 | no (<80) |
| murdannia_keisak | Murdannia keisak | 204 | 536 | yes |
| myriophyllum_aquaticum | Myriophyllum aquaticum | 388 | 1108 | yes |
| nasturtium_officinale | Nasturtium officinale | 9 | 121 | yes |
| orobanche_minor | Orobanche minor | 0 | 8 | no (<80) |
| paederia_foetida | Paederia foetida | 4 | 9 | no (<80) |
| panicum_repens | Panicum repens | 3 | 38 | no (<80) |
| paspalum_quadrifarium | Paspalum quadrifarium | 1 | 0 | no (<80) |
| paspalum_urvillei | Paspalum urvillei | 74 | 273 | yes |
| perilla_frutescens | Perilla frutescens | 805 | 2367 | yes |
| persicaria_longiseta | Persicaria longiseta | 959 | 4866 | yes |
| persicaria_maculosa | Persicaria maculosa | 3 | 66 | no (<80) |
| phragmites_australis | Phragmites australis | 4 | 336 | yes |
| phyllostachys_aurea | Phyllostachys aurea | 33 | 135 | yes |
| pyracantha_coccinea | Pyracantha coccinea | 14 | 27 | no (<80) |
| pyrus_calleryana | Pyrus calleryana | 760 | 1665 | yes |
| quercus_acutissima | Quercus acutissima | 74 | 161 | yes |
| reynoutria_japonica | Reynoutria japonica | 126 | 548 | yes |
| reynoutria_sachalinensis | Reynoutria sachalinensis | 1 | 3 | no (<80) |
| rosa_laevigata | Rosa laevigata | 119 | 140 | yes |
| rottboellia_cochinchinensis | Rottboellia cochinchinensis | 2 | 11 | no (<80) |
| rubus_armeniacus | Rubus armeniacus | 70 | 122 | yes |
| rubus_phoenicolasius | Rubus phoenicolasius | 56 | 1269 | yes |
| schinus_terebinthifolia | Schinus terebinthifolia | 0 | 3 | no (<80) |
| securigera_varia | Securigera varia | 54 | 1388 | yes |
| sesbania_punicea | Sesbania punicea | 188 | 621 | yes |
| setaria_faberi | Setaria faberi | 5 | 72 | no (<80) |
| setaria_pumila | Setaria pumila | 57 | 180 | yes |
| setaria_viridis | Setaria viridis | 17 | 61 | no (<80) |
| solanum_viarum | Solanum viarum | 46 | 64 | yes |
| sonchus_asper | Sonchus asper | 237 | 767 | yes |
| sonchus_oleraceus | Sonchus oleraceus | 29 | 53 | yes |
| sorghum_halepense | Sorghum halepense | 75 | 415 | yes |
| spiraea_japonica | Spiraea japonica | 81 | 594 | yes |
| tamarix_gallica | Tamarix gallica | 0 | 1 | no (<80) |
| torilis_arvensis | Torilis arvensis | 24 | 330 | yes |
| triadica_sebifera | Triadica sebifera | 976 | 2823 | yes |
| verbascum_thapsus | Verbascum thapsus | 827 | 3823 | yes |
| verbena_bonariensis | Verbena bonariensis | 32 | 121 | yes |
| verbena_incompta | Verbena incompta | 1 | 9 | no (<80) |
| vernicia_fordii | Vernicia fordii | 85 | 158 | yes |
| vinca_major | Vinca major | 772 | 2528 | yes |
| vitex_rotundifolia | Vitex rotundifolia | 6 | 328 | yes |
| wisteria_floribunda | Wisteria floribunda | 10 | 34 | no (<80) |

Excluded by hand before the survey (reason): Hydrilla verticillata, Egeria densa, Myriophyllum spicatum, Najas minor, Potamogeton crispus, Limnophila sessiliflora (submerged aquatics, not phone-scannable); Marsilea minuta, Salvinia minima, Salvinia molesta (floating/aquatic ferns); Cynodon dactylon, Festuca arundinacea, Paspalum notatum, Poa annua, Eragrostis curvula (turf and roadside grasses a visitor would not scan); the genus-only entry Verbascum (used Verbascum thapsus). Cinnamomum camphora was not found under that name on iNaturalist (filed as Camphora officinarum) and was skipped; it is a coastal-plain species.

## Tier 3: unknown invasive safety net

Not a class. When nothing is confident the app returns `.rescan(.ambiguous)`; the user can tap "Report anyway for expert review", which saves a report with species `unknown`, `needsExpertReview = true` and the photo for staff.

## Other classes

- `other_plant`: random research-grade Georgia plants excluding every class above (and the same from SE states).
- `not_plant`: Georgia fungi, insects, birds, reptiles, amphibians, mammals, spiders and molluscs: what a visitor also points a phone at.

## Data budget per class

Tier 1: up to 600 images (2 per observation). Native: 350. Tier 2: 220. other_plant: 900. not_plant: 900. Georgia first, then SE states, then the US.
