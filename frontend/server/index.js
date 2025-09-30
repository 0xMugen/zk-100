import express from 'express';
import cors from 'cors';
import { writeFile, unlink, readFile } from 'fs/promises';
import { exec } from 'child_process';
import { promisify } from 'util';
import path from 'path';
import { tmpdir } from 'os';
import { fileURLToPath } from 'url';
import { existsSync } from 'fs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const execAsync = promisify(exec);
const app = express();
const PORT = 3001;

app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Find available shell
function findShell() {
  const shells = [
    process.env.SHELL,
    '/run/current-system/sw/bin/bash',
    '/usr/bin/bash',
    '/bin/bash',
    '/bin/sh'
  ].filter(Boolean);

  for (const shell of shells) {
    if (existsSync(shell)) {
      console.log(`Using shell: ${shell}`);
      return shell;
    }
  }
  
  console.log('Using default shell: sh');
  return 'sh';
}

const SHELL = findShell();

function generateAsmContent(nodes) {
  let asm = '';
  
  for (const node of nodes) {
    const code = node.code.trim();
    if (code) {
      // Swap x,y to convert from frontend (col,row) to Cairo VM (row,col)
      asm += `NODE (${node.position.y},${node.position.x})\n`;
      const lines = code.split('\n');
      for (const line of lines) {
        let trimmed = line.trim();
        if (trimmed && !trimmed.startsWith('#')) {
          // Convert standalone port names to P: format (but not IN/OUT)
          trimmed = trimmed.replace(/\b(UP|DOWN|LEFT|RIGHT)\b/g, (match) => {
            return `P:${match}`;
          });
          // Fix MOV syntax to use comma
          trimmed = trimmed.replace(/MOV\s+(\S+)\s+(\S+)/, 'MOV $1, $2');
          asm += `${trimmed}\n`;
        }
      }
      // Add HLT if not present
      if (!code.includes('HLT')) {
        asm += `HLT\n`;
      }
      asm += '\n';
    }
  }
  
  return asm;
}

// Parse PublicOutputs from scarb execute output
function parsePublicOutputs(output) {
  const result = {
    challenge_commit: null,
    program_commit: null,
    output_commit: null,
    cycles: 0,
    msgs: 0,
    nodes_used: 0,
    solved: false
  };
  
  const lines = output.split('\n');
  const programOutputIndex = lines.findIndex(line => line.includes('Program output:'));
  
  if (programOutputIndex !== -1 && programOutputIndex + 8 < lines.length) {
    // The output format is:
    // [0] array length (should be 7)
    // [1] challenge_commit
    // [2] program_commit  
    // [3] output_commit
    // [4] cycles
    // [5] msgs
    // [6] nodes_used
    // [7] solved (1 or 0)
    
    try {
      result.challenge_commit = lines[programOutputIndex + 2].trim();
      result.program_commit = lines[programOutputIndex + 3].trim();
      result.output_commit = lines[programOutputIndex + 4].trim();
      result.cycles = parseInt(lines[programOutputIndex + 5].trim()) || 0;
      result.msgs = parseInt(lines[programOutputIndex + 6].trim()) || 0;
      result.nodes_used = parseInt(lines[programOutputIndex + 7].trim()) || 0;
      result.solved = lines[programOutputIndex + 8].trim() === '1';
    } catch (e) {
      console.error('Failed to parse PublicOutputs:', e);
    }
  }
  
  return result;
}

// Extract trace information from output
function extractTrace(output) {
  const trace = {
    cycles: [],
    instructions: [],
    portMessages: [],
    finalState: {},
    errors: []
  };
  
  const lines = output.split('\n');
  
  for (const line of lines) {
    // Look for cycle information
    if (line.includes('Cycle')) {
      const cycleMatch = line.match(/Cycle\s+(\d+)/);
      if (cycleMatch) {
        trace.cycles.push(parseInt(cycleMatch[1]));
      }
    }
    
    // Look for instruction traces
    if (line.includes('Executing:') || line.includes('PC:')) {
      trace.instructions.push(line);
    }
    
    // Look for port communication
    if (line.includes('Port') || line.includes('->')) {
      trace.portMessages.push(line);
    }
    
    // Look for final values
    if (line.includes('Output:')) {
      const outputMatch = line.match(/Output:\s*(.+)/);
      if (outputMatch) {
        trace.finalState.outputs = outputMatch[1];
      }
    }
    
    // Look for errors or panics
    if (line.includes('Error') || line.includes('panic') || line.includes('assert')) {
      trace.errors.push(line);
    }
  }
  
  return trace;
}

