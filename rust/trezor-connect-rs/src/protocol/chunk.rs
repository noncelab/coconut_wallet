//! Message chunking utilities.
//!
//! This module handles splitting large messages into chunks for transmission
//! and reassembling received chunks into complete messages.

use crate::error::{ProtocolError, Result};

/// Split a message into chunks of the specified size.
///
/// The first chunk contains the raw data up to chunk_size.
/// Subsequent chunks are prefixed with the chunk_header and padded to chunk_size.
///
/// # Arguments
///
/// * `data` - The complete encoded message
/// * `chunk_header` - Header to prepend to continuation chunks
/// * `chunk_size` - Size of each chunk
///
/// # Returns
///
/// A vector of chunks, each exactly chunk_size bytes (padded with zeros if needed)
pub fn create_chunks(data: &[u8], chunk_header: &[u8], chunk_size: usize) -> Vec<Vec<u8>> {
    let mut chunks = Vec::new();

    // First chunk is raw data (no additional header)
    let first_chunk_data = &data[..data.len().min(chunk_size)];
    let mut first_chunk = first_chunk_data.to_vec();

    // Pad first chunk to chunk_size
    if first_chunk.len() < chunk_size {
        first_chunk.resize(chunk_size, 0);
    }
    chunks.push(first_chunk);

    // Remaining data goes into continuation chunks
    let mut offset = chunk_size;
    while offset < data.len() {
        let remaining = &data[offset..];
        let payload_size = chunk_size - chunk_header.len();
        let chunk_data = &remaining[..remaining.len().min(payload_size)];

        let mut chunk = Vec::with_capacity(chunk_size);
        chunk.extend_from_slice(chunk_header);
        chunk.extend_from_slice(chunk_data);

        // Pad to chunk_size
        if chunk.len() < chunk_size {
            chunk.resize(chunk_size, 0);
        }

        chunks.push(chunk);
        offset += payload_size;
    }

    chunks
}

/// Reassemble chunks into a complete message.
///
/// # Arguments
///
/// * `chunks` - Vector of received chunks
/// * `header_size` - Size of the first chunk header (to know where payload starts)
/// * `continuation_header_size` - Size of continuation chunk headers
/// * `total_length` - Expected total payload length
///
/// # Returns
///
/// The reassembled payload
pub fn reassemble_chunks(
    chunks: &[Vec<u8>],
    header_size: usize,
    continuation_header_size: usize,
    total_length: usize,
) -> Result<Vec<u8>> {
    if chunks.is_empty() {
        return Err(ProtocolError::Malformed("No chunks to reassemble".to_string()).into());
    }

    let mut payload = Vec::with_capacity(total_length);

    // Extract payload from first chunk
    if chunks[0].len() > header_size {
        let first_payload = &chunks[0][header_size..];
        payload.extend_from_slice(first_payload);
    }

    // Extract payload from continuation chunks
    for chunk in chunks.iter().skip(1) {
        if chunk.len() > continuation_header_size {
            let chunk_payload = &chunk[continuation_header_size..];
            payload.extend_from_slice(chunk_payload);
        }
    }

    // Trim to exact length (remove padding)
    payload.truncate(total_length);

    Ok(payload)
}

