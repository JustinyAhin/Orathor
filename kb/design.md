# Orathor — Design Context

## Users
Power users — developers, writers, founders, students — who think faster than they type. They use Orathor in focused work sessions, dictating into any app on their Mac. They value speed, precision, and tools that stay out of the way.

## Brand Personality
**Bold, warm, confident.** Distinctive without being loud. Technical precision with human warmth. "Speak it, author it." Orathor should feel like a premium, opinionated tool — not another generic utility.

## Aesthetic Direction
**Dashboard-native** — polished, data-rich, and confident. Inspired by Readout: clean dark surfaces, multi-color indicators, sidebar navigation, stat cards, and horizontal bar charts. The UI should feel like a well-built native macOS dashboard app — information-dense but never cluttered.

### Primary Reference
- **Readout** — the gold standard for this project's visual direction. Key qualities to match:
  - **Sidebar navigation** with grouped sections (Overview, Monitor, Workspace) and SF Symbol icons
  - **Stat cards** — row of cards with large numbers and small colored dot indicators (blue, green, orange, red)
  - **Card surfaces** — subtle elevation over the background, thin borders, clean padding
  - **Horizontal bar charts** — for distribution data (tool usage, model usage, app usage)
  - **Activity charts** — bar charts for usage over time with period selectors (7d, 14d, 30d)
  - **Search with filter pills** — inline search bar with time-range toggles (Today, This Week, This Month, All Time)
  - **List items as cards** — transcript/session rows with metadata, status indicators, and preview text
  - **Section headers** — small, muted, uppercase labels grouping sidebar items and content sections
  - **Status badges** — colored pill badges ("active", "idle") on list items
  - **Active sidebar items** — highlighted with a subtle background fill

### Secondary Reference
- **Raycast** — for native macOS feel, keyboard-first interactions, and overall polish

### Color Direction
- **Brand**: Rich amber (#D97706) — remains the primary brand accent
- **Accent**: Warm gold (#F59E0B) — complementary for gradients and highlights
- **Indicator palette**: Multi-color system for data types and status:
  - Blue (#3B82F6) — sessions, primary metrics
  - Green (#22C55E) — active status, success, generating
  - Orange/Amber (#F59E0B) — tokens, warnings, brand-adjacent data
  - Red (#EF4444) — errors, recording state
  - Yellow (#EAB308) — secondary data, historical
  - Gray (#6B7280) — inactive, tertiary data
- **Surfaces**: Cool neutral darks — shift away from warm-tinted backgrounds to modern, neutral charcoals
  - Primary background: near-black neutral (#0A0A0B or similar)
  - Secondary/card: slightly lighter neutral (#141416)
  - Elevated: subtle lift (#1C1C1F)
  - Borders: cool gray (#2A2A2E) subtle, (#3A3A3F) default
- **Text**: Clean white hierarchy on dark — primary near-white, secondary muted gray, tertiary subdued
- Both light and dark mode, system-aware — dark mode is the hero experience

### Anti-references
- Generic AI aesthetic (purple gradients, glowing orbs)
- Pale, desaturated, safe color palettes
- Electron-feeling apps (heavy, sluggish, non-native)
- Overly playful or toy-like interfaces
- Default/ordinary macOS utility look
- Single-color-only dashboards — embrace the multi-color indicator system

## Layout Direction
- **Main window**: Sidebar + content area (like Readout), replacing the current top tab bar
  - Sidebar: grouped navigation with section headers (e.g., "Overview", "Monitor", "Settings")
  - Content: full-width area to the right of the sidebar
- **Menu bar popover**: Stays as-is (compact 340pt window) — the sidebar pattern is for the main window only

## Component Patterns (target)
- **Stat cards**: Row of equal-width cards with large mono number + colored dot + label below. Used at top of dashboard pages for key metrics.
- **Cards**: Subtle elevated background + thin border + generous padding + rounded corners. Content container for everything.
- **Left-accent cards**: 2-3pt colored left border on cards for list items (transcripts, sessions). Brand amber or contextual color.
- **Horizontal bar charts**: Label on left, colored bar proportional to value, count on right. For distributions (apps, engines, word counts).
- **Activity bar charts**: Vertical bars over time axis with period selectors. For usage patterns.
- **Search bar**: Clean pill-shaped input with filter pills/toggles for time ranges and categories.
- **Section headers**: Small, uppercase, muted text — used in both sidebar and content areas.
- **Status badges**: Small colored pills for states like "active", "recording", "idle".

## Design Principles
1. **Invisible until needed** — the app should feel like a natural extension of macOS, not a separate product
2. **Every pixel earns its place** — no decorative elements without purpose; whitespace is a feature
3. **Speed is visible** — the interface should feel fast through instant transitions, minimal chrome, and responsive feedback
4. **Quiet confidence** — strong, distinctive presence through color and typography rather than flashy effects; quality reveals itself on inspection
5. **Native first** — respect macOS conventions, use system materials and behaviors, feel like it belongs
6. **Data speaks** — present information clearly with appropriate visual hierarchy; use color meaningfully to differentiate data types, not just for decoration

## Accessibility
- Standard macOS accessibility defaults
- Rely on system accessibility features (VoiceOver, reduced motion, etc.)
- Multi-color indicators should also differ in position/shape for color-blind users
