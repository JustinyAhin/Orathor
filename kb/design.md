# Orathor — Design Context

## Users
Power users — developers, writers, founders, students — who think faster than they type. They use Orathor in focused work sessions, dictating into any app on their Mac. They value speed, precision, and tools that stay out of the way.

## Brand Personality
**Bold, warm, confident.** Distinctive without being loud. Technical precision with human warmth. "Speak it, author it." Orathor should feel like a premium, opinionated tool — not another generic utility.

## Aesthetic Direction
**Dashboard-native, with restraint.** Polished, data-rich, and quietly confident. Modeled closely on Readout: clean dark surfaces, flat cards, a comfortable sidebar, and real charts. The hallmark is **taste through restraint** — quiet numbers, flat chrome, color reserved for data, and an editorial voice. Information-dense but never loud.

The single biggest lesson from Readout: **don't shout.** Numbers are calm system-font, not big bold monospace. Cards are flat, not shadowed. Color lives on the data (dots, bars, inline numbers), never on the chrome.

### Primary Reference
- **Readout** — the gold standard for this project's visual direction. Key qualities to match:
  - **Editorial opener** — a page leads with a greeting + one muted summary sentence where only the *data words* are colored, not a wall of stat cards. (e.g. "Good morning, Justin — you've dictated **10.7K** words across **476** sessions…")
  - **Quiet stat cards** — a row of equal-width cards: number centered in **system font (~24pt, medium weight — not bold, not monospace)**, with a small colored dot + label below. No icon tiles.
  - **Flat card surfaces** — barely-lighter fill, hairline (0.5pt) border, **no drop shadow**, ~12pt radius, generous padding.
  - **Comfortable sidebar** — grouped sections (Overview, Monitor, Settings) with SF Symbol icons; muted sentence-case group headers; roomy icon+label rows; a soft rounded **pill** on the active row; hover state. No collapse toggle.
  - **Calm content section headers** — small colored icon + sentence-case title (~13pt semibold) + optional muted meta. Not loud uppercase.
  - **Real charts** — line/area trend (single-color), vertical activity bars with a period selector (7d/14d/30d), donut for categorical splits. Thin, clean, minimal axes.
  - **Horizontal bar lists** — label/icon on left, single-color proportional bar, value on right (apps, model usage).
  - **List items** — compact single-line rows with metadata (time, count) on the right.
  - **Search with filter pills** — inline search bar with time-range toggles (Today, This Week, This Month, All Time).

### Secondary Reference
- **Raycast** — for native macOS feel, keyboard-first interactions, and overall polish

### Color Direction
**Color is data-only.** Chrome (backgrounds, cards, sidebar, headers) stays neutral gray; color appears only on data — dots, bars, charts, inline numbers, the active sidebar pill, status badges.

