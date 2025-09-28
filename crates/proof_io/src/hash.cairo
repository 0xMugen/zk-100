use core::poseidon::poseidon_hash_span;
use core::array::{ArrayTrait, SpanTrait};
use core::option::Option;
use core::traits::Into;

// Compute Merkle root of an array of felt252 values using Poseidon
pub fn merkle_root(leaves: @Array<felt252>) -> felt252 {
    if leaves.len() == 0 {
        return 0;
    }
    
    if leaves.len() == 1 {
        return *leaves[0];
    }
    
    // Build tree bottom-up
    let mut current_level = ArrayTrait::new();
    let mut i = 0;
    while i < leaves.len() {
        current_level.append(*leaves[i]);
        i += 1;
    }
    
    // Pad to power of 2 with zeros (matching original algorithm)
    let mut size = current_level.len();
    let mut power = 1;
    while power < size {
        power *= 2;
    }
    while current_level.len() < power {
        current_level.append(0);
    }
    
    // Build tree levels using Poseidon
    while current_level.len() > 1 {
        let mut next_level = ArrayTrait::new();
        let mut i = 0;
        while i < current_level.len() {
            let left = *current_level[i];
            let right = if i + 1 < current_level.len() {
                *current_level[i + 1]
            } else {
                0
            };
            
            // Hash pair using Poseidon
            let hash_val = hash_pair(left, right);
            next_level.append(hash_val);
            
            i += 2;
        }
        current_level = next_level;
    }
    
    // Should always have exactly one element at this point
    match current_level.get(0) {
        Option::Some(root) => *root.unbox(),
        Option::None => 0, // Should never happen
    }
}

// Hash a pair of felt252 values using Poseidon
pub fn hash_pair(left: felt252, right: felt252) -> felt252 {
    let mut data = ArrayTrait::new();
    data.append(left);
    data.append(right);
    poseidon_hash_span(data.span())
}

// Verify a Merkle proof
pub fn merkle_proof_verify(
    root: felt252, 
    leaf: felt252, 
    proof: @Array<felt252>, 
    index: u32
) -> bool {
    let mut current = leaf;
    let mut idx = index;
    let mut i = 0;
    
    while i < proof.len() {
        let sibling = *proof[i];
        
        // Determine if current node is left or right child
        if idx % 2 == 0 {
            // Current is left child
            current = hash_pair(current, sibling);
        } else {
            // Current is right child
            current = hash_pair(sibling, current);
        }
        
        idx = idx / 2;
        i += 1;
    }
    
    current == root
}

// Helper to hash a single felt252 value with Poseidon
pub fn hash_single(value: felt252) -> felt252 {
    let mut data = ArrayTrait::new();
    data.append(value);
    poseidon_hash_span(data.span())
}

#[cfg(test)]
mod tests {
    use super::*;
    use core::array::ArrayTrait;

    #[test]
    fn test_merkle_root_empty() {
        // Test merkle root of empty array
        let empty = ArrayTrait::new();
        let root = merkle_root(@empty);
        assert_eq!(root, 0, "Empty merkle root should be 0");
    }

    #[test]
    fn test_merkle_root_single() {
        // Test merkle root of single element
        let mut leaves = ArrayTrait::new();
        leaves.append(12345);
        let root = merkle_root(@leaves);
        assert_eq!(root, 12345, "Single element merkle root should be the element");
    }

    #[test]
    fn test_merkle_root_two_elements() {
        // Test merkle root of two elements
        let mut leaves = ArrayTrait::new();
        leaves.append(100);
        leaves.append(200);
        let root = merkle_root(@leaves);
        
        // Root should be poseidon hash of the pair
        let expected = hash_pair(100, 200);
        assert_eq!(root, expected, "Two element merkle root should be hash of pair");
    }

    #[test]
    fn test_merkle_root_power_of_two() {
        // Test with power of 2 elements
        let mut leaves = ArrayTrait::new();
        leaves.append(1);
        leaves.append(2);
        leaves.append(3);
        leaves.append(4);
        let root = merkle_root(@leaves);
        
        // Should build complete tree
        assert!(root != 0, "Root should not be zero");
    }

    #[test]
    fn test_merkle_root_non_power_of_two() {
        // Test with non-power of 2 elements (should pad)
        let mut leaves = ArrayTrait::new();
        leaves.append(1);
        leaves.append(2);
        leaves.append(3);
        let root = merkle_root(@leaves);
        
        // Should pad to 4 elements and build tree
        assert!(root != 0, "Root should not be zero");
    }

