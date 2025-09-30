import { useState } from 'react';
import { NodeGrid } from './components/NodeGrid';
import { ResultDisplay } from './components/ResultDisplay';
import { executeProgram } from './utils/api';
import type { Node, ExecutionResult } from './types/zk100';

function App() {
  const [nodes, setNodes] = useState<Node[]>([
    { id: '0,0', position: { x: 0, y: 0 }, code: '', lines: [], hasError: false },
    { id: '1,0', position: { x: 1, y: 0 }, code: '', lines: [], hasError: false },
    { id: '0,1', position: { x: 0, y: 1 }, code: '', lines: [], hasError: false },
    { id: '1,1', position: { x: 1, y: 1 }, code: '', lines: [], hasError: false },
  ]);

  const [result, setResult] = useState<ExecutionResult | null>(null);
  const [isExecuting, setIsExecuting] = useState(false);

  const handleCodeChange = (nodeId: string, code: string) => {
    setNodes(prev => prev.map(node => 
      node.id === nodeId 
        ? { ...node, code } 
        : node
    ));
  };

  const handleExecute = async () => {
    setIsExecuting(true);
    setResult(null);
    
    try {
      const executionResult = await executeProgram(nodes);
      setResult(executionResult);
    } catch (error) {
      setResult({
        success: false,
        error: `Unexpected error: ${error instanceof Error ? error.message : 'Unknown error'}`,
      });
    } finally {
      setIsExecuting(false);
    }
  };

  const hasAnyCode = nodes.some(node => node.code.trim() !== '');

  return (
    <div className="min-h-screen bg-zk-bg">
      <div className="container mx-auto p-8">
        <header className="text-center mb-8">
          <h1 className="text-4xl font-bold text-zk-accent mb-2">ZK-100 Puzzle VM</h1>
          <p className="text-gray-400">Write assembly code for each node. IN at (0,0), OUT at (1,1)</p>
        </header>

        <NodeGrid nodes={nodes} onCodeChange={handleCodeChange} />

        <div className="flex justify-center mt-8">
          <button
            onClick={handleExecute}
            disabled={!hasAnyCode || isExecuting}
            className={`
              px-8 py-3 rounded font-bold transition-all
              ${hasAnyCode && !isExecuting
                ? 'bg-zk-accent text-black hover:bg-green-400' 
                : 'bg-gray-700 text-gray-500 cursor-not-allowed'
              }
            `}
          >
            {isExecuting ? 'Executing...' : 'Execute Program'}
          </button>
        </div>

        <ResultDisplay result={result} isExecuting={isExecuting} />
      </div>
    </div>
  );
}

export default App;