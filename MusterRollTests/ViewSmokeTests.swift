import SwiftData
import SwiftUI
import Testing
@testable import MusterRoll

/// Renders key SwiftUI surfaces in a hosting controller so layout code participates in coverage.
@Suite("View smoke", .serialized)
@MainActor
struct ViewSmokeTests {
    private func seedCollection(_ db: TestDatabase) throws -> Army {
        let army = Army(name: "Vermindoom", game: "AoS", faction: "Skaven", sortIndex: 0)
        db.context.insert(army)
        let unit = Unit(name: "Clanrats (5)", qty: 1, source: "Skaventide", state: "Based",
                        notes: "#wip", spearhead: true, order: 0)
        unit.army = army
        db.context.insert(unit)
        db.context.insert(Paint(name: "Khorne Red", type: "Base", brand: "Citadel", low: true))
        try db.context.save()
        return army
    }

    @Test("design system components render")
    func components() {
        let segments = [ProgressSegment(key: "Primed", hex: "#f97316", pct: 50)]
        ViewTestHost.render(VStack {
            ProgressMeter(segments: segments)
            CrestBadge(text: "SK", colorHex: "#8a9a4a")
            StatTile(value: 12, label: "Models")
            StateChip(state: "Primed", pipeline: DefaultPipeline.stages)
        })
    }

    @Test("list rows render with sample models")
    func rows() throws {
        let db = TestDatabase()
        let army = try seedCollection(db)
        let unit = army.orderedUnits[0]
        let paint = try #require((try? db.context.fetch(FetchDescriptor<Paint>()))?.first)

        ViewTestHost.render(ArmyRow(army: army, overrides: [], visibleUnitCount: 1,
                                    percentComplete: 42, scoped: false))
        ViewTestHost.render(UnitRow(unit: unit, pipeline: DefaultPipeline.stages, showSpearhead: true))
        ViewTestHost.render(PaintRow(paint: paint, linkedCount: 1))
    }

    @Test("stats header renders scoped and unscoped")
    func statsHeader() throws {
        let db = TestDatabase()
        let army = try seedCollection(db)
        let units = army.orderedUnits
        ViewTestHost.render(ArmyStatsHeader(units: units, armyCount: 1, pipeline: DefaultPipeline.stages))
        ViewTestHost.render(ArmyStatsHeader(units: units, armyCount: 1,
                                            pipeline: DefaultPipeline.stages, scoped: true))
    }

    @Test("stats header renders at accessibility text sizes")
    func statsHeaderAccessibility() throws {
        let db = TestDatabase()
        let army = try seedCollection(db)
        let units = army.orderedUnits
        for size: DynamicTypeSize in [.accessibility1, .accessibility3, .accessibility5] {
            ViewTestHost.render(
                ArmyStatsHeader(units: units, armyCount: 1, pipeline: DefaultPipeline.stages)
                    .environment(\.dynamicTypeSize, size)
            )
        }
    }

    @Test("army row renders at accessibility text sizes")
    func armyRowAccessibility() throws {
        let db = TestDatabase()
        let army = try seedCollection(db)
        for size: DynamicTypeSize in [.large, .accessibility3] {
            ViewTestHost.render(
                ArmyRow(army: army, overrides: [], visibleUnitCount: 1,
                        percentComplete: 42, scoped: false)
                    .environment(\.dynamicTypeSize, size)
                    .frame(width: 380)
            )
        }
    }

    @Test("onboarding renders landscape and large text")
    func onboardingAdaptive() {
        ViewTestHost.render(
            OnboardingView { _ in }
                .environment(\.dynamicTypeSize, .accessibility3)
                .environment(\.verticalSizeClass, .compact)
        )
    }

    @Test("collection home renders empty and loaded states")
    func collectionHome() throws {
        let empty = TestDatabase()
        ViewTestHost.render(ViewTestHost.appEnvironments(
            NavigationStack {
                CollectionHomeView(selectedArmyId: .constant(nil))
            }
        ), container: empty.container)

        let db = TestDatabase()
        _ = try seedCollection(db)
        ViewTestHost.render(ViewTestHost.appEnvironments(
            NavigationStack {
                CollectionHomeView(selectedArmyId: .constant(nil))
            }
        ), container: db.container)
    }

    @Test("army and unit detail screens render")
    func detailScreens() throws {
        let db = TestDatabase()
        let army = try seedCollection(db)
        let unit = army.orderedUnits[0]

        ViewTestHost.render(ViewTestHost.appEnvironments(
            NavigationStack {
                ArmyDetailView(armyId: army.id, selectedArmyId: .constant(army.id),
                               selectedUnitId: .constant(unit.id))
            }
        ), container: db.container)

        ViewTestHost.render(ViewTestHost.appEnvironments(
            NavigationStack {
                UnitDetailView(unitId: unit.id)
            }
        ), container: db.container)
    }

    @Test("paints tab surfaces render")
    func paintsTab() throws {
        let db = TestDatabase()
        _ = try seedCollection(db)
        let paints = try #require((try? db.context.fetch(FetchDescriptor<Paint>())) ?? [])
        let armies = try #require((try? db.context.fetch(FetchDescriptor<Army>())) ?? [])

        ViewTestHost.render(ViewTestHost.appEnvironments(
            NavigationStack {
                PaintListView(selectedPaintId: .constant(nil))
            }
        ), container: db.container)

        ViewTestHost.render(PaintGridView(
            paints: paints,
            linkedCount: { PaintStore.linkedUnitCount(source: $0.source, armies: armies) },
            onSelect: { _ in }
        ))
    }

    @Test("settings and onboarding render")
    func settingsAndOnboarding() throws {
        let db = TestDatabase()
        _ = try seedCollection(db)

        ViewTestHost.render(ViewTestHost.appEnvironments(
            NavigationStack {
                SettingsScreen()
            }
        ), container: db.container)

        ViewTestHost.render(OnboardingView { _ in })
    }

    @Test("import results sheet renders warnings")
    func importResults() {
        ViewTestHost.render(ImportResultsSheet(title: "Imported", message: "Done",
                                               warnings: ["Unknown faction"], failed: false))
    }
}
