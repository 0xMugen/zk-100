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
