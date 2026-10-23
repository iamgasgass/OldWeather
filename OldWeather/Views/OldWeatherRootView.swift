import SwiftUI

/// OldOS `Weather`: the paged cards on black with the page dots, flipping
/// round to the settings with the iOS 6 3D card turn. Full screen like
/// OldSafari: the cards fill the screen between the status bar / Dynamic
/// Island and the home indicator.
struct OldWeatherRootView: View {
    @ObservedObject private var store = WeatherStore.shared
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var safeArea = OldOSSafeArea()

    @State private var page = 0
    @State private var showSettings = false
    @State private var switchToSettings = false
    /// OldOS `collapse_pager`: the pager is swapped for a still copy of the
    /// current page while the card turns.
    @State private var collapsePager = false
    @State private var flipping = false

    var body: some View {
        GeometryReader { geometry in
            let topInset = max(geometry.safeAreaInsets.top, safeArea.insets.top)
            let bottomInset = max(geometry.safeAreaInsets.bottom, safeArea.insets.bottom)
            let width = geometry.size.width
            let height = geometry.size.height

            ZStack {
                Color.black

                WeatherSettingsView(topInset: topInset, bottomInset: bottomInset, onDone: flipToWeather)
                    .frame(width: width, height: height)
                    .rotation3DEffect(.degrees(showSettings ? 0 : 90), axis: (x: 0, y: 1, z: 0), anchor: UnitPoint(x: 0, y: 0.5))
                    .offset(x: showSettings ? 0 : width / 2)
                    .opacity(showSettings ? 1 : 0)
                    .allowsHitTesting(showSettings)

                VStack(spacing: 0) {
                    Spacer().frame(height: max(topInset, 20))
                    if collapsePager, let city = store.cities[optional: page] {
                        WeatherPageView(city: city, onInfo: {})
                    } else {
                        WeatherPager(cities: store.cities, index: $page) { city in
                            WeatherPageView(city: city, onInfo: flipToSettings)
                        }
                    }
                    Spacer().frame(height: 25)
                    HStack(spacing: 10) {
                        Spacer()
                        ForEach(Array(store.cities.enumerated()), id: \.element.id) { index, _ in
                            Circle()
                                .fill(Color.white)
                                .frame(width: 7.5, height: 7.5)
                                .opacity(index == page ? 1 : 0.25)
                        }
                        Spacer()
                    }
                    .frame(height: 7.5)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        // UIPageControl: tap left / right of the dots.
                        withAnimation(.easeOut(duration: 0.3)) {
                            if location.x < width / 2 {
                                page = max(page - 1, 0)
                            } else {
                                page = min(page + 1, store.cities.count - 1)
                            }
                        }
                    }
                    .oldOSAnimationsDisabled()
                    .padding(.bottom, max(25, bottomInset + 6))
                }
                .frame(width: width, height: height)
                .rotation3DEffect(.degrees(switchToSettings ? -90 : 0), axis: (x: 0, y: 1, z: 0), anchor: UnitPoint(x: 1, y: 0.5))
                .offset(x: switchToSettings ? -width / 2 : 0)
                .opacity(switchToSettings ? 0 : 1)
                .allowsHitTesting(!switchToSettings)
            }
            .compositingGroup()
            .onAppear { safeArea.refresh() }
        }
        .ignoresSafeArea()
        .background(Color.black)
        .environment(\.oldWeatherTheme, OldWeatherTheme.theme(isDark: colorScheme == .dark))
        .onChange(of: store.cities.count) { count in
            page = min(page, max(count - 1, 0))
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            store.refreshIfStale()
            WeatherSettings.shared.apply()
        }
    }

    /// The (i) button: the card turns to the settings (OldOS timings).
    private func flipToSettings() {
        guard !flipping else { return }
        flipping = true
        collapsePager = true
        withAnimation(.easeIn(duration: 0.4)) {
            switchToSettings = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeOut(duration: 0.4)) {
                showSettings = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            flipping = false
        }
    }

    /// Done: the card turns back to the weather.
    private func flipToWeather() {
        guard !flipping else { return }
        flipping = true
        oldOSHideKeyboard()
        withAnimation(.easeIn(duration: 0.4)) {
            showSettings = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.39) {
            withAnimation(.easeOut(duration: 0.4)) {
                switchToSettings = false
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            collapsePager = false
            flipping = false
        }
    }
}

/// Replaces SwiftUIPager: one card per page, swiped horizontally with the
/// UIScrollView paging feel (rubber band at the ends).
struct WeatherPager<Page: View>: View {
    let cities: [WeatherCity]
    @Binding var index: Int
    @ViewBuilder let content: (WeatherCity) -> Page

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            HStack(spacing: 0) {
                ForEach(cities) { city in
                    content(city)
                        .frame(width: width, height: geometry.size.height)
                }
            }
            .frame(width: width, height: geometry.size.height, alignment: .leading)
            .offset(x: -CGFloat(index) * width + dragOffset)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        guard abs(value.translation.width) > abs(value.translation.height) || dragOffset != 0 else { return }
                        var translation = value.translation.width
                        let atStart = index == 0 && translation > 0
                        let atEnd = index == cities.count - 1 && translation < 0
                        if atStart || atEnd {
                            translation /= 3
                        }
                        dragOffset = translation
                    }
                    .onEnded { value in
                        let predicted = value.predictedEndTranslation.width
                        var target = index
                        if dragOffset != 0 {
                            if predicted < -width / 2 || value.translation.width < -width / 2 {
                                target += 1
                            } else if predicted > width / 2 || value.translation.width > width / 2 {
                                target -= 1
                            }
                        }
                        target = min(max(target, 0), max(cities.count - 1, 0))
                        withAnimation(.easeOut(duration: 0.3)) {
                            index = target
                            dragOffset = 0
                        }
                    }
            )
        }
        .clipped()
    }
}
