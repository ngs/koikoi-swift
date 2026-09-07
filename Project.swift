import ProjectDescription

let version = "1.0.0"
let copyright = "© 2026 LittleApps Inc. All rights reserved."

let buildNumber = Environment.buildNumber.getString(default: "0")

let project = Project(
    name: "Koikoi",
    organizationName: "LittleApps Inc.",
    options: .options(
        defaultKnownRegions: ["en", "ja"],
        developmentRegion: "en",
        // 札画像は Card.assetName で名前解決するため、生成アクセサは使わない
        disableSynthesizedResourceAccessors: true
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
            "SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD": "NO",
            // visionOS は volumetric ウィンドウのみのため、既定シーンのロールを
            // SDK 別に切り替える（Info.plist の $(KOIKOI_DEFAULT_SCENE_ROLE) で参照）
            "KOIKOI_DEFAULT_SCENE_ROLE": .string("UIWindowSceneSessionRoleApplication"),
            "KOIKOI_DEFAULT_SCENE_ROLE[sdk=xros*]":
                .string("UIWindowSceneSessionRoleVolumetricApplication"),
            "KOIKOI_DEFAULT_SCENE_ROLE[sdk=xrsimulator*]":
                .string("UIWindowSceneSessionRoleVolumetricApplication")
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
                // visionOS の volumetric ウィンドウ等、複数シーンを開けるようにする
                // （false だと openWindow が黙って失敗する）
                "UIApplicationSceneManifest": [
                    "UIApplicationSupportsMultipleScenes": true,
                    "UIApplicationPreferredDefaultSceneSessionRole":
                        .string("$(KOIKOI_DEFAULT_SCENE_ROLE)")
                ],
                "CFBundleDisplayName": .string("Koikoi"),
                "CFBundleVersion": .string("$(CURRENT_PROJECT_VERSION)"),
                "CFBundleShortVersionString": .string("$(MARKETING_VERSION)"),
                "NSHumanReadableCopyright": .string(copyright),
                "LSApplicationCategoryType": .string("public.app-category.card-games"),
                "UILaunchScreen": [
                    "UIColorName": "AccentColor",
                    "UIImageRespectsSafeAreaInsets": true
                ],
                // アプリ内 D&D 用の札ペイロード型（KoikoiUI の UTType.koikoiCard）と
                // 対局記録ファイル（.koikoi = UTType.koikoiGame）
                "UTExportedTypeDeclarations": [
                    [
                        "UTTypeIdentifier": "io.ngs.Koikoi.card",
                        "UTTypeDescription": "Koikoi card",
                        "UTTypeConformsTo": ["public.data"]
                    ],
                    [
                        "UTTypeIdentifier": "io.ngs.Koikoi.game",
                        "UTTypeDescription": "Koikoi game",
                        "UTTypeConformsTo": ["public.json"],
                        "UTTypeTagSpecification": [
                            "public.filename-extension": ["koikoi"]
                        ]
                    ]
                ]
            ]),
            sources: ["Sources/App/**"],
            // entitlements は resources グロブから外す（バンドルにコピーされ tuist generate が警告する）
            resources: [
                .glob(pattern: "Resources/**", excluding: ["Resources/Koikoi.entitlements"])
            ],
            entitlements: "Resources/Koikoi.entitlements",
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
            ],
            // iOS / macOS のアイコンは Resources/AppIcon.icon（Icon Composer）から Xcode が生成する。
            // visionOS は Icon Composer 非対応で 3 レイヤーの solidimagestack が必須のため別アセットを使う
            // （未設定だと CFBundleIcons.CFBundlePrimaryIcon 欠落でアップロードが 90970 で失敗する）。
            // Tuist がターゲットへ無条件の ASSETCATALOG_COMPILER_APPICON_NAME を自動生成するため、
            // プロジェクトレベルではなくターゲットレベルで上書きする必要がある。
            settings: .settings(base: [
                "ASSETCATALOG_COMPILER_APPICON_NAME": .string("AppIcon"),
                "ASSETCATALOG_COMPILER_APPICON_NAME[sdk=xros*]": .string("AppIconVision"),
                "ASSETCATALOG_COMPILER_APPICON_NAME[sdk=xrsimulator*]": .string("AppIconVision")
            ])
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
