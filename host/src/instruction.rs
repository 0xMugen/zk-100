use anyhow::{Result, anyhow};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Op {
    Mov = 1,
    Add = 2,
    Sub = 3,
    Neg = 4,
    Sav = 5,
    Swp = 6,
    Jmp = 7,
    Jz = 8,
    Jnz = 9,
    Jgz = 10,
    Jlz = 11,
    Nop = 12,
    Hlt = 13,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PortTag {
    Up = 0,
    Down = 1,
    Left = 2,
    Right = 3,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Src {
    Lit(u32),
    Acc,
    Nil,
    In,
    P(PortTag),
    Last,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Dst {
    Acc,
    Nil,
    Out,
    P(PortTag),
    Last,
}

#[derive(Debug, Clone, Copy)]
pub struct Inst {
    pub op: Op,
    pub src: Src,
    pub dst: Dst,
}

impl Op {
    pub fn from_str(s: &str) -> Result<Self> {
        match s.to_uppercase().as_str() {
            "MOV" => Ok(Op::Mov),
            "ADD" => Ok(Op::Add),
            "SUB" => Ok(Op::Sub),
            "NEG" => Ok(Op::Neg),
            "SAV" => Ok(Op::Sav),
            "SWP" => Ok(Op::Swp),
            "JMP" => Ok(Op::Jmp),
            "JZ" => Ok(Op::Jz),
            "JNZ" => Ok(Op::Jnz),
            "JGZ" => Ok(Op::Jgz),
            "JLZ" => Ok(Op::Jlz),
            "NOP" => Ok(Op::Nop),
            "HLT" => Ok(Op::Hlt),
            _ => Err(anyhow!("Unknown operation: {}", s)),
        }
    }
}

impl PortTag {
    pub fn from_str(s: &str) -> Result<Self> {
        match s.to_uppercase().as_str() {
            "UP" => Ok(PortTag::Up),
            "DOWN" => Ok(PortTag::Down),
            "LEFT" => Ok(PortTag::Left),
            "RIGHT" => Ok(PortTag::Right),
            _ => Err(anyhow!("Unknown port: {}", s)),
        }
    }
}

impl Src {
    pub fn from_str(s: &str) -> Result<Self> {
        let upper = s.to_uppercase();
        match upper.as_str() {
            "ACC" => Ok(Src::Acc),
            "NIL" => Ok(Src::Nil),
            "IN" => Ok(Src::In),
            "LAST" => Ok(Src::Last),
            _ => {
                // Check for port
                if upper.starts_with("P:") {
                    let port_str = &upper[2..];
                    let port = PortTag::from_str(port_str)?;
                    Ok(Src::P(port))
                } else if let Ok(num) = s.parse::<u32>() {
                    Ok(Src::Lit(num))
                } else if let Ok(num) = s.parse::<i32>() {
                    // Handle negative numbers with two's complement
                    Ok(Src::Lit(num as u32))
                } else {
                    Err(anyhow!("Invalid source operand: {}", s))
                }
            }
        }
    }
    
    pub fn to_code(&self) -> u8 {
        match self {
            Src::Lit(_) => 0,
            Src::Acc => 1,
            Src::Nil => 2,
            Src::In => 3,
            Src::P(_) => 4,
            Src::Last => 5,
        }
    }
}

impl Dst {
    pub fn from_str(s: &str) -> Result<Self> {
        let upper = s.to_uppercase();
        match upper.as_str() {
            "ACC" => Ok(Dst::Acc),
            "NIL" => Ok(Dst::Nil),
            "OUT" => Ok(Dst::Out),
            "LAST" => Ok(Dst::Last),
            _ => {
                // Check for port
                if upper.starts_with("P:") {
                    let port_str = &upper[2..];
                    let port = PortTag::from_str(port_str)?;
                    Ok(Dst::P(port))
                } else {
                    Err(anyhow!("Invalid destination operand: {}", s))
                }
            }
        }
    }
    
    pub fn to_code(&self) -> u8 {
        match self {
            Dst::Acc => 0,
            Dst::Nil => 1,
            Dst::Out => 2,
            Dst::P(_) => 3,
            Dst::Last => 4,
        }
    }
}

impl Inst {
    pub fn encode(&self) -> u32 {
        // Format: lit(8) | src_port(2) | dst_port(2) | op(4) | src(8) | dst(8) = 32 bits
        let lit_val = match self.src {
            Src::Lit(val) => val,
            _ => 0,
        };
        
        let src_port = match self.src {
            Src::P(port) => port as u32,
            _ => 0,
        };
        
        let dst_port = match self.dst {
            Dst::P(port) => port as u32,
            _ => 0,
        };
        
        ((lit_val & 0xFF) << 24) |
        ((src_port & 0x3) << 22) |
        ((dst_port & 0x3) << 20) |
        ((self.op as u32 & 0xF) << 16) |
        ((self.src.to_code() as u32 & 0xFF) << 8) |
        (self.dst.to_code() as u32 & 0xFF)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_op_from_str() {
        assert_eq!(Op::from_str("MOV").unwrap(), Op::Mov);
        assert_eq!(Op::from_str("add").unwrap(), Op::Add);
        assert_eq!(Op::from_str("HLT").unwrap(), Op::Hlt);
        assert!(Op::from_str("INVALID").is_err());
    }

    #[test]
    fn test_src_from_str() {
        assert_eq!(Src::from_str("ACC").unwrap(), Src::Acc);
        assert_eq!(Src::from_str("42").unwrap(), Src::Lit(42));
        assert_eq!(Src::from_str("-5").unwrap(), Src::Lit(0xFFFFFFFB));
        assert_eq!(Src::from_str("P:UP").unwrap(), Src::P(PortTag::Up));
    }

    #[test]
    fn test_encode_instruction() {
        let nop = Inst {
            op: Op::Nop,
            src: Src::Nil,
            dst: Dst::Nil,
        };
        assert_eq!(nop.encode(), 0x00C0201);
        
        let mov_lit = Inst {
            op: Op::Mov,
            src: Src::Lit(42),
            dst: Dst::Acc,
        };
        assert_eq!(mov_lit.encode(), 0x2A010000);
    }
}