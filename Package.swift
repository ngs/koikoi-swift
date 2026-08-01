// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Koikoi",
    defaultLocalization: "en",
    platforms: [
        .iOS("26.0"),
        .macOS("26.0"),
        .visionOS("26.0"),
    ],
    products: [
        // Static so Xcode never embeds them as (separately signed) dynamic
        // frameworks in the app bundles.
        .library(name: "KoikoiCore", type: .static, targets: ["KoikoiCore"]),
        .library(name: "KoikoiAI", type: .static, targets: ["KoikoiAI"]),
        .library(name: "KoikoiUI", type: .static, targets: ["KoikoiUI"]),
    ],
    targets: [
        // Rules engine: cards, yaku evaluation, round/match state machine.
        // Ported from ngs/go-koikoi (Nintendo rules). Foundation only.
        .target(
            name: "KoikoiCore",
            path: "Sources/Core",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .swiftLanguageMode(.v6),
            ]
        ),
        // Opponent: determinized ISMCTS search over KoikoiCore plus an
        // on-device FoundationModels persona (table talk, koikoi rationale).
        .target(
            name: "KoikoiAI",
            dependencies: [
                .target(name: "KoikoiCore")
            ],
            path: "Sources/AI",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .swiftLanguageMode(.v6),
            ]
        ),
        // SwiftUI views and view models shared by every platform.
        .target(
            name: "KoikoiUI",
            dependencies: [
                .target(name: "KoikoiCore"),
                .target(name: "KoikoiAI"),
            ],
            path: "Sources/UI",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "KoikoiCoreTests",
            dependencies: ["KoikoiCore"],
            path: "Tests/KoikoiCoreTests"
        ),
        .testTarget(
            name: "KoikoiAITests",
            dependencies: ["KoikoiAI", "KoikoiCore"],
            path: "Tests/KoikoiAITests"
        ),
    ]
)