app.post('/api/debug', async (req, res) => {
  const { nodes, inputs } = req.body;
  
  const asmContent = generateAsmContent(nodes);
  
  if (!asmContent.trim()) {
    return res.json({
      success: false,
      error: 'No code to execute'
    });
  }

  const tempFile = path.join(tmpdir(), `zk100_debug_${Date.now()}.asm`);
  const hostDir = path.join(__dirname, '../../host');
  const execDir = path.join(__dirname, '../../crates/exec');
  
  let results = {
    assembleTrace: null,
    scarbTrace: null,
    proveTrace: null,
    assembleError: null,
    scarbError: null,
    proveError: null,
    argsJson: null,
    publicOutputs: null,
    scarbOutput: null,
    proveOutput: null,
    success: false
  };
  
  try {
    // Write ASM file
    await writeFile(tempFile, asmContent);
    
    // Step 1: Assemble
    let assembleCommand = `cargo run --release -- assemble ${tempFile}`;
    
    if (inputs && inputs.length > 0) {
      // For now, use the same values for expected as inputs (game wants input=output)
      assembleCommand += ` -i ${inputs.join(',')} -e ${inputs.join(',')}`;
    }
    
    try {
      const { stdout, stderr } = await execAsync(assembleCommand, {
        cwd: hostDir,
        timeout: 30000,
        maxBuffer: 1024 * 1024 * 10,
        shell: SHELL,
        env: { ...process.env }
      });
      
      results.assembleTrace = extractTrace(stdout + '\n' + stderr);
      
      // Read the generated args.json
      const argsPath = path.join(hostDir, 'args.json');
      try {
        results.argsJson = await readFile(argsPath, 'utf-8');
      } catch (e) {
        console.error('Failed to read args.json:', e);
      }
      
    } catch (error) {
      results.assembleError = error.message;
      results.assembleTrace = extractTrace(error.stdout || '' + '\n' + (error.stderr || ''));
      console.error('Assemble failed:', error.message);
    }
    
    // Step 2: Run scarb execute
    if (!results.assembleError) {
      
      // Copy args.json to exec directory
      await execAsync(
        `cp ${path.join(hostDir, 'args.json')} ${path.join(execDir, 'args.json')}`,
        { shell: SHELL }
      );
      
      try {
        // Change to exec directory and run scarb execute
        const scarbCommand = `cd ${execDir} && scarb execute --arguments-file args.json --print-program-output`;
        // Execute scarb
        
        const { stdout, stderr } = await execAsync(scarbCommand, {
          timeout: 30000,
          maxBuffer: 1024 * 1024 * 10,
          shell: SHELL,
          env: { ...process.env }
        });
        
        results.scarbTrace = extractTrace(stdout + '\n' + stderr);
        // Store the raw output for debugging
        results.scarbOutput = stdout;
        // Parse the PublicOutputs from scarb
        results.publicOutputs = parsePublicOutputs(stdout);
        
      } catch (error) {
        results.scarbError = error.message + '\n\nStdout:\n' + error.stdout + '\n\nStderr:\n' + error.stderr;
        results.scarbTrace = extractTrace((error.stdout || '') + '\n' + (error.stderr || ''));
        console.error('Scarb execute failed:', error.message);
      }
    }
    
    // Step 3: Run prove
    if (!results.assembleError) {
      
      // Run cairo-prove from the same directory as scarb execute, with the same args.json
      const executable = 'target/dev/zk100_exec.executable.json';
      const proofPath = 'proof.json';
      
      // Change to exec directory and run cairo-prove, just like scarb execute
      let proveCommand = `cd ${execDir} && cairo-prove prove ${executable} ${proofPath} --arguments-file args.json`;
      // Execute cairo-prove
      
      try {
        const { stdout, stderr } = await execAsync(proveCommand, {
          timeout: 60000,
          maxBuffer: 1024 * 1024 * 10,
          shell: SHELL,
          env: { ...process.env }
        });
        
        results.proveTrace = extractTrace(stdout + '\n' + stderr);
        // Cairo-prove logs to stderr, so combine both for the output
        results.proveOutput = (stdout + '\n' + stderr).trim();
        results.success = true;
        
      } catch (error) {
        results.proveError = error.message;
        results.proveTrace = extractTrace((error.stdout || '') + '\n' + (error.stderr || ''));
        console.error('Prove failed:', error.message);
      }
    }
    
    // Send results
    res.json({
      success: results.success,
      traces: {
        assemble: results.assembleTrace,
        scarb: results.scarbTrace,
        prove: results.proveTrace
      },
      errors: {
        assemble: results.assembleError,
        scarb: results.scarbError,
        prove: results.proveError
      },
      publicOutputs: results.publicOutputs || {},
      argsJson: results.argsJson,
      asmContent: asmContent,
      scarbOutput: results.scarbOutput,
      proveOutput: results.proveOutput
    });
    
  } catch (error) {
    console.error('General error:', error);
    res.json({
      success: false,
      error: error.message,
      traces: results
    });
  } finally {
    // Clean up temp file
    try {
      await unlink(tempFile);
    } catch (e) {
      console.log('Failed to clean up temp file:', e.message);
    }
  }
});

