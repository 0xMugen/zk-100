use crate::instruction::Inst;
use anyhow::Result;
use num_bigint::BigUint;
use starknet_crypto::poseidon_hash;
use starknet_types_core::felt::Felt;

// Poseidon hash implementation matching Cairo

pub fn compute_program_merkle_root(programs: &[Vec<Vec<Inst>>]) -> Result<Vec<u8>> {
    let mut node_merkle_roots = Vec::new();
    
    // For each node in the 2x2 grid
    for row in programs {
        for program in row {
            if program.is_empty() {
                // Empty programs use zero felt252
                node_merkle_roots.push(BigUint::from(0u32));
            } else {
                // Encode each instruction as felt252
                let mut prog_data = Vec::new();
                for inst in program {
                    let encoded = inst.encode();
                    prog_data.push(BigUint::from(encoded));
                }
                
                // Compute merkle root for this node's instructions
                let node_root = merkle_root(&prog_data)?;
                node_merkle_roots.push(node_root);
            }
        }
    }
    
    // Now compute final merkle root from all node roots
    let final_root = merkle_root(&node_merkle_roots)?;
    
    // Convert to bytes for output (32 bytes, big-endian)
    let root_bytes = final_root.to_bytes_be();
    let mut bytes = vec![0u8; 32];
    let start = if root_bytes.len() > 32 { 0 } else { 32 - root_bytes.len() };
    bytes[start..].copy_from_slice(&root_bytes[root_bytes.len().saturating_sub(32)..]);
    
    Ok(bytes)
}

// Convert BigUint to Felt for Poseidon hashing
fn biguint_to_felt(value: &BigUint) -> Result<Felt> {
    let bytes = value.to_bytes_be();
    let mut padded_bytes = [0u8; 32];
    let start = if bytes.len() > 32 { 0 } else { 32 - bytes.len() };
    padded_bytes[start..].copy_from_slice(&bytes[bytes.len().saturating_sub(32)..]);
    Ok(Felt::from_bytes_be(&padded_bytes))
}

// Convert Felt back to BigUint
fn felt_to_biguint(field: Felt) -> BigUint {
    let bytes = field.to_bytes_be();
    BigUint::from_bytes_be(&bytes)
}

// Hash a pair of felt252 values using Poseidon
fn hash_pair(left: &BigUint, right: &BigUint) -> Result<BigUint> {
    let left_fe = biguint_to_felt(left)?;
    let right_fe = biguint_to_felt(right)?;
    let hash = poseidon_hash(left_fe, right_fe);
    Ok(felt_to_biguint(hash))
}

// Compute merkle root matching Cairo's algorithm
fn merkle_root(leaves: &[BigUint]) -> Result<BigUint> {
    if leaves.is_empty() {
        return Ok(BigUint::from(0u32));
    }
    
    if leaves.len() == 1 {
        return Ok(leaves[0].clone());
    }
    
    // Build tree bottom-up
    let mut current_level: Vec<BigUint> = leaves.to_vec();
    
    // Pad to power of 2 with zeros (matching Cairo)
    let mut power = 1;
    while power < current_level.len() {
        power *= 2;
    }
    while current_level.len() < power {
        current_level.push(BigUint::from(0u32)); // Pad with zeros
    }
    
    // Build tree levels
    while current_level.len() > 1 {
        let mut next_level = Vec::new();
        
        for i in (0..current_level.len()).step_by(2) {
            let left = &current_level[i];
            let right = if i + 1 < current_level.len() {
                &current_level[i + 1]
            } else {
                &BigUint::from(0u32)
            };
            
            let hash_val = hash_pair(left, right)?;
            next_level.push(hash_val);
        }
        
        current_level = next_level;
    }
    
    Ok(current_level[0].clone())
}

