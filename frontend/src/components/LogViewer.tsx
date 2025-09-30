import React, { useState, useEffect } from 'react';
import { logger } from '../utils/logger';
import type { ExecutionLogs, ExecutionDebug } from '../types/zk100';

interface LogViewerProps {
  executionLogs?: ExecutionLogs;
  executionDebug?: ExecutionDebug;
}

export const LogViewer: React.FC<LogViewerProps> = ({ executionLogs, executionDebug }) => {
  const [logs, setLogs] = useState(logger.getLogs());
  const [showLogs, setShowLogs] = useState(false);
  const [selectedTab, setSelectedTab] = useState<'console' | 'cairo' | 'prover' | 'rust' | 'debug'>('console');

  useEffect(() => {
    const updateLogs = (newLogs: any) => setLogs(newLogs);
    logger.subscribe(updateLogs);
    return () => logger.unsubscribe(updateLogs);
  }, []);

  const getLogColor = (level: string) => {
    switch (level) {
      case 'debug': return 'text-gray-500';
      case 'info': return 'text-blue-400';
      case 'warn': return 'text-yellow-400';
      case 'error': return 'text-red-400';
      default: return 'text-gray-300';
    }
  };

  return (
    <div className="fixed bottom-0 left-0 right-0 bg-zk-node border-t border-zk-border z-50">
      <div className="flex items-center justify-between px-4 py-2 border-b border-zk-border">
        <button
          onClick={() => setShowLogs(!showLogs)}
          className="text-sm text-gray-400 hover:text-white transition-colors"
        >
          {showLogs ? '▼' : '▲'} Debug Console ({logs.length} logs)
        </button>
        <button
          onClick={() => logger.clearLogs()}
          className="text-xs text-gray-500 hover:text-red-400 transition-colors"
        >
          Clear
        </button>
      </div>
      
      {showLogs && (
        <div className="h-64 overflow-hidden flex flex-col">
          {/* Tabs */}
          <div className="flex border-b border-zk-border">
            <button
              onClick={() => setSelectedTab('console')}
              className={`px-4 py-2 text-sm transition-colors ${
                selectedTab === 'console' ? 'bg-zk-bg text-zk-accent' : 'text-gray-400 hover:text-white'
              }`}
            >
              Console
            </button>
            {executionLogs && (
              <>
                <button
                  onClick={() => setSelectedTab('cairo')}
                  className={`px-4 py-2 text-sm transition-colors ${
                    selectedTab === 'cairo' ? 'bg-zk-bg text-zk-accent' : 'text-gray-400 hover:text-white'
                  }`}
                >
                  Cairo Output
                </button>
                <button
                  onClick={() => setSelectedTab('prover')}
                  className={`px-4 py-2 text-sm transition-colors ${
                    selectedTab === 'prover' ? 'bg-zk-bg text-zk-accent' : 'text-gray-400 hover:text-white'
                  }`}
                >
                  Prover Output
                </button>
                <button
                  onClick={() => setSelectedTab('rust')}
                  className={`px-4 py-2 text-sm transition-colors ${
                    selectedTab === 'rust' ? 'bg-zk-bg text-zk-accent' : 'text-gray-400 hover:text-white'
                  }`}
                >
                  Rust Host Output
                </button>
                <button
                  onClick={() => setSelectedTab('debug')}
                  className={`px-4 py-2 text-sm transition-colors ${
                    selectedTab === 'debug' ? 'bg-zk-bg text-zk-accent' : 'text-gray-400 hover:text-white'
                  }`}
                >
                  Debug Info
                </button>
              </>
            )}
          </div>
          
          {/* Content */}
          <div className="flex-1 overflow-y-auto bg-black p-4 font-mono text-xs">
            {selectedTab === 'console' ? (
              logs.map((log, index) => (
                <div key={index} className={`mb-1 ${getLogColor(log.level)}`}>
                  [{log.timestamp.toISOString()}] {log.level.toUpperCase()}: {log.message}
                  {log.data && (
                    <pre className="ml-4 text-gray-600">
                      {JSON.stringify(log.data, null, 2)}
                    </pre>
                  )}
                </div>
              ))
            ) : selectedTab === 'cairo' && executionLogs?.cairoOutput ? (
              <pre className="text-gray-300 whitespace-pre-wrap">
                {executionLogs.cairoOutput || 'No Cairo output'}
              </pre>
            ) : selectedTab === 'prover' && executionLogs?.proverOutput ? (
              <pre className="text-gray-300 whitespace-pre-wrap">
                {executionLogs.proverOutput || 'No prover output'}
              </pre>
            ) : selectedTab === 'rust' && executionLogs?.rustHostOutput ? (
              <pre className="text-gray-300 whitespace-pre-wrap">
                {executionLogs.rustHostOutput || 'No Rust host output'}
              </pre>
            ) : selectedTab === 'debug' && executionDebug ? (
              <div className="space-y-4 text-gray-300">
                {executionDebug.asmContent && (
                  <div>
                    <div className="text-zk-accent font-bold mb-1">Generated ASM Content:</div>
                    <pre className="bg-gray-900 p-2 rounded text-xs">
                      {executionDebug.asmContent}
                    </pre>
                  </div>
                )}
                {executionDebug.command && (
                  <div>
                    <div className="text-zk-accent font-bold mb-1">Command:</div>
                    <pre className="bg-gray-900 p-2 rounded text-xs">
                      {executionDebug.command}
                    </pre>
                  </div>
                )}
                {executionDebug.workingDir && (
                  <div>
                    <div className="text-gray-400">Working Directory:</div>
                    <div className="text-xs">{executionDebug.workingDir}</div>
                  </div>
                )}
                {executionDebug.shell && (
                  <div>
                    <div className="text-gray-400">Shell:</div>
                    <div className="text-xs">{executionDebug.shell}</div>
                  </div>
                )}
                {executionDebug.execError && (
                  <div>
                    <div className="text-red-400 font-bold mb-1">Execution Error:</div>
                    <pre className="bg-red-900 bg-opacity-20 p-2 rounded text-xs">
                      {JSON.stringify(executionDebug.execError, null, 2)}
                    </pre>
                  </div>
                )}
                {executionDebug.errorStack && (
                  <div>
                    <div className="text-red-400 font-bold mb-1">Error Stack:</div>
                    <pre className="bg-red-900 bg-opacity-20 p-2 rounded text-xs">
                      {executionDebug.errorStack}
                    </pre>
                  </div>
                )}
              </div>
            ) : (
              <div className="text-gray-600">No output available</div>
            )}
          </div>
        </div>
      )}
    </div>
  );
};