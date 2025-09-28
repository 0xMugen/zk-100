use core::array::ArrayTrait;

// Create a simpler version that takes all prog_words as individual arguments
// For test_simple.asm: NOP in 3 nodes, MOV 42 OUT + HLT in last node
#[executable]
fn main() -> Array<felt252> {
    // For test_simple.asm, we have:
    // prog_words = [1, 0xc0201, 1, 0xc0201, 1, 0xc0201, 2, 0x2a010002, 0xd0201]
    let mut prog_words = ArrayTrait::new();
    prog_words.append(1);          // Node (0,0): 1 instruction
    prog_words.append(0xc0201);    // NOP instruction
    prog_words.append(1);          // Node (0,1): 1 instruction
    prog_words.append(0xc0201);    // NOP instruction
    prog_words.append(1);          // Node (1,0): 1 instruction  
    prog_words.append(0xc0201);    // NOP instruction
    prog_words.append(2);          // Node (1,1): 2 instructions
    prog_words.append(0x2a010002); // MOV 42, OUT
    prog_words.append(0xd0201);    // HLT
    
    calculate_merkle_root(prog_words)
}

use zk100_vm::{Inst, Op, Src, Dst, PortTag, GRID_H, GRID_W};
use zk100_proof_io::commit_programs;

// Calculate merkle root for the given program words
fn calculate_merkle_root(prog_words: Array<felt252>) -> Array<felt252> {
    // Decode programs from flattened word array (same logic as exec/main.cairo)
    let programs = decode_programs(@prog_words);
    
    // Calculate merkle root using the same function as the main executable
    let merkle_root = commit_programs(@programs);
    
    // Return the merkle root as a single-element array
    let mut result = ArrayTrait::new();
    result.append(merkle_root);
    result
}

// Decode programs from flattened word array (copied from exec/main.cairo)
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

// Decode a single instruction from felt252 (copied from exec/main.cairo)
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