import SwiftUI
import SwiftData

/// Collection-wide stats and progress (opened from toolbar).
@MainActor
struct CollectionOverviewView: View {
    @Environment(\.modelContext) private var context
    @Environment(BannerCenter.self) private var banner
    @Query(sort: \Army.sortIndex) private var armies: [Army]
    @Query private var configs: [AppConfiguration]

    @Environment(AppRouter.self) private var router

    private var cfg: AppConfiguration { configs.first ?? Config.current(context) }
    private var search: String { router.collectionSearch }
    private var globalPipeline: [PipelineStage]? { cfg.globalPipeline }
    private var resolvedGlobal: [PipelineStage] { Pipeline.resolve(globalPipeline) }
    private var scoped: Bool { ArmyFilter.isActive(cfg, search: search) }
    private var visible: [VisibleArmy] {
        ArmyFilter.build(armies: armies, cfg: cfg, search: search, global: globalPipeline)
    }
    private var scopedUnits: [Unit] { scoped ? visible.flatMap(\.units) : armies.flatMap(\.units) }
    private var overall: Int {
        Int((Pipeline.progress(of: scopedUnits, resolvedGlobal) * 100).rounded())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    ProgressRing(percent: overall, diameter: 88)
                    Text(scoped ? "Filtered progress" : "Collection progress")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(overall)% complete")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(scoped ? "Filtered" : "Collection") progress, \(overall) percent")

                VStack(alignment: .leading, spacing: 6) {
                    ProgressMeter(segments: Pipeline.segments(of: scopedUnits, resolvedGlobal), height: 10)
                    ProgressLegend(segments: Pipeline.segments(of: scopedUnits, resolvedGlobal))
                }
                .padding(.horizontal)

                ArmyStatsHeader(units: scopedUnits,
                                armyCount: scoped ? visible.count : armies.count,
                                pipeline: resolvedGlobal, scoped: scoped)

                if scoped {
                    Button("Advance visible units", systemImage: "arrow.right.to.line") {
                        let n = ArmyStore.advanceUnits(visible.flatMap(\.units), global: globalPipeline, in: context)
                        banner.show(n > 0 ? "Advanced \(n) unit\(n == 1 ? "" : "s")" : "Nothing to advance")
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Clear filters", systemImage: "line.3.horizontal.decrease.circle") {
                        ArmyFilter.clearFilters(cfg)
                        try? context.save()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .navigationTitle("Overview")
        .navigationBarTitleDisplayMode(.inline)
    }
}
