import Foundation

/// Per-species embedding centroids and similarity floors from `model/compute_centroids.py` (bundled as embeddings.json).
final class EmbeddingTable {
    struct Entry { var centroid: [Float]; var minCosine: Double }
    private(set) var entries: [String: Entry] = [:]
    private(set) var dimension = 0
    private(set) var version = ""
    var isAvailable: Bool { !entries.isEmpty }

    init(bundle: Bundle = .main) {
        guard let url = bundle.url(forResource: "embeddings", withExtension: "json"), let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let classes = obj["classes"] as? [String: [String: Any]] else { return }
        version = obj["version"] as? String ?? ""
        dimension = obj["dim"] as? Int ?? 0
        for (label, v) in classes {
            guard let c = v["centroid"] as? [NSNumber], let f = v["minCosine"] as? NSNumber else { continue }
            entries[label] = Entry(centroid: c.map { $0.floatValue }, minCosine: f.doubleValue)
        }
    }

    /// Cosine similarity of an L2-normalised embedding to the class centroid, with that class's floor.
    func similarity(of embedding: [Float], to label: String) -> (value: Double, floor: Double)? {
        guard let e = entries[label], e.centroid.count == embedding.count, !embedding.isEmpty else { return nil }
        var dot: Float = 0
        for i in 0..<embedding.count { dot += embedding[i] * e.centroid[i] }
        return (Double(dot), e.minCosine)
    }
}
