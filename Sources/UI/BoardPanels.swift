import KoikoiCore
import SwiftUI

// visionOS の空間ボード（`Sources/App/SpatialBoardView.swift`）が RealityView の
// attachment として卓の上に浮かべるパネル群。2D の盤面と同じ部品（`YakuBadges` /
// `ReachList` / `GameScoreboard`）を使い、文言と配色を 1 か所に保つために
// KoikoiUI 側で組み立てて公開する。

extension GameViewModel {
    /// 進行の案内文（ダイアログが出ている局面では nil）。
    /// 2D 版の `statusText` と違い、visionOS には Esc キーが無いので括弧書きは付けない。
    var boardPromptLine: String? {
        switch prompt {
        case .selectHand:
            return String(localized: "Choose a card from your hand", bundle: .module)
        case .selectField:
            return String(localized: "Choose a field card to take", bundle: .module)
        case .opponentTurn:
            return String(localized: "Opponent's turn…", bundle: .module)
        case .decideKoikoi, .roundEnd, .matchEnd:
            return nil
        }
    }
}

/// 空間ボードのパネルの地。ガラス（`regularMaterial`）に卓の色を薄く重ね、
/// どのテーマでも `palette.ink` の文字が読める濃さにする。
private struct BoardPanelBackground: ViewModifier {
    @Environment(\.koikoiPalette)
    private var palette

    func body(content: Content) -> some View {
        content
            .padding(14)
            .background {
                let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
                shape
                    .fill(.regularMaterial)
                    .overlay { shape.fill(palette.table.opacity(0.55)) }
                    .overlay { shape.stroke(palette.ink.opacity(0.25), lineWidth: 1) }
            }
    }
}

/// 成立中の役とリーチをまとめた、卓に垂直に立つパネル（visionOS）。
/// 出すものが何も無いときは何も描かない（空のガラス板を残さない）。
public struct BoardYakuPanel: View {
    /// どちらの陣営のパネルか。
    public enum Side: Sendable {
        case player
        case opponent
    }

    @Environment(\.koikoiPalette)
    private var palette
    private let model: GameViewModel
    private let side: Side

    public init(model: GameViewModel, side: Side) {
        self.model = model
        self.side = side
    }

    private var yakus: [Yaku] {
        side == .player ? model.playerYaku : model.opponentYaku
    }

    /// リーチは自分の側だけ出す（相手の手の内は見せない）。
    private var reaches: [YakuReach] {
        side == .player ? model.playerReaches : []
    }

    private var isEmpty: Bool {
        yakus.isEmpty && reaches.isEmpty
    }

    public var body: some View {
        if !isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                YakuBadges(yakus: yakus, stacked: true)
                if !reaches.isEmpty {
                    ReachList(reaches: reaches, wraps: true)
                }
            }
            .foregroundStyle(palette.ink)
            .frame(width: 190, alignment: .leading)
            .modifier(BoardPanelBackground())
        }
    }
}

/// 月・局・得点の 1 行スコアボード（visionOS の空間ボードで卓の左に立てる）。
/// 右端に対局をやめるボタンを置き、確認ダイアログもこのパネルから出す。
public struct ScoreboardStrip: View {
    @Environment(\.koikoiPalette)
    private var palette
    private let model: GameViewModel
    private let onQuit: (() -> Void)?
    @State private var confirmingQuit = false

    public init(model: GameViewModel, onQuit: (() -> Void)? = nil) {
        self.model = model
        self.onQuit = onQuit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                GameScoreboard(model: model, style: .strip)
                if let onQuit {
                    quitButton(onQuit)
                }
            }
            if let line = model.boardPromptLine {
                Text(verbatim: line)
                    .font(.caption)
                    .foregroundStyle(palette.highlight)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(palette.ink)
        .modifier(BoardPanelBackground())
    }

    /// 2D 版のツールバーと同じ文言の確認。
    /// visionOS の confirmationDialog は cancel ロールのボタンを描かないため、
    /// 「やめる」「続ける」が必ず両方出るアラートにする。
    private func quitButton(_ quit: @escaping () -> Void) -> some View {
        Button(String(localized: "Quit Game", bundle: .module), systemImage: "xmark") {
            confirmingQuit = true
        }
        .labelStyle(.iconOnly)
        .alert(
            Text("Quit this game?", bundle: .module),
            isPresented: $confirmingQuit
        ) {
            Button(String(localized: "Quit", bundle: .module), role: .destructive, action: quit)
            Button(String(localized: "Continue", bundle: .module), role: .cancel) {}
        } message: {
            Text("The saved game will be deleted.", bundle: .module)
        }
    }
}
