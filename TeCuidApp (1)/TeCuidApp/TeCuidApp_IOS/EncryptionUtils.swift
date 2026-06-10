import Foundation
import CryptoKit

// ─────────────────────────────────────────────────────────────────────────────
//  🔑  ENCRYPTION KEY  🔑
//
//  Paste the EXACT value of `ENCRYPTION_KEY` from the Android project's
//  `local.properties` file into the string below.
//
//  • In Android: `local.properties` → `ENCRYPTION_KEY=<your_secret_string>`
//  • That same string is what `BuildConfig.ENCRYPTION_KEY` resolves to and what
//    the Kotlin `EncryptionUtils` uses as the SHA-256 input to derive the AES
//    key. If even one character differs, decryption silently returns the
//    encrypted blob unchanged (matching the Kotlin behavior).
//
//  ⚠️  Without the real value, encrypted fields from Firestore will show up
//      as Base64 strings in the UI. Replace the placeholder when you have it.
// ─────────────────────────────────────────────────────────────────────────────

private let ENCRYPTION_KEY = "p7uao87QRn1AN0gIiH6XbRxaB36DK4FO/LxpibJQ/14="

/// Swift port of the Android `EncryptionUtils` object.
///
/// Byte-format compatibility with the Kotlin version:
///   • AES/GCM/NoPadding, 12-byte IV, 128-bit auth tag.
///   • Stored as Base64(iv ‖ ciphertext ‖ tag) — what CryptoKit's
///     `AES.GCM.SealedBox.combined` produces.
///   • The raw key is SHA-256-hashed to derive the 256-bit AES key.
enum EncryptionUtils {

    private static let key: SymmetricKey = {
        let digest = SHA256.hash(data: Data(ENCRYPTION_KEY.utf8))
        return SymmetricKey(data: Data(digest))
    }()

    /// Decrypts a Base64(iv ‖ ciphertext ‖ tag) blob.
    /// Returns the input unchanged if it can't be decrypted — same as the
    /// Kotlin version, so it's always safe to call on any string field.
    static func decrypt(_ value: String) -> String {
        guard !value.isEmpty,
              let data = Data(base64Encoded: value),
              data.count > 12 else { return value }
        do {
            let box = try AES.GCM.SealedBox(combined: data)
            let plain = try AES.GCM.open(box, using: key)
            return String(data: plain, encoding: .utf8) ?? value
        } catch {
            return value
        }
    }

    /// Encrypts a UTF-8 string and returns Base64(iv ‖ ciphertext ‖ tag).
    /// Kept symmetric with the Kotlin `encrypt()` so writes are reversible
    /// by the Android client.
    static func encrypt(_ value: String) -> String {
        guard !value.isEmpty, let plain = value.data(using: .utf8) else { return value }
        do {
            let box = try AES.GCM.seal(plain, using: key)
            return box.combined?.base64EncodedString() ?? value
        } catch {
            return value
        }
    }

    /// SHA-256 hash of a trimmed string, Base64-encoded. Mirrors Android `hash()`.
    static func hash(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let digest = SHA256.hash(data: Data(trimmed.utf8))
        return Data(digest).base64EncodedString()
    }
}