// Convert bytes to felt252 hex string (for output/display)
pub fn bytes_to_felt252(bytes: &[u8]) -> String {
    let big_int = BigUint::from_bytes_be(bytes);
    format!("0x{}", big_int.to_str_radix(16))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::instruction::{Op, Src, Dst};

    #[test]
    fn test_poseidon_hash_pair() {
        let left = BigUint::from(100u32);
        let right = BigUint::from(200u32);
        let result = hash_pair(&left, &right).unwrap();
        
        // Should produce a deterministic hash
        let result2 = hash_pair(&left, &right).unwrap();
        assert_eq!(result, result2);
        
        // Different order should produce different hash
        let result3 = hash_pair(&right, &left).unwrap();
        assert_ne!(result, result3);
    }

    #[test]
    fn test_felt_conversion() {
        let original = BigUint::from(12345u32);
        let field = biguint_to_felt(&original).unwrap();
        let converted_back = felt_to_biguint(field);
        assert_eq!(original, converted_back);
    }

    #[test]
    fn test_merkle_root_single() {
        let leaves = vec![BigUint::from(12345u32)];
        let root = merkle_root(&leaves).unwrap();
        assert_eq!(root, BigUint::from(12345u32));
    }

    #[test]
    fn test_merkle_root_two() {
        let leaves = vec![BigUint::from(100u32), BigUint::from(200u32)];
        let root = merkle_root(&leaves).unwrap();
        let expected = hash_pair(&BigUint::from(100u32), &BigUint::from(200u32)).unwrap();
        assert_eq!(root, expected);
    }

    #[test]
    fn test_poseidon_test_vectors() {
        // Test vectors to verify Rust Poseidon matches Cairo
        
        // Test hash_pair(100, 200)
        let result1 = hash_pair(&BigUint::from(100u32), &BigUint::from(200u32)).unwrap();
        println!("Rust hash_pair(100, 200) = 0x{}", result1.to_str_radix(16));
        
        // Test merkle_root([12345])
        let leaves1 = vec![BigUint::from(12345u32)];
        let result2 = merkle_root(&leaves1).unwrap();
        println!("Rust merkle_root([12345]) = 0x{}", result2.to_str_radix(16));
        assert_eq!(result2, BigUint::from(12345u32)); // Single element should return itself
        
        // Test merkle_root([100, 200])
        let leaves2 = vec![BigUint::from(100u32), BigUint::from(200u32)];
        let result3 = merkle_root(&leaves2).unwrap();
        println!("Rust merkle_root([100, 200]) = 0x{}", result3.to_str_radix(16));
        // This should equal hash_pair(100, 200) since it's only two elements
        assert_eq!(result3, result1);
        
        // Test merkle_root([])
        let leaves3: Vec<BigUint> = vec![];
        let result4 = merkle_root(&leaves3).unwrap();
        println!("Rust merkle_root([]) = 0x{}", result4.to_str_radix(16));
        assert_eq!(result4, BigUint::from(0u32)); // Empty should return 0
    }

    #[test]
    fn test_simple_program() {
        // Test the exact program from test_simple.asm
        let nop = Inst {
            op: Op::Nop,
            src: Src::Nil,
            dst: Dst::Nil,
        };
        let mov_42_out = Inst {
            op: Op::Mov,
            src: Src::Lit(42),
            dst: Dst::Out,
        };
        let hlt = Inst {
            op: Op::Hlt,
            src: Src::Nil,
            dst: Dst::Nil,
        };
        
        // Verify encodings
        assert_eq!(nop.encode(), 0xc0201);
        assert_eq!(mov_42_out.encode(), 0x2a010002);
        assert_eq!(hlt.encode(), 0xd0201);
        
        let programs = vec![
            vec![vec![nop.clone()], vec![nop.clone()]],
            vec![vec![nop.clone()], vec![mov_42_out, hlt]]
        ];
        
        let root = compute_program_merkle_root(&programs).unwrap();
        let root_hex = bytes_to_felt252(&root);
        
        // This should match the Python calculation
        println!("Rust merkle root: {}", root_hex);
    }

    #[test]
    fn test_empty_program_merkle() {
        let programs = vec![
            vec![vec![], vec![]],
            vec![vec![], vec![]]
        ];
        
        let root = compute_program_merkle_root(&programs).unwrap();
        assert_eq!(root.len(), 32);
    }

    #[test]
    fn test_bytes_to_felt252() {
        let bytes = vec![0x12, 0x34, 0x56, 0x78];
        let felt = bytes_to_felt252(&bytes);
        assert_eq!(felt, "0x12345678");
    }
}