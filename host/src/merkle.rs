use crate::instruction::Inst;
use anyhow::Result;
use sha2::{Sha256, Digest};
use num_bigint::BigUint;

pub fn compute_program_merkle_root(programs: &[Vec<Vec<Inst>>]) -> Result<Vec<u8>> {
    let mut leaves = Vec::new();
    
    // For each program, compute its hash
    for row in programs {
        for program in row {
            let leaf_hash = hash_program(program)?;
            leaves.push(leaf_hash);
        }
    }
    
    // Compute merkle root from leaves
    let root = merkle_root(&leaves);
    
    // Convert to bytes (32 bytes for Sha256)
    Ok(root)
}

fn hash_program(program: &[Inst]) -> Result<Vec<u8>> {
    // Encode all instructions
    let mut encoded_data = Vec::new();
    for inst in program {
        let encoded = inst.encode();
        // Convert u32 to bytes (big-endian to match Cairo)
        encoded_data.extend_from_slice(&encoded.to_be_bytes());
    }
    
    // Hash the encoded program
    let mut hasher = Sha256::new();
    hasher.update(&encoded_data);
    let hash = hasher.finalize();
    
    Ok(hash.to_vec())
}

fn merkle_root(leaves: &[Vec<u8>]) -> Vec<u8> {
    if leaves.is_empty() {
        // Empty tree has zero root
        return vec![0; 32];
    }
    
    if leaves.len() == 1 {
        return leaves[0].clone();
    }
    
    // Simple merkle tree construction
    let mut current_level: Vec<Vec<u8>> = leaves.to_vec();
    
    while current_level.len() > 1 {
        let mut next_level = Vec::new();
        
        for i in (0..current_level.len()).step_by(2) {
            if i + 1 < current_level.len() {
                // Hash pair
                let mut hasher = Sha256::new();
                hasher.update(&current_level[i]);
                hasher.update(&current_level[i + 1]);
                next_level.push(hasher.finalize().to_vec());
            } else {
                // Odd node, just copy up
                next_level.push(current_level[i].clone());
            }
        }
        
        current_level = next_level;
    }
    
    current_level[0].clone()
}

// Convert bytes to felt252 representation (for Cairo compatibility)
pub fn bytes_to_felt252(bytes: &[u8]) -> String {
    let big_int = BigUint::from_bytes_be(bytes);
    format!("0x{}", big_int.to_str_radix(16))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::instruction::{Op, Src, Dst};

    #[test]
    fn test_hash_empty_program() {
        let program = vec![];
        let hash = hash_program(&program).unwrap();
        assert_eq!(hash.len(), 32); // SHA256 produces 32 bytes
    }

    #[test]
    fn test_hash_simple_program() {
        let program = vec![
            Inst {
                op: Op::Nop,
                src: Src::Nil,
                dst: Dst::Nil,
            },
            Inst {
                op: Op::Hlt,
                src: Src::Nil,
                dst: Dst::Nil,
            },
        ];
        
        let hash = hash_program(&program).unwrap();
        assert_eq!(hash.len(), 32);
    }

    #[test]
    fn test_merkle_root_empty() {
        let leaves: Vec<Vec<u8>> = vec![];
        let root = merkle_root(&leaves);
        assert_eq!(root, vec![0; 32]);
    }

    #[test]
    fn test_merkle_root_single() {
        let leaf = vec![1u8; 32];
        let leaves = vec![leaf.clone()];
        let root = merkle_root(&leaves);
        assert_eq!(root, leaf);
    }

    #[test]
    fn test_merkle_root_multiple() {
        let leaves = vec![
            vec![1u8; 32],
            vec![2u8; 32],
            vec![3u8; 32],
            vec![4u8; 32],
        ];
        let root = merkle_root(&leaves);
        assert_eq!(root.len(), 32);
    }

    #[test]
    fn test_bytes_to_felt252() {
        let bytes = vec![0x12, 0x34, 0x56, 0x78];
        let felt = bytes_to_felt252(&bytes);
        assert_eq!(felt, "0x12345678");
    }
}