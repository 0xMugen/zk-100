mod assembler;
mod instruction;
// mod merkle;  // No longer needed - Cairo computes merkle roots
mod cairo_abi;

use anyhow::Result;
use clap::{Parser, Subcommand};
use std::fs;
use std::path::PathBuf;

#[derive(Parser, Debug)]
#[command(author, version, about = "ZK-100 Host - Assembly to Proof Pipeline")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand, Debug)]
enum Commands {
    /// Assemble a program from assembly to Cairo format
    Assemble {
        /// Input assembly file
        input: PathBuf,
        /// Output args.json file
        #[arg(short, long, default_value = "args.json")]
        output: PathBuf,
        /// Input values (comma-separated)
        #[arg(short = 'i', long)]
        inputs: Option<String>,
        /// Expected output values (comma-separated)
        #[arg(short = 'e', long)]
        expected: Option<String>,
    },
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    
    match cli.command {
        Commands::Assemble { input, output, inputs, expected } => {
            assemble_program(input, output, inputs, expected)?;
        }
    }
    
    Ok(())
}

fn assemble_program(
    input_path: PathBuf,
    output_path: PathBuf,
    inputs_str: Option<String>,
    expected_str: Option<String>,
) -> Result<()> {
    println!("Assembling program from: {}", input_path.display());
    
    // Read assembly file
    let assembly_code = fs::read_to_string(&input_path)?;
    
    // Parse assembly into programs for 2x2 grid
    let programs = assembler::parse_assembly(&assembly_code)?;
    
    // Encode programs to prog_words
    let prog_words = assembler::encode_programs(&programs)?;
    
    println!("Encoded prog_words:");
    for (i, word) in prog_words.iter().enumerate() {
        println!("  [{}] = {}", i, word);
    }
    
    // Parse inputs and expected values
    let inputs = parse_u32_array(&inputs_str.unwrap_or_default());
    let expected = parse_u32_array(&expected_str.unwrap_or_default());
    
    // Generate Cairo ABI format args (Cairo will compute merkle root)
    let args = cairo_abi::generate_args(&inputs, &expected, &prog_words)?;
    
    // Write to output file
    fs::write(&output_path, serde_json::to_string(&args)?)?;
    
    println!("Generated args file: {}", output_path.display());
    println!("  Inputs: {:?}", inputs);
    println!("  Expected: {:?}", expected);
    println!("  Programs: {} words", prog_words.len());
    
    Ok(())
}

fn parse_u32_array(s: &str) -> Vec<u32> {
    if s.is_empty() {
        return vec![];
    }
    s.split(',')
        .filter_map(|v| v.trim().parse::<u32>().ok())
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_u32_array() {
        assert_eq!(parse_u32_array(""), Vec::<u32>::new());
        assert_eq!(parse_u32_array("42"), vec![42u32]);
        assert_eq!(parse_u32_array("1,2,3"), vec![1u32, 2, 3]);
        assert_eq!(parse_u32_array("10, 20, 30"), vec![10u32, 20, 30]);
    }
}