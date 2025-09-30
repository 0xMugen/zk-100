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
        
        {/* Show debug traces if available */}
        {result.debug?.traces && (
          <details className="mt-4">
            <summary className="cursor-pointer text-gray-400 hover:text-white">
              Show execution traces
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