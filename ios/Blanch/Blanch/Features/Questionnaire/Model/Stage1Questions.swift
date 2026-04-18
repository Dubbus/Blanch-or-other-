import Foundation

// MARK: - Stage 1 Factual Questions
//
// Four undertone/depth questions drawn from traditional color-analyst intake.
// Likelihoods are deliberately mild (0.7–1.4) — each question is weak evidence,
// the posterior firms up only after all four. This keeps any single mis-answer
// from locking the user into the wrong season.

enum Stage1Questions {
    static let all: [QuizQuestion] = [
        veinColor,
        jewelry,
        sunBehavior,
        whites
    ]

    // Classic undertone tell. Blue/purple wrist veins correlate with cool
    // undertones; green with warm. "Can't tell" is genuinely neutral.
    static let veinColor = QuizQuestion(
        id: "vein_color",
        prompt: "Look at the veins on the inside of your wrist in natural light.",
        helperText: "What color are they?",
        options: [
            QuizAnswer(
                id: "blue_purple",
                label: "Blue or purple",
                detail: nil,
                likelihood: AnswerLikelihood(undertoneWarm: 0.7, undertoneCool: 1.4)
            ),
            QuizAnswer(
                id: "green",
                label: "Green or olive",
                detail: nil,
                likelihood: AnswerLikelihood(undertoneWarm: 1.4, undertoneCool: 0.7)
            ),
            QuizAnswer(
                id: "mixed",
                label: "A mix — some blue, some green",
                detail: nil,
                likelihood: AnswerLikelihood(undertoneWarm: 1.05, undertoneCool: 1.05)
            ),
            QuizAnswer(
                id: "unsure",
                label: "Honestly can't tell",
                detail: nil,
                likelihood: AnswerLikelihood()
            )
        ]
    )

    // Gut preference — not "what do you own," but which makes you feel
    // more polished. Gold = warm, silver/platinum = cool.
    static let jewelry = QuizQuestion(
        id: "jewelry",
        prompt: "Which metal makes your skin glow?",
        helperText: "Not what you own — what looks right against your face.",
        options: [
            QuizAnswer(
                id: "gold",
                label: "Gold",
                detail: "Warm yellow gold flatters me",
                likelihood: AnswerLikelihood(undertoneWarm: 1.4, undertoneCool: 0.75)
            ),
            QuizAnswer(
                id: "silver",
                label: "Silver or platinum",
                detail: "Cool tones make my skin look brighter",
                likelihood: AnswerLikelihood(undertoneWarm: 0.75, undertoneCool: 1.4)
            ),
            QuizAnswer(
                id: "rose",
                label: "Rose gold",
                detail: "The in-between usually wins",
                likelihood: AnswerLikelihood(undertoneWarm: 1.15, undertoneCool: 1.0)
            ),
            QuizAnswer(
                id: "both",
                label: "Both work equally",
                detail: nil,
                likelihood: AnswerLikelihood()
            )
        ]
    )

    // Sun behavior informs BOTH undertone and depth. Easy tanners skew
    // warm and often deeper-seasoned; always-burners skew cool and lighter.
    static let sunBehavior = QuizQuestion(
        id: "sun_behavior",
        prompt: "In the sun without SPF, your skin…",
        helperText: nil,
        options: [
            QuizAnswer(
                id: "tans_easily",
                label: "Tans easily, rarely burns",
                detail: nil,
                likelihood: AnswerLikelihood(
                    undertoneWarm: 1.3, undertoneCool: 0.85,
                    depthLight: 0.85, depthDeep: 1.2
                )
            ),
            QuizAnswer(
                id: "burns_then_tans",
                label: "Burns first, then tans",
                detail: nil,
                likelihood: AnswerLikelihood(
                    undertoneWarm: 1.0, undertoneCool: 1.0,
                    depthLight: 1.0, depthDeep: 1.0
                )
            ),
            QuizAnswer(
                id: "always_burns",
                label: "Burns and stays burned",
                detail: nil,
                likelihood: AnswerLikelihood(
                    undertoneWarm: 0.8, undertoneCool: 1.25,
                    depthLight: 1.25, depthDeep: 0.8
                )
            ),
            QuizAnswer(
                id: "never_changes",
                label: "Stays the same year-round",
                detail: nil,
                likelihood: AnswerLikelihood()
            )
        ]
    )

    // Classic drape test for undertone. Pure optical white against a
    // warm undertone reads harsh; cream/ivory against cool reads sallow.
    static let whites = QuizQuestion(
        id: "whites",
        prompt: "Which white shirt is more flattering against your face?",
        helperText: "Think about photos of yourself — which one doesn't wash you out?",
        options: [
            QuizAnswer(
                id: "pure_white",
                label: "Crisp, optical white",
                detail: "Clean and bright",
                likelihood: AnswerLikelihood(undertoneWarm: 0.75, undertoneCool: 1.35)
            ),
            QuizAnswer(
                id: "cream",
                label: "Cream or ivory",
                detail: "Softer, yellow-tinged",
                likelihood: AnswerLikelihood(undertoneWarm: 1.35, undertoneCool: 0.75)
            ),
            QuizAnswer(
                id: "both",
                label: "Both look fine",
                detail: nil,
                likelihood: AnswerLikelihood()
            )
        ]
    )
}
