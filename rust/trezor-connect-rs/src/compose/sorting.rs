//! Transaction sorting strategies.
//!
//! Implements BIP-69, random, and no-op sorting for transaction inputs and outputs.

use serde::{Deserialize, Serialize};

/// Sorting strategy for transaction inputs and outputs.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
pub enum SortingStrategy {
    /// BIP-69: deterministic lexicographic sorting
    Bip69,
    /// Random shuffle (better privacy, prevents fingerprinting)
    #[default]
    Random,
    /// Keep original order
    None,
}

/// A composed input (for sorting purposes).
#[derive(Debug, Clone)]
pub struct SortableInput {
    /// Original index in the input array
    pub index: usize,
    /// Transaction ID (hex)
    pub txid: String,
    /// Output index
    pub vout: u32,
}

/// A composed output (for sorting purposes).
#[derive(Debug, Clone)]
pub struct SortableOutput {
    /// Original index in the output array
    pub index: usize,
    /// Amount in satoshis
    pub amount: u64,
    /// Raw scriptPubKey bytes for BIP69 comparison
    pub script_pubkey: Vec<u8>,
    /// Whether this is a change output (used by random sorting)
    pub is_change: bool,
}

/// Derive a scriptPubKey from an address string.
///
/// Supports P2PKH (1...), P2SH (3...), P2WPKH (bc1q.../tb1q.../bcrt1q...),
/// P2TR (bc1p.../tb1p.../bcrt1p...), and testnet/regtest variants.
/// Returns empty vec for unrecognized addresses.
pub fn address_to_script_pubkey(address: &str) -> Vec<u8> {
    let addr_lower = address.to_lowercase();

    // Bech32/Bech32m (P2WPKH or P2TR)
    if addr_lower.starts_with("bc1")
        || addr_lower.starts_with("tb1")
        || addr_lower.starts_with("bcrt1")
    {
        // Find the separator '1' - for bech32, it's the last '1' in the string
        if let Some(sep_pos) = addr_lower.rfind('1') {
            let data_part = &addr_lower[sep_pos + 1..];
            if let Some(decoded) = bech32_decode_data(data_part) {
                if decoded.is_empty() {
                    return Vec::new();
                }
                let witness_version = decoded[0];
                let witness_program = convert_bits(&decoded[1..], 5, 8, false);
                if let Some(program) = witness_program {
                    let mut script = Vec::new();
                    // Witness version: OP_0 (0x00) for v0, OP_1..OP_16 (0x51..0x60) for v1..v16
                    if witness_version == 0 {
                        script.push(0x00);
                    } else {
                        script.push(0x50 + witness_version);
                    }
                    script.push(program.len() as u8);
                    script.extend_from_slice(&program);
                    return script;
                }
            }
        }
        return Vec::new();
    }

    // Base58Check (P2PKH or P2SH)
    if let Some(decoded) = base58check_decode(address) {
        if decoded.len() == 21 {
            let version = decoded[0];
            let hash = &decoded[1..];
            match version {
                // P2PKH mainnet (0x00) or testnet (0x6f)
                0x00 | 0x6f => {
                    // OP_DUP OP_HASH160 <20> <hash> OP_EQUALVERIFY OP_CHECKSIG
                    let mut script = vec![0x76, 0xa9, 0x14];
                    script.extend_from_slice(hash);
                    script.push(0x88);
                    script.push(0xac);
                    return script;
                }
                // P2SH mainnet (0x05) or testnet (0xc4)
                0x05 | 0xc4 => {
                    // OP_HASH160 <20> <hash> OP_EQUAL
                    let mut script = vec![0xa9, 0x14];
                    script.extend_from_slice(hash);
                    script.push(0x87);
                    return script;
                }
                _ => {}
            }
        }
    }

    Vec::new()
}

