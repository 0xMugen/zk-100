use core::array::ArrayTrait;
use core::option::Option;

use zk100_vm::{
    GridState, StepResult, Inst, Op, Src, Dst, Score,
    create_empty_grid, step_cycle, check_target,
    GRID_H, GRID_W
};

use zk100_proof_io::{
    PublicOutputs, commit_programs, commit_outputs, commit_challenge,
    serialize_public_outputs, hash_single
};

// Maximum cycles before giving up
const MAX_CYCLES: u64 = 10000;

// Main entry point for STWO proving
pub fn execute_zk100(seed: felt252, prog_merkle_root: felt252, prog_words: Array<felt252>) -> Array<felt252> {
    // 1. Expand seed to generate initial state and target
    let (mut grid, inputs, expected) = expand_seed(seed);
    
    // 2. Decode programs from prog_words
    let programs = decode_programs(@prog_words);
    
    // 3. Verify program commitment matches
    let computed_root = commit_programs(@programs);
    assert(computed_root == prog_merkle_root, 'Invalid program commitment');
    
    // 4. Load programs into grid
    load_programs(ref grid, @programs);
    
    // 5. Load input stream
    load_inputs(ref grid, @inputs);
    
    // 6. Execute VM until completion or timeout
    let (final_grid, _result) = execute_vm(grid, MAX_CYCLES);
    
    // 7. Check if target was achieved
    let solved = check_target(@final_grid, @expected);
    
    // 8. Compute commitments
    let challenge_commit = commit_challenge(@inputs, @expected);
    let output_commit = commit_outputs(@final_grid.out_stream);
    
    // 9. Create and return PublicOutputs
    let outputs = PublicOutputs {
        challenge_commit: challenge_commit,
        program_commit: prog_merkle_root,
        output_commit: output_commit,
        score: Score {
            cycles: final_grid.cycles,
            msgs: final_grid.msgs,
            nodes_used: count_nodes_used(@programs),
        },
        solved: solved,
    };
    
    serialize_public_outputs(@outputs)
}

// Expand seed into initial VM state and challenge
fn expand_seed(seed: felt252) -> (GridState, Array<u32>, Array<u32>) {
    // Use seed to generate deterministic values
    let mut rng_state = seed;
    
    // Create empty grid
    let mut grid = create_empty_grid();
    
    // Generate input stream (simplified - just a few values)
    let mut inputs = ArrayTrait::new();
    let mut i = 0;
    while i < 5 {
        rng_state = hash_single(rng_state);
        // Simple conversion - take lower bits as u32
        inputs.append(i * 100); // Simple deterministic values
        i += 1;
    }
    
    // Generate expected output
    let mut expected = ArrayTrait::new();
    expected.append(500); // Simple expected value
    
    (grid, inputs, expected)
}

// Decode programs from flattened word array
fn decode_programs(prog_words: @Array<felt252>) -> Array<Array<Array<Inst>>> {
    let mut programs = ArrayTrait::new();
    let mut word_idx = 0;
    
    // For each position in 2x2 grid
    let mut r = 0;
    while r < GRID_H {
        let mut row = ArrayTrait::new();
        let mut c = 0;
        while c < GRID_W {
            let mut program = ArrayTrait::new();
            
            // Read program length (simplified - assume fixed length)
            if word_idx < prog_words.len() {
                let prog_len: u32 = 3; // Fixed program length for simplicity
                word_idx += 1;
                
                // Read instructions
                let mut i: u32 = 0;
                while i < prog_len {
                    if word_idx >= prog_words.len() {
                        break;
                    }
                    let inst_word = *prog_words[word_idx];
                    let inst = decode_instruction(inst_word);
                    program.append(inst);
                    word_idx += 1;
                    i += 1;
                }
            }
            
            row.append(program);
            c += 1;
        }
        programs.append(row);
        r += 1;
    }
    
    programs
}

// Decode a single instruction from felt252
fn decode_instruction(_word: felt252) -> Inst {
    // Simplified - return a NOP instruction
    // In production would properly decode the instruction
    Inst {
        op: Op::Nop,
        src: Src::Nil,
        dst: Dst::Nil,
    }
}

// Load programs into grid
fn load_programs(ref grid: GridState, programs: @Array<Array<Array<Inst>>>) {
    // Clear existing programs and set new ones
    grid.progs = ArrayTrait::new();
    
    let mut r = 0;
    while r < programs.len() {
        match programs.get(r) {
            Option::Some(row_box) => {
                let row = row_box.unbox();
                let mut prog_row = ArrayTrait::new();
                let mut c = 0;
                while c < row.len() {
                    match row.get(c) {
                        Option::Some(prog_box) => {
                            let prog = prog_box.unbox();
                            let mut new_prog = ArrayTrait::new();
                            let mut i = 0;
                            while i < prog.len() {
                                match prog.get(i) {
                                    Option::Some(inst_box) => {
                                        new_prog.append(*inst_box.unbox());
                                    },
                                    Option::None => { }
                                }
                                i += 1;
                            }
                            prog_row.append(new_prog);
                        },
                        Option::None => {
                            prog_row.append(ArrayTrait::new());
                        }
                    }
                    c += 1;
                }
                grid.progs.append(prog_row);
            },
            Option::None => { }
        }
        r += 1;
    }
}

// Load input stream into grid
fn load_inputs(ref grid: GridState, inputs: @Array<u32>) {
    grid.in_stream = ArrayTrait::new();
    let mut i = 0;
    while i < inputs.len() {
        grid.in_stream.append(*inputs[i]);
        i += 1;
    }
    grid.in_cursor = 0;
}

// Execute VM until completion or timeout
fn execute_vm(mut grid: GridState, max_cycles: u64) -> (GridState, StepResult) {
    let mut result = StepResult::Continue;
    
    while grid.cycles < max_cycles {
        result = step_cycle(ref grid);
        
        match result {
            StepResult::Continue => { },
            StepResult::Halted => { break; },
            StepResult::Deadlock => { break; },
        }
    }
    
    (grid, result)
}

// Count how many nodes have programs
fn count_nodes_used(programs: @Array<Array<Array<Inst>>>) -> u32 {
    let mut count = 0;
    let mut r = 0;
    while r < programs.len() {
        match programs.get(r) {
            Option::Some(row_box) => {
                let row = row_box.unbox();
                let mut c = 0;
                while c < row.len() {
                    match row.get(c) {
                        Option::Some(prog_box) => {
                            let prog = prog_box.unbox();
                            if prog.len() > 0 {
                                count += 1;
                            }
                        },
                        Option::None => { }
                    }
                    c += 1;
                }
            },
            Option::None => { }
        }
        r += 1;
    }
    count
}