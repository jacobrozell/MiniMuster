import Testing
@testable import MusterRoll

@Suite("Pipeline")
struct PipelineTests {
    let p = DefaultPipeline.stages

    @Test("stage progress spans 0...1")
    func stageProgress() {
        #expect(Pipeline.stageProgress("Unassembled", p) == 0)
        #expect(Pipeline.stageProgress("Done", p) == 1)
        #expect(abs(Pipeline.stageProgress("Primed", p) - 0.5) < 0.0001)
    }

    @Test("unknown state resolves to index 0")
    func unknown() {
        #expect(Pipeline.stageProgress("Nonsense", p) == 0)
    }

    @Test("next stage")
    func next() {
        #expect(Pipeline.next(after: "Unassembled", in: p) == "Assembled")
        #expect(Pipeline.next(after: "Done", in: p) == nil)
        #expect(Pipeline.next(after: "Nonsense", in: p) == nil)
    }

    @Test("single-stage pipeline clamps denominator")
    func singleStage() {
        let one = [PipelineStage(key: "Only", hex: "#888")]
        #expect(Pipeline.stageProgress("Only", one) == 0)
    }

    @Test("normalizeState matches case-insensitively and warns on unknown")
    func normalize() {
        #expect(Pipeline.normalizeState("based", pipeline: p).state == "Based")
        #expect(Pipeline.normalizeState("", pipeline: p).state == "Unassembled")
        let bad = Pipeline.normalizeState("Glazed", pipeline: p)
        #expect(bad.state == "Unassembled")
        #expect(bad.warning != nil)
    }

    @Test("model-weighted progress")
    func weighted() {
        let a = Unit(name: "Squad (5)", qty: 1, state: "Done")    // 5 models @ 100%
        let b = Unit(name: "Hero", qty: 1, state: "Unassembled")  // 1 model @ 0%
        // total models = 6, weighted sum = 5*1 + 1*0 = 5 → 5/6
        #expect(abs(Pipeline.progress(of: [a, b], p) - (5.0 / 6.0)) < 0.0001)
    }

    @Test("segments are in pipeline order and sum to ~100")
    func segments() {
        let a = Unit(name: "Squad (5)", qty: 1, state: "Done")
        let b = Unit(name: "Hero", qty: 1, state: "Primed")
        let segs = Pipeline.segments(of: [a, b], p)
        #expect(segs.map(\.key) == ["Primed", "Done"])  // pipeline order
        #expect(abs(segs.reduce(0) { $0 + $1.pct } - 100) < 0.0001)
    }

    @Test("advance one step on a non-squad unit")
    func advance() {
        let u = Unit(name: "Hero", qty: 1, state: "Primed")
        Pipeline.advanceOneStep(u, p)
        #expect(u.state == "Base Coated")
        #expect(Pipeline.canAdvance(u, p))
    }

    @Test("empty unit list yields zero progress")
    func emptyProgress() {
        #expect(Pipeline.progress(of: [], p) == 0)
        #expect(Pipeline.segments(of: [], p).isEmpty)
    }

    @Test("squad-weighted progress averages per-model states")
    func squadProgress() {
        let u = Unit(name: "Squad (4)", qty: 1, state: "Primed")
        for i in 0..<4 {
            let m = SquadMember(index: i)
            m.unit = u
            if i < 2 { m.state = "Done" }
        }
        // 2 models @ Done (1.0) + 2 @ Primed (0.5) → avg 0.75
        #expect(abs(Pipeline.progress(of: [u], p) - 0.75) < 0.0001)
    }

    @Test("canAdvance when unit is Done but a member trails behind")
    func canAdvanceSquad() {
        let u = Unit(name: "Squad (3)", qty: 1, state: "Done")
        for i in 0..<3 {
            let m = SquadMember(index: i)
            m.unit = u
            if i == 0 { m.state = "Primed" }
        }
        #expect(Pipeline.canAdvance(u, p))
        Pipeline.advanceOneStep(u, p)
        #expect(u.state == "Done")
        #expect(Members.effectiveState(of: u, at: 0) == "Base Coated")
    }

    @Test("segments count squad members individually")
    func squadSegments() {
        let u = Unit(name: "Squad (3)", qty: 1, state: "Primed")
        for i in 0..<3 {
            let m = SquadMember(index: i)
            m.unit = u
            if i == 0 { m.state = "Done" }
        }
        let segs = Pipeline.segments(of: [u], p)
        #expect(segs.map(\.key) == ["Primed", "Done"])
        #expect(segs.first { $0.key == "Done" }?.pct == (1.0 / 3.0) * 100)
    }
}
