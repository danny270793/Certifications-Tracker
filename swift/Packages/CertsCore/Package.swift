// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "CertsCore",
  defaultLocalization: "en",
  platforms: [.iOS(.v26), .macOS(.v26)],
  products: [
    .library(name: "CertsCore", targets: ["CertsCore"]),
    .library(name: "CertsData", targets: ["CertsData"]),
  ],
  dependencies: [
    .package(url: "https://github.com/supabase/supabase-swift", from: "2.55.0"),
  ],
  targets: [
    // Certification entity, sorting, tag helpers and dashboard counts. No I/O.
    .target(name: "CertsCore"),
    // Supabase repository (`cert_certifications` + the `cert-pdfs` bucket) and the offline JSON cache.
    .target(
      name: "CertsData",
      dependencies: [
        "CertsCore",
        .product(name: "Supabase", package: "supabase-swift"),
      ]
    ),
    .testTarget(name: "CertsCoreTests", dependencies: ["CertsCore"]),
    .testTarget(name: "CertsDataTests", dependencies: ["CertsData"]),
  ]
)
