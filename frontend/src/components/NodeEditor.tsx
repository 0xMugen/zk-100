import React, { useState, useEffect } from 'react';
import { validateCode } from '../utils/syntaxValidator';
import { logger } from '../utils/logger';
import type { Node, CodeLine } from '../types/zk100';

interface NodeEditorProps {
  node: Node;
  onCodeChange: (nodeId: string, code: string) => void;
}

export const NodeEditor: React.FC<NodeEditorProps> = ({ node, onCodeChange }) => {
  const [code, setCode] = useState(node.code);
  const [lines, setLines] = useState<CodeLine[]>([]);
  
  useEffect(() => {
    const validatedLines = validateCode(code, node.position);
    setLines(validatedLines);
    
    const errors = validatedLines.filter(line => line.error).map(line => line.error);
    logger.logValidation(node.id, errors);
  }, [code, node.position, node.id]);

  const handleChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    const newCode = e.target.value;
    setCode(newCode);
    onCodeChange(node.id, newCode);
  };

  const hasErrors = lines.some(line => line.error);
  
  const getLineError = (lineIndex: number): string | undefined => {
    return lines[lineIndex]?.error;
  };

  const renderLineNumbers = () => {
    const lineCount = code.split('\n').length;
    return Array.from({ length: lineCount }, (_, i) => (
      <div key={i} className="text-gray-500 text-sm pr-2">
        {i + 1}
      </div>
    ));
  };

  const renderErrorOverlay = () => {
    const lineHeight = 20; // approximate line height in pixels
    return code.split('\n').map((_, index) => {
      const error = getLineError(index);
      if (!error) return null;
      
      return (
        <div
          key={index}
          className="absolute left-0 right-0 pointer-events-none"
          style={{
            top: `${index * lineHeight}px`,
            height: `${lineHeight}px`,
          }}
        >
          <div className="w-full h-0.5 bg-zk-error mt-4" />
        </div>
      );
    });
  };

  return (
    <div className="bg-zk-node border border-zk-border rounded p-4 h-full">
      <div className="flex justify-between items-center mb-2">
        <span className="text-sm text-gray-400">
          Node ({node.position.y},{node.position.x})
          {node.position.x === 0 && node.position.y === 0 && ' - IN'}
          {node.position.x === 1 && node.position.y === 1 && ' - OUT'}
        </span>
        {hasErrors && <span className="text-zk-error text-sm">Errors</span>}
      </div>
      
      <div className="relative flex bg-black rounded overflow-hidden">
        <div className="flex flex-col py-2 px-2 bg-gray-900">
          {renderLineNumbers()}
        </div>
        
        <div className="relative flex-1">
          <textarea
            value={code}
            onChange={handleChange}
            className={`
              w-full h-48 bg-transparent text-gray-100 
              font-mono text-sm p-2 resize-none outline-none
              ${hasErrors ? 'text-red-100' : ''}
            `}
            spellCheck={false}
            placeholder="Enter ZK-100 assembly..."
          />
          <div className="absolute inset-0 pointer-events-none">
            {renderErrorOverlay()}
          </div>
        </div>
      </div>
      
      {/* Error messages */}
      {hasErrors && (
        <div className="mt-2 text-xs text-zk-error">
          {lines
            .filter(line => line.error)
            .map((line, i) => (
              <div key={i}>{line.error}</div>
            ))[0]}
        </div>
      )}
    </div>
  );
};