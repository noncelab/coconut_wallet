//! BIP32 path utilities.

use crate::constants::HARDENED_OFFSET;
use crate::error::{BitcoinError, Result};

/// Parse a BIP32 path string to a vector of u32 indices.
///
/// Supports both apostrophe (') and 'h' notation for hardened keys.
///
/// # Examples
///
/// ```
/// use trezor_connect_rs::types::path::parse_path;
///
/// let path = parse_path("m/84'/0'/0'/0/0").unwrap();
/// assert_eq!(path.len(), 5);
/// ```
pub fn parse_path(path: &str) -> Result<Vec<u32>> {
    let path = path.trim();

    // Handle "m" alone as empty path
    if path == "m" {
        return Ok(vec![]);
    }

    // Remove leading 'm/' if present
    let path = path.strip_prefix("m/").unwrap_or(path);

    if path.is_empty() {
        return Ok(vec![]);
    }

    let mut result = Vec::new();

    for component in path.split('/') {
        let component = component.trim();
        if component.is_empty() {
            continue;
        }

        let (num_str, is_hardened) = if component.ends_with('\'') || component.ends_with('h') {
            (&component[..component.len() - 1], true)
        } else {
            (component, false)
        };

        let num: u32 = num_str
            .parse()
            .map_err(|_| BitcoinError::InvalidPath(format!("Invalid component: {}", component)))?;

        if is_hardened {
            result.push(num | HARDENED_OFFSET);
        } else {
            result.push(num);
        }
    }

    Ok(result)
}

/// Serialize a path to string format.
///
/// # Examples
///
/// ```
/// use trezor_connect_rs::types::path::{parse_path, serialize_path};
///
/// let path = parse_path("m/84'/0'/0'/0/0").unwrap();
/// let serialized = serialize_path(&path);
/// assert_eq!(serialized, "m/84'/0'/0'/0/0");
/// ```
pub fn serialize_path(path: &[u32]) -> String {
    let components: Vec<String> = path
        .iter()
        .map(|&n| {
            if n >= HARDENED_OFFSET {
                format!("{}'", n - HARDENED_OFFSET)
            } else {
                n.to_string()
            }
        })
        .collect();

    if components.is_empty() {
        "m".to_string()
    } else {
        format!("m/{}", components.join("/"))
    }
}

/// Check if a path index is hardened.
pub fn is_hardened(index: u32) -> bool {
    index >= HARDENED_OFFSET
}

/// Make an index hardened.
pub fn harden(index: u32) -> u32 {
    index | HARDENED_OFFSET
}

/// Get the unhardened value of an index.
pub fn unharden(index: u32) -> u32 {
    index & !HARDENED_OFFSET
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_path() {
        let path = parse_path("m/84'/0'/0'/0/0").unwrap();
        assert_eq!(path.len(), 5);
        assert!(is_hardened(path[0]));
        assert!(is_hardened(path[1]));
        assert!(is_hardened(path[2]));
        assert!(!is_hardened(path[3]));
        assert!(!is_hardened(path[4]));

        assert_eq!(unharden(path[0]), 84);
        assert_eq!(unharden(path[1]), 0);
        assert_eq!(unharden(path[2]), 0);
    }

    #[test]
    fn test_parse_path_h_notation() {
        let path = parse_path("m/84h/0h/0h/0/0").unwrap();
        assert_eq!(path.len(), 5);
        assert!(is_hardened(path[0]));
    }

    #[test]
    fn test_serialize_path() {
        let path = vec![harden(84), harden(0), harden(0), 0, 0];
        assert_eq!(serialize_path(&path), "m/84'/0'/0'/0/0");
    }

    #[test]
    fn test_empty_path() {
        let path = parse_path("m").unwrap();
        assert!(path.is_empty());
    }
}
