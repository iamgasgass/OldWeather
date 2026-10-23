import SwiftUI

/// OldOS `weather_settings`: the back of the card. Linen tile, the black
/// "Weather" bar with + and Done, the white list of cities (delete with the
/// red minus, reorder with the grabber), °F / °C and the provider logo.
struct WeatherSettingsView: View {
    @ObservedObject private var store = WeatherStore.shared
    @Environment(\.oldWeatherTheme) private var theme
    let topInset: CGFloat
    let bottomInset: CGFloat
    let onDone: () -> Void

    @State private var toDelete: UUID?
    @State private var showAddLocation = false
    @State private var selectedSegment = WeatherStore.shared.mode == .imperial ? 0 : 1
    @State private var draggingID: UUID?
    @State private var dragStartIndex = 0
    @State private var dragOffset: CGFloat = 0

    private let rowHeight: CGFloat = 44

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image("SettingsTile")
                    .resizable(resizingMode: .tile)
                    .colorMultiply(theme.linenTint)
                    .frame(width: geometry.size.width, height: geometry.size.height)

                VStack(spacing: 0) {
                    WeatherSettingsTitleBar(
                        topInset: topInset,
                        newAction: {
                            toDelete = nil
                            withAnimation { showAddLocation = true }
                        },
                        doneAction: {
                            toDelete = nil
                            onDone()
                        }
                    )
                    Spacer().frame(height: 15)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(store.cities) { city in
                                row(city)
                                    .offset(y: draggingID == city.id ? dragOffset : 0)
                                    .zIndex(draggingID == city.id ? 1 : 0)
                            }
                        }
                    }
                    .scrollDisabled(draggingID != nil)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(theme.listBackground)
                    .cornerRadius(12)
                    .padding([.leading, .trailing], 12)

                    Spacer().frame(height: 15)
                    WeatherUnitControl(selected: $selectedSegment, first: "°F", second: "°C")
                        .frame(width: geometry.size.width - 24, height: 45)
                    Spacer().frame(height: 15)
                    Link(destination: URL(string: "https://open-meteo.com/")!) {
                        Image("YahooWeatherLogo")
                    }
                    Text("Weather data by Open-Meteo.com")
                        .font(OldOSFont.regular(11))
                        .foregroundColor(Color.white.opacity(0.75))
                        .shadow(color: Color.black.opacity(0.6), radius: 0, x: 0, y: -1)
                        .padding(.top, 4)
                    Spacer().frame(height: 15 + bottomInset)
                }

                if showAddLocation {
                    WeatherSearchView(
                        topInset: topInset,
                        bottomInset: bottomInset,
                        onCancel: { withAnimation { showAddLocation = false } },
                        onPick: { result in
                            store.add(result)
                            withAnimation { showAddLocation = false }
                        }
                    )
                    .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .move(edge: .bottom)))
                    .zIndex(2)
                }
            }
        }
        .onChange(of: selectedSegment) { segment in
            store.setMode(segment == 0 ? .imperial : .metric)
        }
    }

    // MARK: Rows

    private func row(_ city: WeatherCity) -> some View {
        let canDelete = store.cities.count > 1
        let deleting = toDelete == city.id && canDelete
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Spacer().frame(width: 1, height: rowHeight - 0.95)
                if canDelete {
                    Button {
                        withAnimation(.linear(duration: 0.15)) {
                            toDelete = toDelete == city.id ? nil : city.id
                        }
                    } label: {
                        ZStack {
                            Image("RemoveMinus")
                            Text("—")
                                .foregroundColor(.white)
                                .font(.system(size: 15, weight: .heavy))
                                .offset(y: deleting ? -0.8 : -2)
                                .rotationEffect(.degrees(deleting ? -90 : 0), anchor: .center)
                                .offset(y: deleting ? -0.5 : 0)
                        }
                    }
                    .buttonStyle(.plain)
                    .transition(AnyTransition.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading)).combined(with: .opacity))
                    .offset(x: -4)
                }
                WeatherCityName(city: city)
                ZStack {
                    HStack {
                        Spacer()
                        if !deleting {
                            Image("TableGrabber")
                                .padding(.trailing, 12)
                                .padding(.leading, 12)
                                .frame(height: rowHeight)
                                .contentShape(Rectangle())
                                .gesture(reorderGesture(city))
                        }
                    }
                    HStack {
                        Spacer()
                        if deleting {
                            WeatherBarButton(type: .red, title: "Delete") {
                                withAnimation {
                                    toDelete = nil
                                    store.remove(city)
                                }
                            }
                            .padding(.trailing, 12)
                            .transition(AnyTransition.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)).combined(with: .opacity))
                        }
                    }
                }
            }
            .padding(.leading, 8)
            Rectangle()
                .fill(theme.listSeparator)
                .frame(height: 0.95)
        }
        .frame(height: rowHeight)
        .background(theme.listBackground)
        .shadow(color: Color.black.opacity(draggingID == city.id ? 0.35 : 0), radius: 4, x: 0, y: 2)
    }

    /// Drag the grabber to change the order of the pages.
    private func reorderGesture(_ city: WeatherCity) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                if draggingID != city.id {
                    draggingID = city.id
                    toDelete = nil
                    dragStartIndex = store.cities.firstIndex(of: city) ?? 0
                }
                let count = store.cities.count
                let raw = Int((value.translation.height / rowHeight).rounded())
                let target = min(max(dragStartIndex + raw, 0), count - 1)
                if let current = store.cities.firstIndex(of: city), current != target {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        store.move(from: current, to: target)
                    }
                }
                dragOffset = value.translation.height - CGFloat(target - dragStartIndex) * rowHeight
            }
            .onEnded { _ in
                withAnimation(.easeOut(duration: 0.15)) {
                    dragOffset = 0
                    draggingID = nil
                }
            }
    }
}

