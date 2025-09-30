use core::array::ArrayTrait;
use core::option::Option;

#[executable]
fn main(inputs: Array<u32>, expected: Array<u32>, prog_words: Array<felt252>) -> Array<felt252> {
    execute_zk100(inputs, expected, prog_words)
}

use zk100_vm::{
    GridState, StepResult, Inst, Op, Src, Dst, Score, PortTag,
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
fn execute_zk100(    
    inputs: Array<u32>,
    expected: Array<u32>,
    prog_words: Array<felt252>
) -> Array<felt252> {
    // 1. Expand seed to generate initial state and target
    let mut grid = create_empty_grid();
    
    // 2. Decode programs from prog_words
    let programs = decode_programs(@prog_words);
    
    // 3. Compute program commitment (Cairo now owns this calculation)
    let prog_merkle_root = commit_programs(@programs);
    
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
            
            // Read program length
            if word_idx < prog_words.len() {
                let prog_len: u32 = (*prog_words[word_idx]).try_into().unwrap();
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
fn decode_instruction(word: felt252) -> Inst {
    // Decode instruction from encoded felt252
    // Format: lit(8) | src_port(2) | dst_port(2) | op(4) | src(8) | dst(8) = 32 bits
    let val: u32 = word.try_into().unwrap();
    
    let lit_val = val / 0x1000000;                    // bits 24-31
    let src_port_val = (val / 0x400000) & 0x3;        // bits 22-23  
    let dst_port_val = (val / 0x100000) & 0x3;        // bits 20-21
    let op_val = (val / 0x10000) & 0xf;               // bits 16-19
    let src_val = (val / 0x100) & 0xff;               // bits 8-15
    let dst_val = val & 0xff;                         // bits 0-7
    
    // Decode operation
    let op = decode_op(op_val);
    
    // Decode source with port direction
    let src = if src_val == 0 { Src::Lit(lit_val) }
    else if src_val == 1 { Src::Acc }
    else if src_val == 2 { Src::Nil }
    else if src_val == 3 { Src::In }
    else if src_val == 4 { 
        // Decode port with actual direction
        Src::P(decode_port_tag(src_port_val))
    }
    else { Src::Last };
    
    // Decode destination with port direction
    let dst = if dst_val == 0 { Dst::Acc }
    else if dst_val == 1 { Dst::Nil }
    else if dst_val == 2 { Dst::Out }
    else if dst_val == 3 {
        // Decode port with actual direction
        Dst::P(decode_port_tag(dst_port_val))
    }
    else { Dst::Last };
    
    Inst { op, src, dst }
}

// Helper to decode operation
fn decode_op(val: u32) -> Op {
    if val == 1 { Op::Mov }
    else if val == 2 { Op::Add }
    else if val == 3 { Op::Sub }
    else if val == 4 { Op::Neg }
    else if val == 5 { Op::Sav }
    else if val == 6 { Op::Swp }
    else if val == 7 { Op::Jmp }
    else if val == 8 { Op::Jz }
    else if val == 9 { Op::Jnz }
    else if val == 10 { Op::Jgz }
    else if val == 11 { Op::Jlz }
    else if val == 12 { Op::Nop }
    else { Op::Hlt }
}

// Helper to decode port tag
fn decode_port_tag(val: u32) -> PortTag {
    if val == 0 { PortTag::Up }
    else if val == 1 { PortTag::Down }
    else if val == 2 { PortTag::Left }
    else { PortTag::Right }
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

#[cfg(test)]
mod tests {
    use super::*;
    use core::array::ArrayTrait;
    use core::option::Option;
    use zk100_vm::get_program;
    use zk100_proof_io::{deserialize_public_outputs, encode_instruction};

    #[test]
    fn test_decode_instruction() {
        // Test instruction encoding and decoding
        let orig_inst = Inst {
            op: Op::Mov,
            src: Src::Lit(42),
            dst: Dst::Acc,
        };
        
        let encoded = encode_test_instruction(orig_inst);
        let decoded = decode_instruction(encoded);
        
        match decoded.op {
            Op::Mov => assert!(true, "Operation should be MOV"),
            _ => assert!(false, "Expected MOV instruction"),
        }
        
        match decoded.src {
            Src::Lit(val) => assert_eq!(val, 42, "Literal value should be 42"),
            _ => assert!(false, "Expected literal source"),
        }
        
        match decoded.dst {
            Dst::Acc => assert!(true, "Destination should be ACC"),
            _ => assert!(false, "Expected ACC destination"),
        }
    }

    #[test]
    fn test_decode_programs_empty() {
        // Test decoding empty program words
        let empty_words = ArrayTrait::new();
        let programs = decode_programs(@empty_words);
        
        assert_eq!(programs.len(), GRID_H, "Should have correct grid height");
        
        // Check all positions have programs (even if empty)
        let mut r = 0;
        while r < programs.len() {
            match programs.get(r) {
                Option::Some(row) => {
                    assert_eq!(row.unbox().len(), GRID_W, "Row should have correct width");
                },
                Option::None => assert!(false, "Row should exist"),
            }
            r += 1;
        }
    }

    #[test]
    fn test_load_programs() {
        // Test loading programs into grid
        let mut grid = create_empty_grid();
        
        // Create test programs
        let mut programs = ArrayTrait::new();
        let mut row0 = ArrayTrait::new();
        let mut prog00 = ArrayTrait::new();
        prog00.append(Inst { op: Op::Add, src: Src::Lit(5), dst: Dst::Nil });
        row0.append(prog00);
        row0.append(ArrayTrait::new()); // Empty at (0,1)
        
        let mut row1 = ArrayTrait::new();
        row1.append(ArrayTrait::new()); // Empty at (1,0)
        row1.append(ArrayTrait::new()); // Empty at (1,1)
        
        programs.append(row0);
        programs.append(row1);
        
        load_programs(ref grid, @programs);
        
        // Verify programs were loaded
        match get_program(@grid, 0, 0) {
            Option::Some(prog) => {
                assert_eq!(prog.len(), 1, "Program should have 1 instruction");
            },
            Option::None => assert!(false, "Program should exist at (0,0)"),
        }
    }

    #[test]
    fn test_load_inputs() {
        // Test loading input stream
        let mut grid = create_empty_grid();
        let mut inputs = ArrayTrait::new();
        inputs.append(10);
        inputs.append(20);
        inputs.append(30);
        
        load_inputs(ref grid, @inputs);
        
        assert_eq!(grid.in_stream.len(), 3, "Input stream should have 3 values");
        assert_eq!(grid.in_cursor, 0, "Input cursor should start at 0");
        assert_eq!(*grid.in_stream[0], 10, "First input should be 10");
        assert_eq!(*grid.in_stream[1], 20, "Second input should be 20");
        assert_eq!(*grid.in_stream[2], 30, "Third input should be 30");
    }

    #[test]
    fn test_count_nodes_used_empty() {
        // Test counting with no programs
        let programs = ArrayTrait::new();
        let count = count_nodes_used(@programs);
        assert_eq!(count, 0, "Empty grid should have 0 nodes used");
    }

    #[test]
    fn test_count_nodes_used_with_programs() {
        // Test counting with some programs
        let mut programs = ArrayTrait::new();
        
        // Row 0
        let mut row0 = ArrayTrait::new();
        let mut prog00 = ArrayTrait::new();
        prog00.append(Inst { op: Op::Nop, src: Src::Nil, dst: Dst::Nil });
        row0.append(prog00); // Program at (0,0)
        row0.append(ArrayTrait::new()); // Empty at (0,1)
        
        // Row 1
        let mut row1 = ArrayTrait::new();
        row1.append(ArrayTrait::new()); // Empty at (1,0)
        let mut prog11 = ArrayTrait::new();
        prog11.append(Inst { op: Op::Hlt, src: Src::Nil, dst: Dst::Nil });
        row1.append(prog11); // Program at (1,1)
        
        programs.append(row0);
        programs.append(row1);
        
        let count = count_nodes_used(@programs);
        assert_eq!(count, 2, "Should count 2 nodes with programs");
    }

    #[test]
    fn test_execute_vm_simple() {
        // Test basic VM execution
        let mut grid = create_empty_grid();
        
        // Add a simple program that halts immediately
        let mut prog = ArrayTrait::new();
        prog.append(Inst { op: Op::Hlt, src: Src::Nil, dst: Dst::Nil });
        
        grid.progs = ArrayTrait::new();
        let mut row0 = ArrayTrait::new();
        row0.append(prog);
        row0.append(ArrayTrait::new());
        let mut row1 = ArrayTrait::new();
        row1.append(ArrayTrait::new());
        row1.append(ArrayTrait::new());
        grid.progs.append(row0);
        grid.progs.append(row1);
        
        let (final_grid, result) = execute_vm(grid, 100);
        
        match result {
            StepResult::Halted => assert!(true, "VM should halt"),
            _ => assert!(false, "Expected halted result"),
        }
        
        assert!(final_grid.cycles > 0, "Should have executed some cycles");
    }

    #[test]
    fn test_execute_vm_timeout() {
        // Test VM timeout
        let mut grid = create_empty_grid();
        
        // Add infinite loop program
        let mut prog = ArrayTrait::new();
        prog.append(Inst { op: Op::Jmp, src: Src::Lit(0), dst: Dst::Nil });
        
        grid.progs = ArrayTrait::new();
        let mut row0 = ArrayTrait::new();
        row0.append(prog);
        row0.append(ArrayTrait::new());
        let mut row1 = ArrayTrait::new();
        row1.append(ArrayTrait::new());
        row1.append(ArrayTrait::new());
        grid.progs.append(row0);
        grid.progs.append(row1);
        
        let (final_grid, _result) = execute_vm(grid, 5);
        
        assert_eq!(final_grid.cycles, 5, "Should execute exactly max_cycles");
    }

    #[test]
    fn test_expand_seed() {
        // Test seed expansion
        let (grid, inputs, expected) = expand_seed(12345);
        
        // Check grid is initialized
        assert_eq!(grid.cycles, 0, "Grid should start with 0 cycles");
        
        // Check inputs generated
        assert_eq!(inputs.len(), 5, "Should generate 5 inputs");
        assert_eq!(*inputs[0], 0, "First input should be 0");
        assert_eq!(*inputs[1], 100, "Second input should be 100");
        
        // Check expected output
        assert_eq!(expected.len(), 1, "Should have 1 expected output");
        assert_eq!(*expected[0], 500, "Expected output should be 500");
    }

    #[test]
    fn test_execute_zk100_integration() {
        // Integration test for execute_zk100
        let mut inputs = ArrayTrait::new();
        inputs.append(1);
        inputs.append(2);
        
        let mut expected = ArrayTrait::new();
        expected.append(3);
        
        // Create a simple program that adds two inputs
        let mut prog_words = ArrayTrait::new();
        // This is simplified - in reality would need proper encoding
        prog_words.append(0); // Program length marker
        prog_words.append(0); // Instruction word
        
        let result = execute_zk100(inputs, expected, prog_words);
        
        // Check result is properly serialized
        assert_eq!(result.len(), 7, "Result should have 7 elements");
    }

    // Helper function to encode an instruction for testing
    fn encode_test_instruction(inst: Inst) -> felt252 {
        encode_instruction(@inst)
    }

    // Helper to create programs for a 2x2 grid with empty nodes except specified
    fn create_test_programs(node_programs: Array<(u32, u32, Array<Inst>)>) -> Array<felt252> {
        let mut prog_words = ArrayTrait::new();
        
        // For each position in 2x2 grid
        let mut r = 0;
        while r < 2 {
            let mut c = 0;
            while c < 2 {
                // Check if we have a program for this position
                let mut found = false;
                let mut i = 0;
                while i < node_programs.len() {
                    match node_programs.get(i) {
                        Option::Some(entry_box) => {
                            let (row, col, prog) = entry_box.unbox();
                            if *row == r && *col == c {
                                // Add program length marker
                                prog_words.append(prog.len().into());
                                
                                // Encode each instruction
                                let mut j = 0;
                                while j < prog.len() {
                                    match prog.get(j) {
                                        Option::Some(inst_box) => {
                                            let inst = inst_box.unbox();
                                            prog_words.append(encode_test_instruction(*inst));
                                        },
                                        Option::None => {},
                                    }
                                    j += 1;
                                }
                                found = true;
                                break;
                            }
                        },
                        Option::None => {},
                    }
                    i += 1;
                }
                
                if !found {
                    // Empty program
                    prog_words.append(0);
                }
                
                c += 1;
            }
            r += 1;
        }
        
        prog_words
    }

    #[test]
    fn test_full_execution_pass_through() {
        // Test 1: Simple test with NOP instructions
        // Just test that the system runs without crashing
        
        let mut node00_prog = ArrayTrait::new();
        node00_prog.append(Inst { op: Op::Nop, src: Src::Nil, dst: Dst::Nil });
        node00_prog.append(Inst { op: Op::Hlt, src: Src::Nil, dst: Dst::Nil });
        
        let mut node_programs = ArrayTrait::new();
        node_programs.append((0, 0, node00_prog));
        
        let prog_words = create_test_programs(node_programs);
        
        // Create empty input and expected output
        let inputs = ArrayTrait::new();
        let expected = ArrayTrait::new();
        
        // Execute
        let result = execute_zk100(inputs, expected, prog_words);
        
        // Check result
        assert!(result.len() > 0, "Should return results");
        
        // Deserialize outputs
        match deserialize_public_outputs(@result) {
            Option::Some(outputs) => {
                // Empty input and output should be considered solved
                assert!(outputs.solved, "Should solve empty challenge");
                assert_eq!(outputs.score.nodes_used, 1, "Should use 1 node");
            },
            Option::None => assert!(false, "Failed to deserialize outputs"),
        }
    }

    #[test] 
    fn test_full_execution_negation() {
        // Test 2: Simple addition test
        // Node (0,0): MOV 5, ACC; ADD 10; HLT
        
        let mut node00_prog = ArrayTrait::new();
        node00_prog.append(Inst { op: Op::Mov, src: Src::Lit(5), dst: Dst::Acc });
        node00_prog.append(Inst { op: Op::Add, src: Src::Lit(10), dst: Dst::Nil });
        node00_prog.append(Inst { op: Op::Hlt, src: Src::Nil, dst: Dst::Nil });
        
        let mut node_programs = ArrayTrait::new();
        node_programs.append((0, 0, node00_prog));
        
        let prog_words = create_test_programs(node_programs);
        
        
        // Create empty input and expected output (no I/O needed)
        let inputs = ArrayTrait::new();
        let expected = ArrayTrait::new();
        
        // Execute
        let result = execute_zk100(inputs, expected, prog_words);
        
        // Check result
        match deserialize_public_outputs(@result) {
            Option::Some(outputs) => {
                assert!(outputs.solved, "Should solve empty challenge");
                assert_eq!(outputs.score.cycles, 4, "Should take 4 cycles");
            },
            Option::None => assert!(false, "Failed to deserialize outputs"),
        }
    }

    #[test]
    fn test_full_execution_double() {
        // Test 3: Test with literal values
        // Node (1,1): MOV 100, ACC; HLT
        
        let mut node11_prog = ArrayTrait::new();
        node11_prog.append(Inst { op: Op::Mov, src: Src::Lit(100), dst: Dst::Acc });
        node11_prog.append(Inst { op: Op::Hlt, src: Src::Nil, dst: Dst::Nil });
        
        let mut node_programs = ArrayTrait::new();
        node_programs.append((1, 1, node11_prog));
        
        let prog_words = create_test_programs(node_programs);
        
        // Create empty input and expected output
        let inputs = ArrayTrait::new();
        let expected = ArrayTrait::new();
        
        // Execute
        let result = execute_zk100(inputs, expected, prog_words);
        
        // Check result
        match deserialize_public_outputs(@result) {
            Option::Some(outputs) => {
                assert!(outputs.solved, "Should solve empty challenge");
                assert_eq!(outputs.score.nodes_used, 1, "Should use 1 node");
                assert_eq!(outputs.score.cycles, 3, "Should take 3 cycles");
            },
            Option::None => assert!(false, "Failed to deserialize outputs"),
        }
    }

    #[test]
    fn test_port_communication_basic() {
        // Test port communication between two nodes
        // Node (0,0): MOV 42, RIGHT (send value to the right)
        // Node (0,1): MOV LEFT, ACC (receive from the left); HLT
        
        let mut node00_prog = ArrayTrait::new();
        node00_prog.append(Inst { op: Op::Mov, src: Src::Lit(42), dst: Dst::P(PortTag::Right) });
        node00_prog.append(Inst { op: Op::Hlt, src: Src::Nil, dst: Dst::Nil });
        
        let mut node01_prog = ArrayTrait::new();
        node01_prog.append(Inst { op: Op::Mov, src: Src::P(PortTag::Left), dst: Dst::Acc });
        node01_prog.append(Inst { op: Op::Hlt, src: Src::Nil, dst: Dst::Nil });
        
        let mut node_programs = ArrayTrait::new();
        node_programs.append((0, 0, node00_prog));
        node_programs.append((0, 1, node01_prog));
        
        let prog_words = create_test_programs(node_programs);
        
        // Create empty input and expected output
        let inputs = ArrayTrait::new();
        let expected = ArrayTrait::new();
        
        // Execute
        let result = execute_zk100(inputs, expected, prog_words);
        
        // Check result
        match deserialize_public_outputs(@result) {
            Option::Some(outputs) => {
                assert!(outputs.solved, "Should solve empty challenge");
                assert_eq!(outputs.score.nodes_used, 2, "Should use 2 nodes");
                // Port communication should happen in one cycle
                assert!(outputs.score.cycles <= 4, "Should complete within 4 cycles");
            },
            Option::None => assert!(false, "Failed to deserialize outputs"),
        }
    }

    #[test]
    fn test_direct_input_to_output() {
        // Direct test: Node (0,0) reads input, Node (1,1) outputs
        // Node (0,0): MOV IN, ACC; HLT
        // Node (1,1): MOV 42, OUT; HLT
        
        let mut node00_prog = ArrayTrait::new();
        node00_prog.append(Inst { op: Op::Mov, src: Src::In, dst: Dst::Acc });
        node00_prog.append(Inst { op: Op::Hlt, src: Src::Nil, dst: Dst::Nil });
        
        let mut node11_prog = ArrayTrait::new();
        node11_prog.append(Inst { op: Op::Mov, src: Src::Lit(42), dst: Dst::Out });
        node11_prog.append(Inst { op: Op::Hlt, src: Src::Nil, dst: Dst::Nil });
        
        let mut node_programs = ArrayTrait::new();
        node_programs.append((0, 0, node00_prog));
        node_programs.append((1, 1, node11_prog));
        
        let prog_words = create_test_programs(node_programs);
        
        
        // Create input and expected output
        let mut inputs = ArrayTrait::new();
        inputs.append(99);  // Input value doesn't matter since we output 42
        
        let mut expected = ArrayTrait::new();
        expected.append(42);
        
        // Execute
        let result = execute_zk100(inputs, expected, prog_words);
        
        // Check result
        match deserialize_public_outputs(@result) {
            Option::Some(outputs) => {
                assert!(outputs.solved, "Should output expected value");
                assert_eq!(outputs.score.nodes_used, 2, "Should use 2 nodes");
                assert_eq!(outputs.score.msgs, 1, "Should output 1 message");
            },
            Option::None => assert!(false, "Failed to deserialize outputs"),
        }
    }

    #[test]
    fn test_simple_input_to_output() {
        // Two node test: pass input to output through one port connection
        // Node (0,0): MOV IN, RIGHT (read input, send right)
        // Node (0,1): MOV LEFT, ACC; MOV ACC, DOWN (receive from left, send down)
        // Node (1,1): MOV UP, OUT (receive from up, output)
        
        let mut node00_prog = ArrayTrait::new();
        node00_prog.append(Inst { op: Op::Mov, src: Src::In, dst: Dst::P(PortTag::Right) });
        node00_prog.append(Inst { op: Op::Hlt, src: Src::Nil, dst: Dst::Nil });
        
        let mut node01_prog = ArrayTrait::new();
        node01_prog.append(Inst { op: Op::Mov, src: Src::P(PortTag::Left), dst: Dst::Acc });
        node01_prog.append(Inst { op: Op::Mov, src: Src::Acc, dst: Dst::P(PortTag::Down) });
        node01_prog.append(Inst { op: Op::Hlt, src: Src::Nil, dst: Dst::Nil });
        
        let mut node11_prog = ArrayTrait::new();
        node11_prog.append(Inst { op: Op::Mov, src: Src::P(PortTag::Up), dst: Dst::Out });
        node11_prog.append(Inst { op: Op::Hlt, src: Src::Nil, dst: Dst::Nil });
        
        let mut node_programs = ArrayTrait::new();
        node_programs.append((0, 0, node00_prog));
        node_programs.append((0, 1, node01_prog));
        node_programs.append((1, 1, node11_prog));
        
        let prog_words = create_test_programs(node_programs);
        
        
        // Create input and expected output - single value
        let mut inputs = ArrayTrait::new();
        inputs.append(42);
        
        let mut expected = ArrayTrait::new();
        expected.append(42);
        
        // Execute
        let result = execute_zk100(inputs, expected, prog_words);
        
        // Check result
        match deserialize_public_outputs(@result) {
            Option::Some(outputs) => {
                assert!(outputs.solved, "Should pass single input to output");
                assert_eq!(outputs.score.nodes_used, 3, "Should use 3 nodes");
                assert_eq!(outputs.score.msgs, 1, "Should output 1 message");
            },
            Option::None => assert!(false, "Failed to deserialize outputs"),
        }
    }
}