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

/// Replaces SwiftUIPager with a real paging `UIScrollView`, exactly the
/// control iOS 6 Weather used: native finger tracking, deceleration, the
/// rubber band at the first and last card, and the page dots following the
/// card under the finger.
struct WeatherPager<Page: View>: View {
    let cities: [WeatherCity]
    @Binding var index: Int
    @ViewBuilder let content: (WeatherCity) -> Page

    var body: some View {
        GeometryReader { geometry in
            WeatherPagingScrollView(
                pages: cities.map { city in
                    WeatherPagerPage(id: city.id, view: AnyView(content(city)))
                },
                size: geometry.size,
                index: $index
            )
        }
    }
}

struct WeatherPagerPage: Identifiable {
    let id: UUID
    let view: AnyView
}

struct WeatherPagingScrollView: UIViewRepresentable {
    let pages: [WeatherPagerPage]
    let size: CGSize
    @Binding var index: Int

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.isPagingEnabled = true
        scroll.bounces = true
        scroll.alwaysBounceHorizontal = true
        scroll.alwaysBounceVertical = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.delaysContentTouches = false
        scroll.scrollsToTop = false
        scroll.backgroundColor = .clear
        scroll.delegate = context.coordinator

        let host = context.coordinator.host
        host.view.backgroundColor = .clear
        if #available(iOS 16.4, *) {
            host.safeAreaRegions = []
        }
        scroll.addSubview(host.view)
        return scroll
    }

    func updateUIView(_ scroll: UIScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        let width = max(size.width, 1)
        let height = max(size.height, 1)

        coordinator.host.rootView = AnyView(
            HStack(spacing: 0) {
                ForEach(pages) { page in
                    page.view
                        .frame(width: width, height: height)
                }
            }
            .frame(width: width * CGFloat(max(pages.count, 1)), height: height, alignment: .leading)
            .ignoresSafeArea()
        )

        let contentSize = CGSize(width: width * CGFloat(pages.count), height: height)
        if scroll.contentSize != contentSize {
            scroll.contentSize = contentSize
        }
        let frame = CGRect(origin: .zero, size: CGSize(width: max(contentSize.width, width), height: height))
        if coordinator.host.view.frame != frame {
            coordinator.host.view.frame = frame
        }

        // Follow a page change made elsewhere (dot taps, a deleted city),
        // never while the finger moves the cards.
        guard !scroll.isDragging, !scroll.isDecelerating, !pages.isEmpty else { return }
        let target = CGFloat(min(max(index, 0), pages.count - 1)) * width
        if abs(scroll.contentOffset.x - target) > 0.5 {
            let animated = coordinator.laidOut && coordinator.lastWidth == width
            scroll.setContentOffset(CGPoint(x: target, y: 0), animated: animated)
        }
        coordinator.lastWidth = width
        coordinator.laidOut = true
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: WeatherPagingScrollView
        let host = UIHostingController(rootView: AnyView(EmptyView()))
        var laidOut = false
        var lastWidth: CGFloat = 0

        init(_ parent: WeatherPagingScrollView) {
            self.parent = parent
        }

        /// The dots switch when the next card is more than half visible
        /// (UIPageControl behaviour).
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard scrollView.isDragging || scrollView.isDecelerating else { return }
            let width = max(scrollView.bounds.width, 1)
            let page = Int((scrollView.contentOffset.x / width).rounded())
            let clamped = min(max(page, 0), max(parent.pages.count - 1, 0))
            if clamped != parent.index {
                parent.index = clamped
            }
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            settle(scrollView)
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate { settle(scrollView) }
        }

        private func settle(_ scrollView: UIScrollView) {
            let width = max(scrollView.bounds.width, 1)
            let page = min(max(Int((scrollView.contentOffset.x / width).rounded()), 0), max(parent.pages.count - 1, 0))
            if page != parent.index {
                parent.index = page
            }
        }
    }
}