/// Derive a scriptPubKey for an OP_RETURN output from hex data.
pub fn op_return_script_pubkey(data_hex: &str) -> Vec<u8> {
    let data = hex::decode(data_hex).unwrap_or_default();
    let mut script = vec![0x6a]; // OP_RETURN
    if data.len() <= 75 {
        script.push(data.len() as u8);
    } else if data.len() <= 255 {
        script.push(0x4c); // OP_PUSHDATA1
        script.push(data.len() as u8);
    } else {
        script.push(0x4d); // OP_PUSHDATA2
        script.push((data.len() & 0xff) as u8);
        script.push((data.len() >> 8) as u8);
    }
    script.extend_from_slice(&data);
    script
}

/// Decode bech32 data part (5-bit values).
fn bech32_decode_data(data: &str) -> Option<Vec<u8>> {
    const CHARSET: &str = "qpzry9x8gf2tvdw0s3jn54khce6mua7l";

    let mut values = Vec::with_capacity(data.len());
    for c in data.chars() {
        if let Some(pos) = CHARSET.find(c) {
            values.push(pos as u8);
        } else {
            return None;
        }
    }

    // Strip the 6-character checksum
    if values.len() < 7 {
        return None;
    }
    values.truncate(values.len() - 6);

    Some(values)
}

/// Convert between bit groups (e.g., 5-bit to 8-bit for bech32).
fn convert_bits(data: &[u8], from_bits: u32, to_bits: u32, pad: bool) -> Option<Vec<u8>> {
    let mut acc: u32 = 0;
    let mut bits: u32 = 0;
    let mut result = Vec::new();
    let max_v = (1u32 << to_bits) - 1;

    for &value in data {
        if (value as u32) >> from_bits != 0 {
            return None;
        }
        acc = (acc << from_bits) | value as u32;
        bits += from_bits;
        while bits >= to_bits {
            bits -= to_bits;
            result.push(((acc >> bits) & max_v) as u8);
        }
    }

    if pad {
        if bits > 0 {
            result.push(((acc << (to_bits - bits)) & max_v) as u8);
        }
    } else if bits >= from_bits || ((acc << (to_bits - bits)) & max_v) != 0 {
        return None;
    }

    Some(result)
}

/// Decode a Base58Check-encoded string.
fn base58check_decode(input: &str) -> Option<Vec<u8>> {
    const ALPHABET: &[u8] = b"123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";

    // Use a big number approach
    let mut bytes = Vec::new();
    let mut leading_zeros = 0;

    // Count leading '1's (which represent leading zero bytes)
    for c in input.chars() {
        if c == '1' {
            leading_zeros += 1;
        } else {
            break;
        }
    }

    // Convert from base58 to base256 using big number arithmetic
    let mut num = vec![0u8; 0];
    for c in input.bytes() {
        let digit = ALPHABET.iter().position(|&x| x == c)? as u32;

        // Multiply num by 58 and add digit
        let mut carry = digit;
        for byte in num.iter_mut().rev() {
            let val = (*byte as u32) * 58 + carry;
            *byte = (val & 0xff) as u8;
            carry = val >> 8;
        }
        while carry > 0 {
            num.insert(0, (carry & 0xff) as u8);
            carry >>= 8;
        }
    }

    // Add leading zero bytes
    for _ in 0..leading_zeros {
        bytes.push(0);
    }
    bytes.extend_from_slice(&num);

    // Verify checksum (last 4 bytes)
    if bytes.len() < 4 {
        return None;
    }
    let payload_len = bytes.len() - 4;
    let payload = &bytes[..payload_len];
    let checksum = &bytes[payload_len..];

    use sha2::{Digest, Sha256};
    let hash1 = Sha256::digest(payload);
    let hash2 = Sha256::digest(hash1);

    if &hash2[..4] != checksum {
        return None;
    }

    let result = payload.to_vec();
    Some(result)
}

