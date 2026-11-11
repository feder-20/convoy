// swift-tools-version:6.0
import PackageDescription

// Arquitectura hexagonal (convoy.md §8): Domain ← Ports ← Application; Adapters implementan Ports.
// El dominio no importa AppKit ni FileManager.
let package = Package(
    name: "Convoy",
    defaultLocalization: "es",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Convoy", targets: ["ConvoyApp"])],
    targets: [
        .target(name: "ConvoyDomain"),
        .target(name: "ConvoyPorts", dependencies: ["ConvoyDomain"]),
        // Prueba y licencia: lógica pura (CryptoKit, sin AppKit).
        .target(name: "ConvoyLicensing", dependencies: ["ConvoyDomain", "ConvoyPorts"]),
        .target(name: "ConvoyApplication", dependencies: ["ConvoyDomain", "ConvoyPorts"]),
        .target(name: "ConvoyAdapters", dependencies: ["ConvoyDomain", "ConvoyPorts"]),
        .executableTarget(name: "ConvoyApp", dependencies: ["ConvoyDomain", "ConvoyPorts", "ConvoyApplication", "ConvoyAdapters", "ConvoyLicensing"]),
        .testTarget(name: "DomainTests", dependencies: ["ConvoyDomain"]),
        .testTarget(name: "ApplicationTests", dependencies: ["ConvoyDomain", "ConvoyPorts", "ConvoyApplication"]),
        .testTarget(name: "LicensingTests", dependencies: ["ConvoyDomain", "ConvoyPorts", "ConvoyLicensing"]),
        .testTarget(name: "AdapterTests", dependencies: ["ConvoyDomain", "ConvoyPorts", "ConvoyApplication", "ConvoyAdapters"]),
        .testTarget(name: "AppTests", dependencies: ["ConvoyApp", "ConvoyDomain", "ConvoyApplication", "ConvoyLicensing"]),
    ]
)
