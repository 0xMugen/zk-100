use anyhow::Result;
use serde_json::Value;

/// Generate args.json in the format expected by cairo-prove
/// Format: [inputs_len, ...inputs, expected_len, ...expected, merkle_root, prog_words_len, ...prog_words]
pub fn generate_args(
    inputs: &[u32],
    expected: &[u32],
    merkle_root: &[u8],
    prog_words: &[u32],
) -> Result<Vec<Value>> {
    let mut args = Vec::new();
    
    // Add inputs array
    args.push(json_value_from_u32(inputs.len() as u32));
    for &input in inputs {
        args.push(json_value_from_u32(input));
    }
    
    // Add expected array
    args.push(json_value_from_u32(expected.len() as u32));
    for &exp in expected {
        args.push(json_value_from_u32(exp));
    }
    
    // Add merkle root as felt252
    args.push(json_value_from_bytes(merkle_root));
    
    // Add prog_words array
    args.push(json_value_from_u32(prog_words.len() as u32));
    for &word in prog_words {
        args.push(json_value_from_u32(word));
    }
    
    Ok(args)
}

/// Convert u32 to JSON value in hex format
fn json_value_from_u32(val: u32) -> Value {
    Value::String(format!("0x{:x}", val))
}

/// Convert bytes to felt252 hex string
fn json_value_from_bytes(bytes: &[u8]) -> Value {
    let hex = crate::merkle::bytes_to_felt252(bytes);
    Value::String(hex)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_generate_args_empty() {
        let inputs = vec![];
        let expected = vec![];
        let merkle_root = vec![0u8; 32];
        let prog_words = vec![];
        
        let args = generate_args(&inputs, &expected, &merkle_root, &prog_words).unwrap();
        
        // Should have: [0, 0, merkle_root, 0]
        assert_eq!(args.len(), 4);
        assert_eq!(args[0], Value::String("0x0".to_string())); // inputs len
        assert_eq!(args[1], Value::String("0x0".to_string())); // expected len
        assert!(args[2].as_str().unwrap().starts_with("0x")); // merkle root
        assert_eq!(args[3], Value::String("0x0".to_string())); // prog_words len
    }

    #[test]
    fn test_generate_args_with_data() {
        let inputs = vec![1, 2, 3];
        let expected = vec![10, 20];
        let merkle_root = vec![0x12, 0x34, 0x56, 0x78];
        let prog_words = vec![100, 200, 300, 400];
        
        let args = generate_args(&inputs, &expected, &merkle_root, &prog_words).unwrap();
        
        // Should have: [3, 1, 2, 3, 2, 10, 20, merkle_root, 4, 100, 200, 300, 400]
        assert_eq!(args.len(), 13);
        assert_eq!(args[0], Value::String("0x3".to_string())); // inputs len
        assert_eq!(args[1], Value::String("0x1".to_string()));
        assert_eq!(args[2], Value::String("0x2".to_string()));
        assert_eq!(args[3], Value::String("0x3".to_string()));
        assert_eq!(args[4], Value::String("0x2".to_string())); // expected len
        assert_eq!(args[5], Value::String("0xa".to_string()));
        assert_eq!(args[6], Value::String("0x14".to_string()));
        assert_eq!(args[7], Value::String("0x12345678".to_string())); // merkle root
        assert_eq!(args[8], Value::String("0x4".to_string())); // prog_words len
        assert_eq!(args[9], Value::String("0x64".to_string()));
        assert_eq!(args[10], Value::String("0xc8".to_string()));
        assert_eq!(args[11], Value::String("0x12c".to_string()));
        assert_eq!(args[12], Value::String("0x190".to_string()));
    }
}