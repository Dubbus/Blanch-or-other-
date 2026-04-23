import Foundation

// MARK: - Stage 1 Factual Questions
//
// Phase 3.6 split: questions are now divided into two phases.
//
// Phase A — Family call: cross-family questions that probe undertone + depth.
//   Chroma signals are intentionally stripped from these likelihoods (or
//   ignored by the scorer) because all 12 seasons are in play and chroma
//   is a within-family discriminator, not a cross-family one.
//
// Phase B — Variant discrimination: family-specific questions that probe
//   the chroma/clarity/depth axis to distinguish the 3 variants within
//   the identified family.
//
// Weights are intentionally mild in Phase A (0.65–1.5) — no single answer
// can lock the user into the wrong family. Phase B weights are stronger
// because the posterior is already collapsed to 3 seasons.

enum Stage1Questions {

    // MARK: - Phase A: Family questions (cross-family, chroma-blind)

    static let familyPhaseQuestions: [QuizQuestion] = [
        veinColor,
        jewelry,
        sunBehavior,
        whites,
        eyeColor,
        hairColor,
        freckles,
        naturalFlush
    ]

    // MARK: - Phase B: Variant questions (within-family, chroma-aware)

    static func variantPhaseQuestions(for family: SeasonFamily) -> [QuizQuestion] {
        switch family {
        case .winter: return [contrast, neonTolerance]
        case .spring: return [contrast, springClarity]
        case .summer: return [contrast, summerSoftness]
        case .autumn: return [contrast, autumnRichness]
        }
    }

    // MARK: - Family Phase Questions

    // Classic undertone tell. Blue/purple wrist veins → cool; green → warm.
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

    // Gold = warm, silver/platinum = cool.
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

