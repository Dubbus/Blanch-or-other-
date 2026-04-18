import Foundation

// MARK: - Result Explainer
//
// Narrates the season call from the raw picks. The posterior alone is
// abstract ("Light Spring: 42%") — this translates the user's concrete
// choices into reasoning the user can validate and share.
//
// Strategy: walk through Stage 1 answers and Stage 2 shade picks, extract
// the directional bias each one carries on undertone (warm/cool) and depth
// (light/deep) axes, and build a prioritized bullet list of the strongest
// signals. Also compute normalized axis positions for the visual bars.

struct ResultExplanation: Sendable {
    let headline: String
    // Normalized axis scores in [-1, +1].
    //   undertoneScore: -1 = fully cool, +1 = fully warm
    //   depthScore:     -1 = fully light, +1 = fully deep
    let undertoneScore: Double
    let depthScore: Double
    let reasons: [ExplainerReason]
}

struct ExplainerReason: Sendable, Identifiable, Hashable {
    let id: String
    let icon: String
    let text: String
    let axis: Axis
    let direction: Direction
}

enum Axis: Sendable, Hashable { case undertone, depth }
enum Direction: Sendable, Hashable { case warm, cool, light, deep, neutral }

protocol ResultExplaining: Sendable {
    func explain(
        selectedAnswerIds: [String: String],
        pickedShadeIds: [String],
        topSeasonName: String
    ) -> ResultExplanation
}

struct ResultExplainer: ResultExplaining {

    func explain(
        selectedAnswerIds: [String: String],
        pickedShadeIds: [String],
        topSeasonName: String
    ) -> ResultExplanation {
        var undertoneLog = 0.0
        var depthLog = 0.0
        var reasons: [ExplainerReason] = []

        // Stage 1 — one reason per answered question, interpreted into plain text.
        for question in Stage1Questions.all {
            guard let answerId = selectedAnswerIds[question.id],
                  let answer = question.options.first(where: { $0.id == answerId }) else {
                continue
            }
            undertoneLog += safeLog(answer.likelihood.undertoneWarm / answer.likelihood.undertoneCool)
            depthLog += safeLog(answer.likelihood.depthDeep / answer.likelihood.depthLight)

            if let reason = stage1Reason(questionId: question.id, answerId: answerId) {
                reasons.append(reason)
            }
        }

        // Stage 2 — aggregate all shade picks into undertone/depth axes, then
        // add a single summarizing bullet per axis when the lean is meaningful.
        var stage2WarmCount = 0
        var stage2DeepCount = 0
        var stage2TotalPicks = 0
        for shadeId in pickedShadeIds {
            guard let shade = DrapingShadeCatalog.all.first(where: { $0.id == shadeId }) else {
                continue
            }
            undertoneLog += safeLog(shade.likelihood.undertoneWarm / shade.likelihood.undertoneCool)
            depthLog += safeLog(shade.likelihood.depthDeep / shade.likelihood.depthLight)
            stage2TotalPicks += 1
            if shade.likelihood.undertoneWarm > shade.likelihood.undertoneCool { stage2WarmCount += 1 }
            if shade.likelihood.depthDeep > shade.likelihood.depthLight { stage2DeepCount += 1 }
        }

        if stage2TotalPicks > 0 {
            reasons.append(contentsOf: stage2AggregateReasons(
                totalPicks: stage2TotalPicks,
                warmCount: stage2WarmCount,
                deepCount: stage2DeepCount
            ))
        }

        // Map log-scores to [-1, +1] via a softening squash so the axis bars
        // stay visually stable even when one axis dominates.
        let undertoneScore = squash(undertoneLog)
        let depthScore = squash(depthLog)

        let headline = buildHeadline(
            undertoneScore: undertoneScore,
            depthScore: depthScore,
            seasonName: topSeasonName
        )

        // Surface the most directional reasons first, cap at 5 to stay scannable.
        let ranked = reasons.sorted { strength($0) > strength($1) }
        return ResultExplanation(
            headline: headline,
            undertoneScore: undertoneScore,
            depthScore: depthScore,
            reasons: Array(ranked.prefix(5))
        )
    }

    // MARK: - Stage 1 → plain-language reasons

