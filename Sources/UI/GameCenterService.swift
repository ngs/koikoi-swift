import Foundation
import GameKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Game Center 連携。認証・アクセスポイント表示・対局結果の報告を行う。
/// 認証不可・報告失敗はすべて黙って無視し、ゲーム進行には影響させない。
@MainActor
public final class GameCenterService {
    public static let shared = GameCenterService()

    /// リーダーボード ID（App Store Connect 側の定義と一致させる）。
    enum LeaderboardID {
        static let wins = "io.ngs.Koikoi.wins"
        static let totalPoints = "io.ngs.Koikoi.totalpoints"
    }

    public private(set) var isAuthenticated = false
    private var didStartAuthentication = false

    private init() {}

    /// 起動時に一度呼ぶ。サインイン UI が必要なら提示し、
    /// 成功したらアクセスポイントを左上に表示する。
    public func authenticate() {
        guard !didStartAuthentication else { return }
        didStartAuthentication = true
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in
                if let viewController {
                    self?.present(viewController)
                    return
                }
                guard error == nil, GKLocalPlayer.local.isAuthenticated else { return }
                self?.isAuthenticated = true
                GKAccessPoint.shared.location = .topLeading
                GKAccessPoint.shared.showHighlights = false
                GKAccessPoint.shared.isActive = true
            }
        }
    }

    /// サインイン UI を最前面から提示する。
    #if canImport(UIKit)
    private func present(_ viewController: UIViewController) {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        scene?.keyWindow?.rootViewController?
            .present(viewController, animated: true)
    }
    #elseif canImport(AppKit)
    private func present(_ viewController: NSViewController) {
        NSApp.keyWindow?.contentViewController?
            .presentAsSheet(viewController)
    }
    #endif

    /// 対局終了を報告する（勝利数と累計文数）。
    public func reportMatchEnd(playerWon: Bool, playerScore: Int) {
        guard isAuthenticated else { return }
        Task {
            if playerWon {
                try? await GKLeaderboard.submitScore(
                    1, context: 0, player: GKLocalPlayer.local,
                    leaderboardIDs: [LeaderboardID.wins])
            }
            try? await GKLeaderboard.submitScore(
                playerScore, context: 0, player: GKLocalPlayer.local,
                leaderboardIDs: [LeaderboardID.totalPoints])
        }
    }
}
