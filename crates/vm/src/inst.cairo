// Instruction set & operands (decoded form)

#[derive(Copy, Drop)]
pub enum Op {
    Mov,
    Add,
    Sub,
    Neg,
    Sav,
    Swp,
    Jmp,
    Jz,
    Jnz,
    Jgz,
    Jlz,
    Nop,
    Hlt,
}

#[derive(Copy, Drop)]
pub enum PortTag {
    Up,
    Down,
    Left,
    Right,
}

#[derive(Copy, Drop)]
pub enum Src {
    Lit: u32,        // literals are encoded as u32; sign handling is up to assembler (two's complement) or host
    Acc,
    Nil,             // reads 0
    In,              // only valid at (0,0)
    P: PortTag,      // UP/DOWN/LEFT/RIGHT
    Last,            // last successful port
}

#[derive(Copy, Drop)]
pub enum Dst {
    Acc,
    Nil,             // discard
    Out,             // only valid at (1,1)
    P: PortTag,      // UP/DOWN/LEFT/RIGHT
    Last,            // write to LAST (requires LAST set to a real port)
}

// One decoded instruction
#[derive(Copy, Drop)]
pub struct Inst {
    pub op: Op,
    pub src: Src,   // for unary ops this is the operand; for MOV: source
    pub dst: Dst,   // for MOV only; ignored otherwise
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_op_enum() {
        // Test that Op enum variants can be created
        let _mov = Op::Mov;
        let _add = Op::Add;
        let _sub = Op::Sub;
        let _neg = Op::Neg;
        let _sav = Op::Sav;
        let _swp = Op::Swp;
        let _jmp = Op::Jmp;
        let _jz = Op::Jz;
        let _jnz = Op::Jnz;
        let _jgz = Op::Jgz;
        let _jlz = Op::Jlz;
        let _nop = Op::Nop;
        let _hlt = Op::Hlt;
        // If we get here, all variants are valid
        assert!(true, "All Op variants created successfully");
    }

    #[test]
    fn test_port_tag_enum() {
        // Test PortTag enum variants
        let _up = PortTag::Up;
        let _down = PortTag::Down;
        let _left = PortTag::Left;
        let _right = PortTag::Right;
        assert!(true, "All PortTag variants created successfully");
    }

    #[test]
    fn test_src_enum() {
        // Test Src enum variants
        let _lit = Src::Lit(42);
        let _acc = Src::Acc;
        let _nil = Src::Nil;
        let _in = Src::In;
        let _port_up = Src::P(PortTag::Up);
        let _last = Src::Last;
        assert!(true, "All Src variants created successfully");
    }

    #[test]
    fn test_dst_enum() {
        // Test Dst enum variants
        let _acc = Dst::Acc;
        let _nil = Dst::Nil;
        let _out = Dst::Out;
        let _port_down = Dst::P(PortTag::Down);
        let _last = Dst::Last;
        assert!(true, "All Dst variants created successfully");
    }

    #[test]
    fn test_inst_struct() {
        // Test creating various instruction types
        let mov_inst = Inst {
            op: Op::Mov,
            src: Src::Lit(100),
            dst: Dst::Acc,
        };
        
        let add_inst = Inst {
            op: Op::Add,
            src: Src::Acc,
            dst: Dst::Nil, // Ignored for Add
        };
        
        let jmp_inst = Inst {
            op: Op::Jmp,
            src: Src::Lit(5),
            dst: Dst::Nil, // Ignored for Jmp
        };
        
        // Verify we can access fields
        match mov_inst.op {
            Op::Mov => assert!(true, "Mov instruction created"),
            _ => assert!(false, "Expected Mov instruction"),
        }
        
        match add_inst.src {
            Src::Acc => assert!(true, "Acc source verified"),
            _ => assert!(false, "Expected Acc source"),
        }
        
        match jmp_inst.src {
            Src::Lit(val) => assert_eq!(val, 5, "Jump target verified"),
            _ => assert!(false, "Expected Lit source"),
        }
    }
}
