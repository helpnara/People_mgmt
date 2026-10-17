// swift-tools-version: 6.0
import PackageDescription

// Core 는 Foundation 만 쓴다 (ADR-0002).
// SwiftUI · SwiftData 를 import 하면 리눅스 CI 의 `swift test` 가 통째로 없어진다.
// 그 경계가 이 저장소에서 유일하게 빠른 심판이다 — 원격 세션은 컴파일을 못 한다.
let package = Package(
    name: "Core",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "Core", targets: ["Core"]),
    ],
    targets: [
        .target(name: "Core"),
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"],
            // Golden/ 은 파이썬이 만든 기댓값 JSON 이다. 테스트가 #filePath 로
            // 직접 읽으므로 번들 리소스로 선언하지 않는다 (리눅스에서 더 안전하다).
            exclude: ["Golden"]
        ),
    ]
)
