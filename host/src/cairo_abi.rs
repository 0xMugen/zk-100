use anyhow::Result;
use serde_json::Value;

/// Generate args.json in the format expected by cairo-prove
/// Format: [inputs_len, ...inputs, expected_len, ...expected, prog_words_len, ...prog_words]
pub fn generate_args(
    inputs: &[u32],
    expected: &[u32],
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
    
    // Add prog_words array (Cairo will compute merkle root from these)
    args.push(json_value_from_u32(prog_words.len() as u32));
    for &word in prog_words {
        args.push(json_value_from_u32(word));
    }
    
    Ok(args)
}

/// Convert u32 to JSON value (as hex string for Cairo compatibility)
fn json_value_from_u32(val: u32) -> Value {
    Value::String(format!("0x{:x}", val))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_generate_args_empty() {
        let inputs = vec![];
        let expected = vec![];
        let prog_words = vec![];
        
        let args = generate_args(&inputs, &expected, &prog_words).unwrap();
        
        // Should have: [0, 0, 0]
        assert_eq!(args.len(), 3);
        assert_eq!(args[0], Value::String("0x0".to_string())); // inputs len
        assert_eq!(args[1], Value::String("0x0".to_string())); // expected len
        assert_eq!(args[2], Value::String("0x0".to_string())); // prog_words len
    }

    #[test]
    fn test_generate_args_with_data() {
        let inputs = vec![1, 2, 3];
        let expected = vec![10, 20];
        let prog_words = vec![100, 200, 300, 400];
        
        let args = generate_args(&inputs, &expected, &prog_words).unwrap();
        
        // Should have: [3, 1, 2, 3, 2, 10, 20, 4, 100, 200, 300, 400]
        assert_eq!(args.len(), 12);
        assert_eq!(args[0], Value::String("0x3".to_string())); // inputs len
        assert_eq!(args[1], Value::String("0x1".to_string()));
        assert_eq!(args[2], Value::String("0x2".to_string()));
        assert_eq!(args[3], Value::String("0x3".to_string()));
        assert_eq!(args[4], Value::String("0x2".to_string())); // expected len
        assert_eq!(args[5], Value::String("0xa".to_string()));
        assert_eq!(args[6], Value::String("0x14".to_string()));
        assert_eq!(args[7], Value::String("0x4".to_string())); // prog_words len
        assert_eq!(args[8], Value::String("0x64".to_string()));
        assert_eq!(args[9], Value::String("0xc8".to_string()));
        assert_eq!(args[10], Value::String("0x12c".to_string()));
        assert_eq!(args[11], Value::String("0x190".to_string()));
    }
}