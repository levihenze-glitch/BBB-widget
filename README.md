# Berliner Bäder Widget

An iOS widget that shows opening hours and closure warnings for selected Berlin public swimming pools, scraped directly from [berlinerbaeder.de](https://www.berlinerbaeder.de).

## Features

- **Configurable pool selection** – pick any combination of the 28 pre-defined pools (indoor, outdoor, lake)
- **Live open/closed indicator** – computed from today's hours at the moment the widget refreshes
- **Closure warnings** – surfaces any notice/alert banners from the pool's detail page
- **Multiple widget sizes** – Small (1 pool), Medium (2 pools), Large (4 pools), plus Lock Screen variants
- **30-minute cache** – avoids hammering the site; shared via App Group between app and widget extension
- **No external dependencies** – pure Swift, WidgetKit, SwiftUI

## Project Structure

```
Sources/
├── Models/
│   ├── Pool.swift              – Pool struct + catalogue of all known pools
│   └── PoolStatus.swift        – Fetched status model + WidgetKit TimelineEntry
├── Networking/
│   └── BBBScraper.swift        – URLSession fetcher + HTML parser + in-memory cache
├── Widget/
│   ├── BerlinBaederWidget.swift      – @main Widget entry point + Xcode previews
│   ├── PoolWidgetProvider.swift      – AppIntentTimelineProvider
│   ├── PoolWidgetView.swift          – SwiftUI views for all widget families
│   └── PoolSelectionIntent.swift     – AppIntent + AppEntity for pool selection
└── App/
    ├── BerlinBaederApp.swift   – @main App entry point
    └── PoolListView.swift      – Main app: pool list, detail view, manual refresh
```

## Xcode Setup

### Requirements
- Xcode 15.2+
- iOS 17 deployment target (uses `AppIntentTimelineProvider` and `AppIntent`)
- Swift 5.9+

### Steps

1. **Create a new Xcode project** – choose *App* template, Swift / SwiftUI.
   Name it `BerlinBaeder`, bundle ID e.g. `de.yourname.BerlinBaeder`.

2. **Add a Widget Extension target** – *File › New › Target… › Widget Extension*.
   Name it `BerlinBaederWidget`.
   Tick *Include Configuration App Intent* if prompted.

3. **Add an App Group** to both the App and Widget Extension targets:
   Go to *Signing & Capabilities › + Capability › App Groups*.
   Use the same group ID `group.de.berlinerbaeder.widget` (matches the cache code).

4. **Copy the source files** into the appropriate targets:

   | File | Belongs to target |
   |------|------------------|
   | `Sources/Models/*.swift` | App + Widget Extension |
   | `Sources/Networking/BBBScraper.swift` | App + Widget Extension |
   | `Sources/Widget/*.swift` | Widget Extension only |
   | `Sources/App/*.swift` | App only |

5. Make sure both targets have **Outgoing Connections (Client)** in App Sandbox / entitlements so URLSession can reach berlinerbaeder.de.

6. **Build & run** the scheme on a simulator or device.

### Adding more pools

Edit `Pool.allPools` in `Sources/Models/Pool.swift`.
The `urlSlug` must match the path component used on berlinerbaeder.de, e.g.
`https://www.berlinerbaeder.de/baeder/detail/stadtbad-mitte-james-simon/` → slug is `stadtbad-mitte-james-simon`.

## HTML parsing

The scraper targets the TYPO3 CMS markup that berlinerbaeder.de uses:

```
Opening hours section
  <div class="frame frame-default frame-type-text …">
    <header><h2 …>Öffnungszeiten</h2></header>
    <div class="ce-bodytext">
      <table>…</table>  ← primary target
      OR <dl>…</dl>     ← fallback
      OR <p>…</p>       ← fallback
    </div>
  </div>

Warning boxes
  <div class="message message--warning …">…</div>
  <div class="alert alert-warning …">…</div>
  <div class="ce-notice …">…</div>
```

If the site is redesigned, adjust the patterns in `BBBScraper.swift`:
- `extractOpeningHoursSection(_:)` – heading marker strings
- `divFragments(matching:in:)` – warning CSS class patterns

## Refresh schedule

The widget requests a new timeline every **30 minutes**.
iOS may defer refreshes to preserve battery – this is normal WidgetKit behaviour.
You can force an immediate update from the app using the *↺* toolbar button (calls `WidgetCenter.shared.reloadAllTimelines()`).

## Legal / Terms of use

This widget scrapes publicly available information from berlinerbaeder.de for personal use.
Check [berlinerbaeder.de's terms of use](https://www.berlinerbaeder.de/service/datenschutz/) before distributing an app that relies on this data.
