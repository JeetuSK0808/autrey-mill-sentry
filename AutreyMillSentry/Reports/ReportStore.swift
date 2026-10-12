import Foundation
import SwiftData
import CoreGraphics

/// Create, update and rank reports. All writes go through here so priorities stay consistent.
enum ReportStore {
    static func all(_ context: ModelContext) -> [Report] {
        (try? context.fetch(FetchDescriptor<Report>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))) ?? []
    }

    @discardableResult
    static func create(from result: ScanResult, species: String, speciesName: String, confidence: Double, needsExpertReview: Bool,
                       patchSize: PatchSize, note: String, fieldTrueLabel: String?,
                       catalog: SpeciesCatalog, preserve: PreserveData, context: ModelContext) throws -> Report {
        let id = UUID()
        let fileName = try PhotoStore.save(result.image, id: id)
        let loc = result.location ?? Config.preserveCenter
        let report = Report(id: id, latitude: loc.latitude, longitude: loc.longitude, horizontalAccuracy: result.horizontalAccuracy ?? -1,
                            photoFileName: fileName, species: species, speciesName: speciesName, confidence: confidence,
                            top3: result.classification.top3, modelVersion: result.classification.modelVersion, quality: result.quality,
                            patchSize: patchSize, note: note, nearestTrailName: result.nearestTrailName,
                            distanceToCreekMeters: result.distanceToCreekMeters,
                            isPractice: result.location == nil || !result.isInsidePreserve,
                            needsExpertReview: needsExpertReview, lowAccuracy: result.lowAccuracy)
        if let fieldTrueLabel { report.fieldTrueLabel = fieldTrueLabel; report.fieldTrueLabelAt = .now }
        context.insert(report)
        recomputePriorities(context: context, catalog: catalog)
        try context.save()
        return report
    }

    static func addSighting(to report: Report, note: String, context: ModelContext) {
        report.additionalSightings += 1
        if !note.isEmpty { report.note = report.note.isEmpty ? note : report.note + "\n" + note }
        report.statusUpdatedAt = .now
        try? context.save()
    }

    /// Status change by staff (Ranger mode). "treated" fires the local "Tell" notification.
    static func update(status: ReportStatus, of report: Report, context: ModelContext, catalog: SpeciesCatalog) async {
        report.status = status
        recomputePriorities(context: context, catalog: catalog)
        try? context.save()
        if status == .treated {
            await NotificationService.scheduleTreated(speciesName: report.speciesName, reportID: report.id)
        }
    }

    static func setFieldLabel(_ label: String?, on report: Report, context: ModelContext) {
        report.fieldTrueLabel = label
        report.fieldTrueLabelAt = label == nil ? nil : .now
        try? context.save()
    }

    static func markSent(_ reports: [Report], context: ModelContext) {
        for r in reports { r.sentAt = .now }
        try? context.save()
    }

    static func delete(_ report: Report, context: ModelContext, catalog: SpeciesCatalog) {
        PhotoStore.delete(report.photoFileName)
        context.delete(report)
        recomputePriorities(context: context, catalog: catalog)
        try? context.save()
    }

    static func deleteAll(context: ModelContext) {
        for r in all(context) { context.delete(r) }
        try? context.save()
        PhotoStore.deleteAll()
    }

    // MARK: Ranking

    static func rankingInput(for r: Report, all: [Report], catalog: SpeciesCatalog, now: Date = .now) -> RankingInput {
        let nearby = all.filter { $0.id != r.id && $0.status.isOpen && !$0.isPractice && Geo.distanceMeters($0.location, r.location) <= Config.isolationRadiusMeters }.count
        return RankingInput(patchSize: r.patchSize, nearbyReportCount: nearby, distanceToCreekMeters: r.distanceToCreekMeters,
                            confidence: r.confidence, needsExpertReview: r.needsExpertReview,
                            ageDays: now.timeIntervalSince(r.createdAt) / 86_400, status: r.status,
                            speciesAggressiveness: catalog.species(for: r.species)?.aggressiveness ?? (r.species == "unknown" ? 0.3 : 0))
    }

    static func recomputePriorities(context: ModelContext, catalog: SpeciesCatalog) {
        let reports = all(context)
        for r in reports {
            r.priorityScore = r.isPractice ? 0 : PriorityScore.score(rankingInput(for: r, all: reports, catalog: catalog)).total
        }
    }
}