/// Calculate the number of chunks needed for a message of given length.
///
/// # Arguments
///
/// * `message_length` - Total length of the encoded message (including header)
/// * `chunk_size` - Size of each chunk
/// * `continuation_header_size` - Size of continuation chunk headers
///
/// # Returns
///
/// Number of chunks needed
pub fn chunks_needed(
    message_length: usize,
    chunk_size: usize,
    continuation_header_size: usize,
) -> usize {
    if message_length <= chunk_size {
        return 1;
    }

    // First chunk takes chunk_size bytes
    let remaining = message_length - chunk_size;

    // Each continuation chunk carries (chunk_size - continuation_header_size) bytes
    let continuation_payload_size = chunk_size - continuation_header_size;

    // Calculate continuation chunks needed (ceiling division)
    let continuation_chunks =
        (remaining + continuation_payload_size - 1) / continuation_payload_size;

    1 + continuation_chunks
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_create_chunks_single() {
        let data = vec![0x01, 0x02, 0x03, 0x04];
        let chunk_header = vec![0x3F];
        let chunk_size = 64;

        let chunks = create_chunks(&data, &chunk_header, chunk_size);

        assert_eq!(chunks.len(), 1);
        assert_eq!(chunks[0].len(), chunk_size);
        assert_eq!(&chunks[0][..4], &data[..]);
    }

    #[test]
    fn test_create_chunks_multiple() {
        // Create data larger than one chunk
        let data: Vec<u8> = (0..100).collect();
        let chunk_header = vec![0x3F];
        let chunk_size = 64;

        let chunks = create_chunks(&data, &chunk_header, chunk_size);

        // First chunk: 64 bytes of data
        // Second chunk: 1 byte header + 63 bytes data = 64 bytes total
        // We need: ceil((100 - 64) / 63) = ceil(36 / 63) = 1 more chunk
        assert_eq!(chunks.len(), 2);
        assert_eq!(chunks[0].len(), chunk_size);
        assert_eq!(chunks[1].len(), chunk_size);

        // First chunk should have first 64 bytes
        assert_eq!(&chunks[0][..64], &data[..64]);

        // Second chunk should start with header then remaining data
        assert_eq!(chunks[1][0], 0x3F);
        assert_eq!(&chunks[1][1..37], &data[64..100]);
    }

    #[test]
    fn test_chunks_needed() {
        let chunk_size = 64;
        let header_size = 1;

        // Small message fits in one chunk
        assert_eq!(chunks_needed(50, chunk_size, header_size), 1);

        // Exactly one chunk
        assert_eq!(chunks_needed(64, chunk_size, header_size), 1);

        // Just over one chunk
        assert_eq!(chunks_needed(65, chunk_size, header_size), 2);

        // Two full chunks
        assert_eq!(chunks_needed(127, chunk_size, header_size), 2);

        // Larger message
        assert_eq!(chunks_needed(200, chunk_size, header_size), 4);
    }

    #[test]
    fn test_reassemble_chunks() {
        let header_size = 9;
        let continuation_header_size = 1;

        // Create mock chunks with proper payload layout
        // First chunk: 9 bytes header + 55 bytes payload
        // We fill the first 5 bytes of payload with [1,2,3,4,5]
        // And the remaining with padding (which will be truncated)
        let mut chunk1 = vec![0; 64];
        chunk1[9..14].copy_from_slice(&[1, 2, 3, 4, 5]);

        // For this test, we only need 10 bytes total, so 5 from first chunk
        // and 5 from continuation. But first chunk has 55 bytes of payload space.
        // The function takes all bytes and then truncates.

        // So for a 10-byte payload that spans two chunks correctly:
        // First chunk payload size should be 10-5=5 bytes needed from first chunk
        // But our chunks are 64 bytes, so first chunk has 64-9=55 payload bytes
        // This means all 10 bytes fit in first chunk!

        // Let's test with a larger payload that actually spans chunks
        // With chunk size 64 and header 9, first chunk holds 55 payload bytes
        // To span 2 chunks, we need more than 55 bytes

        // Actually, let's test with proper small chunks
        let header_size = 3;
        let continuation_header_size = 1;
        let chunk_size = 8;

        // First chunk: 3 byte header + 5 bytes payload = 8 bytes
        let chunk1 = vec![0x3F, 0x23, 0x23, 1, 2, 3, 4, 5];

        // Second chunk: 1 byte header + 7 bytes payload = 8 bytes
        let chunk2 = vec![0x3F, 6, 7, 8, 9, 10, 0, 0];

        let chunks = vec![chunk1, chunk2];
        let payload =
            reassemble_chunks(&chunks, header_size, continuation_header_size, 10).unwrap();

        assert_eq!(payload, vec![1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    }
}
