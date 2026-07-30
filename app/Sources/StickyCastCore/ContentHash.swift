import Foundation
import CryptoKit

/// 콘텐츠의 안정적 SHA-256 hex. String.hashValue는 실행마다 시드가 달라 불가 — CryptoKit 사용.
public enum ContentHash {
    public static func sha256Hex(_ s: String) -> String {
        let digest = SHA256.hash(data: Data(s.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
