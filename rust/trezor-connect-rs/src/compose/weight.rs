//! Transaction weight and fee calculation.
//!
//! Calculates transaction weight in weight units (WU) following BIP-141 rules,
//! matching the behavior of trezor-suite's utxo-lib.

use crate::types::bitcoin::ScriptType;

/// Base transaction weight: 4 * (4 version + 4 locktime) = 32 WU
const TX_BASE_WEIGHT: usize = 32;

/// Segwit overhead: 2 WU (marker + flag byte in witness)
const SEGWIT_OVERHEAD: usize = 2;

/// Input weight for a given script type (in weight units).
pub fn input_weight(script_type: ScriptType) -> usize {
    match script_type {
        ScriptType::SpendAddress => 592,     // p2pkh: 4*148
        ScriptType::SpendP2SHWitness => 364, // p2sh-p2wpkh: nested segwit
        ScriptType::SpendWitness => 272,     // p2wpkh: native segwit
        ScriptType::SpendTaproot => 230,     // p2tr: taproot
        ScriptType::SpendMultisig => 592,    // treat as p2pkh (varies by m-of-n)
        ScriptType::External => 272,         // assume segwit for external
    }
}

/// Output weight for a given script type (in weight units).
pub fn output_weight(script_type: ScriptType) -> usize {
    match script_type {
        ScriptType::SpendAddress => 136,     // p2pkh: 4*(8+1+25)
        ScriptType::SpendP2SHWitness => 128, // p2sh: 4*(8+1+23)
        ScriptType::SpendWitness => 124,     // p2wpkh: 4*(8+1+22)
        ScriptType::SpendTaproot => 172,     // p2tr: 4*(8+1+34)
        ScriptType::SpendMultisig => 128,    // p2sh: 4*(8+1+23)
        ScriptType::External => 124,         // assume p2wpkh
    }
}

/// Output weight for an OP_RETURN output with the given data length.
pub fn op_return_output_weight(data_len: usize) -> usize {
    // 4 * (8 amount + 1 script_len + 1 OP_RETURN + 1 OP_PUSH + data_len)
    4 * (8 + 1 + 1 + 1 + data_len)
}

/// Weight of a change output for a given script type.
pub fn change_output_weight(script_type: ScriptType) -> usize {
    output_weight(script_type)
}

/// Encode a varint and return its weight (4x because non-witness).
fn varint_weight(n: usize) -> usize {
    let bytes = if n < 0xFD {
        1
    } else if n <= 0xFFFF {
        3
    } else if n <= 0xFFFF_FFFF {
        5
    } else {
        9
    };
    4 * bytes
}

/// Whether any inputs are segwit (requiring the segwit overhead).
fn has_segwit(input_types: &[ScriptType]) -> bool {
    input_types.iter().any(|t| {
        matches!(
            t,
            ScriptType::SpendWitness | ScriptType::SpendP2SHWitness | ScriptType::SpendTaproot
        )
    })
}

/// Calculate total transaction weight from input and output weights.
pub fn transaction_weight(input_types: &[ScriptType], output_weights: &[usize]) -> usize {
    let mut weight = TX_BASE_WEIGHT;

    // Varint for input count
    weight += varint_weight(input_types.len());

    // Sum input weights
    for t in input_types {
        weight += input_weight(*t);
    }

    // Varint for output count
    weight += varint_weight(output_weights.len());

    // Sum output weights
    for w in output_weights {
        weight += w;
    }

    // Segwit overhead
    if has_segwit(input_types) {
        weight += SEGWIT_OVERHEAD;
        // Each non-segwit input needs 1 WU for the empty witness stack (0x00)
        let non_segwit_count = input_types
            .iter()
            .filter(|t| {
                !matches!(
                    t,
                    ScriptType::SpendWitness
                        | ScriptType::SpendP2SHWitness
                        | ScriptType::SpendTaproot
                )
            })
            .count();
        weight += non_segwit_count;
    }

    weight
}

/// Convert weight units to virtual bytes (vBytes), rounding up.
pub fn weight_to_vbytes(weight: usize) -> usize {
    (weight + 3) / 4
}

