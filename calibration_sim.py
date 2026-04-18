#!/usr/bin/env python3
"""
Bayesian season scorer simulation.
Mirrors BayesianSeasonScorer.swift exactly to verify confidence levels
for archetype profiles after Stage 1 and Stage 2.
"""

seasons = [
    {"name": "Deep Winter",   "category": "winter", "undertone": "cool"},
    {"name": "True Winter",   "category": "winter", "undertone": "cool"},
    {"name": "Bright Winter", "category": "winter", "undertone": "cool"},
    {"name": "Light Spring",  "category": "spring", "undertone": "warm"},
    {"name": "True Spring",   "category": "spring", "undertone": "warm"},
    {"name": "Bright Spring", "category": "spring", "undertone": "warm"},
    {"name": "Light Summer",  "category": "summer", "undertone": "cool"},
    {"name": "True Summer",   "category": "summer", "undertone": "cool"},
    {"name": "Soft Summer",   "category": "summer", "undertone": "cool"},
    {"name": "Soft Autumn",   "category": "autumn", "undertone": "warm"},
    {"name": "True Autumn",   "category": "autumn", "undertone": "warm"},
    {"name": "Dark Autumn",   "category": "autumn", "undertone": "warm"},
]

def depth_weight(category, lk):
    dL, dD = lk.get("depthLight", 1.0), lk.get("depthDeep", 1.0)
    if category == "spring": return dL
    if category == "winter": return dD
    if category == "summer": return dL * 0.5 + 1.0 * 0.5
    if category == "autumn": return dD * 0.5 + 1.0 * 0.5
    return 1.0

def chroma_weight(name, lk):
    v = lk.get("chromaVivid", 1.0) - 1.0
    m = lk.get("chromaMuted", 1.0) - 1.0
    fracs = {
        "Bright Winter":  (1.0,  0.0),
        "Bright Spring":  (1.0,  0.0),
        "True Winter":    (0.6,  0.0),
        "True Spring":    (0.6,  0.0),
        "Deep Winter":    (0.15, 0.1),
        "Dark Autumn":    (0.1,  0.35),
        "Light Spring":   (0.25, 0.15),
        "Light Summer":   (0.1,  0.35),
        "True Summer":    (0.0,  0.6),
        "True Autumn":    (0.15, 0.3),
        "Soft Summer":    (0.0,  1.0),
        "Soft Autumn":    (0.0,  1.0),
    }
    vf, mf = fracs.get(name, (0.0, 0.0))
    return 1.0 + v * vf + m * mf

def likelihood_weight(season, lk):
    undertone = lk.get("undertoneWarm", 1.0) if season["undertone"] == "warm" \
                else lk.get("undertoneCool", 1.0)
    depth  = depth_weight(season["category"], lk)
    chroma = chroma_weight(season["name"], lk)
    return undertone * depth * chroma

def update(posterior, lk):
    updated = {s["name"]: posterior[s["name"]] * likelihood_weight(s, lk)
               for s in seasons}
    total = sum(updated.values())
    return {k: v / total for k, v in updated.items()}

def initial():
    u = 1.0 / len(seasons)
    return {s["name"]: u for s in seasons}

def run(answers, label):
    p = initial()
    for lk in answers:
        p = update(p, lk)
    ranked = sorted(p.items(), key=lambda x: -x[1])
    print(f"\n{'='*55}")
    print(f"Profile: {label}")
    print(f"{'='*55}")
    for name, prob in ranked[:6]:
        bar = "█" * int(prob * 40)
        print(f"  {name:<22} {prob*100:5.1f}%  {bar}")
    top = ranked[0]
    family_mass = sum(v for k, v in p.items()
                      if any(s["category"] == next(x["category"] for x in seasons if x["name"] == top[0])
                             and k == s["name"] for s in seasons))
    # simpler: top-family mass
    top_cat = next(s["category"] for s in seasons if s["name"] == top[0])
    fam = sum(v for k, v in p.items()
              if next(s["category"] for s in seasons if s["name"] == k) == top_cat)
    print(f"\n  Top season:  {top[0]} ({top[1]*100:.1f}%)")
    print(f"  Top family:  {top_cat} ({fam*100:.1f}%)")