    // Sun behavior informs undertone + depth. Easy tanners → warm + deeper;
    // always-burners → cool + lighter.
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
                likelihood: AnswerLikelihood()
            ),
            QuizAnswer(
                id: "always_burns",
                label: "Burns and stays burned",
                detail: nil,
                likelihood: AnswerLikelihood(
                    undertoneWarm: 0.85, undertoneCool: 1.2,
                    depthLight: 1.15, depthDeep: 0.9
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

    // Classic drape test for undertone. Pure optical white → cool;
    // cream/ivory → warm. Chroma signals intentionally omitted here —
    // white contrast is a cross-family tell, not a within-family one.
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
            ),
            QuizAnswer(
                id: "unsure_whites",
                label: "Not sure — I've never compared",
                detail: nil,
                likelihood: AnswerLikelihood()
            )
        ]
    )

    // Eye color: strong undertone + depth signal.
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
                likelihood: AnswerLikelihood(
                    undertoneWarm: 0.75, undertoneCool: 1.35
                )
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

    // Natural flush reveals undertone. Pink → cool (Summer/Winter);
    // peach/coral → warm (Spring); red-orange → warm (Autumn).
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
                likelihood: AnswerLikelihood(depthLight: 0.9, depthDeep: 1.12)
            )
        ]
    )

    // MARK: - Variant Phase Questions (chroma-aware, within-family)

    // Contrast applies to all families — key discriminator for vivid vs muted/light variants.
    static let contrast = QuizQuestion(
        id: "contrast",
        prompt: "How much contrast is there between your hair, skin, and eyes?",
        helperText: "Imagine a black-and-white photo of yourself — how different are the tones?",
        options: [
            QuizAnswer(
                id: "high_contrast",
                label: "High contrast",
                detail: "Very different — e.g. dark hair against fair skin, or vivid eyes",
                likelihood: AnswerLikelihood(
                    depthLight: 0.85, depthDeep: 1.15,
                    chromaVivid: 1.4, chromaMuted: 0.75
                )
            ),
            QuizAnswer(
                id: "medium_contrast",
                label: "Medium contrast",
                detail: "Some difference but not striking",
                likelihood: AnswerLikelihood(chromaVivid: 1.05, chromaMuted: 1.05)
            ),
            QuizAnswer(
                id: "low_contrast",
                label: "Low contrast",
                detail: "All similar value — e.g. blonde hair, light skin, light eyes, or all medium-dark",
                likelihood: AnswerLikelihood(
                    depthLight: 1.1, depthDeep: 0.9,
                    chromaVivid: 0.75, chromaMuted: 1.4
                )
            ),
            QuizAnswer(
                id: "unsure_contrast",
                label: "Hard to tell",
                detail: nil,
                likelihood: AnswerLikelihood()
            )
        ]
    )

    // Neon tolerance: primary Bright Winter vs True Winter discriminator.
    static let neonTolerance = QuizQuestion(
        id: "neon_tolerance",
        prompt: "In a neon or ultra-saturated color — electric blue, hot pink, cobalt — you look:",
        helperText: "Imagine a top in that color held up to your face.",
        options: [
            QuizAnswer(
                id: "neon_alive",
                label: "Completely alive — electric and striking",
                detail: "The intensity looks intentional, not costume-y",
                likelihood: AnswerLikelihood(
                    undertoneCool: 1.1,
                    chromaVivid: 1.5, chromaMuted: 0.72
                )
            ),
            QuizAnswer(
                id: "neon_intense",
                label: "Sharp, but icy or pure tones suit me more",
                detail: "Clean and clear yes — neon specifically feels like too much",
                likelihood: AnswerLikelihood(
                    undertoneCool: 1.05,
                    chromaVivid: 0.85, chromaMuted: 1.05
                )
            ),
            QuizAnswer(
                id: "neon_washed",
                label: "Washed out — the color fights my face",
                detail: nil,
                likelihood: AnswerLikelihood(chromaVivid: 0.72, chromaMuted: 1.3)
            ),
            QuizAnswer(
                id: "neon_unsure",
                label: "Honestly not sure — I avoid those colors",
                detail: nil,
                likelihood: AnswerLikelihood()
            )
        ]
    )

    // Spring clarity: discriminates Bright / True / Light Spring.
    // Bright Spring → vivid, electric warm tones.
    // True Spring → clear and warm, not extreme saturation.
    // Light Spring → soft, powdery warm pastels.
    static let springClarity = QuizQuestion(
        id: "spring_clarity",
        prompt: "Which spring palette feels most like you?",
        helperText: "Think about what you're drawn to and what you've been told looks great on you.",
        options: [
            QuizAnswer(
                id: "vivid_spring",
                label: "Vivid, electric spring — hot coral, fuchsia, vivid peach",
                detail: "The brighter, the better",
                likelihood: AnswerLikelihood(
                    undertoneWarm: 1.1,
                    chromaVivid: 1.65, chromaMuted: 0.65
                )
            ),
            QuizAnswer(
                id: "clear_warm_spring",
                label: "Clear and warm — classic coral, warm red-orange, golden yellow",
                detail: "Clear colors, not pastel — but not neon either",
                likelihood: AnswerLikelihood(
                    undertoneWarm: 1.2,
                    chromaVivid: 1.2, chromaMuted: 0.88
                )
            ),
            QuizAnswer(
                id: "soft_pastel_spring",
                label: "Soft, warm pastels — peach blush, warm ivory, powdery apricot",
                detail: "Light and delicate — bold colors feel too much",
                likelihood: AnswerLikelihood(
                    undertoneWarm: 1.1,
                    depthLight: 1.35,
                    chromaVivid: 0.65, chromaMuted: 1.5
                )
            ),
            QuizAnswer(
                id: "spring_unsure",
                label: "Not sure — I wear a mix",
                detail: nil,
                likelihood: AnswerLikelihood()
            )
        ]
    )

    // Summer softness: discriminates Light / True / Soft Summer.
    // Soft Summer → dusty, smoky, heavily muted.
    // True Summer → clean cool, medium muted.
    // Light Summer → light and airy, slightly more clarity than True.
    static let summerSoftness = QuizQuestion(
        id: "summer_softness",
        prompt: "Which cool-toned palette feels most like you?",
        helperText: "Think about colors you reach for instinctively.",
        options: [
            QuizAnswer(
                id: "dusty_muted",
                label: "Dusty, smoky, and grayed — muted mauve, dusty lavender, smoked plum",
                detail: "The more blended and muted the better — pure colors feel harsh",
                likelihood: AnswerLikelihood(
                    undertoneCool: 1.1,
                    chromaVivid: 0.62, chromaMuted: 1.65
                )
            ),
            QuizAnswer(
                id: "clean_medium_cool",
                label: "Clean, medium cool — rose, soft blue, cool berry",
                detail: "Clear enough to look put-together, not too saturated",
                likelihood: AnswerLikelihood(
                    undertoneCool: 1.1,
                    chromaVivid: 0.88, chromaMuted: 1.18
                )
            ),
            QuizAnswer(
                id: "light_airy_cool",
                label: "Light and airy — icy lavender, powder blue, pale rose",
                detail: "Barely-there cool — bold colors overwhelm me",
                likelihood: AnswerLikelihood(
                    undertoneCool: 1.05,
                    depthLight: 1.4,
                    chromaVivid: 0.82, chromaMuted: 1.25
                )
            ),
            QuizAnswer(
                id: "summer_unsure",
                label: "Not sure — I wear a mix",
                detail: nil,
                likelihood: AnswerLikelihood()
            )
        ]
    )

    // Autumn richness: discriminates True / Soft / Dark Autumn.
    // Dark Autumn → rich, deep jewel tones; high contrast.
    // Soft Autumn → muted, dusty earthy; low chroma.
    // True Autumn → balanced warm earthy; neither extreme.
    static let autumnRichness = QuizQuestion(
        id: "autumn_richness",
        prompt: "Which autumn palette feels most like you?",
        helperText: "Think about the depth and intensity of colors that flatter you most.",
        options: [
            QuizAnswer(
                id: "rich_dark",
                label: "Rich and deep — burgundy, forest green, deep plum",
                detail: "Dark, saturated jewel tones — I can handle intensity",
                likelihood: AnswerLikelihood(
                    undertoneWarm: 1.05,
                    depthLight: 0.72, depthDeep: 1.55,
                    chromaVivid: 1.25, chromaMuted: 0.88
                )
            ),
            QuizAnswer(
                id: "warm_balanced",
                label: "Warm and balanced — terracotta, camel, warm olive, spice",
                detail: "Grounded earthy tones — not too deep, not too muted",
                likelihood: AnswerLikelihood(
                    undertoneWarm: 1.2,
                    chromaVivid: 1.12, chromaMuted: 1.08
                )
            ),
            QuizAnswer(
                id: "soft_muted",
                label: "Soft and muted — dusty rose-brown, sage, taupe, warm grey",
                detail: "Gentle, toned-down earthy — bold colors feel too loud",
                likelihood: AnswerLikelihood(
                    undertoneWarm: 1.05,
                    chromaVivid: 0.65, chromaMuted: 1.6
                )
            ),
            QuizAnswer(
                id: "autumn_unsure",
                label: "Not sure — I wear a mix",
                detail: nil,
                likelihood: AnswerLikelihood()
            )
        ]
    )
}
