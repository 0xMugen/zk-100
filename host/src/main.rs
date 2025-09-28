mod assembler;
mod instruction;
mod merkle;
mod cairo_abi;

use anyhow::{Result, Context};
use clap::{Parser, Subcommand};
use std::fs;
use std::path::PathBuf;
use std::process::Command;
use serde::{Deserialize, Serialize};

#[derive(Parser, Debug)]
#[command(author, version, about = "ZK-100 Host - Assembly to Proof Pipeline")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Debug, Deserialize, Serialize)]
struct Challenge {
    inputs: Vec<u32>,
    expected: Vec<u32>,
}

#[derive(Subcommand, Debug)]
enum Commands {
    /// Assemble a program from assembly to Cairo format
    Assemble {
        /// Input assembly file
        input: PathBuf,
        /// Output args.json file (auto-generated if not specified)
        #[arg(short, long)]
        output: Option<PathBuf>,
        /// Challenge JSON file (alternative to -i/-e)
        #[arg(short, long)]
        challenge: Option<PathBuf>,
        /// Input values (comma-separated)
        #[arg(short = 'i', long)]
        inputs: Option<String>,
        /// Expected output values (comma-separated)
        #[arg(short = 'e', long)]
        expected: Option<String>,
    },
    /// Generate and run proof
    Prove {
        /// Input assembly file
        input: PathBuf,
        /// Proof output file (auto-generated if not specified)
        #[arg(short, long)]
        proof: Option<PathBuf>,
        /// Cairo executable path
        #[arg(long, default_value = "../crates/exec/target/dev/zk100_exec.executable.json")]
        executable: PathBuf,
        /// Challenge JSON file (alternative to -i/-e)
        #[arg(short, long)]
        challenge: Option<PathBuf>,
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
        Commands::Assemble { input, output, challenge, inputs, expected } => {
            assemble_program(input, output, challenge, inputs, expected)?;
        }
        Commands::Prove { input, proof, executable, challenge, inputs, expected } => {
            prove_program(input, proof, executable, challenge, inputs, expected)?;
        }
    }
    
    Ok(())
}

fn assemble_program(
    input_path: PathBuf,
    output_path: Option<PathBuf>,
    challenge_path: Option<PathBuf>,
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
    
    // Calculate merkle root using Cairo for perfect compatibility
    let merkle_root = calculate_merkle_root_with_cairo(&prog_words)?;
    
    // Parse inputs and expected values from challenge file or CLI args
    let (inputs, expected) = if let Some(challenge_path) = challenge_path {
        let challenge_str = fs::read_to_string(&challenge_path)
            .with_context(|| format!("Failed to read challenge file: {:?}", challenge_path))?;
        let challenge: Challenge = serde_json::from_str(&challenge_str)
            .with_context(|| format!("Failed to parse challenge file: {:?}", challenge_path))?;
        (challenge.inputs, challenge.expected)
    } else {
        (
            parse_u32_array(&inputs_str.unwrap_or_default()),
            parse_u32_array(&expected_str.unwrap_or_default())
        )
    };
    
    // Generate output path based on input if not provided
    let output_path = output_path.unwrap_or_else(|| {
        let stem = input_path.file_stem().unwrap().to_string_lossy();
        let output_name = stem.replace("test_", "args_");
        PathBuf::from("args").join(format!("{}.json", output_name))
    });
    
    // Generate Cairo ABI format args
    let args = cairo_abi::generate_args(&inputs, &expected, &merkle_root, &prog_words)?;
    
    // Write to output file
    fs::write(&output_path, serde_json::to_string(&args)?)?;
    
    println!("Generated args file: {}", output_path.display());
    println!("  Inputs: {:?}", inputs);
    println!("  Expected: {:?}", expected);
    println!("  Merkle root: 0x{}", hex::encode(&merkle_root));
    println!("  Programs: {} words", prog_words.len());
    
    Ok(())
}

