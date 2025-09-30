import React, { useState, useEffect } from 'react';
import { logger } from '../utils/logger';
import type { ExecutionLogs } from '../types/zk100';

interface LogViewerProps {
  executionLogs?: ExecutionLogs;
}

export const LogViewer: React.FC<LogViewerProps> = ({ executionLogs }) => {
  const [logs, setLogs] = useState(logger.getLogs());
  const [showLogs, setShowLogs] = useState(false);
  const [selectedTab, setSelectedTab] = useState<'console' | 'cairo' | 'prover' | 'rust'>('console');

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
            ) : (
              <div className="text-gray-600">No output available</div>
            )}
          </div>
        </div>
      )}
    </div>
  );
};