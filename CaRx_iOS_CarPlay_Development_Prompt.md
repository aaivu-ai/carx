# Development Prompt: CaRx — iOS + CarPlay OBD-II Diagnostic App

Paste this whole document into your coding agent (Claude Code, Xcode's Claude integration, etc.) as the build brief for the app.

---

## 1. App Summary

Build **CaRx**, a native iOS app (Swift/SwiftUI) with a companion **CarPlay** scene that connects to an **ELM327 OBD-II adapter over Bluetooth (BLE) or Wi‑Fi** — user-selectable per session/vehicle profile — and turns the car's live sensor data and trouble codes into a modern, futuristic, fully configurable dashboard.

Core capabilities:
1. Configurable dashboard of gauges and cards (add/remove/resize/reorder).
2. Real-time DTC (trouble code) reading, with description lookup.
3. Erase/clear DTCs (with confirmation).
4. Real-time charts for selected sensors.
5. Multi-series charts — pick multiple sensors, each with its own configurable value range/axis, plotted together.
6. Multi-vehicle support with model-specific PID packs — ship built-in profiles for at least **2014 Chevrolet Cruze**, **2015 BMW**, and **2020 Ram 1500**, each surfacing that vehicle's manufacturer-specific sensors in addition to standard OBD-II PIDs (see §5b).
7. CarPlay presence for use while driving, within Apple's actual CarPlay capabilities (see §8 — this is a hard platform constraint, not a design choice).

---

## 2. Platform & Tech Stack

- **Language/UI:** Swift 5.10+, SwiftUI, Swift Concurrency (`async/await`, `AsyncStream`), Combine only where SwiftUI bindings need it.
- **Min iOS target:** iOS 17 (use `Observable` macro, Swift Charts, SwiftData).
- **Persistence:** SwiftData for dashboard layouts, vehicle profiles, DTC history, session logs. `UserDefaults`/`AppStorage` for lightweight settings (connection mode, units).
- **Charting:** Swift Charts (`Charts` framework) for line charts and multi-series overlays — do not hand-roll Canvas drawing for charts, use the native framework for accessibility, animation and dark-mode support for free.
- **Connectivity:**
  - Bluetooth: `CoreBluetooth` (BLE). Most consumer ELM327 "Bluetooth" adapters are classic SPP (Bluetooth Classic), which **iOS cannot access without an MFi chip** — iOS has no public Bluetooth Classic RFCOMM API. Scope Bluetooth support explicitly to **BLE ELM327 adapters** (e.g. Vgate iCar Pro BLE, OBDLink CX/MX+) that expose a UART-style GATT service. Document this limitation clearly in onboarding/adapter picker copy so users buy compatible hardware.
  - Wi‑Fi: `Network` framework (`NWConnection` over TCP), targeting the typical ELM327 Wi‑Fi adapter default of `192.168.0.10:35000`, configurable host/port in settings.
- **Architecture:** MVVM + a protocol-oriented transport layer so Bluetooth/Wi‑Fi/mock are interchangeable implementations of one `OBDTransport` protocol.
- **App icon / brand:** Dark, futuristic, neon-accented "CaRx" wordmark (car + diagnosis/Rx pun) — see §9 for visual direction.

---

## 3. Architecture Overview

```
CaRx/
├── App/
│   ├── CaRxApp.swift                 // @main, SwiftData container setup
│   └── CarPlaySceneDelegate.swift    // CPTemplateApplicationSceneDelegate
├── Transport/
│   ├── OBDTransport.swift            // protocol: connect(), send(_:), responses: AsyncStream<String>
│   ├── BLEELM327Transport.swift      // CoreBluetooth implementation
│   ├── WiFiELM327Transport.swift     // Network.framework implementation
│   └── MockTransport.swift           // simulated data for previews/dev without hardware
├── OBD/
│   ├── ELM327Session.swift           // AT command handshake, protocol negotiation, header switching
│   ├── PID.swift                     // PID model + decoder closures (mirrors Android SensorPid)
│   ├── PIDRegistry.swift             // standard SAE PIDs + extensible manufacturer PID sets
│   ├── DTCParser.swift               // Mode 03/07/0A response → DiagnosticCode
│   ├── DTCDatabase.swift             // P/B/C/U code → human description lookup (bundle JSON)
│   └── VehiclePacks/                 // bundled JSON: cruze_2014.json, bmw_2015.json, ram1500_2020.json
├── Models/ (SwiftData)
│   ├── VehicleProfile.swift          // name, connection type, address/host, selected PID pack
│   ├── DashboardLayout.swift         // named layout, ordered list of WidgetConfig
│   ├── WidgetConfig.swift            // widget type, pid id(s), gauge range override, size
│   └── ChartPreset.swift             // saved multi-series chart: pid ids + per-series range + window
├── Features/
│   ├── Dashboard/                    // gauges/cards grid, edit mode
│   ├── Gauges/                       // RadialGaugeView, LinearBarGaugeView, DigitalCardView, SparklineCardView
│   ├── DTC/                          // live DTC list, freeze frame, clear codes flow
│   ├── Charts/                       // single-sensor chart, multi-series chart builder
│   ├── Onboarding/                   // adapter type picker, pairing/connect flow
│   └── Settings/                     // units, vehicle profiles, manufacturer PID packs
└── CarPlay/
    ├── CarPlayDashboardController.swift  // CPListTemplate/CPGridTemplate live values
    └── CarPlayDTCController.swift        // CPInformationTemplate for DTC status
```

Data flow: `Transport` emits raw ASCII lines → `ELM327Session` handles AT handshake/header switching and decodes `PID` responses → publishes a `@Observable` `TelemetryStore` (`[PIDID: RollingBuffer<Double>]`) → both the SwiftUI dashboard/charts and the CarPlay controller read from the same store, so phone and car screen never drift.

---

## 4. Connectivity Layer

Requirements:
- A `ConnectionMode` enum: `.bluetoothLE`, `.wifi`. Selectable per `VehicleProfile`, changeable in Settings without restarting the app.
- Unified `OBDTransport` protocol:
  ```swift
  protocol OBDTransport {
      func connect() async throws
      func disconnect()
      func send(_ command: String) async throws
      var incomingLines: AsyncStream<String> { get }
      var connectionState: AsyncStream<ConnectionState> { get }
  }
  ```
- `ELM327Session` owns the standard init sequence and must be transport-agnostic:
  `ATZ` → `ATE0` (echo off) → `ATL0` (linefeeds off) → `ATH1` (headers on, needed to distinguish ECM/TCM responses) → `ATSP0` (auto protocol) → per-PID `AT SH <header>` switching when polling manufacturer-specific PIDs on non-default headers (mirrors the GM-LAN ECM `7E0`/TCM `7E1` pattern from the Android app).
- Reconnect/backoff logic: auto-retry with exponential backoff on drop, surfaced as a connection state banner, never silently fail mid-drive.
- BLE: scan filtered to known ELM327 BLE service UUIDs, list discovered peripherals for pairing, persist last-used peripheral identifier per `VehicleProfile`.
- Wi‑Fi: manual host/port entry (default `192.168.0.10:35000`), with a "Test Connection" action before saving a profile.
- All socket/BLE I/O on a background actor; never touch the UI thread with raw I/O.

---

## 5. OBD-II PID Engine

- Ship the full standard SAE J1979 Mode 01 PID set (RPM, speed, coolant temp, intake temp, MAF, throttle position, fuel level, O2 sensors, timing advance, etc.) as the default registry — do not hardcode only a handful.
- Support **manufacturer-specific PID packs** as data (JSON or Swift structs bundled per make/model), following the same shape as the Cruze example: id, display name, request (`mode+pid` hex string), target ECU header, unit, expected min/max, and a decoder closure/function. Ship the three built-in packs specified in §5b so the extensibility is proven with real target vehicles, not just declared.
- `PID` model:
  ```swift
  struct PID: Identifiable {
      let id: String
      let name: String
      let request: String       // e.g. "010C"
      let header: String        // e.g. "7E0"
      let unit: String
      let range: ClosedRange<Double>
      let decode: (Data) -> Double
  }
  ```
- Polling loop: round-robins only the PIDs actually in use by the active dashboard layout + open charts (don't poll everything always — this is what keeps refresh rate high on slow ELM327 clones). Adaptive: increase priority/frequency for PIDs on visible gauges, lower for backgrounded ones.
- Rolling buffer per PID (configurable retention, default ~120 samples / ~2 min at 1Hz) backing both gauges (latest value) and charts (history).

---

## 5b. Multi-Vehicle Support & Built-in PID Packs

CaRx must ship with at least **three built-in vehicle profiles**, each pairing the standard SAE PID set with a manufacturer-specific "enhanced PID" pack and a sensible default dashboard layout:

| Vehicle | Platform / ECU access | Enhanced PIDs to include |
|---|---|---|
| **2014 Chevrolet Cruze** (1.4L Turbo) | GM-LAN, mode `22` extended PIDs, ECM header `7E0`, TCM header `7E1` | Turbo boost pressure, transmission fluid temperature, high-res engine coolant temp (already specified in §5's Cruze example — reuse those values, they've been validated in the sibling Android app) |
| **2015 BMW** (N20/N55-era 4/6-cyl, e.g. 3-Series/X-Series) | ISO 15765 CAN, mode `22` extended PIDs, typical diagnostic gateway header `6F1` (verify per chassis) | Engine oil temperature, battery/IBS (intelligent battery sensor) voltage & state of charge, turbo boost pressure |
| **2020 Ram 1500** (5.7L HEMI / 3.6L Pentastar / 3.0L EcoDiesel) | FCA/Stellantis CAN, mode `22` extended PIDs, ECM header `7E0` | Transmission fluid temperature, engine oil temperature, turbo boost pressure (EcoDiesel), DEF (diesel exhaust fluid) level (diesel trims) |

**Important — read before hardcoding hex values:** manufacturer-specific/enhanced PIDs are *not* published by GM, BMW, or FCA. They're reverse-engineered by the enthusiast/tuning community and can vary by exact trim, engine code, model-year mid-cycle ECU revision, and even software calibration. Do not treat any BMW or Ram hex PID you or an AI coding assistant generates as ground truth — treat it as a **placeholder to verify against a real vehicle** (via a wideband scan tool, factory service documentation, or community references like Torque Pro's manufacturer plugins/forums for that specific chassis/engine code) before shipping it as a trusted reading. The Cruze values are the exception, since they're already carried over from the validated Android sibling app.

To make this safe and correct in practice:
- Model the PID packs as **data** (bundled JSON per vehicle, not hardcoded Swift literals), so incorrect hex codes can be corrected without a code change/App Store release.
- Mark every enhanced PID with a `verified: Bool` flag. Unverified PIDs display in the UI with a small "unverified" badge/tooltip until a user confirms the reading looks sane for their car (or explicitly marks it verified in Settings).
- Include a **raw diagnostic / discovery tool** (Settings → Advanced) that lets a user send an arbitrary `mode+PID` hex string at an arbitrary header and see the raw response — this is how the enhanced PID packs get built and corrected against real hardware, and it's the standard workflow the OBD hobbyist community already uses.
- Vehicle selection (onboarding or Settings → Vehicle Profile) picks one of the three built-in profiles (or a "Generic/Standard OBD-II only" profile for unsupported vehicles), which auto-loads that pack's PIDs into the registry and pre-populates the default dashboard with that vehicle's most relevant widgets (e.g. Cruze → boost + trans temp front and center; BMW → oil temp + battery IBS; Ram diesel → boost + DEF level).
- Architecture must make adding a 4th, 5th, Nth vehicle pack trivial — dropping in a new JSON pack file should be the only work required, no core code changes.

---

## 6. Dashboard (Configurable Gauges & Cards)

- Grid-based, edit-mode dashboard (long-press or an explicit "Edit Layout" button) — drag to reorder, pinch/handle to resize, tap "+" to add a widget, swipe to remove.
- Widget types, each bindable to any PID:
  - **Radial gauge** — animated needle/arc, configurable min/max/redline zone.
  - **Linear bar gauge** — horizontal/vertical fill bar with threshold coloring.
  - **Digital card** — big numeric readout + unit + trend arrow.
  - **Sparkline card** — numeric readout with a small embedded trend line (last N samples).
- Multiple named dashboard layouts (e.g. "Track Mode", "Daily Driver", "Diagnostics"), quick-switch via a segmented control or tab bar; persisted via SwiftData.
- Per-widget range override: default to the PID's declared range but let the user set a custom min/max/redline (e.g. narrower boost gauge range for a specific build).
- Live connection-state indicator always visible (connected / reconnecting / disconnected), not buried in settings.

---

## 7. DTC (Trouble Codes) — Read & Erase

- Real-time DTC panel: poll Mode 03 (current codes), Mode 07 (pending codes), Mode 0A (permanent codes) and clearly section them in the UI (Current / Pending / Permanent).
- Each code shows: raw code (e.g. `P0234`), decoded description from a bundled DTC description database (ship a reasonably complete generic P/B/C/U code JSON; note in code where a user could extend it with manufacturer-specific code text), and status.
- Freeze frame data (Mode 02) shown when available for a selected current code.
- **Erase codes** (Mode 04): require an explicit confirmation dialog ("Clear all stored trouble codes? This cannot be undone.") before sending — never clear on a single tap. After clearing, re-poll to confirm codes are gone and show a success/failure state (some ECUs reject clear while engine is running/MIL conditions unmet — surface that failure clearly rather than assuming success).
- Log DTC read/clear events with timestamp to session history (SwiftData) for later review.

---

## 8. Charts (Single & Multi-Series)

- **Single-sensor chart:** tap any dashboard widget to open a full-screen live chart for that PID (Swift Charts `LineMark`, animated, auto-scrolling time window, pause/resume/scrub).
- **Multi-series chart builder:**
  - Sensor picker (multi-select from the full PID registry, not just what's on the dashboard).
  - Per-series Y-axis range: since PIDs have wildly different scales (RPM vs. boost PSI vs. coolant temp), let the user set each series' own min/max, and either (a) normalize all series to a shared 0–100% axis for visual overlay, or (b) show a couple of independent Y-axes — pick whichever Swift Charts can render cleanly (normalized-overlay is simpler and looks better; implement that first, independent axes as a stretch goal).
  - Configurable time window (30s / 1m / 5m / session-so-far).
  - Save a multi-series configuration as a named **Chart Preset** (SwiftData) for reuse.
  - Export a session's chart data to CSV via the share sheet.

---

## 9. Visual Design Direction — "Modern & Futuristic"

- Dark-first theme (this is a car dashboard, glare/eye-strain matter): deep charcoal/near-black background (`#0B0F14`-ish), neon accent — pick one signature accent color (electric cyan or violet) used consistently for active states, live data traces, and highlights, matching how the Android sibling app uses ice-blue.
- Subtle glassmorphism/blur on cards, soft glow on active gauge needles/redline zones, smooth spring animations on value changes (avoid jarring jumps — animate gauge needles and numeric counters).
- Monospaced or technical-feeling numeric font for readouts (SF Mono or similar) to reinforce the "instrument cluster" feel; standard SF Pro for labels/UI chrome.
- Respect Dynamic Type and support a Light appearance too (don't hardcode colors — use semantic/adaptive colors), even though dark is the primary design target.
- Motion and density should stay driver-safe: large touch targets, minimal required taps, no dense text walls on any screen likely to be glanced at while parked/idling.

---

## 8b. CarPlay — What's Actually Possible (read before implementing)

This is the part most OBD app prompts get wrong, so build to reality:

- **Apple does not grant third-party apps a general "draw custom UI/gauges on the CarPlay screen" entitlement.** Full custom instrument-cluster rendering is gated behind `com.apple.developer.carplay-instrument-cluster`, an OEM-only entitlement Apple doesn't issue to indie/hobby developers. Do not design CaRx's CarPlay screen around free-form custom gauge graphics — it won't pass entitlement review.
- What CaRx **can** ship on CarPlay, using standard `CPTemplate` types (these don't require a special entitlement beyond a normal CarPlay app category, though Apple still requires requesting CarPlay app capability via the developer portal and justifying the category in review):
  - `CPGridTemplate` or `CPListTemplate` showing a handful of key live PID values as list rows/buttons, refreshed on a timer (text updates, not animated gauges).
  - `CPInformationTemplate` for a DTC summary screen ("3 active codes" / "No codes stored" + a list).
  - A "Clear Codes" action as a `CPAlertTemplate` confirmation triggered from the CarPlay UI.
- Practically: **the rich configurable gauge dashboard and charts live on the iPhone screen only.** CarPlay gets a simplified, glanceable, template-based companion view fed by the same `TelemetryStore`. Make this split explicit in onboarding copy ("Full dashboard on iPhone, quick status on CarPlay") so it's a stated feature, not a discovered limitation.
- Flag to the user during setup: getting *any* custom CarPlay entitlement (even the standard app-category one) requires an Apple Developer Program application through Apple's CarPlay entitlement request form, which can take weeks and isn't guaranteed — build and ship the iPhone app fully functional on its own first, and treat CarPlay as an additive, review-gated milestone.

---

## 10. Non-Functional Requirements

- Target ≥10Hz effective UI refresh for the dashboard's highest-priority PID (e.g. RPM) when the adapter/protocol allows it; degrade gracefully (lower polling rate, show a "slow adapter" hint) rather than freezing the UI on slow ELM327 clones.
- No destructive action (clear codes, delete a profile/layout) without confirmation.
- All Bluetooth/network permissions requested with clear, specific `Info.plist` usage-description strings (`NSBluetoothAlwaysUsageDescription`, local network usage description for Wi‑Fi discovery if used).
- Offline-safe: app must not crash or hang if the adapter is unreachable at launch; always land on a clear "not connected" state with a retry action.
- Unit tests for the PID decoder functions and DTC parser (pure functions — easy to test in isolation without hardware). A `MockTransport` replaying a canned ELM327 session should be enough to test the dashboard/chart UI without a physical adapter.

---

## 11. Suggested Build Order (milestones)

1. `OBDTransport` protocol + `MockTransport` + `ELM327Session` handshake/PID decode logic, unit-tested, no UI yet.
2. Wi‑Fi transport working end-to-end against a real or simulated ELM327 Wi‑Fi adapter.
3. BLE transport against a real BLE ELM327 adapter.
4. Dashboard MVP: fixed layout, a few gauges/cards, live data from transport.
5. Configurable dashboard: edit mode, add/remove/resize, multiple named layouts, SwiftData persistence.
6. DTC read (current/pending/permanent) + freeze frame + description lookup.
7. Erase codes flow with confirmation + re-poll verification.
8. Single-sensor full-screen chart.
9. Multi-series chart builder + Chart Presets + CSV export.
10. Visual polish pass (§9) — motion, glow, adaptive theming.
11. CarPlay scene: `CPListTemplate`/`CPGridTemplate` live values + DTC `CPInformationTemplate`, scoped per §8b.
12. Vehicle profiles: build the three required PID packs (Cruze, BMW, Ram 1500) as bundled JSON per §5b, the raw diagnostic/discovery tool, the `verified` badge UI, and the vehicle-picker onboarding flow that loads the right pack + default dashboard.

---

Build CaRx as a real, runnable Xcode project (not a mockup) — target a working `.xcodeproj`/SwiftPM structure, with `MockTransport` wired in by default so the UI is fully demoable in Simulator without any physical OBD-II hardware.
