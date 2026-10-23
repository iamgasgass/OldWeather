# OldWeather

> A standalone, modern iOS rebuild of the **Weather** app from **The OldOS Project**. It keeps the iOS 6 cards, the big weather icons and the 3D flip to the settings, and runs full screen on current iPhones and iPads with iOS 16 or later.

[![iOS](https://img.shields.io/badge/iOS-16.0%2B-0A84FF?logo=apple&logoColor=white)](#requirements)
[![Swift](https://img.shields.io/badge/Swift-SwiftUI-F05138?logo=swift&logoColor=white)](#architecture)
[![Build](https://img.shields.io/github/actions/workflow/status/iamgasgass/OldWeather/build.yml?branch=main&label=build)](https://github.com/iamgasgass/OldWeather/actions)
[![License](https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey)](#license-and-attribution)

## Features

Every screen of OldOS `Weather.swift` is included, with live data from [Open-Meteo](https://open-meteo.com/), the same service OldOS used.

### Cards

- One card per city, swiped left and right, with the white **page dots**. Tapping left or right of the dots changes page.
- **Day** card in blue and **night** card in plum, chosen from the city's current day or night.
- The big iOS 6 **weather icon** overlaps the top of the card: sun, partly cloudy, cloudy, rain, thunderstorm, snow, fog, moon.
- Header with the **city**, **H / L** and the big **temperature**.
- **6-day forecast** (today first) with the weekday, the small icon, and the high and low.
- Footer with the provider button, **"Updated M/d/yy h:mm a"** and the **(i)** button.

### Settings (the back of the card)

- **(i)** turns the card round with the OldOS 3D flip, and **Done** turns it back.
- Linen background and the black **"Weather"** bar with **+** and **Done**.
- White list of cities:
  - the red **minus** turns, then **Delete** removes the city;
  - drag the **grabber** to reorder the pages (OldOS only drew it).
- **°F / °C** segmented control. Every city reloads in the new unit.
- **+** opens the search: **"Type the City, State, or ZIP code:"**, then **"Validating City..."**. The search runs 1 s after you stop typing, and you tap a result to add it (up to 9 cities, as on iOS 6).

### Data

- Cities and unit are saved, in the OldOS `weather_cities` / `weather_mode` format plus the coordinates. A city picked from the search is therefore always the right one.
- The first launch shows **Cupertino**, as iOS 6 did.
- Data refreshes when the app returns to the foreground if it is older than 15 minutes.

### Appearance

**Aspect UI** in Settings › OldWeather: *Sistema*, *Chiaro* or *Scuro*. In Scuro the settings and search tables, the linen, the search field and the °F / °C control use OldSafari's Private palette, and the keyboard and alerts follow. The weather cards and black bars are the iOS 6 ones in both.

### Full screen

Like OldSafari, the cards fill the screen between the status bar / Dynamic Island and the home indicator, and the settings bar extends behind the status bar.

## Requirements

- iOS / iPadOS 16.0 or later, with network access.
- Xcode 16 and [XcodeGen](https://github.com/yonaskolb/XcodeGen) to build.

## Build

```sh
brew install xcodegen
xcodegen generate --spec project.yml
open OldWeather.xcodeproj
```

The GitHub Actions workflow (`.github/workflows/build.yml`) generates the project, builds it without signing and uploads an unsigned IPA (`OldWeather-Unsigned-IPA`).

## Architecture

| File | Role |
| --- | --- |
| `OldWeatherApp.swift` | App and scene delegate; light status bar |
| `Models/WeatherModels.swift` | Open-Meteo responses, icon mapping, `WeatherCity` (OldOS `WeatherObserver`) |
| `Store/WeatherStore.swift` | Cities, unit, persistence |
| `Views/OldWeatherRootView.swift` | Pager, page dots, 3D flip |
| `Views/WeatherCardView.swift` | Day / night card, header, forecast, footer |
| `Views/WeatherSettingsView.swift` | Settings, title bar, °F / °C control |
| `Views/WeatherSearchView.swift` | City search |
| `Support/OldOSKit.swift` | Shared OldOS look (same file as OldSafari) |
| `Support/OldOSKit+Weather.swift` | Buttons, keyboard, shapes |
| `Support/OldWeatherTheme.swift` | Light / Dark skins |
| `Store/WeatherSettings.swift`, `Settings.bundle` | Aspect UI (Sistema / Chiaro / Scuro) |

There are no third-party dependencies: the OldOS SwiftUIPager and ObservableArray were replaced with native code.

## License and attribution

Derived from [The OldOS Project](https://github.com/zzanehip/The-OldOS-Project) by Zane Kleinberg, licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Weather data by [Open-Meteo.com](https://open-meteo.com/) (CC BY 4.0). See `LICENSE` and `EXTRACTION.json`.
