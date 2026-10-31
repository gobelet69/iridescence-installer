import SwiftUI
import IridescenceCore

public enum BadgeKind {
    case official
    case stable
    case beta
    case quarantinePresent
    case quarantineClean
    case architecture(BinaryArchitecture)
}

public struct StatusBadge: View {
    let kind: BadgeKind

    public init(_ kind: BadgeKind) {
        self.kind = kind
    }

    public var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 5, height: 5)

            Text(title)
                .font(IridescenceTheme.fontMono(size: 10, weight: .bold))
                .foregroundColor(textColor)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(backgroundColor)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(borderColor, lineWidth: 0.8)
        )
    }

    private var title: String {
        switch kind {
        case .official: return "Official"
        case .stable: return "Stable"
        case .beta: return "Beta"
        case .quarantinePresent: return "Quarantined"
        case .quarantineClean: return "Unrestricted"
        case .architecture(let arch): return arch.displayName
        }
    }

    private var indicatorColor: Color {
        switch kind {
        case .official: return IridescenceTheme.deepViolet
        case .stable: return IridescenceTheme.emeraldPhosphor
        case .beta: return IridescenceTheme.warmCoral
        case .quarantinePresent: return Color.orange
        case .quarantineClean: return IridescenceTheme.turquoise
        case .architecture: return IridescenceTheme.luminousCyan
        }
    }

    private var textColor: Color {
        switch kind {
        case .official: return IridescenceTheme.deepViolet
        case .stable: return IridescenceTheme.emeraldPhosphor
        case .beta: return IridescenceTheme.warmCoral
        case .quarantinePresent: return Color.orange
        case .quarantineClean: return IridescenceTheme.turquoise
        case .architecture: return IridescenceTheme.textSecondary
        }
    }

    private var backgroundColor: Color {
        indicatorColor.opacity(0.12)
    }

    private var borderColor: Color {
        indicatorColor.opacity(0.3)
    }
}
