import React from 'react';
import type { ExecutionResult } from '../types/zk100';

interface ResultDisplayProps {
  result: ExecutionResult | null;
  isExecuting: boolean;
}

export const ResultDisplay: React.FC<ResultDisplayProps> = ({ result, isExecuting }) => {
  if (isExecuting) {
    return (
      <div className="bg-zk-node border border-zk-border rounded p-4 mt-4">
        <div className="flex items-center gap-2">
          <div className="animate-spin h-4 w-4 border-2 border-zk-accent border-t-transparent rounded-full" />
          <span className="text-gray-400">Executing...</span>
        </div>
      </div>
    );
  }

  if (!result) {
    return null;
  }

  return (
    <div className={`
      bg-zk-node border rounded p-4 mt-4 max-h-96 overflow-y-auto
      ${result.success ? 'border-zk-accent' : 'border-zk-error'}
    `}>
      <div className="flex flex-col gap-2">
        <h3 className={`font-bold ${result.success ? 'text-zk-accent' : 'text-zk-error'}`}>
          {result.success ? 'Execution Successful' : 'Execution Failed'}
        </h3>
        
        {result.output && result.output.length > 0 && (
          <div className="mb-2">
            <span className="text-gray-400">Output: </span>
            <span className="text-white font-mono">
              [{result.output.join(', ')}]
            </span>
          </div>
        )}
        
        {result.error && (
          <div className="text-gray-300 text-sm font-mono whitespace-pre-wrap">
            {result.error}
          </div>
        )}
        
        {/* Show PublicOutputs if available */}
        {result.debug?.publicOutputs && (
          <div className="mt-4">
            <h4 className="text-gray-400 mb-2">Proven Execution Results:</h4>
            <div className="bg-black/50 rounded p-3 text-sm">
              <div className="grid grid-cols-2 gap-2 text-gray-300">
                <div>Cycles: <span className="text-white">{result.debug.publicOutputs.cycles}</span></div>
                <div>Messages: <span className="text-white">{result.debug.publicOutputs.msgs}</span></div>
                <div>Nodes Used: <span className="text-white">{result.debug.publicOutputs.nodes_used}</span></div>
                <div>Solved: <span className={result.debug.publicOutputs.solved ? "text-green-500" : "text-red-500"}>
                  {result.debug.publicOutputs.solved ? "✓ Yes" : "✗ No"}
                </span></div>
              </div>
              {result.success && (
                <div className="mt-2 text-xs text-green-400">
                  ✓ These results have been cryptographically proven
                </div>
              )}
              {result.debug.publicOutputs.output_commit && (
                <div className="mt-2 text-xs text-gray-400">
                  Output Commit: {result.debug.publicOutputs.output_commit}
                </div>
              )}
            </div>
          </div>
        )}

        {/* Show Scarb Output */}
        {result.debug?.scarbOutput && (
          <details className="mt-4">
            <summary className="cursor-pointer text-gray-400 hover:text-white mb-2">
              Cairo Execution Output
            </summary>
            <pre className="bg-black/50 rounded p-3 text-xs text-gray-300 overflow-x-auto max-h-40 mt-2">
              {result.debug.scarbOutput}
            </pre>
          </details>
        )}

        {/* Show Prove Output if available */}
        {result.debug?.proveOutput && (
          <details className="mt-4">
            <summary className="cursor-pointer text-gray-400 hover:text-white mb-2">
              Proof Generation Output
            </summary>
            <pre className="bg-black/50 rounded p-3 text-xs text-gray-300 overflow-x-auto max-h-40 mt-2">
              {result.debug.proveOutput}
            </pre>
          </details>
        )}

        {/* Show debug traces if available */}
        {result.debug?.traces && (
          <details className="mt-4">
            <summary className="cursor-pointer text-gray-400 hover:text-white text-sm">
              Show detailed execution traces
            </summary>
            <pre className="mt-2 text-xs text-gray-500 overflow-x-auto">
              {JSON.stringify(result.debug.traces, null, 2)}
            </pre>
          </details>
        )}
        
        {result.executionTime !== undefined && (
          <div className="text-gray-400 text-xs">
            Executed in {result.executionTime}ms
          </div>
        )}
      </div>
    </div>
  );
};