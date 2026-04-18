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
        whites,
        eyeColor,
        hairColor,
        freckles,
        naturalFlush
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

    // Eye color is a strong undertone + depth signal. Blue/grey → cool;
    // grey-steel → Summer cool muted; green → mild cool; hazel → warm Autumn;
    // amber/honey brown → warm; dark brown/black → depth signal only
    // (warm vs cool can't be read from dark eyes alone — undertone stays neutral).
    static let eyeColor = QuizQuestion(
        id: "eye_color",
        prompt: "What's your natural eye color in daylight?",
        helperText: "No colored contacts — your true iris color.",
        options: [
            QuizAnswer(
                id: "blue_grey",
                label: "Blue or grey-blue",
                detail: nil,
                likelihood: AnswerLikelihood(
                    undertoneWarm: 0.72, undertoneCool: 1.38,
                    depthLight: 1.12, depthDeep: 0.9
                )
            ),
            QuizAnswer(
                id: "grey_steel",
                label: "Grey or steel",
                detail: "Flat, muted grey — not blue-grey",
                likelihood: AnswerLikelihood(undertoneWarm: 0.75, undertoneCool: 1.35)
            ),
            QuizAnswer(
                id: "green_teal",
                label: "Green or teal-green",
                detail: nil,
                likelihood: AnswerLikelihood(undertoneWarm: 0.88, undertoneCool: 1.15)
            ),
            QuizAnswer(
                id: "hazel",
                label: "Hazel — green, gold, and brown mixed",
                detail: nil,
                likelihood: AnswerLikelihood(undertoneWarm: 1.25, undertoneCool: 0.85)
            ),
            QuizAnswer(
                id: "amber_brown",
                label: "Light to medium brown, honey, or amber",
                detail: nil,
                likelihood: AnswerLikelihood(
                    undertoneWarm: 1.3, undertoneCool: 0.82,
                    depthLight: 1.08, depthDeep: 0.95
                )
            ),
            QuizAnswer(
                id: "dark_brown",
                label: "Dark brown or nearly black",
                detail: nil,
                likelihood: AnswerLikelihood(
                    undertoneWarm: 1.0, undertoneCool: 1.0,
                    depthLight: 0.78, depthDeep: 1.3
                )
            )
        ]
    )

    // Hair color is the strongest single physical signal color analysts use.
    // Warm vs cool split on dark hair is the key discriminator between
    // Winter (blue-black) and Dark Autumn (warm dark brown).
    // Weights are the strongest in Stage 1 to reflect this.
    static let hairColor = QuizQuestion(
        id: "hair_color",
        prompt: "Your natural hair color — before any coloring — is closest to:",
        helperText: "If you color it, think about your roots, or what it was as a child.",
        options: [
            QuizAnswer(
                id: "platinum_ash",
                label: "Platinum, ash, or white-blonde",
                detail: "Cool-toned, no golden or yellow",
                likelihood: AnswerLikelihood(
                    undertoneWarm: 0.65, undertoneCool: 1.5,
                    depthLight: 1.35, depthDeep: 0.7
                )
            ),
            QuizAnswer(
                id: "golden_blonde",
                label: "Golden, honey, or strawberry blonde",
                detail: "Warm, yellow or reddish cast",
                likelihood: AnswerLikelihood(
                    undertoneWarm: 1.5, undertoneCool: 0.65,
                    depthLight: 1.25, depthDeep: 0.8
                )
            ),
            QuizAnswer(
                id: "light_brown_cool",
                label: "Light to medium brown — no obvious warmth",
                detail: "Ash, mousy, or flat brown",
                likelihood: AnswerLikelihood(
                    undertoneWarm: 0.88, undertoneCool: 1.15,
                    depthLight: 1.05, depthDeep: 0.95
                )
            ),
            QuizAnswer(
                id: "warm_brown",
                label: "Warm brown, chestnut, auburn, or copper",
                detail: "Warm red or golden cast",
                likelihood: AnswerLikelihood(
                    undertoneWarm: 1.45, undertoneCool: 0.7,
                    depthLight: 0.95, depthDeep: 1.1
                )
            ),
            QuizAnswer(
                id: "dark_warm",
                label: "Dark brown or black — warm",
                detail: "Gold or reddish glints visible in sunlight",
                likelihood: AnswerLikelihood(
                    undertoneWarm: 1.22, undertoneCool: 0.85,
                    depthLight: 0.78, depthDeep: 1.35
                )
            ),
            QuizAnswer(
                id: "dark_cool",
                label: "Dark brown or black — cool",
                detail: "No warmth; looks almost blue-black",
                likelihood: AnswerLikelihood(
                    undertoneWarm: 0.82, undertoneCool: 1.22,
                    depthLight: 0.78, depthDeep: 1.35
                )
            ),
            QuizAnswer(
                id: "red_copper",
                label: "Red or deep copper",
                detail: nil,
                likelihood: AnswerLikelihood(
                    undertoneWarm: 1.5, undertoneCool: 0.65,
                    depthLight: 0.92, depthDeep: 1.12
                )
            )
        ]
    )

    // Freckles are almost exclusively a warm-undertone feature (spring/autumn).
    // Signal is asymmetric: presence is strong warm evidence; absence tells
    // us little because warm deeper skin types often don't freckle either.
    static let freckles = QuizQuestion(
        id: "freckles",
        prompt: "Do you have natural freckles?",
        helperText: "The kind that appear on their own — not sun spots that came in adulthood.",
        options: [
            QuizAnswer(
                id: "yes_many",
                label: "Yes — scattered across my nose and cheeks",
                detail: nil,
                likelihood: AnswerLikelihood(undertoneWarm: 1.6, undertoneCool: 0.65)
            ),
            QuizAnswer(
                id: "yes_few",
                label: "A few — barely noticeable",
                detail: nil,
                likelihood: AnswerLikelihood(undertoneWarm: 1.25, undertoneCool: 0.85)
            ),
            QuizAnswer(
                id: "none",
                label: "None",
                detail: nil,
                likelihood: AnswerLikelihood(undertoneWarm: 0.95, undertoneCool: 1.05)
            ),
            QuizAnswer(
                id: "hard_to_tell",
                label: "Hard to tell on my skin tone",
                detail: nil,
                likelihood: AnswerLikelihood()
            )
        ]
    )

    // The color of your natural flush reveals a lot about skin undertone.
    // Pink = cool (Summer/Winter); peach/coral = warm (Spring); red-orange
    // = warm (Autumn). Depth options cover darker complexions where flush
    // is less visible but undertone can still be read from intensity.
    static let naturalFlush = QuizQuestion(
        id: "natural_flush",
        prompt: "After a workout or hot shower, your face flushes…",
        helperText: "Look in a mirror right after — what's the actual color?",
        options: [
            QuizAnswer(
                id: "pink_rosy",
                label: "Pink or rosy",
                detail: "Clean, cool-toned pink",
                likelihood: AnswerLikelihood(undertoneWarm: 0.8, undertoneCool: 1.35)
            ),
            QuizAnswer(
                id: "peach_coral",
                label: "Peachy or coral",
                detail: "Warm, orange-leaning",
                likelihood: AnswerLikelihood(undertoneWarm: 1.35, undertoneCool: 0.8)
            ),
            QuizAnswer(
                id: "red_orange",
                label: "Red-orange or terracotta",
                detail: "Distinctly warm and ruddy",
                likelihood: AnswerLikelihood(undertoneWarm: 1.2, undertoneCool: 0.85)
            ),
            QuizAnswer(
                id: "deep_red",
                label: "Deep red — subtle on my complexion",
                detail: nil,
                likelihood: AnswerLikelihood(
                    undertoneWarm: 1.05, undertoneCool: 0.95,
                    depthLight: 0.82, depthDeep: 1.22
                )
            ),
            QuizAnswer(
                id: "barely_visible",
                label: "I barely flush at all",
                detail: nil,
                likelihood: AnswerLikelihood(
                    undertoneWarm: 1.0, undertoneCool: 1.0,
                    depthLight: 0.9, depthDeep: 1.12
                )
            )
        ]
    )
}
