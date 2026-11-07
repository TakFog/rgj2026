# Temperature Rebalance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Slow the temperature ramp from `0.02` to `0.004` and make every hot-end effect harsher, except coral oxygen regen.

**Architecture:** Data-only tuning in the two balance resources. No code changes: `Game.by_temperature` already lerps each effect from its cold to its hot value, so lowering the hot endpoint increases late-game pressure. The `.gd` defaults stay untouched because unit tests build `BalanceActors.new()`/`BalanceEcosystem.new()` and assert those defaults; only the `.tres` overrides are tuned.

**Tech Stack:** Godot 4.7.2, GDScript `Resource` files.

**Spec:** Approved in the session: `temp_base_rate = 0.004`; hot endpoints `algae_growth_interval_hot = 5`, `egg_death_chance_hot = 0.85`, `co2_interval_hot = 5`, `cyclone_interval_hot = 18`, `fish_speed_hot_factor = 0.35`; `coral_regen_hot_per_sec` and `temp_max_slowdown` unchanged.

## Global Constraints

- Never commit on `main`; work only on `TakFog/balance-temperature`.
- Never stage `project.godot`, `export_presets.cfg`, or the user's modified `core/debug_overlay.gd`.
- Do not change `.gd` defaults: tests assert them.
- Leave `coral_regen_hot_per_sec = -1.5` and `temp_max_slowdown = 0.45` as they are.
- Run `tools/test.sh` and `tools/smoke.sh` before committing.

## Review Focus

- Heat must never stop rising and each effect must still be a linear interpolation of `T`; only endpoints change.
- Slower heat must not make the opening minutes unfair: cold values stay untouched.
- The two populations that can snowball (algae, fish eggs) get the harshest hot endpoints.

---

### Task 1: Tune the balance resources

**Files:**
- Modify: `data/balance_ecosystem.tres`
- Modify: `data/balance_actors.tres`

**Interfaces:**
- Consumes: `Game.by_temperature(cold, hot)` and `ThreatSchedule.interval`.
- Produces: live tuning values read by `TemperatureSystem`, `Algae._process`, `Nest._process`, `Fish`, `Predator`, `Turtle`, `ThreatSchedule`.

- [x] **Step 1: Update `data/balance_ecosystem.tres`**

Set `algae_growth_interval_hot = 5.0`, `egg_death_chance_hot = 0.85`, `temp_base_rate = 0.004`. Keep `coral_regen_hot_per_sec = -1.5` and `temp_max_slowdown = 0.45`.

- [x] **Step 2: Update `data/balance_actors.tres`**

Set `fish_speed_hot_factor = 0.35`, `co2_interval_hot = 5.0`, `cyclone_interval_hot = 18.0`.

- [x] **Step 3: Verify the files load**

Run: `tools/smoke.sh`
Expected: boots without script errors.

### Task 2: Update the GDD

**Files:**
- Modify: `docs/GDD.md` (§5.5 egg death chance, §6 temperature table)

- [x] **Step 1: Update §5.5** to `egg_death_chance_hot` = 0.85 (85%).
- [x] **Step 2: Update §6** to `temp_base_rate` = 0.004 (T=1 in ~4 min without corals, ~7.5 min with maximum coral slowdown) and the hot column of the effects table (5 s algae, 5 s CO₂, 18 s cyclone, 35% speed, 85% egg death).

### Task 3: Verify and commit

- [x] **Step 1: Run `tools/test.sh`** — expected 200+ passed, 0 failed.
- [x] **Step 2: Run `tools/smoke.sh`** — expected OK.
- [x] **Step 3: Stage only the four intended files** (two `.tres`, `docs/GDD.md`, this plan) and commit in English.
