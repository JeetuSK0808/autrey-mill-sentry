import Foundation

enum SpeciesTier: String, Codable, Sendable {
    case tier1   // documented at Autrey Mill or very common in north Georgia; can be "confirmed"
    case tier2   // on the Georgia Invasive Species Council list; always "needs expert review"
    case native  // native look-alike; never reported as invasive
    case other   // other_plant / not_plant / unknown
}

struct LookAlike: Codable, Sendable, Hashable {
    var label: String?          // classifier label if the look-alike is a class
    var name: String
    var tellThemApart: String
}

struct Species: Codable, Sendable, Identifiable, Hashable {
    var id: String { label }
    var label: String           // classifier label, e.g. "ligustrum_sinense"
    var scientificName: String
    var commonName: String
    var tier: SpeciesTier
    /// 0...1 "aggressive spreader" weight from the Georgia Forestry Commission Dirty Dozen (acres occupied).
    var aggressiveness: Double
    var documentedAtPreserve: Bool
    var whyItMatters: String
    var howToRecognize: String
    var whatToPhotograph: String
    var lookAlike: LookAlike?
    var sourceURL: String
    var inatTaxonID: Int? = nil

    var displayName: String { commonName.isEmpty ? scientificName : commonName }
    var inatURL: URL? { inatTaxonID.flatMap { URL(string: "https://www.inaturalist.org/taxa/\($0)") } }
    var isInvasive: Bool { tier == .tier1 || tier == .tier2 }
}

/// All species the classifier knows, with Learn content for Tier 1 and natives.
/// Tier 2 entries come from `Resources/tier2_species.json`, generated from `model/classes.json`.
struct SpeciesCatalog: Sendable {
    let species: [Species]
    private let byLabel: [String: Species]

    init(species: [Species]) {
        self.species = species
        self.byLabel = Dictionary(uniqueKeysWithValues: species.map { ($0.label, $0) })
    }