# ── Stage 1 answer sets ────────────────────────────────────────────────────────

# Perfect Soft Summer: cool, muted, light-medium
stage1_soft_summer = [
    {"undertoneCool": 1.4,  "undertoneWarm": 0.7},   # veins: blue/purple
    {"undertoneCool": 1.4,  "undertoneWarm": 0.75},  # jewelry: silver
    {"undertoneCool": 1.25, "undertoneWarm": 0.8,
     "depthLight": 1.25, "depthDeep": 0.8},           # sun: always burns
    {"undertoneCool": 1.35, "undertoneWarm": 0.75,
     "chromaVivid": 0.75, "chromaMuted": 1.35},       # whites: cream
    {"undertoneCool": 1.35, "undertoneWarm": 0.72,
     "depthLight": 1.12, "depthDeep": 0.9,
     "chromaVivid": 0.88, "chromaMuted": 1.25},       # eyes: grey/steel
    {"undertoneCool": 1.5,  "undertoneWarm": 0.65,
     "depthLight": 1.35, "depthDeep": 0.7,
     "chromaVivid": 0.85, "chromaMuted": 1.2},        # hair: platinum/ash
    {"undertoneCool": 1.05, "undertoneWarm": 0.95},   # freckles: none
    {"undertoneCool": 1.35, "undertoneWarm": 0.8,
     "chromaVivid": 0.9, "chromaMuted": 1.12},        # flush: red-orange (muted cool)
]

# Perfect Bright Winter: cool, vivid, deep/medium
stage1_bright_winter = [
    {"undertoneCool": 1.4,  "undertoneWarm": 0.7},
    {"undertoneCool": 1.4,  "undertoneWarm": 0.75},
    {"undertoneCool": 1.25, "undertoneWarm": 0.8,
     "depthLight": 1.25, "depthDeep": 0.8},
    {"undertoneCool": 1.35, "undertoneWarm": 0.75,
     "chromaVivid": 1.35, "chromaMuted": 0.75},       # whites: crisp white
    {"undertoneCool": 1.38, "undertoneWarm": 0.72,
     "depthLight": 1.12, "depthDeep": 0.9,
     "chromaVivid": 1.15, "chromaMuted": 0.95},       # eyes: blue/grey-blue
    {"undertoneCool": 1.22, "undertoneWarm": 0.82,
     "depthLight": 0.78, "depthDeep": 1.35,
     "chromaVivid": 1.2, "chromaMuted": 0.88},        # hair: dark cool
    {"undertoneCool": 1.05, "undertoneWarm": 0.95},   # freckles: none
    {"undertoneCool": 1.35, "undertoneWarm": 0.8,
     "chromaVivid": 1.15, "chromaMuted": 0.92},       # flush: pink
]

# Perfect True Autumn: warm, muted, medium-deep
stage1_true_autumn = [
    {"undertoneWarm": 1.4,  "undertoneCool": 0.7},
    {"undertoneWarm": 1.4,  "undertoneCool": 0.75},
    {"undertoneWarm": 1.3,  "undertoneCool": 0.85,
     "depthLight": 0.85, "depthDeep": 1.2},
    {"undertoneWarm": 1.35, "undertoneCool": 0.75,
     "chromaVivid": 0.75, "chromaMuted": 1.35},       # whites: cream
    {"undertoneWarm": 1.25, "undertoneCool": 0.85},   # eyes: hazel
    {"undertoneWarm": 1.45, "undertoneCool": 0.7,
     "depthLight": 0.95, "depthDeep": 1.1},           # hair: warm brown/chestnut
    {"undertoneWarm": 1.6,  "undertoneCool": 0.65},   # freckles: yes many
    {"undertoneWarm": 1.2,  "undertoneCool": 0.85,
     "chromaVivid": 0.9, "chromaMuted": 1.12},        # flush: red-orange
]

