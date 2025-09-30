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
      asm += `NODE (${node.position.x},${node.position.y})\n`;
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
  
  console.log('=== Debug Execution Request ===');
  console.log('Inputs:', inputs);
  
  const asmContent = generateAsmContent(nodes);
  console.log('Generated ASM:\n', asmContent);
  
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
    success: false
  };
  
  try {
    // Write ASM file
    await writeFile(tempFile, asmContent);
    console.log('ASM file written to:', tempFile);
    
    // Step 1: Assemble with verbose output
    console.log('\n=== Step 1: Assembling ===');
    let assembleCommand = `RUST_LOG=debug cargo run --release -- assemble ${tempFile}`;
    
    if (inputs && inputs.length > 0) {
      assembleCommand += ` -i ${inputs.join(',')} -e ${inputs.join(',')}`;
    }
    
    try {
      const { stdout, stderr } = await execAsync(assembleCommand, {
        cwd: hostDir,
        timeout: 30000,
        maxBuffer: 1024 * 1024 * 10,
        shell: SHELL,
        env: { ...process.env, RUST_LOG: 'debug' }
      });
      
      results.assembleTrace = extractTrace(stdout + '\n' + stderr);
      console.log('Assemble completed successfully');
      
      // Read the generated args.json
      const argsPath = path.join(hostDir, 'args.json');
      try {
        results.argsJson = await readFile(argsPath, 'utf-8');
        console.log('Generated args.json:', results.argsJson);
      } catch (e) {
        console.error('Failed to read args.json:', e);
      }
      
    } catch (error) {
      results.assembleError = error.message;
      results.assembleTrace = extractTrace(error.stdout || '' + '\n' + (error.stderr || ''));
      console.error('Assemble failed:', error.message);
    }
    
    // Step 2: Run scarb execute with verbose output
    if (!results.assembleError) {
      console.log('\n=== Step 2: Running Scarb Execute ===');
      
      // Copy args.json to exec directory
      await execAsync(
        `cp ${path.join(hostDir, 'args.json')} ${path.join(execDir, 'args.json')}`,
        { shell: SHELL }
      );
      
      try {
        const { stdout, stderr } = await execAsync(
          'RUST_LOG=trace scarb execute --arguments-file args.json --print-program-output',
          {
            cwd: execDir,
            timeout: 30000,
            maxBuffer: 1024 * 1024 * 10,
            shell: SHELL,
            env: { ...process.env, RUST_LOG: 'trace' }
          }
        );
        
        results.scarbTrace = extractTrace(stdout + '\n' + stderr);
        console.log('Scarb execute completed');
        
      } catch (error) {
        results.scarbError = error.message;
        results.scarbTrace = extractTrace((error.stdout || '') + '\n' + (error.stderr || ''));
        console.error('Scarb execute failed:', error.message);
      }
    }
    
    // Step 3: Run prove with verbose output
    if (!results.assembleError) {
      console.log('\n=== Step 3: Running Prove ===');
      
      let proveCommand = `RUST_LOG=debug cargo run --release -- prove ${tempFile}`;
      if (inputs && inputs.length > 0) {
        proveCommand += ` -i ${inputs.join(',')} -e ${inputs.join(',')}`;
      }
      
      try {
        const { stdout, stderr } = await execAsync(proveCommand, {
          cwd: hostDir,
          timeout: 60000,
          maxBuffer: 1024 * 1024 * 10,
          shell: SHELL,
          env: { ...process.env, RUST_LOG: 'debug' }
        });
        
        results.proveTrace = extractTrace(stdout + '\n' + stderr);
        results.success = true;
        console.log('Prove completed successfully');
        
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
      argsJson: results.argsJson,
      asmContent: asmContent
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