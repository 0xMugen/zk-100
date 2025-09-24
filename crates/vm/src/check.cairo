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