# Perfect Light Spring: warm, vivid, light
stage1_light_spring = [
    {"undertoneWarm": 1.4,  "undertoneCool": 0.7},
    {"undertoneWarm": 1.4,  "undertoneCool": 0.75},
    {"undertoneWarm": 1.3,  "undertoneCool": 0.85,
     "depthLight": 1.25, "depthDeep": 0.8},           # sun: tans easily
    {"undertoneWarm": 1.35, "undertoneCool": 0.75,
     "chromaVivid": 0.75, "chromaMuted": 1.35},       # whites: cream (springs lean cream)
    {"undertoneWarm": 1.3,  "undertoneCool": 0.82,
     "depthLight": 1.08, "depthDeep": 0.95},          # eyes: amber/honey brown
    {"undertoneWarm": 1.5,  "undertoneCool": 0.65,
     "depthLight": 1.25, "depthDeep": 0.8,
     "chromaVivid": 1.2, "chromaMuted": 0.9},         # hair: golden/honey blonde
    {"undertoneWarm": 1.25, "undertoneCool": 0.85},   # freckles: a few
    {"undertoneWarm": 1.35, "undertoneCool": 0.8,
     "chromaVivid": 1.1, "chromaMuted": 0.95},        # flush: peach/coral
]

run(stage1_soft_summer,   "Soft Summer (Stage 1 only)")
run(stage1_bright_winter, "Bright Winter (Stage 1 only)")
run(stage1_true_autumn,   "True Autumn (Stage 1 only)")
run(stage1_light_spring,  "Light Spring (Stage 1 only)")

# ── Stage 2 shades ─────────────────────────────────────────────────────────────
shades = {
    "cool_berry":  {"undertoneWarm": 0.55, "undertoneCool": 1.8,
                    "depthLight": 0.8, "depthDeep": 1.2,
                    "chromaVivid": 1.3, "chromaMuted": 0.82},
    "dusty_rose":  {"undertoneWarm": 0.65, "undertoneCool": 1.6,
                    "depthLight": 1.2, "depthDeep": 0.85,
                    "chromaVivid": 0.78, "chromaMuted": 1.45},
    "blue_red":    {"undertoneWarm": 0.5, "undertoneCool": 1.9,
                    "depthLight": 0.9, "depthDeep": 1.1,
                    "chromaVivid": 1.6, "chromaMuted": 0.65},
    "soft_mauve":  {"undertoneWarm": 0.7, "undertoneCool": 1.5,
                    "depthLight": 1.15, "depthDeep": 0.9,
                    "chromaVivid": 0.7, "chromaMuted": 1.55},
    "warm_coral":  {"undertoneWarm": 1.8, "undertoneCool": 0.55,
                    "depthLight": 1.2, "depthDeep": 0.85,
                    "chromaVivid": 1.45, "chromaMuted": 0.78},
    "orange_red":  {"undertoneWarm": 1.9, "undertoneCool": 0.5,
                    "depthLight": 0.85, "depthDeep": 1.2,
                    "chromaVivid": 1.25, "chromaMuted": 0.85},
    "terracotta":  {"undertoneWarm": 1.7, "undertoneCool": 0.6,
                    "depthLight": 0.8, "depthDeep": 1.25,
                    "chromaVivid": 0.72, "chromaMuted": 1.5},
    "peach_nude":  {"undertoneWarm": 1.55, "undertoneCool": 0.7,
                    "depthLight": 1.3, "depthDeep": 0.8,
                    "chromaVivid": 0.88, "chromaMuted": 1.2},
}

