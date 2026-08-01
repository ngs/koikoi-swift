import ProjectDescription

let version = "0.1.0"
let copyright = "© 2026 Atsushi Nagase. All rights reserved."

let buildNumber = Environment.buildNumber.getString(default: "0")

let project = Project(
    name: "Koikoi",
    organizationName: "Atsushi Nagase",
    options: .options(
        defaultKnownRegions: ["en", "ja"],
        developmentRegion: "en"
    ),
    packages: [
        .package(path: ".")
    ],
    settings: .settings(
        base: [
            "INFOPLIST_KEY_LSApplicationCategoryType": .string("public.app-category.card-games"),
            "CURRENT_PROJECT_VERSION": .string(buildNumber),
            "MARKETING_VERSION": .string(version),
            "DEVELOPMENT_TEAM": .string("3Y8APYUG2G"),
            // Development builds provision themselves; the release lanes switch
            // the Release configuration to the match profiles.
            "CODE_SIGN_STYLE": .string("Automatic"),
            "SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD": "NO"
        ]),
    targets: [
        .target(
            name: "Koikoi",
            destinations: [.iPhone, .iPad, .mac, .appleVision],
            product: .app,
            bundleId: "io.ngs.Koikoi",
            deploymentTargets: .multiplatform(
                iOS: "26.0",
                macOS: "26.0",
                visionOS: "26.0"
            ),
            infoPlist: .extendingDefault(with: [
                "ITSAppUsesNonExemptEncryption": .boolean(false),
                "CFBundleDisplayName": .string("Koikoi"),
                "CFBundleVersion": .string("$(CURRENT_PROJECT_VERSION)"),
                "CFBundleShortVersionString": .string("$(MARKETING_VERSION)"),
                "NSHumanReadableCopyright": .string(copyright),
                "LSApplicationCategoryType": .string("public.app-category.card-games"),
                "UILaunchScreen": [
                    "UIColorName": "AccentColor",
                    "UIImageRespectsSafeAreaInsets": true
                ]
            ]),
            sources: ["Sources/App/**"],
            resources: ["Resources/**"],
            scripts: [
                .pre(
                    script: "${SRCROOT}/Scripts/swiftlint-fix-build-phase.sh",
                    name: "SwiftLint Auto-Fix",
                    basedOnDependencyAnalysis: false
                )
            ],
            dependencies: [
                .package(product: "KoikoiCore"),
                .package(product: "KoikoiAI"),
                .package(product: "KoikoiUI")
            ]
        ),
        .target(
            name: "KoikoiTests",
            destinations: [.iPhone, .iPad, .mac, .appleVision],
            product: .unitTests,
            bundleId: "io.ngs.Koikoi.tests",
            deploymentTargets: .multiplatform(
                iOS: "26.0",
                macOS: "26.0",
                visionOS: "26.0"
            ),
            infoPlist: .default,
            sources: ["Tests/AppTests/**"],
            dependencies: [
                .target(name: "Koikoi")
            ]
        )
    ]
)