/// Sort inputs and outputs according to the given strategy.
/// Returns the permutation indices for outputs.
pub fn sort_transaction(
    inputs: &mut Vec<SortableInput>,
    outputs: &mut Vec<SortableOutput>,
    strategy: SortingStrategy,
) -> Vec<usize> {
    match strategy {
        SortingStrategy::Bip69 => {
            // Sort inputs by txid (as raw bytes via hex), then by vout
            inputs.sort_by(|a, b| a.txid.cmp(&b.txid).then(a.vout.cmp(&b.vout)));

            // Sort outputs by amount, then by scriptPubKey bytes (BIP69 spec)
            outputs.sort_by(|a, b| {
                a.amount
                    .cmp(&b.amount)
                    .then(a.script_pubkey.cmp(&b.script_pubkey))
            });
        }
        SortingStrategy::Random => {
            use rand::seq::SliceRandom;
            let mut rng = rand::thread_rng();
            inputs.shuffle(&mut rng);

            // Insert change outputs at random positions among payment outputs,
            // matching JS behavior for better privacy.
            // Payment outputs keep their user-specified order (JS randomSortingStrategy.ts).
            let (mut payment_outputs, change_outputs): (Vec<_>, Vec<_>) =
                outputs.drain(..).partition(|o| !o.is_change);

            // Insert each change output at a random position
            for change in change_outputs {
                use rand::Rng;
                let pos = rng.gen_range(0..=payment_outputs.len());
                payment_outputs.insert(pos, change);
            }

            *outputs = payment_outputs;
        }
        SortingStrategy::None => {
            // Keep original order
        }
    }

    // Build output permutation: permutation[new_position] = original_index
    outputs.iter().map(|o| o.index).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_bip69_sort_inputs() {
        let mut inputs = vec![
            SortableInput {
                index: 0,
                txid: "bbbb".into(),
                vout: 1,
            },
            SortableInput {
                index: 1,
                txid: "aaaa".into(),
                vout: 0,
            },
            SortableInput {
                index: 2,
                txid: "aaaa".into(),
                vout: 2,
            },
        ];
        let mut outputs = vec![
            SortableOutput {
                index: 0,
                amount: 5000,
                script_pubkey: vec![0xcc],
                is_change: false,
            },
            SortableOutput {
                index: 1,
                amount: 1000,
                script_pubkey: vec![0xaa],
                is_change: false,
            },
        ];

        let perm = sort_transaction(&mut inputs, &mut outputs, SortingStrategy::Bip69);

        // Inputs should be sorted: aaaa:0, aaaa:2, bbbb:1
        assert_eq!(inputs[0].txid, "aaaa");
        assert_eq!(inputs[0].vout, 0);
        assert_eq!(inputs[1].txid, "aaaa");
        assert_eq!(inputs[1].vout, 2);
        assert_eq!(inputs[2].txid, "bbbb");

        // Outputs sorted by amount: 1000, 5000
        assert_eq!(outputs[0].amount, 1000);
        assert_eq!(outputs[1].amount, 5000);

        // Permutation maps new positions to original indices
        assert_eq!(perm, vec![1, 0]);
    }

    #[test]
    fn test_none_sort_preserves_order() {
        let mut inputs = vec![
            SortableInput {
                index: 0,
                txid: "bb".into(),
                vout: 1,
            },
            SortableInput {
                index: 1,
                txid: "aa".into(),
                vout: 0,
            },
        ];
        let mut outputs = vec![
            SortableOutput {
                index: 0,
                amount: 5000,
                script_pubkey: vec![0xcc],
                is_change: false,
            },
            SortableOutput {
                index: 1,
                amount: 1000,
                script_pubkey: vec![0xaa],
                is_change: false,
            },
        ];

        let perm = sort_transaction(&mut inputs, &mut outputs, SortingStrategy::None);

        assert_eq!(inputs[0].txid, "bb");
        assert_eq!(inputs[1].txid, "aa");
        assert_eq!(perm, vec![0, 1]);
    }

    #[test]
    fn test_bip69_sort_outputs_by_script_pubkey() {
        // Two outputs with same amount but different scriptPubKeys
        let mut inputs = vec![SortableInput {
            index: 0,
            txid: "aa".into(),
            vout: 0,
        }];
        let mut outputs = vec![
            SortableOutput {
                index: 0,
                amount: 1000,
                script_pubkey: vec![0x76, 0xa9],
                is_change: false,
            },
            SortableOutput {
                index: 1,
                amount: 1000,
                script_pubkey: vec![0x00, 0x14],
                is_change: false,
            },
        ];

        let perm = sort_transaction(&mut inputs, &mut outputs, SortingStrategy::Bip69);

        // scriptPubKey [0x00, 0x14] < [0x76, 0xa9]
        assert_eq!(outputs[0].script_pubkey, vec![0x00, 0x14]);
        assert_eq!(outputs[1].script_pubkey, vec![0x76, 0xa9]);
        assert_eq!(perm, vec![1, 0]);
    }

    #[test]
    fn test_address_to_script_pubkey_p2wpkh() {
        // Known P2WPKH address: bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4
        // Expected scriptPubKey: 0014751e76e8199196d454941c45d1b3a323f1433bd6
        let script = address_to_script_pubkey("bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4");
        assert!(!script.is_empty(), "Should decode P2WPKH address");
        assert_eq!(script[0], 0x00, "Witness version 0");
        assert_eq!(script[1], 0x14, "20-byte program push");
        assert_eq!(script.len(), 22, "P2WPKH script is 22 bytes");
        assert_eq!(
            hex::encode(&script),
            "0014751e76e8199196d454941c45d1b3a323f1433bd6"
        );
    }

    #[test]
    fn test_address_to_script_pubkey_p2tr() {
        // Known P2TR address: bc1pqyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqs3wf0qm
        // Witness version 1, 32-byte program
        let script = address_to_script_pubkey(
            "bc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vqzk5jj0",
        );
        assert!(!script.is_empty(), "Should decode P2TR address");
        assert_eq!(script[0], 0x51, "Witness version 1 = OP_1");
        assert_eq!(script[1], 0x20, "32-byte program push");
        assert_eq!(script.len(), 34, "P2TR script is 34 bytes");
    }

    #[test]
    fn test_address_to_script_pubkey_p2pkh() {
        // Known P2PKH address: 1BvBMSEYstWetqTFn5Au4m4GFg7xJaNVN2
        let script = address_to_script_pubkey("1BvBMSEYstWetqTFn5Au4m4GFg7xJaNVN2");
        assert!(!script.is_empty(), "Should decode P2PKH address");
        assert_eq!(script[0], 0x76, "OP_DUP");
        assert_eq!(script[1], 0xa9, "OP_HASH160");
        assert_eq!(script[2], 0x14, "20-byte push");
        assert_eq!(script.len(), 25, "P2PKH script is 25 bytes");
    }

    #[test]
    fn test_address_to_script_pubkey_p2sh() {
        // Known P2SH address: 3J98t1WpEZ73CNmQviecrnyiWrnqRhWNLy
        let script = address_to_script_pubkey("3J98t1WpEZ73CNmQviecrnyiWrnqRhWNLy");
        assert!(!script.is_empty(), "Should decode P2SH address");
        assert_eq!(script[0], 0xa9, "OP_HASH160");
        assert_eq!(script[1], 0x14, "20-byte push");
        assert_eq!(script.len(), 23, "P2SH script is 23 bytes");
    }

    #[test]
    fn test_address_to_script_pubkey_regtest() {
        // Regtest P2WPKH address
        let script = address_to_script_pubkey("bcrt1qj2gz3meule5mc4r4knv65vjds3g88rlxs0jlmq");
        assert!(!script.is_empty(), "Should decode regtest bech32 address");
        assert_eq!(script[0], 0x00, "Witness version 0");
        assert_eq!(script[1], 0x14, "20-byte program push");
        assert_eq!(script.len(), 22);
    }

    #[test]
    fn test_op_return_script_pubkey() {
        let script = op_return_script_pubkey("deadbeef");
        assert_eq!(script[0], 0x6a, "OP_RETURN");
        assert_eq!(script[1], 4, "4 bytes of data");
        assert_eq!(&script[2..], &[0xde, 0xad, 0xbe, 0xef]);
    }
}
