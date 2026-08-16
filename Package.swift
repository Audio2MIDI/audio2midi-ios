// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Audio2MIDICore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "Audio2MIDICore", targets: ["Audio2MIDICore"])],
    targets: [
        .target(name: "Audio2MIDICore"),
        .testTarget(name: "Audio2MIDICoreTests", dependencies: ["Audio2MIDICore"]),
    ]
)

