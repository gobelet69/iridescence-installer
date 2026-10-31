import SwiftUI
import IridescenceCore

public struct ProgressCard: View {
    let phase: InstallationPhase
    let appName: String

    public init(phase: InstallationPhase, appName: String) {
        self.phase = phase
        self.appName = appName
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(phaseTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(IridescenceTheme.textPrimary)

                Spacer()

                if case .downloading(let progress) = phase {
                    Text("\(Int(progress * 100))%")
                        .font(IridescenceTheme.fontMono(size: 11, weight: .bold))
                        .foregroundColor(IridescenceTheme.electricBlue)
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(IridescenceTheme.surfaceSubtle)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(barGradient)
                        .frame(width: max(6, geo.size.width * progressFraction), height: 6)
                        .animation(.easeInOut(duration: 0.2), value: progressFraction)
                }
            }
            .frame(height: 6)
        }
        .padding(10)
        .background(IridescenceTheme.cardSurface)
        .cornerRadius(IridescenceTheme.radiusSm)
        .overlay(
            RoundedRectangle(cornerRadius: IridescenceTheme.radiusSm)
                .stroke(IridescenceTheme.hairline, lineWidth: 1)
        )
    }

    private var phaseTitle: String {
        switch phase {
        case .resolvingAsset: return "Resolving compatible asset..."
        case .downloading: return "Downloading \(appName)..."
        case .verifyingIntegrity: return "Verifying SHA256 integrity..."
        case .extracting: return "Extracting application..."
        case .validatingBundle: return "Validating application bundle..."
        case .backingUp: return "Backing up previous version..."
        case .terminatingRunningApp: return "Closing running instance..."
        case .installing: return "Installing \(appName)..."
        case .handlingQuarantine: return "Applying quarantine policy..."
        case .completed: return "Installation completed"
        case .failed(let err): return "Failed: \(err)"
        }
    }

    private var progressFraction: CGFloat {
        switch phase {
        case .resolvingAsset: return 0.1
        case .downloading(let p): return 0.1 + (0.5 * CGFloat(p))
        case .verifyingIntegrity: return 0.65
        case .extracting: return 0.75
        case .validatingBundle: return 0.85
        case .backingUp: return 0.90
        case .terminatingRunningApp: return 0.92
        case .installing: return 0.96
        case .handlingQuarantine: return 0.98
        case .completed: return 1.0
        case .failed: return 1.0
        }
    }

    private var barGradient: LinearGradient {
        LinearGradient(
            colors: [IridescenceTheme.electricBlue, IridescenceTheme.luminousCyan],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