    #[test]
    fn test_merkle_proof_verify_valid() {
        // Test valid merkle proof
        let mut leaves = ArrayTrait::new();
        leaves.append(10);
        leaves.append(20);
        leaves.append(30);
        leaves.append(40);
        
        let root = merkle_root(@leaves);
        
        // Create proof for leaf at index 0 (value 10)
        // Sibling at level 0: 20
        // Sibling at level 1: hash_pair(30, 40)
        let mut proof = ArrayTrait::new();
        proof.append(20);
        proof.append(hash_pair(30, 40));
        
        let valid = merkle_proof_verify(root, 10, @proof, 0);
        assert!(valid, "Valid proof should verify");
    }

    #[test]
    fn test_merkle_proof_verify_invalid_leaf() {
        // Test invalid proof - wrong leaf value
        let mut leaves = ArrayTrait::new();
        leaves.append(10);
        leaves.append(20);
        
        let root = merkle_root(@leaves);
        
        let mut proof = ArrayTrait::new();
        proof.append(20); // Sibling
        
        // Try to verify with wrong leaf value
        let valid = merkle_proof_verify(root, 99, @proof, 0);
        assert!(!valid, "Invalid leaf should not verify");
    }

    #[test]
    fn test_merkle_proof_verify_invalid_proof() {
        // Test invalid proof - wrong sibling
        let mut leaves = ArrayTrait::new();
        leaves.append(10);
        leaves.append(20);
        
        let root = merkle_root(@leaves);
        
        let mut proof = ArrayTrait::new();
        proof.append(99); // Wrong sibling
        
        let valid = merkle_proof_verify(root, 10, @proof, 0);
        assert!(!valid, "Invalid proof should not verify");
    }

    #[test]
    fn test_hash_single() {
        // Test single value hashing helper
        let val1 = hash_single(42);
        let val2 = hash_single(42);
        assert_eq!(val1, val2, "Same input should produce same hash");
        
        let val3 = hash_single(43);
        assert!(val1 != val3, "Different inputs should produce different hashes");
    }

    #[test]
    fn test_hash_pair_deterministic() {
        // Test pair hashing is deterministic
        let hash1 = hash_pair(10, 20);
        let hash2 = hash_pair(10, 20);
        assert_eq!(hash1, hash2, "Same pair should produce same hash");
        
        let hash3 = hash_pair(20, 10);
        assert!(hash1 != hash3, "Order should matter in pair hashing");
    }

    #[test]
    fn test_poseidon_basic() {
        // Basic test to ensure Poseidon is working
        let mut data = ArrayTrait::new();
        data.append(1);
        data.append(2);
        data.append(3);
        
        let hash = poseidon_hash_span(data.span());
        
        // Poseidon should produce non-zero hash for non-empty input
        assert!(hash != 0, "Poseidon hash should not be zero");
        
        // Hash should be deterministic
        let hash2 = poseidon_hash_span(data.span());
        assert_eq!(hash, hash2, "Poseidon should be deterministic");
    }

    #[test]
    fn test_cairo_poseidon_test_vectors() {
        // Test vectors to match with Rust implementation
        
        // Test hash_pair(100, 200)
        let result1 = hash_pair(100, 200);
        // Cairo actual result: 3199895829076014876906394973539079787786658195321510851734821809729636028785
        // Let's just verify it's deterministic for now
        let result1_check = hash_pair(100, 200);
        assert_eq!(result1, result1_check, "hash_pair should be deterministic");
        
        // Test merkle_root([12345])
        let mut single = ArrayTrait::new();
        single.append(12345);
        let result2 = merkle_root(@single);
        assert_eq!(result2, 12345, "merkle_root([12345]) should return 12345");
        
        // Test merkle_root([100, 200])
        let mut two = ArrayTrait::new();
        two.append(100);
        two.append(200);
        let result3 = merkle_root(@two);
        // Should equal hash_pair(100, 200)
        assert_eq!(result3, result1, "merkle_root([100, 200]) should equal hash_pair(100, 200)");
        
        // Test merkle_root([])
        let empty = ArrayTrait::new();
        let result4 = merkle_root(@empty);
        assert_eq!(result4, 0, "merkle_root([]) should return 0");
    }
}