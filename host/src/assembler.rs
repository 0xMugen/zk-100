use crate::instruction::{Inst, Op, Src, Dst};
use anyhow::{Result, anyhow};
use std::collections::HashMap;

pub type Programs = Vec<Vec<Vec<Inst>>>;

pub fn parse_assembly(code: &str) -> Result<Programs> {
    let mut programs = vec![vec![vec![], vec![]], vec![vec![], vec![]]];
    let mut current_node: Option<(usize, usize)> = None;
    
    // First pass: parse instructions and collect labels
    let mut node_labels: HashMap<(usize, usize), HashMap<String, usize>> = HashMap::new();
    let mut node_instructions: HashMap<(usize, usize), Vec<(String, Option<String>)>> = HashMap::new();
    
    for line in code.lines() {
        let line = line.trim();
        
        // Skip empty lines and comments
        if line.is_empty() || line.starts_with('#') || line.starts_with("//") {
            continue;
        }
        
        // Handle node declaration
        if line.starts_with("NODE") {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() >= 2 {
                let coords = parse_node_coords(parts[1])?;
                current_node = Some(coords);
                node_labels.entry(coords).or_insert_with(HashMap::new);
                node_instructions.entry(coords).or_insert_with(Vec::new);
            }
            continue;
        }
        
        // Handle labels
        if line.ends_with(':') {
            if let Some((r, c)) = current_node {
                let label_name = line.trim_end_matches(':');
                let inst_count = node_instructions.get(&(r, c)).map(|v| v.len()).unwrap_or(0);
                node_labels.get_mut(&(r, c)).unwrap().insert(label_name.to_string(), inst_count);
            }
            continue;
        }
        
        // Store instruction line for later parsing
        if let Some((r, c)) = current_node {
            node_instructions.get_mut(&(r, c)).unwrap().push((line.to_string(), None));
        }
    }
    
    // Second pass: parse instructions with label knowledge
    for ((r, c), inst_lines) in node_instructions {
        let labels = node_labels.get(&(r, c)).unwrap();
        
        for (line, _) in inst_lines {
            let inst = parse_instruction(&line, labels)?;
            programs[r][c].push(inst);
        }
    }
    
    Ok(programs)
}

fn parse_node_coords(s: &str) -> Result<(usize, usize)> {
    let coords: Vec<&str> = s.trim_matches(|c| c == '(' || c == ')').split(',').collect();
    if coords.len() != 2 {
        return Err(anyhow!("Invalid node coordinates: {}", s));
    }
    let r = coords[0].trim().parse::<usize>()?;
    let c = coords[1].trim().parse::<usize>()?;
    if r >= 2 || c >= 2 {
        return Err(anyhow!("Node coordinates must be in 2x2 grid: {}", s));
    }
    Ok((r, c))
}

fn parse_instruction(
    line: &str,
    labels: &HashMap<String, usize>,
) -> Result<Inst> {
    let parts: Vec<&str> = line.split_whitespace().collect();
    if parts.is_empty() {
        return Err(anyhow!("Empty instruction line"));
    }
    
    let op = Op::from_str(parts[0])?;
    
    match op {
        Op::Nop | Op::Hlt | Op::Neg | Op::Sav | Op::Swp => {
            // No operands
            Ok(Inst {
                op,
                src: Src::Nil,
                dst: Dst::Nil,
            })
        }
        Op::Add | Op::Sub | Op::Jmp | Op::Jz | Op::Jnz | Op::Jgz | Op::Jlz => {
            // One source operand
            if parts.len() < 2 {
                return Err(anyhow!("Missing operand for {}", parts[0]));
            }
            let src = parse_src_operand(parts[1], labels)?;
            Ok(Inst {
                op,
                src,
                dst: Dst::Nil,
            })
        }
        Op::Mov => {
            // Two operands
            if parts.len() < 3 {
                return Err(anyhow!("MOV requires two operands"));
            }
            let src = parse_src_operand(parts[1].trim_end_matches(','), labels)?;
            let dst = Dst::from_str(parts[2])?;
            Ok(Inst { op, src, dst })
        }
    }
}

fn parse_src_operand(
    s: &str,
    labels: &HashMap<String, usize>,
) -> Result<Src> {
    // Check if it's a label reference
    if let Some(&pc) = labels.get(s) {
        return Ok(Src::Lit(pc as u32));
    }
    
    // Try to parse as normal source operand
    Src::from_str(s)
}

pub fn encode_programs(programs: &Programs) -> Result<Vec<u32>> {
    let mut prog_words = Vec::new();
    
    for row in programs {
        for program in row {
            // Add program length
            prog_words.push(program.len() as u32);
            
            // Add encoded instructions
            for inst in program {
                prog_words.push(inst.encode());
            }
        }
    }
    
    Ok(prog_words)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_simple_program() {
        let code = r#"
# Simple test program
NODE (0,0)
NOP
HLT

NODE (0,1)
# Empty node
"#;
        
        let programs = parse_assembly(code).unwrap();
        assert_eq!(programs[0][0].len(), 2);
        assert_eq!(programs[0][1].len(), 0);
        assert_eq!(programs[1][0].len(), 0);
        assert_eq!(programs[1][1].len(), 0);
    }

    #[test]
    fn test_parse_with_labels() {
        let code = r#"
NODE (0,0)
loop:
    ADD 1
    JNZ loop
    HLT
"#;
        
        let programs = parse_assembly(code).unwrap();
        assert_eq!(programs[0][0].len(), 3);
        // The JNZ should jump to PC 0 (the loop label)
        if let Src::Lit(target) = programs[0][0][1].src {
            assert_eq!(target, 0);
        } else {
            panic!("Expected literal jump target");
        }
    }

    #[test]
    fn test_parse_port_communication() {
        let code = r#"
NODE (0,0)
MOV 42, P:RIGHT
HLT

NODE (0,1)
MOV P:LEFT, ACC
HLT
"#;
        
        let programs = parse_assembly(code).unwrap();
        assert_eq!(programs[0][0].len(), 2);
        assert_eq!(programs[0][1].len(), 2);
    }

    #[test]
    fn test_encode_programs() {
        let code = r#"
NODE (0,0)
NOP
HLT
"#;
        
        let programs = parse_assembly(code).unwrap();
        let words = encode_programs(&programs).unwrap();
        
        // Should have: [2, nop_encoded, hlt_encoded, 0, 0, 0]
        assert_eq!(words.len(), 6);
        assert_eq!(words[0], 2); // Program length
        assert_eq!(words[3], 0); // Empty program
        assert_eq!(words[4], 0); // Empty program
        assert_eq!(words[5], 0); // Empty program
    }
}