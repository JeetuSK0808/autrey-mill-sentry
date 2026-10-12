# Map notes: OpenStreetMap data vs the official trail map

Data pulled 2026-10-12 with `tools/fetch_map.py` (Overpass API, bounding box around the preserve with a 0.0035° margin), clipped with `tools/clip_map.py` to the park polygon (OSM way 589352774, `leisure=park`, name "Autrey Mill Park", website autreymill.org) plus 120 m. Geocoding: Nominatim returned OSM way 34787528 (`natural=wood`, "Autrey Mill Nature Preserve"). Raw responses are in `data/raw/` (not committed). Map data © OpenStreetMap contributors, ODbL.

Compared by eye against the preserve's own map image "2024-Trail-map-Feb9-2025.png" (autreymill.org/about/trails, downloaded for reference only, never bundled or copied) and the text on the trails page.

## What matches
- The overall shape: the long north-south preserve with the heritage village and parking at the north end on Autrey Mill Road, the creek along the west side, the big loop in the south, and the gate and parking at the south-east corner near Old Alabama Road.
- Named trails present in both: **Warsaw Trail** (north-west, starts by Warsaw Church).
- Water: **Sal's Creek** is named in OSM; the pond ("Autry Pond") is in OSM.
- Points of interest in both: Warsaw Church, Wetland Pavilion, parking areas, benches, toilets, the south gate, a viewpoint (overlook).

## Discrepancies that could not be resolved from public data
| Item | Official map / website | OSM | What the app does |
|---|---|---|---|
| Trail names | Warsaw Trail, Millers' Trail, Wildflower Trail; the trails page also mentions River Trail and Forest Loop | Warsaw Trail, Mill Race, Perimeter Trail East, Forest Trail North, Forest Pass, Wetland Pass, Spur Trail, 20+ unnamed footways | OSM names are kept (they are the only geometry we have). Unnamed ways show as "Unnamed trail". **Ask staff** for the current trail names; renaming is a one-line edit in `tools/clip_map.py`. |
| "Millers' Trail" | Runs north-south from the village to the creek bridge | Probably OSM "Mill Race" or the unnamed footway next to it | Not renamed without confirmation. |
| "Wildflower Trail" | Long trail on the east side parallel to Autrey Mill Road | Probably "Perimeter Trail East" plus unnamed segments | Not renamed without confirmation. |
| New Eagle Scout trail sections on the south side (continuous loop from the road-side picnic shelter) | Mentioned on the trails page | Present as unnamed footways in the south loop (OSM edited 2024/2025) | Shown. |
| Gold Mine, Amphitheater, Summerour House, Tenant House, Nature Classroom, Green Store, Pole Barn, Upper Pavilion, Heritage Garden, Butterfly Garden, goats | On the official map | Only Warsaw Church and Wetland Pavilion are named in OSM; other buildings are unnamed polygons | Unnamed buildings are not labelled. Could be added by hand once staff confirm positions. |
| Trail hours | Map image says 8 am to 8 pm; website (12 Oct 2026) says 8 am to 9 pm | n/a | The app shows the website hours with the retrieval date. **Ask staff which is right.** |
| Boundary | The official map shows no survey boundary | The `leisure=park` polygon | Used as the geofence with a 60 m buffer, so a slightly-off boundary does not block reports at the edges. |

## Offline behaviour
Trails, boundary, creek and points of interest are bundled GeoJSON and render with no network. The Apple basemap tiles are cached by MapKit only for areas already viewed; with no signal and no cache the pins and overlays still draw on a blank background.
