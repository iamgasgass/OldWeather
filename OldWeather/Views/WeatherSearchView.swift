import SwiftUI

/// OldOS `new_location_search`: the black search bar with "Type the City,
/// State, or ZIP code:" / "Validating City...", and the white list of
/// matches. The search starts 1 s after the last keystroke, as in OldOS.
struct WeatherSearchView: View {
    @ObservedObject private var keyboard = WeatherKeyboard.shared
    @Environment(\.oldWeatherTheme) private var theme
    let topInset: CGFloat
    let bottomInset: CGFloat
    let onCancel: () -> Void
    let onPick: (OpenMeteoGeocodingResponse.Result) -> Void

    @State private var search = ""
    @State private var isValidating = false
    @State private var cityList: [OpenMeteoGeocodingResponse.Result] = []
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            WeatherSearchBar(
                search: $search,
                focused: $focused,
                topInset: topInset,
                prompt: isValidating ? "Validating City..." : "Type the City, State, or ZIP code:",
                onCancel: {
                    oldOSHideKeyboard()
                    searchTask?.cancel()
                    onCancel()
                }
            )

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(cityList) { result in
                        Button {
                            WeatherHaptics.tap()
                            oldOSHideKeyboard()
                            onPick(result)
                        } label: {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(alignment: .center) {
                                    Spacer().frame(width: 1, height: 44 - 0.95)
                                    Text(result.searchName)
                                        .font(OldOSFont.bold(20))
                                        .foregroundColor(theme.listText)
                                        .lineLimit(1)
                                        .padding(.trailing, 12)
                                    Spacer(minLength: 0)
                                }
                                .padding(.leading, 8)
                                Rectangle()
                                    .fill(theme.listSeparator)
                                    .frame(height: 0.95)
                            }
                            .frame(height: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, max(keyboard.height, bottomInset))
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(theme.listBackground)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                focused = true
            }
        }
        .onDisappear {
            searchTask?.cancel()
        }
        .onChange(of: search) { text in
            searchTask?.cancel()
            let query = text.trimmingCharacters(in: .whitespaces)
            guard !query.isEmpty else {
                isValidating = false
                cityList = []
                return
            }
            isValidating = true
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                let results = await Self.find(query)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    if let results {
                        cityList = results
                    }
                    isValidating = false
                }
            }
        }
    }

    /// OldOS `parse_search_data`: Open-Meteo geocoding, 10 results.
    static func find(_ query: String) async -> [OpenMeteoGeocodingResponse.Result]? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encoded)&count=10&language=en&format=json")
        else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OpenMeteoGeocodingResponse.self, from: data)
            return response.results ?? []
        } catch {
            return nil
        }
    }
}

/// OldOS `search_text_title_bar`.
struct WeatherSearchBar: View {
    @Binding var search: String
    @Environment(\.oldWeatherTheme) private var theme
    var focused: FocusState<Bool>.Binding
    let topInset: CGFloat
    let prompt: String
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: topInset)
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Text(prompt)
                        .foregroundColor(.oldOS(168, 168, 168))
                        .font(OldOSFont.regular(14))
                        .shadow(color: Color.black.opacity(0.9), radius: 0, x: 0, y: -1)
                        .padding([.leading, .trailing], 24)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.top, 12)
                Spacer()
                HStack {
                    HStack(alignment: .center, spacing: 10) {
                        Image("SearchIcon")
                            .resizable()
                            .frame(width: 15, height: 15)
                            .padding(.leading, 5)
                        TextField("", text: $search)
                            .font(OldOSFont.regular(16))
                            .foregroundColor(theme.fieldText)
                            .keyboardType(.alphabet)
                            .submitLabel(.search)
                            .autocorrectionDisabled()
                            .focused(focused)
                        if !search.isEmpty {
                            Button {
                                search = ""
                            } label: {
                                Image("TextFieldClear")
                            }
                            .buttonStyle(.plain)
                            .fixedSize()
                        }
                    }
                    .padding([.top, .bottom], 5)
                    .padding(.leading, 5)
                    .padding(.trailing, 8)
                    .frame(height: 31)
                    .oldOSInnerShadowBackground(Capsule(), theme.fieldBackground, radius: 1.6, offset: CGPoint(x: 0, y: 1), intensity: 0.7)
                    .oldOSStrokeCapsule(.oldOS(166, 166, 166), lineWidth: 0.33)
                    .padding(.leading, 5.5)
                    .padding(.trailing, 5.5)
                    WeatherBarButton(type: .black, title: "Cancel", action: onCancel)
                        .padding(.trailing, 5)
                }
                Spacer()
            }
            .frame(height: 90)
            .background(
                LinearGradient(oldOS: [
                    OldOSStop(.oldOS(59, 59, 59), 0),
                    OldOSStop(.oldOS(29, 29, 29), 0.39),
                    OldOSStop(.oldOS(7.5, 7.5, 7.5), 0.39),
                    OldOSStop(.oldOS(7.5, 7.5, 7.5), 1)
                ])
                .oldOSBorder(width: 1, edges: [.bottom], color: .oldOS(45, 48, 51))
                .oldOSInnerShadowBottom(color: .oldOS(230, 230, 230), radius: 0.015)
            )
        }
        .background(Color.black)
    }
}