// Regular execution endpoint (simpler, without debug info)
app.post('/api/execute', async (req, res) => {
  const { nodes, inputs } = req.body;
  
  const asmContent = generateAsmContent(nodes);
  
  if (!asmContent.trim()) {
    return res.json({
      success: false,
      error: 'No code to execute'
    });
  }

  const tempFile = path.join(tmpdir(), `zk100_${Date.now()}.asm`);
  const hostDir = path.join(__dirname, '../../host');
  const execDir = path.join(__dirname, '../../crates/exec');
  
  try {
    await writeFile(tempFile, asmContent);
    
    // Assemble
    let assembleCommand = `cargo run --release -- assemble ${tempFile}`;
    if (inputs && inputs.length > 0) {
      assembleCommand += ` -i ${inputs.join(',')} -e ${inputs.join(',')}`;
    }
    
    await execAsync(assembleCommand, {
      cwd: hostDir,
      shell: SHELL
    });
    
    // Copy args.json
    await execAsync(
      `cp ${path.join(hostDir, 'args.json')} ${path.join(execDir, 'args.json')}`,
      { shell: SHELL }
    );
    
    // Execute
    const { stdout: scarbOut } = await execAsync(
      'scarb execute --arguments-file args.json --print-program-output',
      {
        cwd: execDir,
        shell: SHELL
      }
    );
    
    // Extract output
    const output = [];
    const lines = scarbOut.split('\n');
    for (const line of lines) {
      if (line.includes('Output:')) {
        const match = line.match(/Output:\s*(-?\d+)/);
        if (match) {
          output.push(parseInt(match[1]));
        }
      }
    }
    
    res.json({
      success: true,
      output,
      logs: {
        cairoOutput: scarbOut
      }
    });
    
  } catch (error) {
    res.json({
      success: false,
      error: error.message
    });
  } finally {
    try {
      await unlink(tempFile);
    } catch (e) {}
  }
});

app.listen(PORT, () => {
  console.log(`ZK-100 debug server running on http://localhost:${PORT}`);
  console.log(`Using shell: ${SHELL}`);
  console.log(`Host directory: ${path.join(__dirname, '../../host')}`);
  console.log('Debug endpoint: POST /api/debug');
  console.log('Execute endpoint: POST /api/execute');
});