def run_stage2(stage1_answers, stage2_wins, label):
    p = initial()
    for lk in stage1_answers:
        p = update(p, lk)
    for shade_id in stage2_wins:
        p = update(p, shades[shade_id])
    ranked = sorted(p.items(), key=lambda x: -x[1])
    print(f"\n{'='*55}")
    print(f"Profile: {label}")
    print(f"{'='*55}")
    for name, prob in ranked[:6]:
        bar = "█" * int(prob * 40)
        print(f"  {name:<22} {prob*100:5.1f}%  {bar}")
    top = ranked[0]
    top_cat = next(s["category"] for s in seasons if s["name"] == top[0])
    fam = sum(v for k, v in p.items()
              if next(s["category"] for s in seasons if s["name"] == k) == top_cat)
    print(f"\n  Top season:  {top[0]} ({top[1]*100:.1f}%)")
    print(f"  Top family:  {top_cat} ({fam*100:.1f}%)")

# Stage 2: Soft Summer wins muted/cool shades
run_stage2(stage1_soft_summer, ["soft_mauve", "dusty_rose", "soft_mauve", "dusty_rose"],
           "Soft Summer (Stage 1 + 4 Stage 2 pairs)")

# Stage 2: Bright Winter wins vivid/cool shades
run_stage2(stage1_bright_winter, ["blue_red", "cool_berry", "blue_red", "cool_berry"],
           "Bright Winter (Stage 1 + 4 Stage 2 pairs)")

# Stage 2: True Autumn — information-gain pairs pit warm vs cool.
# True Autumn consistently wins WARM over cool. The distinguishing factor vs Soft Autumn:
# True Autumn wins orange_red (vivid warm) vs soft_mauve — Soft Autumn would prefer soft_mauve.
# Three vivid-warm wins + one muted-warm win correctly routes to True vs Soft Autumn.
run_stage2(stage1_true_autumn, ["warm_coral", "orange_red", "orange_red", "terracotta"],
           "True Autumn (Stage 1 + 4 Stage 2 pairs)")

# Stage 2: Light Spring — wins peach/light warm over all cool shades
# Prefers peach_nude (light muted-warm) over cool shades; warm_coral beats cool berry
run_stage2(stage1_light_spring, ["peach_nude", "peach_nude", "warm_coral", "peach_nude"],
           "Light Spring (Stage 1 + 4 Stage 2 pairs)")

# Stage 2 + tiebreaker (2x weight on one more pick)
def run_with_tiebreaker(stage1_answers, stage2_wins, tb_win, label):
    p = initial()
    for lk in stage1_answers:
        p = update(p, lk)
    for shade_id in stage2_wins:
        p = update(p, shades[shade_id])
    # tiebreaker = 2x weight
    p = update(p, shades[tb_win])
    p = update(p, shades[tb_win])
    ranked = sorted(p.items(), key=lambda x: -x[1])
    print(f"\n{'='*55}")
    print(f"Profile: {label}")
    print(f"{'='*55}")
    for name, prob in ranked[:4]:
        bar = "█" * int(prob * 40)
        print(f"  {name:<22} {prob*100:5.1f}%  {bar}")
    print(f"\n  Top season: {ranked[0][0]} ({ranked[0][1]*100:.1f}%)")

run_with_tiebreaker(stage1_soft_summer, ["soft_mauve", "dusty_rose", "soft_mauve", "dusty_rose"],
                    "soft_mauve", "Soft Summer (+ tiebreaker)")
run_with_tiebreaker(stage1_bright_winter, ["blue_red", "cool_berry", "blue_red", "cool_berry"],
                    "blue_red", "Bright Winter (+ tiebreaker)")
run_with_tiebreaker(stage1_true_autumn, ["warm_coral", "orange_red", "orange_red", "terracotta"],
                    "orange_red", "True Autumn (+ tiebreaker)")
run_with_tiebreaker(stage1_light_spring, ["peach_nude", "peach_nude", "warm_coral", "peach_nude"],
                    "peach_nude", "Light Spring (+ tiebreaker)")
