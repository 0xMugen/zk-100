use core::bool::{True, False};
use super::state::GridState;

// Simple predicate: exact match of OUT with expected (provided by the exec layer)
pub fn check_target_exact(final_grid: @GridState, expected: @Array<u32>) -> bool {
    if final_grid.out_stream.len() != expected.len() { 
        return False; 
    }
    
    let mut i = 0_u32;
    while i < expected.len() {
        match final_grid.out_stream.get(i) {
            Option::Some(out_val) => {
                match expected.get(i) {
                    Option::Some(exp_val) => {
                        if *out_val.unbox() != *exp_val.unbox() {
                            return False;
                        }
                    },
                    Option::None => { return False; }
                }
            },
            Option::None => { return False; }
        }
        i += 1;
    }
    True
}

// Re-exportable type alias for clarity
pub use check_target_exact as check_target;

#[cfg(test)]
mod tests {
    use super::*;
    use crate::state::create_empty_grid;
    use core::array::ArrayTrait;

    #[test]
    fn test_check_target_exact_match() {
        // Test exact match
        let mut grid = create_empty_grid();
        grid.out_stream = array![1, 2, 3, 4, 5];
        
        let expected = array![1, 2, 3, 4, 5];
        assert!(check_target_exact(@grid, @expected), "Should match identical arrays");
    }

    #[test]
    fn test_check_target_different_length() {
        // Test different lengths
        let mut grid = create_empty_grid();
        grid.out_stream = array![1, 2, 3];
        
        let expected = array![1, 2, 3, 4, 5];
        assert!(!check_target_exact(@grid, @expected), "Should not match different lengths");
        
        // Test opposite case
        grid.out_stream = array![1, 2, 3, 4, 5];
        let expected_short = array![1, 2, 3];
        assert!(!check_target_exact(@grid, @expected_short), "Should not match when output longer");
    }

    #[test]
    fn test_check_target_different_values() {
        // Test different values
        let mut grid = create_empty_grid();
        grid.out_stream = array![1, 2, 3, 4, 5];
        
        let expected = array![1, 2, 3, 99, 5];
        assert!(!check_target_exact(@grid, @expected), "Should not match different values");
    }

    #[test]
    fn test_check_target_empty_arrays() {
        // Test empty arrays
        let grid = create_empty_grid();
        let expected = ArrayTrait::new();
        
        assert!(check_target_exact(@grid, @expected), "Empty arrays should match");
    }

    #[test]
    fn test_check_target_single_element() {
        // Test single element arrays
        let mut grid = create_empty_grid();
        grid.out_stream = array![42];
        
        let expected = array![42];
        assert!(check_target_exact(@grid, @expected), "Single matching element should pass");
        
        let expected_wrong = array![99];
        assert!(!check_target_exact(@grid, @expected_wrong), "Single non-matching element should fail");
    }

    #[test]
    fn test_check_target_alias() {
        // Test that check_target is properly aliased
        let mut grid = create_empty_grid();
        grid.out_stream = array![10, 20, 30];
        
        let expected = array![10, 20, 30];
        assert!(check_target(@grid, @expected), "check_target alias should work");
    }
}