    private func stage1Reason(questionId: String, answerId: String) -> ExplainerReason? {
        switch (questionId, answerId) {
        case ("vein_color", "blue_purple"):
            return ExplainerReason(id: "s1_vein_cool", icon: "drop.fill",
                text: "Blue-purple veins suggest cool undertone",
                axis: .undertone, direction: .cool)
        case ("vein_color", "green"):
            return ExplainerReason(id: "s1_vein_warm", icon: "leaf.fill",
                text: "Green-olive veins suggest warm undertone",
                axis: .undertone, direction: .warm)
        case ("vein_color", "mixed"):
            return ExplainerReason(id: "s1_vein_mix", icon: "drop",
                text: "Mixed vein colors — undertone read is subtle",
                axis: .undertone, direction: .neutral)

        case ("jewelry", "gold"):
            return ExplainerReason(id: "s1_gold", icon: "crown.fill",
                text: "Gold flatters you — strong warm signal",
                axis: .undertone, direction: .warm)
        case ("jewelry", "silver"):
            return ExplainerReason(id: "s1_silver", icon: "sparkle",
                text: "Silver flatters you — strong cool signal",
                axis: .undertone, direction: .cool)
        case ("jewelry", "rose"):
            return ExplainerReason(id: "s1_rose", icon: "sparkles",
                text: "Rose gold wins — leans slightly warm",
                axis: .undertone, direction: .warm)

        case ("sun_behavior", "tans_easily"):
            return ExplainerReason(id: "s1_tan", icon: "sun.max.fill",
                text: "You tan easily — warm undertone, deeper value",
                axis: .undertone, direction: .warm)
        case ("sun_behavior", "always_burns"):
            return ExplainerReason(id: "s1_burn", icon: "sun.haze.fill",
                text: "You always burn — cool undertone, lighter value",
                axis: .undertone, direction: .cool)
        case ("sun_behavior", "burns_then_tans"):
            return ExplainerReason(id: "s1_mix_sun", icon: "sun.min.fill",
                text: "Burn-then-tan pattern — undertone read is neutral here",
                axis: .undertone, direction: .neutral)

        case ("whites", "pure_white"):
            return ExplainerReason(id: "s1_white_cool", icon: "square.fill",
                text: "Optical white flatters you — cool undertone",
                axis: .undertone, direction: .cool)
        case ("whites", "cream"):
            return ExplainerReason(id: "s1_white_warm", icon: "circle.fill",
                text: "Cream flatters you — warm undertone",
                axis: .undertone, direction: .warm)

        default:
            return nil
        }
    }

    // MARK: - Stage 2 aggregate reasons

    private func stage2AggregateReasons(totalPicks: Int, warmCount: Int, deepCount: Int) -> [ExplainerReason] {
        var out: [ExplainerReason] = []

        let coolCount = totalPicks - warmCount
        let lightCount = totalPicks - deepCount

        // Undertone lean — only bother narrating if at least 2-to-1.
        if warmCount >= coolCount + 2 {
            out.append(ExplainerReason(
                id: "s2_warm",
                icon: "paintpalette.fill",
                text: "Across \(totalPicks) drapes, warm shades flattered you \(warmCount) times",
                axis: .undertone, direction: .warm
            ))
        } else if coolCount >= warmCount + 2 {
            out.append(ExplainerReason(
                id: "s2_cool",
                icon: "paintpalette.fill",
                text: "Across \(totalPicks) drapes, cool shades flattered you \(coolCount) times",
                axis: .undertone, direction: .cool
            ))
        }

        if deepCount >= lightCount + 2 {
            out.append(ExplainerReason(
                id: "s2_deep",
                icon: "circle.lefthalf.filled",
                text: "You kept picking deeper shades — your skin carries saturation well",
                axis: .depth, direction: .deep
            ))
        } else if lightCount >= deepCount + 2 {
            out.append(ExplainerReason(
                id: "s2_light",
                icon: "circle.lefthalf.filled",
                text: "You kept picking lighter shades — deeper tones washed you out",
                axis: .depth, direction: .light
            ))
        }

        return out
    }

    // MARK: - Headline

    private func buildHeadline(undertoneScore: Double, depthScore: Double, seasonName: String) -> String {
        let undertoneWord: String
        if undertoneScore > 0.25 { undertoneWord = "warm" }
        else if undertoneScore < -0.25 { undertoneWord = "cool" }
        else { undertoneWord = "neutral" }

        let depthWord: String
        if depthScore > 0.25 { depthWord = "deep" }
        else if depthScore < -0.25 { depthWord = "light" }
        else { depthWord = "balanced" }

        return "Your skin reads \(undertoneWord) and \(depthWord) — that's why \(seasonName) scored highest."
    }

    // MARK: - Math

    // Guard against log(0) or negative inputs; clamp to a safe range.
    private func safeLog(_ x: Double) -> Double {
        guard x > 0 else { return 0 }
        return log(x)
    }

    // Soft squash to [-1, +1]. Denominator calibrated so a typical Stage 1 +
    // Stage 2 perfect alignment lands around ±0.85, not saturating at ±1.
    private func squash(_ value: Double) -> Double {
        tanh(value / 2.5)
    }

    // Rank reasons by how directional they are — neutral ones sink.
    private func strength(_ reason: ExplainerReason) -> Double {
        reason.direction == .neutral ? 0 : 1
    }
}