/// Calculate fee in satoshis from fee rate (sat/vB) and weight.
///
/// Accepts fractional fee rates (e.g., 1.5 sat/vB) and rounds up,
/// matching JS `Math.ceil(feeRate * bytes)` behavior.
pub fn calculate_fee(fee_rate: f64, weight: usize) -> u64 {
    let vbytes = weight_to_vbytes(weight) as f64;
    (fee_rate * vbytes).ceil() as u64
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_input_weights() {
        assert_eq!(input_weight(ScriptType::SpendAddress), 592);
        assert_eq!(input_weight(ScriptType::SpendP2SHWitness), 364);
        assert_eq!(input_weight(ScriptType::SpendWitness), 272);
        assert_eq!(input_weight(ScriptType::SpendTaproot), 230);
    }

    #[test]
    fn test_output_weights() {
        assert_eq!(output_weight(ScriptType::SpendAddress), 136);
        assert_eq!(output_weight(ScriptType::SpendWitness), 124);
        assert_eq!(output_weight(ScriptType::SpendTaproot), 172);
    }

    #[test]
    fn test_weight_to_vbytes() {
        assert_eq!(weight_to_vbytes(400), 100);
        assert_eq!(weight_to_vbytes(401), 101);
        assert_eq!(weight_to_vbytes(403), 101);
        assert_eq!(weight_to_vbytes(404), 101);
    }

    #[test]
    fn test_transaction_weight_single_p2wpkh() {
        // 1-in 1-out p2wpkh transaction
        let input_types = vec![ScriptType::SpendWitness];
        let output_weights = vec![output_weight(ScriptType::SpendWitness)];
        let weight = transaction_weight(&input_types, &output_weights);
        // TX_BASE(32) + varint_in(4) + input(272) + varint_out(4) + output(124) + segwit(2) = 438
        assert_eq!(weight, 438);
        assert_eq!(weight_to_vbytes(weight), 110);
    }

    #[test]
    fn test_transaction_weight_legacy() {
        // 1-in 1-out p2pkh (no segwit overhead)
        let input_types = vec![ScriptType::SpendAddress];
        let output_weights = vec![output_weight(ScriptType::SpendAddress)];
        let weight = transaction_weight(&input_types, &output_weights);
        // TX_BASE(32) + varint_in(4) + input(592) + varint_out(4) + output(136) = 768
        assert_eq!(weight, 768);
        assert_eq!(weight_to_vbytes(weight), 192);
    }

    #[test]
    fn test_calculate_fee() {
        // 10 sat/vB * 110 vB = 1100 sat
        assert_eq!(calculate_fee(10.0, 438), 1100);
    }

    #[test]
    fn test_calculate_fee_fractional() {
        // 1.5 sat/vB * 110 vB = ceil(165.0) = 165
        assert_eq!(calculate_fee(1.5, 438), 165);
        // 1.1 sat/vB * 110 vB = ceil(121.000...01) = 122
        // (matches JS Math.ceil(1.1 * 110) = 122 due to IEEE 754 representation)
        assert_eq!(calculate_fee(1.1, 438), 122);
        // 2.5 sat/vB * 110 vB = ceil(275.0) = 275
        assert_eq!(calculate_fee(2.5, 438), 275);
    }

    #[test]
    fn test_mixed_input_weight_includes_empty_witness() {
        // Mixed transaction: 1 P2PKH + 1 P2WPKH input, 1 P2WPKH output
        // The P2PKH input needs 1 WU for empty witness stack in a segwit tx
        let input_types = vec![ScriptType::SpendAddress, ScriptType::SpendWitness];
        let output_weights = vec![output_weight(ScriptType::SpendWitness)];
        let weight = transaction_weight(&input_types, &output_weights);
        // TX_BASE(32) + varint_in(4) + P2PKH(592) + P2WPKH(272) + varint_out(4)
        // + output(124) + segwit_overhead(2) + non_segwit_empty_witness(1) = 1031
        assert_eq!(weight, 1031);
    }

    #[test]
    fn test_pure_segwit_no_extra_witness_overhead() {
        // Pure segwit: 2 P2WPKH inputs — no non-segwit inputs, no extra WU
        let input_types = vec![ScriptType::SpendWitness, ScriptType::SpendWitness];
        let output_weights = vec![output_weight(ScriptType::SpendWitness)];
        let weight = transaction_weight(&input_types, &output_weights);
        // TX_BASE(32) + varint_in(4) + 2*P2WPKH(544) + varint_out(4) + output(124) + segwit(2) = 710
        assert_eq!(weight, 710);
    }

    #[test]
    fn test_pure_legacy_no_segwit_overhead() {
        // Pure legacy: 2 P2PKH inputs — no segwit overhead at all
        let input_types = vec![ScriptType::SpendAddress, ScriptType::SpendAddress];
        let output_weights = vec![output_weight(ScriptType::SpendAddress)];
        let weight = transaction_weight(&input_types, &output_weights);
        // TX_BASE(32) + varint_in(4) + 2*P2PKH(1184) + varint_out(4) + output(136) = 1360
        assert_eq!(weight, 1360);
    }
}
