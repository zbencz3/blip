import Foundation
import Crypto

enum SecretGenerator {
    static func generate() -> String {
        let bytes = SymmetricKey(size: .bits256)
        let hex = bytes.withUnsafeBytes { buffer in
            buffer.map { String(format: "%02x", $0) }.joined()
        }
        return "bps_usr_\(hex)"
    }
}