/// The city name of a row (observes the city so a resolved name shows up).
private struct WeatherCityName: View {
    @ObservedObject var city: WeatherCity
    @Environment(\.oldWeatherTheme) private var theme

    var body: some View {
        Text(city.locationString)
            .font(OldOSFont.bold(20))
            .foregroundColor(theme.listText)
            .lineLimit(1)
    }
}

/// OldOS `weather_settings_title_bar`.
struct WeatherSettingsTitleBar: View {
    let topInset: CGFloat
    let newAction: () -> Void
    let doneAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Color.black.opacity(0.8).frame(height: topInset)
            ZStack {
                LinearGradient(oldOS: [
                    OldOSStop(.oldOS(0, 0, 0), 0),
                    OldOSStop(.oldOS(84, 84, 84), 0.02),
                    OldOSStop(.oldOS(59, 59, 59), 0.04),
                    OldOSStop(.oldOS(29, 29, 29), 0.5),
                    OldOSStop(.oldOS(7.5, 7.5, 7.5), 0.51),
                    OldOSStop(.oldOS(7.5, 7.5, 7.5), 1)
                ])
                .oldOSBorder(width: 1, edges: [.bottom], color: .oldOS(45, 48, 51))
                .oldOSInnerShadowBottom(color: .oldOS(230, 230, 230), radius: 0.025)
                .opacity(0.8)

                Text("Weather")
                    .font(OldOSFont.bold(22))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.21), radius: 0, x: 0, y: -1)

                HStack {
                    Button {
                        WeatherHaptics.tap()
                        newAction()
                    } label: {
                        ZStack {
                            Image("NavBarBlackButton")
                                .resizable(capInsets: EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5.5), resizingMode: .stretch)
                                .frame(width: 32, height: 30)
                            Image("BarPlus")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 13)
                        }
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 8)
                    Spacer()
                    WeatherBarButton(type: .blue, title: "Done", action: doneAction)
                        .padding(.trailing, 8)
                }
            }
            .frame(height: 60)
        }
    }
}

/// OldOS `dual_segmented_control_big_bluegray_no_stroke`.
struct WeatherUnitControl: View {
    @Binding var selected: Int
    let first: String
    let second: String
    @Environment(\.oldWeatherTheme) private var theme
    private let selectedGradient = LinearGradient(oldOS: [
        OldOSStop(.oldOS(64, 135, 220), 0),
        OldOSStop(.oldOS(81, 151, 236), 0.46),
        OldOSStop(.oldOS(103, 165, 245), 0.56),
        OldOSStop(.oldOS(138, 188, 253), 1)
    ])

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                segment(0, title: first, shape: OldOSRoundedCorners(tl: 12, bl: 12), size: geometry.size)
                segment(1, title: second, shape: OldOSRoundedCorners(tr: 12, br: 12), size: geometry.size)
            }
        }
    }

    private func segment(_ index: Int, title: String, shape: OldOSRoundedCorners, size: CGSize) -> some View {
        let isOn = selected == index
        return Button {
            WeatherHaptics.tap()
            selected = index
        } label: {
            Text(title)
                .font(OldOSFont.bold(18))
                .foregroundColor(isOn ? .white : theme.segmentOffText)
                .shadow(color: isOn ? Color.black.opacity(0.4) : theme.segmentOffShadow, radius: 0, x: 0, y: isOn ? -0.66 : 0.99)
                .frame(width: size.width / 2, height: size.height)
                .background(
                    OldOSInnerShadow(
                        shape: shape,
                        fill: isOn ? selectedGradient : theme.segmentOff,
                        radius: 3,
                        offset: CGPoint(x: 0, y: 3),
                        intensity: isOn ? 0.4 : 0
                    )
                )
                .shadow(color: Color.white.opacity(0.28), radius: 0, x: 0, y: 0.8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
