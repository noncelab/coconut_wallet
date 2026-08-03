//! BIP39 passphrase normalization.
//!
//! Trezor firmware derives the wallet seed from the UTF-8 bytes of the
//! passphrase, so the *exact* byte sequence matters. The official
//! `@trezor/connect` client normalizes every passphrase to Unicode **NFKD**
//! before sending it (`value.normalize('NFKD')`), and so must we: otherwise a
//! passphrase containing composable Unicode (accented letters, many non-Latin
//! scripts, some symbols) would be sent with whatever composition the host
//! OS/keyboard happened to produce, deriving a *different* hidden wallet than
//! Trezor Suite derives for the same typed string. ASCII passphrases are
//! unaffected (NFKD is a no-op for them).
//!
//! NFKD is idempotent, so normalizing an already-normalized passphrase is
//! harmless.

use unicode_normalization::UnicodeNormalization;

/// Normalize a passphrase to Unicode NFKD, matching `@trezor/connect`.
///
/// Apply this to any host-entered passphrase immediately before it is bound to
/// a session (legacy `PassphraseAck` or THP `ThpCreateNewSession`). On-device
/// entry and the empty (standard-wallet) passphrase do not need it, but calling
/// it on them is safe.
///
/// The result is built into a single exactly-sized allocation, so normalization
/// leaves no reallocated fragments of the passphrase in the heap; callers hold
/// the returned `String` in `Zeroizing` to wipe that allocation on drop.
/// (Zeroization remains best-effort generally: the input `&str` and any
/// serialized/protobuf copies made by callers live outside this function.)
pub(crate) fn normalize_passphrase(passphrase: &str) -> String {
    // Size the buffer up front so filling it never reallocates. A growing
    // `collect()` would copy the partial passphrase into a larger buffer and
    // free the old one *without* wiping it, leaving fragments behind. The first
    // pass only sums char lengths (chars are `Copy`, so it allocates nothing);
    // the second fills the pre-sized buffer, which is then the only place the
    // normalized passphrase ever lives.
    let len: usize = passphrase.nfkd().map(char::len_utf8).sum();
    let mut normalized = String::with_capacity(len);
    normalized.extend(passphrase.nfkd());
    normalized
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ascii_is_unchanged() {
        assert_eq!(normalize_passphrase("hunter2"), "hunter2");
        assert_eq!(normalize_passphrase(""), "");
    }

    #[test]
    fn precomposed_and_decomposed_converge() {
        // U+00E9 (é, precomposed) and "e" + U+0301 (combining acute) must
        // produce the same NFKD byte sequence so both derive the same wallet.
        let precomposed = "caf\u{00e9}";
        let decomposed = "cafe\u{0301}";
        assert_ne!(precomposed.as_bytes(), decomposed.as_bytes());
        assert_eq!(
            normalize_passphrase(precomposed),
            normalize_passphrase(decomposed)
        );
    }

    #[test]
    fn compatibility_decomposition_applies() {
        // NFKD (not just NFD) decomposes compatibility characters, e.g. the
        // ligature U+FB01 (ﬁ) becomes "fi".
        assert_eq!(normalize_passphrase("\u{fb01}"), "fi");
    }

    #[test]
    fn is_idempotent() {
        let once = normalize_passphrase("caf\u{00e9} \u{fb01}");
        assert_eq!(normalize_passphrase(&once), once);
    }
}
