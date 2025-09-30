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
      bg-zk-node border rounded p-4 mt-4
      ${result.success ? 'border-zk-accent' : 'border-zk-error'}
    `}>
      <div className="flex justify-between items-start">
        <div>
          <h3 className={`font-bold mb-2 ${result.success ? 'text-zk-accent' : 'text-zk-error'}`}>
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
            <div className="text-zk-error text-sm font-mono">
              {result.error}
            </div>
          )}
        </div>
        
        {result.executionTime !== undefined && (
          <div className="text-gray-400 text-sm">
            {result.executionTime}ms
          </div>
        )}
      </div>
    </div>
  );
};