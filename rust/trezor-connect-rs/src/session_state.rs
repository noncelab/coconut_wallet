//! Static session id derivation and wrong-passphrase detection.
//!
//! A passphrase opens a *different* wallet for every distinct value, but the
//! host never sees the seed and so cannot tell from the passphrase string alone
//! whether the user re-entered the same passphrase as last time (a typo on a
//! hidden wallet silently opens a different, usually empty, wallet).
//!
//! `@trezor/connect` solves this with a **static session id**: a stable
//! fingerprint of the active wallet, derived by asking the device for its first
//! testnet receive address (`m/44'/1'/0'/0/0`, P2PKH) and combining it with the
//! device id and host wallet instance:
//!
//! ```text
//! <firstTestnetAddress>@<deviceId>:<instance>
//! ```
//!
//! The address depends on seed + passphrase, so it changes whenever the
//! passphrase changes. By remembering the expected static session id and
//! comparing it against a freshly derived one, a wrong passphrase can be
//! detected ([`is_unexpected_state`]) and surfaced as
//! [`crate::error::DeviceError::InvalidState`].
//!
//! This library is single-instance (one passphrase per transport/session), so
//! the `instance` component is always `0`; it is kept in the format string for
//! wire-compatibility with trezor-suite. Matching trezor-suite, the instance is
//! **ignored** when comparing two ids — only the address and device id matter.

/// Build a static session id string in the trezor-suite format
/// `<firstTestnetAddress>@<deviceId>:<instance>`.
pub fn build_static_session_id(
    first_testnet_address: &str,
    device_id: &str,
    instance: u32,
) -> String {
    format!("{}@{}:{}", first_testnet_address, device_id, instance)
}

/// The parsed components of a static session id.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct StaticSessionId {
    /// First testnet receive address (`m/44'/1'/0'/0/0`), seed+passphrase bound.
    pub first_testnet_address: String,
    /// Device id reported in `Features.device_id`.
    pub device_id: String,
    /// Host wallet instance (always `0` in this library).
    pub instance: u32,
}

/// Parse a static session id of the form `<address>@<deviceId>:<instance>`.
///
/// Strictly validates the shape, mirroring trezor-suite's `isStaticSessionId` /
/// `parseStaticSessionId`: exactly one `@` and exactly one `:`, a non-empty
/// address and device id, and a canonical non-negative integer instance (no
/// leading zeros, no sign). Returns `None` for anything else.
pub fn parse_static_session_id(state: &str) -> Option<StaticSessionId> {
    // Exactly one `@`, splitting address from the rest.
    if state.matches('@').count() != 1 {
        return None;
    }
    let (address, rest) = state.split_once('@')?;
    // Exactly one `:`, splitting device id from instance.
    if rest.matches(':').count() != 1 {
        return None;
    }
    let (device_id, instance) = rest.split_once(':')?;
    if address.is_empty() || device_id.is_empty() {
        return None;
    }
    let instance = parse_canonical_u32(instance)?;
    Some(StaticSessionId {
        first_testnet_address: address.to_string(),
        device_id: device_id.to_string(),
        instance,
    })
}

/// Parse a canonical non-negative integer: either `"0"`, or a digit string with
/// no leading zero. Mirrors trezor-suite's `isNonNegativeIntegerString`
/// (`/^(0|[1-9]\d*)$/`), so values `parse::<u32>` would silently accept (e.g.
/// `"01"`) are rejected.
fn parse_canonical_u32(s: &str) -> Option<u32> {
    let canonical =
        s == "0" || (!s.starts_with('0') && !s.is_empty() && s.bytes().all(|b| b.is_ascii_digit()));
    if !canonical {
        return None;
    }
    s.parse::<u32>().ok()
}

/// Returns `true` if `current` represents a different wallet than `expected`.
///
/// Compares only the first testnet address and device id (the instance is
/// deliberately ignored, matching trezor-suite's `isUnexpectedState`). If either
/// id is empty or unparseable, returns `false` — there is nothing to compare
/// against, so it is not treated as a mismatch.
pub fn is_unexpected_state(expected: &str, current: &str) -> bool {
    if expected.is_empty() || current.is_empty() {
        return false;
    }
    match (
        parse_static_session_id(expected),
        parse_static_session_id(current),
    ) {
        (Some(e), Some(c)) => {
            e.first_testnet_address != c.first_testnet_address || e.device_id != c.device_id
        }
        // Unparseable input: don't claim a mismatch we can't substantiate.
        _ => false,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn build_and_parse_roundtrip() {
        let id = build_static_session_id("tb1qaddr", "dev123", 0);
        assert_eq!(id, "tb1qaddr@dev123:0");
        let parsed = parse_static_session_id(&id).unwrap();
        assert_eq!(parsed.first_testnet_address, "tb1qaddr");
        assert_eq!(parsed.device_id, "dev123");
        assert_eq!(parsed.instance, 0);
    }

    #[test]
    fn parse_rejects_malformed() {
        assert!(parse_static_session_id("no-separators").is_none());
        assert!(parse_static_session_id("addr@deviceid").is_none()); // missing :instance
        assert!(parse_static_session_id("@deviceid:0").is_none()); // empty address
        assert!(parse_static_session_id("addr@:0").is_none()); // empty device id
        assert!(parse_static_session_id("addr@deviceid:x").is_none()); // non-numeric instance
        assert!(parse_static_session_id("addr@deviceid:01").is_none()); // leading-zero instance
        assert!(parse_static_session_id("addr@deviceid:-1").is_none()); // signed instance
        assert!(parse_static_session_id("a@b:0:1").is_none()); // extra ':'
        assert!(parse_static_session_id("a@b@c:0").is_none()); // extra '@'
    }

    #[test]
    fn same_passphrase_is_expected() {
        let a = build_static_session_id("tb1qsame", "dev", 0);
        let b = build_static_session_id("tb1qsame", "dev", 0);
        assert!(!is_unexpected_state(&a, &b));
    }

    #[test]
    fn different_address_is_unexpected() {
        // A different passphrase yields a different first testnet address.
        let expected = build_static_session_id("tb1qwallet_a", "dev", 0);
        let current = build_static_session_id("tb1qwallet_b", "dev", 0);
        assert!(is_unexpected_state(&expected, &current));
    }

    #[test]
    fn instance_is_ignored_in_comparison() {
        let expected = build_static_session_id("tb1qsame", "dev", 0);
        let current = build_static_session_id("tb1qsame", "dev", 7);
        assert!(!is_unexpected_state(&expected, &current));
    }

    #[test]
    fn different_device_is_unexpected() {
        let expected = build_static_session_id("tb1qsame", "dev_a", 0);
        let current = build_static_session_id("tb1qsame", "dev_b", 0);
        assert!(is_unexpected_state(&expected, &current));
    }

    #[test]
    fn empty_inputs_are_not_a_mismatch() {
        let current = build_static_session_id("tb1qsame", "dev", 0);
        assert!(!is_unexpected_state("", &current));
        assert!(!is_unexpected_state(&current, ""));
    }
}
