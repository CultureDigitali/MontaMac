import CryptoKit
import Foundation

// Gate signed releases against the key embedded in the actual shipped app.
// Usage: swift Scripts/verify-sparkle-release.swift MontaMac.app dist/MontaMac-x.zip dist/appcast.xml
guard CommandLine.arguments.count == 4 else {
    fatalError("Expected app path, update ZIP and appcast")
}
let app = URL(fileURLWithPath: CommandLine.arguments[1])
let archive = URL(fileURLWithPath: CommandLine.arguments[2])
let appcast = URL(fileURLWithPath: CommandLine.arguments[3])
let plist = app.appendingPathComponent("Contents/Info.plist")
guard let info = NSDictionary(contentsOf: plist),
      let encodedKey = info["SUPublicEDKey"] as? String,
      let publicKeyData = Data(base64Encoded: encodedKey),
      let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData) else {
    fatalError("Shipped application has no valid Sparkle Ed25519 public key")
}
let xml = try String(contentsOf: appcast, encoding: .utf8)
let signaturePattern = #"sparkle:edSignature="([A-Za-z0-9+/=]+)""#
let expression = try NSRegularExpression(pattern: signaturePattern)
let range = NSRange(xml.startIndex..<xml.endIndex, in: xml)
guard let match = expression.firstMatch(in: xml, range: range),
      let signatureRange = Range(match.range(at: 1), in: xml),
      let signature = Data(base64Encoded: String(xml[signatureRange])) else {
    fatalError("Appcast is missing a valid EdDSA archive signature")
}
let archiveData = try Data(contentsOf: archive)
guard publicKey.isValidSignature(signature, for: archiveData) else {
    fatalError("Sparkle archive signature does not match shipped public key")
}
print("SPARKLE_SIGNATURE_VERIFIED")