- **Primary data color**: **Blue (#3B82F6)** — the default for single-series charts (WPM trend, activity bars), distribution bars, and primary metrics. When in doubt, it's blue.
- **Brand**: Amber (#D97706 / gold #F59E0B) — **demoted to a reserved accent.** Used for the logo, the streak, and at most one brand-adjacent data point. Never the primary data color and never on chrome.
- **Indicator palette** — for *categorical* differentiation only (e.g. engine split, multi-series). Don't sprinkle multiple colors on a single series:
  - Blue (#3B82F6) — primary / sessions
  - Green (#22C55E) — success, "up" deltas, active status
  - Amber (#F59E0B) — brand-adjacent / streak only
  - Red (#EF4444) — errors, recording state
  - Yellow (#EAB308) — secondary categorical data
  - Gray (#6B7280) — inactive, tertiary, muted "down" deltas
- **Surfaces**: Cool neutral darks — shift away from warm-tinted backgrounds to modern, neutral charcoals
  - Primary background: near-black neutral (#0A0A0B or similar)
  - Secondary/card: slightly lighter neutral (#141416)
  - Elevated: subtle lift (#1C1C1F)
  - Borders: cool gray (#2A2A2E) subtle, (#3A3A3F) default
- **Text**: Clean white hierarchy on dark — primary near-white, secondary muted gray, tertiary subdued
- Both light and dark mode, system-aware — dark mode is the hero experience

### Anti-references
- Generic AI aesthetic (purple gradients, glowing orbs)
- **Shouting** — big bold monospace numbers, heavy drop shadows, oversized hero cards, color on the chrome
- Pale, desaturated, safe color palettes
- Electron-feeling apps (heavy, sluggish, non-native)
- Overly playful or toy-like interfaces
- Default/ordinary macOS utility look
- Rainbow dashboards — color is reserved for data and meaning, not decoration

## Layout Direction
- **Main window**: Sidebar + content area (like Readout), replacing the current top tab bar
  - Sidebar: grouped navigation with section headers (e.g., "Overview", "Monitor", "Settings")
  - Content: full-width area to the right of the sidebar
  - Sidebar is always visible — the collapse/"Hide Sidebar" toggle is removed
- **Menu bar popover**: Stays as-is (compact 340pt window) — the sidebar pattern is for the main window only

## Component Patterns
- **Greeting + summary**: Pages open with a time-of-day greeting using the user's name (`NSFullUserName()`) over a single muted summary sentence; only the data words are colored (medium weight). Replaces a lead stat wall.
- **Stat cards**: Row of equal-width flat cards — number centered in **system font (~24pt, medium)**, optional small muted unit, then a small colored dot + label below. No icon tiles, no shadow.
- **Cards**: `surfaceElevated` fill + 0.5pt `borderSubtle` border + ~12pt radius + generous padding. **No drop shadow.** The single content container for everything. (`statCardStyle`)
- **Content section headers**: Small colored SF Symbol + sentence-case title (~13pt semibold) + optional muted meta, optional trailing control. (`ContentSectionHeader`) — not uppercase.
- **Sidebar group headers**: Small (~11pt), muted, sentence-case labels above each nav group.
- **Sidebar rows**: Icon (~13pt) + label (~13pt); inactive muted, active in primary text with a soft rounded `borderSubtle` pill; subtle hover fill. No collapse toggle.
- **Trend chart**: Swift Charts area+line, single-color blue, thin stroke, low-opacity gradient fill, hidden Y axis, sparse X. Optional delta badge (green "up", gray "down").
- **Activity bars**: Swift Charts vertical bars, blue (brightest = peak day), rounded corners, hidden Y axis, sparse date X.
- **Donut**: Swift Charts `SectorMark` for categorical splits (engines), inner ratio ~0.64, per-category color, center label + muted legend with dots.
- **Period selector**: 7d/14d/30d segmented pills, **standalone** (scopes the trend charts as a group — not nested inside one card), selection persisted via `@AppStorage`.
- **Bar lists** (Top apps): icon + name on left, single-color blue proportional bar (~6pt), count on right; compact rows.
- **List rows** (Recent): compact single-line — icon + truncated text + muted count/time on the right.
- **Status badges**: Small colored pills for states like "active", "recording", "idle".

## Design Principles
1. **Invisible until needed** — the app should feel like a natural extension of macOS, not a separate product
2. **Every pixel earns its place** — no decorative elements without purpose; whitespace is a feature
3. **Speed is visible** — the interface should feel fast through instant transitions, minimal chrome, and responsive feedback
4. **Quiet confidence** — restraint is the aesthetic. Calm system-font numbers, flat chrome, no shadows; color reserved for data and meaning. Strong presence through hierarchy and editorial voice, not loudness. Quality reveals itself on inspection.
5. **Native first** — respect macOS conventions, use system materials and behaviors, feel like it belongs
6. **Data speaks** — present information clearly with appropriate visual hierarchy; use color meaningfully to differentiate data types, not just for decoration

## Accessibility
- Standard macOS accessibility defaults
- Rely on system accessibility features (VoiceOver, reduced motion, etc.)
- Multi-color indicators should also differ in position/shape for color-blind users