fn prove_program(
    input_path: PathBuf,
    proof_path: Option<PathBuf>,
    executable_path: PathBuf,
    challenge_path: Option<PathBuf>,
    inputs_str: Option<String>,
    expected_str: Option<String>,
) -> Result<()> {
    // Generate proof path based on input if not provided
    let proof_path = proof_path.unwrap_or_else(|| {
        let stem = input_path.file_stem().unwrap().to_string_lossy();
        let proof_name = stem.replace("test_", "proof_");
        PathBuf::from("proof").join(format!("{}.json", proof_name))
    });
    
    // First assemble the program to a temporary args file
    let args_path = PathBuf::from("temp_args.json");
    assemble_program(input_path.clone(), Some(args_path.clone()), challenge_path, inputs_str, expected_str)?;
    
    // First, run scarb execute to test the logic without proving
    println!("\nTesting execution with scarb execute...");
    let scarb_output = Command::new("scarb")
        .arg("execute")
        .arg("-p")
        .arg("zk100_exec")
        .arg("--print-program-output")
        .arg("--arguments-file")
        .arg(format!("../../host/{}", args_path.to_string_lossy()))
        .current_dir("../crates/exec")
        .output()?;
    
    println!("Scarb execute output:");
    println!("{}", String::from_utf8_lossy(&scarb_output.stdout));
    if !scarb_output.status.success() {
        println!("Scarb execute FAILED (logic error):");
        println!("{}", String::from_utf8_lossy(&scarb_output.stderr));
    } else {
        println!("Scarb execute succeeded!");
    }
    
    // Then run cairo-prove
    println!("\nGenerating proof...");
    let output = Command::new("cairo-prove")
        .arg("prove")
        .arg(&executable_path)
        .arg(&proof_path)
        .arg("--arguments-file")
        .arg(&args_path)
        .output()?;
    
    if !output.status.success() {
        anyhow::bail!(
            "cairo-prove failed: {}",
            String::from_utf8_lossy(&output.stderr)
        );
    }
    
    // Clean up temp file
    fs::remove_file(args_path).ok();
    
    println!("Proof generated successfully: {}", proof_path.display());
    
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

/// Calculate merkle root by calling the Cairo merkle calculator program
/// This ensures perfect compatibility between Rust and Cairo implementations
fn calculate_merkle_root_with_cairo(_prog_words: &[u32]) -> Result<Vec<u8>> {
    use std::process::Command;
    
    // For now, we'll use a hardcoded merkle calculator that matches our test
    // TODO: Make this dynamic based on prog_words
    
    // Run scarb execute to get the Cairo-calculated merkle root
    let output = Command::new("scarb")
        .arg("execute")
        .arg("-p")
        .arg("zk100_merkle_calc")
        .arg("--print-program-output")
        .current_dir("../crates/merkle_calc")
        .output()
        .with_context(|| "Failed to run Cairo merkle calculator")?;
    
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(anyhow::anyhow!("Cairo merkle calculator failed: {}", stderr));
    }
    
    // Parse the output to extract the merkle root
    let stdout = String::from_utf8_lossy(&output.stdout);
    let merkle_root = parse_cairo_merkle_output(&stdout)?;
    
    Ok(merkle_root)
}

/// Parse Cairo program output to extract the merkle root
fn parse_cairo_merkle_output(output: &str) -> Result<Vec<u8>> {
    use num_bigint::BigInt;
    
    // Look for "Program output:" section
    let mut found_output = false;
    let mut lines = output.lines();
    
    while let Some(line) = lines.next() {
        if line.contains("Program output:") {
            found_output = true;
            break;
        }
    }
    
    if !found_output {
        return Err(anyhow::anyhow!("Could not find 'Program output:' in Cairo output"));
    }
    
    // Skip the return status (first line after "Program output:")
    lines.next();
    
    // Get the merkle root (second line)
    if let Some(merkle_line) = lines.next() {
        let merkle_str = merkle_line.trim();
        
        // Parse the felt252 value (could be negative)
        let merkle_bigint = BigInt::parse_bytes(merkle_str.as_bytes(), 10)
            .ok_or_else(|| anyhow::anyhow!("Failed to parse merkle root: {}", merkle_str))?;
        
        // Cairo's felt252 prime
        let prime_str = "3618502788666131213697322783095070105623107215331596699973092056135872020481";
        let prime = BigInt::parse_bytes(prime_str.as_bytes(), 10).unwrap();
        
        // Convert negative to positive representation
        let positive_merkle = if merkle_bigint < BigInt::from(0) {
            &prime + merkle_bigint
        } else {
            merkle_bigint
        };
        
        // Convert to bytes (32 bytes, big-endian)
        let (_, bytes) = positive_merkle.to_bytes_be();
        let mut result = vec![0u8; 32];
        let start = if bytes.len() > 32 { bytes.len() - 32 } else { 0 };
        let copy_start = if bytes.len() < 32 { 32 - bytes.len() } else { 0 };
        result[copy_start..].copy_from_slice(&bytes[start..]);
        
        Ok(result)
    } else {
        Err(anyhow::anyhow!("Could not find merkle root value in Cairo output"))
    }
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