    func species(for label: String) -> Species? { byLabel[label] }
    func tier(of label: String) -> SpeciesTier { byLabel[label]?.tier ?? .other }
    func name(for label: String) -> String {
        if let s = byLabel[label] { return s.displayName }
        switch label {
        case "other_plant": return "Other plant"
        case "not_plant": return "Not a plant"
        default: return label.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
    var tier1: [Species] { species.filter { $0.tier == .tier1 } }
    var tier2: [Species] { species.filter { $0.tier == .tier2 } }
    var natives: [Species] { species.filter { $0.tier == .native } }
    /// The hand-written native look-alikes (each paired with an invasive it is confused with).
    var lookAlikeNatives: [Species] { natives.filter { Self.builtInLabels.contains($0.label) } }
    /// Common natives of the preserve's neighbourhood from `local_species.json` (known by name so they are never flagged).
    var localNatives: [Species] { natives.filter { !Self.builtInLabels.contains($0.label) } }
    static let builtInLabels: Set<String> = Set(builtIn.map(\.label))
    var aggressiveness: [String: Double] { Dictionary(uniqueKeysWithValues: species.map { ($0.label, $0.aggressiveness) }) }

    static let gisc = "https://gainvasivespeciescouncil.org/list/invasive-plants/"
    static let bugwood = "https://www.invasive.org/"

    /// Tier 1 + native content is hand-written here so it is reviewable in one place.
    static let builtIn: [Species] = [
        Species(label: "ligustrum_sinense", scientificName: "Ligustrum sinense", commonName: "Chinese privet", tier: .tier1,
                aggressiveness: 1.0, documentedAtPreserve: true,
                whyItMatters: "Georgia's number one invasive plant by area. It forms dense thickets that shade out native understory plants and tree seedlings.",
                howToRecognize: "Shrub to small tree. Small oval leaves in opposite pairs along the twig, matte and about the size of a fingernail to a thumb. Clusters of tiny white flowers in late spring, then dark blue-black berries in winter. Twigs have fine hairs.",
                whatToPhotograph: "A twig showing the opposite leaf pairs, then the whole shrub.",
                lookAlike: LookAlike(label: "viburnum_acerifolium", name: "native viburnums",
                                     tellThemApart: "Viburnum leaves are larger, usually toothed or lobed, and its berries hang in flat-topped clusters. Privet leaves are small, smooth-edged and its twigs are hairy."),
                sourceURL: "https://www.invasive.org/species/subject.cfm?sub=3035"),
        Species(label: "mahonia_bealei", scientificName: "Mahonia bealei (Berberis bealei)", commonName: "Leatherleaf mahonia", tier: .tier1,
                aggressiveness: 0.3, documentedAtPreserve: true,
                whyItMatters: "Birds carry its berries into the forest, where it forms spiny evergreen clumps in the shade and crowds out spring wildflowers.",
                howToRecognize: "Stiff, leathery, holly-like leaflets with sharp spines along the edges, arranged in long compound leaves that spread out like a fan from a woody stem. Yellow flower spikes in late winter, then powder-blue berries.",
                whatToPhotograph: "One compound leaf from above, then the whole plant.",
                lookAlike: LookAlike(label: "ilex_opaca", name: "American holly",
                                     tellThemApart: "American holly is a tree with single glossy leaves spaced along the twig and red berries. Mahonia has leaflets in pairs along a central stalk and blue berries."),
                sourceURL: "https://www.invasive.org/species/subject.cfm?sub=11598"),
        Species(label: "lonicera_japonica", scientificName: "Lonicera japonica", commonName: "Japanese honeysuckle", tier: .tier1,
                aggressiveness: 0.5, documentedAtPreserve: true,
                whyItMatters: "A twining vine that blankets shrubs and the forest floor, girdles saplings and keeps native plants from getting light.",
                howToRecognize: "Twining vine with opposite oval leaves that stay green most of the winter. White flowers that turn yellow, in pairs, very fragrant. Black berries. Young stems are hairy and reddish.",
                whatToPhotograph: "A stem with leaf pairs, and flowers or berries if present.",
                lookAlike: LookAlike(label: "lonicera_sempervirens", name: "Coral honeysuckle (native)",
                                     tellThemApart: "Coral honeysuckle has red-orange tubular flowers, red berries, and the top pair of leaves is fused around the stem. Japanese honeysuckle has white-to-yellow flowers, black berries and separate leaves."),
                sourceURL: "https://www.invasive.org/species/subject.cfm?sub=3039"),
        Species(label: "wisteria_sinensis", scientificName: "Wisteria sinensis", commonName: "Chinese wisteria", tier: .tier1,
                aggressiveness: 0.5, documentedAtPreserve: true,
                whyItMatters: "A heavy woody vine that strangles and topples trees and smothers everything under it.",
                howToRecognize: "Thick woody vine twisting around trunks. Compound leaves with 7 to 13 leaflets. Hanging clusters of lilac flowers in spring before the leaves fully open. Velvety seed pods.",
                whatToPhotograph: "A leaf showing all the leaflets, and the vine on its support.",
                lookAlike: LookAlike(label: "wisteria_frutescens", name: "American wisteria (native)",
                                     tellThemApart: "American wisteria blooms after the leaves are out, in shorter, denser clusters, and its seed pods are smooth. Chinese wisteria blooms earlier with longer clusters and velvety pods."),
                sourceURL: "https://www.invasive.org/species/subject.cfm?sub=3082"),
        Species(label: "vinca_minor", scientificName: "Vinca minor", commonName: "Common periwinkle", tier: .tier1,
                aggressiveness: 0.3, documentedAtPreserve: true,
                whyItMatters: "An evergreen ground cover that escapes from old home sites and forms mats that exclude native wildflowers.",
                howToRecognize: "Trailing stems with glossy, dark green, opposite leaves and five-petalled blue-violet pinwheel flowers in spring.",
                whatToPhotograph: "A patch from above and one stem close up.",
                lookAlike: LookAlike(label: "mitchella_repens", name: "Partridgeberry (native)",
                                     tellThemApart: "Partridgeberry has tiny rounded leaves with a pale midrib, paired white flowers and red berries. Periwinkle leaves are larger and pointed, with blue flowers."),
                sourceURL: "https://www.invasive.org/species/subject.cfm?sub=3078"),
        Species(label: "elaeagnus_umbellata", scientificName: "Elaeagnus umbellata", commonName: "Autumn olive", tier: .tier1,
                aggressiveness: 0.65, documentedAtPreserve: true,
                whyItMatters: "Fixes nitrogen and changes the soil, then forms thickets that crowd out native shrubs. Birds spread the berries widely.",
                howToRecognize: "Shrub with silvery undersides on the leaves (look for the metallic sheen), small fragrant cream flowers in spring and speckled red berries in autumn. Often thorny.",
                whatToPhotograph: "The underside of a leaf in good light, then the shrub.",
                lookAlike: LookAlike(label: "elaeagnus_pungens", name: "Thorny olive (also invasive)",
                                     tellThemApart: "Thorny olive is evergreen with brown-dotted leaf undersides and blooms in autumn. Autumn olive loses its leaves in winter and blooms in spring."),
                sourceURL: "https://www.invasive.org/species/subject.cfm?sub=3021"),
        Species(label: "elaeagnus_pungens", scientificName: "Elaeagnus pungens", commonName: "Thorny olive", tier: .tier1,
                aggressiveness: 0.65, documentedAtPreserve: true,
                whyItMatters: "An evergreen shrub that sends long whip-like shoots into the canopy and shades out native plants year-round.",
                howToRecognize: "Evergreen leaves with wavy edges, silvery below with rusty-brown dots. Long arching shoots with thorns. Small fragrant flowers in autumn.",
                whatToPhotograph: "Leaf underside and the long shoots.",
                lookAlike: LookAlike(label: "elaeagnus_umbellata", name: "Autumn olive (also invasive)",
                                     tellThemApart: "Both are reported the same way. Thorny olive keeps its leaves all winter and the leaf undersides have brown dots."),
                sourceURL: "https://www.invasive.org/species/subject.cfm?sub=3020"),
        Species(label: "rosa_multiflora", scientificName: "Rosa multiflora", commonName: "Multiflora rose", tier: .tier1,
                aggressiveness: 0.3, documentedAtPreserve: true,
                whyItMatters: "Forms impenetrable thorny thickets along trails and creek banks.",
                howToRecognize: "Arching thorny canes. Compound leaves with 5 to 9 toothed leaflets and a fringed (comb-like) stipule where the leaf meets the stem. Clusters of small white flowers, then small red hips.",
                whatToPhotograph: "The base of a leaf where it meets the stem (the fringed stipule), and the canes.",
                lookAlike: LookAlike(label: "rosa_carolina", name: "Carolina rose (native)",
                                     tellThemApart: "Carolina rose has pink flowers, usually one at a time, straight thorns and a plain stipule. Multiflora rose has many white flowers together, curved thorns and a fringed stipule."),
                sourceURL: "https://www.invasive.org/species/subject.cfm?sub=3071"),
        Species(label: "hedera_helix", scientificName: "Hedera helix", commonName: "English ivy", tier: .tier1,
                aggressiveness: 0.55, documentedAtPreserve: true,
                whyItMatters: "Carpets the ground and climbs trees, adding weight and shading the trunk. It can bring down trees in storms.",
                howToRecognize: "Evergreen vine with dark, waxy, lobed leaves (three to five lobes) and pale veins. Climbs with root-like hairs on the stem. Mature climbing stems have unlobed leaves and black berries.",
                whatToPhotograph: "A few leaves close up showing the pale veins, then the vine on the ground or trunk.",
                lookAlike: LookAlike(label: "parthenocissus_quinquefolia", name: "Virginia creeper and poison ivy (native)",
                                     tellThemApart: "Virginia creeper has five separate leaflets and poison ivy has three. English ivy has one leaf with lobes, never separate leaflets. Do not touch any of them."),
                sourceURL: "https://www.invasive.org/species/subject.cfm?sub=3027"),
        Species(label: "albizia_julibrissin", scientificName: "Albizia julibrissin", commonName: "Mimosa (silk tree)", tier: .tier1,
                aggressiveness: 0.45, documentedAtPreserve: true,
                whyItMatters: "A fast-growing tree that seeds into forest edges and creek banks and shades out native saplings.",
                howToRecognize: "Small tree with fern-like, twice-compound leaves that fold at night. Pink powder-puff flowers in summer, then flat brown seed pods that hang through winter.",
                whatToPhotograph: "One fern-like leaf and the trunk or pods.",
                lookAlike: nil,
                sourceURL: "https://www.invasive.org/species/subject.cfm?sub=3004"),
        Species(label: "paulownia_tomentosa", scientificName: "Paulownia tomentosa", commonName: "Princess tree", tier: .tier1,
                aggressiveness: 0.3, documentedAtPreserve: true,
                whyItMatters: "Produces millions of wind-blown seeds and sprouts quickly on disturbed ground, outgrowing native trees.",
                howToRecognize: "Very large heart-shaped, velvety leaves in opposite pairs, hollow twigs, purple foxglove-like flowers in spring and clusters of woody egg-shaped seed capsules.",
                whatToPhotograph: "A leaf with your hand nearby for scale, and the seed capsules if present.",
                lookAlike: LookAlike(label: "catalpa_bignonioides", name: "Southern catalpa (native)",
                                     tellThemApart: "Catalpa has white flowers, long bean-like pods and leaves in whorls of three. Princess tree has purple flowers, egg-shaped capsules and leaves in pairs."),
                sourceURL: "https://www.invasive.org/species/subject.cfm?sub=3055"),
        Species(label: "microstegium_vimineum", scientificName: "Microstegium vimineum", commonName: "Japanese stiltgrass", tier: .tier1,
                aggressiveness: 0.9, documentedAtPreserve: false,
                whyItMatters: "Georgia's second most widespread invasive. It carpets shady forest floors and trail edges and crowds out native wildflowers and tree seedlings.",
                howToRecognize: "A sprawling annual grass with short, pale green, lance-shaped leaves that have a silvery stripe down the middle. Stems root at the nodes. Dies back to tan straw in winter.",
                whatToPhotograph: "A few leaves close up showing the silver midline, then the patch.",
                lookAlike: LookAlike(label: "chasmanthium_latifolium", name: "River oats and other native grasses",
                                     tellThemApart: "River oats is taller with wide leaves and flat, dangling seed heads. Stiltgrass is low, sprawling and has the pale stripe on each leaf."),
                sourceURL: "https://www.invasive.org/species/subject.cfm?sub=3051"),
        Species(label: "pueraria_montana", scientificName: "Pueraria montana var. lobata", commonName: "Kudzu", tier: .tier1,
                aggressiveness: 0.75, documentedAtPreserve: false,
                whyItMatters: "The vine that covers whole hillsides. It smothers trees and shrubs under a blanket of leaves.",
                howToRecognize: "Fast vine with large leaves made of three broad leaflets, often lobed, hairy underneath. Purple grape-scented flowers in late summer. Hairy stems.",
                whatToPhotograph: "One three-part leaf and the extent of the patch.",
                lookAlike: LookAlike(label: "vitis_rotundifolia", name: "Muscadine grape and other native vines",
                                     tellThemApart: "Muscadine has single rounded toothed leaves and tendrils. Kudzu leaves are in threes with no tendrils."),
                sourceURL: "https://www.invasive.org/species/subject.cfm?sub=2425"),
        Species(label: "nandina_domestica", scientificName: "Nandina domestica", commonName: "Nandina (sacred bamboo)", tier: .tier1,
                aggressiveness: 0.3, documentedAtPreserve: false,
                whyItMatters: "Escapes from yards into the woods. Its red berries are spread by birds and are toxic to some of them in quantity.",
                howToRecognize: "Upright shrub with cane-like stems and lacy compound leaves of many pointed leaflets, often tinged red. Bright red berry clusters that last through winter.",
                whatToPhotograph: "A leaf showing the leaflets and the berries if present.",
                lookAlike: nil,
                sourceURL: "https://www.invasive.org/species/subject.cfm?sub=3052"),

        // Native look-alikes: never reported, shown as "looks like native ...".
        Species(label: "lonicera_sempervirens", scientificName: "Lonicera sempervirens", commonName: "Coral honeysuckle", tier: .native, aggressiveness: 0, documentedAtPreserve: false,
                whyItMatters: "A native vine that hummingbirds love.", howToRecognize: "Red-orange tubular flowers, red berries, and the top leaf pair fused around the stem.",
                whatToPhotograph: "", lookAlike: LookAlike(label: "lonicera_japonica", name: "Japanese honeysuckle (invasive)", tellThemApart: "White-to-yellow flowers and black berries mean Japanese honeysuckle."), sourceURL: "https://www.wildflower.org/plants/result.php?id_plant=LOSE"),
        Species(label: "wisteria_frutescens", scientificName: "Wisteria frutescens", commonName: "American wisteria", tier: .native, aggressiveness: 0, documentedAtPreserve: false,
                whyItMatters: "A well-behaved native vine.", howToRecognize: "Blooms after leaf-out in short dense clusters, smooth seed pods.",
                whatToPhotograph: "", lookAlike: LookAlike(label: "wisteria_sinensis", name: "Chinese wisteria (invasive)", tellThemApart: "Long flower clusters before the leaves and velvety pods mean Chinese wisteria."), sourceURL: "https://www.wildflower.org/plants/result.php?id_plant=WIFR"),
        Species(label: "viburnum_acerifolium", scientificName: "Viburnum acerifolium", commonName: "Mapleleaf viburnum", tier: .native, aggressiveness: 0, documentedAtPreserve: false,
                whyItMatters: "A common native understory shrub.", howToRecognize: "Maple-shaped three-lobed leaves in pairs, flat white flower clusters, black berries.",
                whatToPhotograph: "", lookAlike: LookAlike(label: "ligustrum_sinense", name: "Chinese privet (invasive)", tellThemApart: "Privet leaves are small and smooth-edged."), sourceURL: "https://www.wildflower.org/plants/result.php?id_plant=VIAC"),
        Species(label: "viburnum_dentatum", scientificName: "Viburnum dentatum", commonName: "Arrowwood viburnum", tier: .native, aggressiveness: 0, documentedAtPreserve: false,
                whyItMatters: "A native shrub whose berries feed birds.", howToRecognize: "Coarsely toothed oval leaves in pairs, straight stems, blue-black berries.",
                whatToPhotograph: "", lookAlike: LookAlike(label: "ligustrum_sinense", name: "Chinese privet (invasive)", tellThemApart: "Privet leaves have no teeth and the twigs are hairy."), sourceURL: "https://www.wildflower.org/plants/result.php?id_plant=VIDE"),
        Species(label: "ilex_opaca", scientificName: "Ilex opaca", commonName: "American holly", tier: .native, aggressiveness: 0, documentedAtPreserve: false,
                whyItMatters: "A native evergreen tree.", howToRecognize: "Single spiny glossy leaves spaced along the twig, red berries.",
                whatToPhotograph: "", lookAlike: LookAlike(label: "mahonia_bealei", name: "Leatherleaf mahonia (invasive)", tellThemApart: "Mahonia has leaflets along a central stalk and blue berries."), sourceURL: "https://www.wildflower.org/plants/result.php?id_plant=ILOP"),
        Species(label: "toxicodendron_radicans", scientificName: "Toxicodendron radicans", commonName: "Poison ivy", tier: .native, aggressiveness: 0, documentedAtPreserve: false,
                whyItMatters: "Native, and important for birds, but it causes a rash. Do not touch.", howToRecognize: "Leaves of three, the middle leaflet on a longer stalk. Hairy climbing vines.",
                whatToPhotograph: "", lookAlike: LookAlike(label: "hedera_helix", name: "English ivy (invasive)", tellThemApart: "English ivy is one lobed leaf, never three leaflets."), sourceURL: "https://www.wildflower.org/plants/result.php?id_plant=TORA2"),
        Species(label: "parthenocissus_quinquefolia", scientificName: "Parthenocissus quinquefolia", commonName: "Virginia creeper", tier: .native, aggressiveness: 0, documentedAtPreserve: false,
                whyItMatters: "A native vine with autumn colour and berries for birds.", howToRecognize: "Five leaflets spread like a hand, turns red in autumn.",
                whatToPhotograph: "", lookAlike: LookAlike(label: "hedera_helix", name: "English ivy (invasive)", tellThemApart: "Five separate leaflets means Virginia creeper."), sourceURL: "https://www.wildflower.org/plants/result.php?id_plant=PAQU2"),
        Species(label: "vitis_rotundifolia", scientificName: "Vitis rotundifolia", commonName: "Muscadine grape", tier: .native, aggressiveness: 0, documentedAtPreserve: false,
                whyItMatters: "A native vine with edible fruit.", howToRecognize: "Rounded toothed single leaves, unbranched tendrils, smooth bark.",
                whatToPhotograph: "", lookAlike: LookAlike(label: "pueraria_montana", name: "Kudzu (invasive)", tellThemApart: "Kudzu leaves are in threes and the vine has no tendrils."), sourceURL: "https://www.wildflower.org/plants/result.php?id_plant=VIRO3"),
        Species(label: "rosa_carolina", scientificName: "Rosa carolina", commonName: "Carolina rose", tier: .native, aggressiveness: 0, documentedAtPreserve: false,
                whyItMatters: "A low native rose.", howToRecognize: "Single pink flowers, straight thorns, plain stipules.",
                whatToPhotograph: "", lookAlike: LookAlike(label: "rosa_multiflora", name: "Multiflora rose (invasive)", tellThemApart: "Many white flowers and a fringed stipule mean multiflora rose."), sourceURL: "https://www.wildflower.org/plants/result.php?id_plant=ROCA4"),
        Species(label: "rubus_argutus", scientificName: "Rubus argutus", commonName: "Sawtooth blackberry", tier: .native, aggressiveness: 0, documentedAtPreserve: false,
                whyItMatters: "A native bramble that feeds wildlife.", howToRecognize: "Angled canes, leaves of 3 to 5 toothed leaflets, white flowers, black fruit.",
                whatToPhotograph: "", lookAlike: LookAlike(label: "rosa_multiflora", name: "Multiflora rose (invasive)", tellThemApart: "Rose hips are red and the stipule is fringed on multiflora rose."), sourceURL: "https://www.wildflower.org/plants/result.php?id_plant=RUAR2"),
        Species(label: "mitchella_repens", scientificName: "Mitchella repens", commonName: "Partridgeberry", tier: .native, aggressiveness: 0, documentedAtPreserve: false,
                whyItMatters: "A delicate native ground cover.", howToRecognize: "Tiny round paired leaves with a pale midrib, paired white flowers, red berries.",
                whatToPhotograph: "", lookAlike: LookAlike(label: "vinca_minor", name: "Common periwinkle (invasive)", tellThemApart: "Periwinkle leaves are larger and pointed, flowers blue."), sourceURL: "https://www.wildflower.org/plants/result.php?id_plant=MIRE"),
        Species(label: "catalpa_bignonioides", scientificName: "Catalpa bignonioides", commonName: "Southern catalpa", tier: .native, aggressiveness: 0, documentedAtPreserve: false,
                whyItMatters: "A native tree with big heart-shaped leaves.", howToRecognize: "Leaves in threes, white flowers, long bean-like pods.",
                whatToPhotograph: "", lookAlike: LookAlike(label: "paulownia_tomentosa", name: "Princess tree (invasive)", tellThemApart: "Purple flowers, paired leaves and egg-shaped capsules mean princess tree."), sourceURL: "https://www.wildflower.org/plants/result.php?id_plant=CABI8"),
        Species(label: "chasmanthium_latifolium", scientificName: "Chasmanthium latifolium", commonName: "River oats", tier: .native, aggressiveness: 0, documentedAtPreserve: false,
                whyItMatters: "A native grass of creek banks.", howToRecognize: "Wide leaves and flat dangling seed heads.",
                whatToPhotograph: "", lookAlike: LookAlike(label: "microstegium_vimineum", name: "Japanese stiltgrass (invasive)", tellThemApart: "Stiltgrass is low and sprawling with a silver stripe on each leaf."), sourceURL: "https://www.wildflower.org/plants/result.php?id_plant=CHLA5"),
        Species(label: "smilax_rotundifolia", scientificName: "Smilax rotundifolia", commonName: "Common greenbrier", tier: .native, aggressiveness: 0, documentedAtPreserve: false,
                whyItMatters: "A thorny native vine that shelters birds.", howToRecognize: "Round glossy leaves, green stems with stout thorns, tendrils.",
                whatToPhotograph: "", lookAlike: nil, sourceURL: "https://www.wildflower.org/plants/result.php?id_plant=SMRO"),
    ]
}
