import SwiftUI
import UIKit
import Combine

// OldOS helpers needed by the Weather screens that OldSafari never used.
// `OldOSKit.swift` is shared verbatim with OldSafari; additions live here.

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, content: (Self) -> Content) -> some View {
        if condition {
            content(self)
        } else {
            self
        }
    }

    /// OldOS `animationsDisabled()`.
    func oldOSAnimationsDisabled() -> some View {
        transaction { $0.animation = nil }
    }

    /// OldOS `isHidden(_:)`.
    @ViewBuilder
    func oldOSHidden(_ hidden: Bool) -> some View {
        if hidden {
            self.hidden()
        } else {
            self
        }
    }
}

extension Collection {
    /// OldOS `subscript(optional:)`.
    subscript(optional i: Index) -> Element? {
        indices.contains(i) ? self[i] : nil
    }
}

extension Array {
    /// OldOS `subscript(wrapping:)`.
    subscript(wrapping index: Int) -> Element {
        self[(index % count + count) % count]
    }
}

/// OldOS `RoundedCorners`.
struct OldOSRoundedCorners: Shape {
    var tl: CGFloat = 0
    var tr: CGFloat = 0
    var bl: CGFloat = 0
    var br: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.size.width
        let h = rect.size.height
        let tr = min(min(self.tr, h / 2), w / 2)
        let tl = min(min(self.tl, h / 2), w / 2)
        let bl = min(min(self.bl, h / 2), w / 2)
        let br = min(min(self.br, h / 2), w / 2)

        path.move(to: CGPoint(x: w / 2, y: 0))
        path.addLine(to: CGPoint(x: w - tr, y: 0))
        path.addArc(center: CGPoint(x: w - tr, y: tr), radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: w, y: h - br))
        path.addArc(center: CGPoint(x: w - br, y: h - br), radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: bl, y: h))
        path.addArc(center: CGPoint(x: bl, y: h - bl), radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: 0, y: tl))
        path.addArc(center: CGPoint(x: tl, y: tl), radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}

/// OldOS `tool_bar_button_type` / `returnLinearGradient`.
enum WeatherButtonType {
    case blue, black, red

    var gradient: LinearGradient {
        switch self {
        case .blue:
            return LinearGradient(oldOS: [
                OldOSStop(.oldOS(137, 173, 238), 0),
                OldOSStop(.oldOS(80, 140, 231), 0.51),
                OldOSStop(.oldOS(43, 120, 228), 0.52),
                OldOSStop(.oldOS(46, 123, 229), 1)
            ])
        case .black:
            return LinearGradient(oldOS: [
                OldOSStop(.oldOS(95, 95, 95), 0),
                OldOSStop(.oldOS(32, 32, 32), 0.51),
                OldOSStop(.oldOS(7.5, 7.5, 7.5), 0.51),
                OldOSStop(.oldOS(7.5, 7.5, 7.5), 1)
            ])
        case .red:
            return LinearGradient(oldOS: [
                OldOSStop(.oldOS(239, 135, 142), 0),
                OldOSStop(.oldOS(199, 52, 63), 0.48),
                OldOSStop(.oldOS(189, 20, 33), 0.49),
                OldOSStop(.oldOS(189, 20, 33), 1)
            ])
        }
    }
}

/// OldOS `tool_bar_rectangle_button`.
struct WeatherBarButton: View {
    let type: WeatherButtonType
    let title: String
    let action: () -> Void

    var body: some View {
        Button {
            WeatherHaptics.tap()
            action()
        } label: {
            Text(title)
                .font(OldOSFont.bold(13.25))
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.75), radius: 1, x: 0, y: -0.25)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 11)
                .frame(height: 32)
                .oldOSInnerShadowBackground(RoundedRectangle(cornerRadius: 5.5), type.gradient, radius: 0.8, offset: CGPoint(x: 0, y: 0.6), intensity: 0.7)
                .shadow(color: Color.white.opacity(0.28), radius: 0, x: 0, y: 0.8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(height: 32)
    }
}

enum WeatherHaptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

/// Keyboard height (OldOS `OldOSKeyboardController.currentHeight`), for the
/// edge-to-edge layout that ignores the keyboard safe area.
final class WeatherKeyboard: ObservableObject {
    static let shared = WeatherKeyboard()

    @Published private(set) var height: CGFloat = 0
    private var cancellables = Set<AnyCancellable>()

    private init() {
        let center = NotificationCenter.default
        center.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            .merge(with: center.publisher(for: UIResponder.keyboardWillHideNotification))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                guard let self else { return }
                if note.name == UIResponder.keyboardWillHideNotification {
                    self.height = 0
                    return
                }
                let frame = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect) ?? .zero
                let windows = UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .flatMap { $0.windows }
                let screen = (windows.first(where: { $0.isKeyWindow }) ?? windows.first)?.bounds.height ?? UIScreen.main.bounds.height
                self.height = max(0, screen - frame.minY)
            }
            .store(in: &cancellables)
    }
}
