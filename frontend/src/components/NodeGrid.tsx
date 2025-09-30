import React from 'react';
import { NodeEditor } from './NodeEditor';
import type { Node } from '../types/zk100';

interface NodeGridProps {
  nodes: Node[];
  onCodeChange: (nodeId: string, code: string) => void;
}

export const NodeGrid: React.FC<NodeGridProps> = ({ nodes, onCodeChange }) => {
  const getConnectionStyle = (from: string, to: string) => {
    const connections: Record<string, string> = {
      '0,0-0,1': 'absolute top-1/2 -right-px w-6 h-px bg-zk-accent',
      '0,1-0,0': 'absolute top-1/2 -left-px w-6 h-px bg-zk-accent',
      '0,0-1,0': 'absolute -bottom-px left-1/2 w-px h-6 bg-zk-accent',
      '1,0-0,0': 'absolute -top-px left-1/2 w-px h-6 bg-zk-accent',
      '0,1-1,1': 'absolute -bottom-px left-1/2 w-px h-6 bg-zk-accent',
      '1,1-0,1': 'absolute -top-px left-1/2 w-px h-6 bg-zk-accent',
      '1,0-1,1': 'absolute top-1/2 -right-px w-6 h-px bg-zk-accent',
      '1,1-1,0': 'absolute top-1/2 -left-px w-6 h-px bg-zk-accent',
    };
    return connections[`${from}-${to}`] || '';
  };

  return (
    <div className="relative max-w-4xl mx-auto">
      <div className="grid grid-cols-2 gap-6">
        {nodes.map((node) => (
          <div key={node.id} className="relative">
            <NodeEditor node={node} onCodeChange={onCodeChange} />
            
            {/* Port indicators */}
            <div className="absolute -top-2 left-1/2 transform -translate-x-1/2">
              <div className="text-xs text-gray-400">UP</div>
            </div>
            <div className="absolute -bottom-2 left-1/2 transform -translate-x-1/2">
              <div className="text-xs text-gray-400">DOWN</div>
            </div>
            <div className="absolute top-1/2 -left-2 transform -translate-y-1/2">
              <div className="text-xs text-gray-400">LEFT</div>
            </div>
            <div className="absolute top-1/2 -right-2 transform -translate-y-1/2">
              <div className="text-xs text-gray-400">RIGHT</div>
            </div>
            
            {/* Connections - using VM coordinate system (row,col) */}
            {node.position.x === 0 && node.position.y === 0 && (
              <>
                <div className={getConnectionStyle('0,0', '0,1')} />
                <div className={getConnectionStyle('0,0', '1,0')} />
              </>
            )}
            {node.position.x === 1 && node.position.y === 0 && (
              <>
                <div className={getConnectionStyle('0,1', '0,0')} />
                <div className={getConnectionStyle('0,1', '1,1')} />
              </>
            )}
            {node.position.x === 0 && node.position.y === 1 && (
              <>
                <div className={getConnectionStyle('1,0', '0,0')} />
                <div className={getConnectionStyle('1,0', '1,1')} />
              </>
            )}
            {node.position.x === 1 && node.position.y === 1 && (
              <>
                <div className={getConnectionStyle('1,1', '1,0')} />
                <div className={getConnectionStyle('1,1', '0,1')} />
              </>
            )}
          </div>
        ))}
      </div>
    </div>
  );
};