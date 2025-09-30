import React, { useState } from 'react';
import { instructions, specialRegisters, ports } from '../data/instructions';

interface DocsPanelProps {
  onToggle?: (isOpen: boolean) => void;
}

export const DocsPanel: React.FC<DocsPanelProps> = ({ onToggle }) => {
  const [isOpen, setIsOpen] = useState(true);
  const [activeTab, setActiveTab] = useState<'instructions' | 'registers' | 'ports'>('instructions');
  
  const handleToggle = () => {
    const newState = !isOpen;
    setIsOpen(newState);
    onToggle?.(newState);
  };
  
  const categoryColors = {
    data: 'text-blue-400',
    arithmetic: 'text-green-400',
    control: 'text-yellow-400',
    special: 'text-gray-400',
  };
  
  return (
    <div className={`fixed right-0 top-0 h-screen bg-zk-node border-l border-zk-border transition-all z-40 ${isOpen ? 'w-96' : 'w-12'}`}>
      {/* Toggle button */}
      <button
        onClick={handleToggle}
        className="absolute -left-8 top-4 bg-zk-node border border-zk-border rounded-l px-2 py-2 text-gray-400 hover:text-white z-50"
      >
        {isOpen ? '→' : '←'}
      </button>
      
      {isOpen && (
        <div className="h-full flex flex-col">
          {/* Header */}
          <div className="p-4 border-b border-zk-border">
            <h2 className="text-xl font-bold text-zk-accent">ZK-100 Reference</h2>
          </div>
          
          {/* Tabs */}
          <div className="flex border-b border-zk-border">
            <button
              onClick={() => setActiveTab('instructions')}
              className={`flex-1 px-4 py-2 text-sm transition-colors ${
                activeTab === 'instructions' ? 'bg-zk-bg text-zk-accent' : 'text-gray-400 hover:text-white'
              }`}
            >
              Instructions
            </button>
            <button
              onClick={() => setActiveTab('registers')}
              className={`flex-1 px-4 py-2 text-sm transition-colors ${
                activeTab === 'registers' ? 'bg-zk-bg text-zk-accent' : 'text-gray-400 hover:text-white'
              }`}
            >
              Registers
            </button>
            <button
              onClick={() => setActiveTab('ports')}
              className={`flex-1 px-4 py-2 text-sm transition-colors ${
                activeTab === 'ports' ? 'bg-zk-bg text-zk-accent' : 'text-gray-400 hover:text-white'
              }`}
            >
              Ports
            </button>
          </div>
          
          {/* Content */}
          <div className="flex-1 overflow-y-auto p-4 space-y-4">
            {activeTab === 'instructions' && (
              <>
                {['data', 'arithmetic', 'control', 'special'].map((category) => (
                  <div key={category}>
                    <h3 className="text-sm font-bold text-gray-500 uppercase mb-2">
                      {category} Operations
                    </h3>
                    {instructions
                      .filter(inst => inst.category === category)
                      .map(inst => (
                        <div key={inst.name} className="mb-4 bg-black rounded p-3">
                          <div className={`font-bold ${categoryColors[inst.category as keyof typeof categoryColors]}`}>
                            {inst.name}
                          </div>
                          <div className="text-sm text-gray-300 font-mono mt-1">
                            {inst.syntax}
                          </div>
                          <div className="text-sm text-gray-400 mt-1">
                            {inst.description}
                          </div>
                          <div className="mt-2 space-y-1">
                            {inst.examples.map((ex, i) => (
                              <div key={i} className="text-xs font-mono text-gray-500">
                                {ex}
                              </div>
                            ))}
                          </div>
                        </div>
                      ))}
                  </div>
                ))}
              </>
            )}
            
            {activeTab === 'registers' && (
              <div className="space-y-4">
                {specialRegisters.map(reg => (
                  <div key={reg.name} className="bg-black rounded p-3">
                    <div className="font-bold text-purple-400">{reg.name}</div>
                    <div className="text-sm text-gray-300 mt-1">{reg.description}</div>
                    <div className="text-sm text-gray-500 mt-1">{reg.usage}</div>
                  </div>
                ))}
              </div>
            )}
            
            {activeTab === 'ports' && (
              <div className="space-y-4">
                <div className="text-sm text-gray-400 mb-4">
                  Ports allow communication between nodes. Reading from a port blocks until data is available.
                </div>
                {ports.map(port => (
                  <div key={port.name} className="bg-black rounded p-3">
                    <div className="font-bold text-orange-400">{port.name}</div>
                    <div className="text-sm text-gray-300 mt-1">{port.description}</div>
                    <div className="mt-2 space-y-1">
                      {Object.entries(port.connections).map(([node, conn]) => (
                        <div key={node} className="text-xs text-gray-500">
                          <span className="text-gray-400">{node}:</span> {conn}
                        </div>
                      ))}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
          
          {/* Quick tips */}
          <div className="p-4 border-t border-zk-border bg-black">
            <div className="text-xs text-gray-500">
              <div className="font-bold text-gray-400 mb-1">Quick Tips:</div>
              <div>• Labels end with ':'</div>
              <div>• Comments start with '#'</div>
              <div>• ACC is implicit for arithmetic</div>
              <div>• Ports block until data arrives</div>
            </div>
            
            <div className="mt-3 text-xs">
              <div className="font-bold text-gray-400 mb-1">Example Pattern:</div>
              <div className="font-mono text-gray-600">
                <div>loop:</div>
                <div>  MOV IN ACC</div>
                <div>  JEZ done</div>
                <div>  MOV ACC RIGHT</div>
                <div>  JMP loop</div>
                <div>done:</div>
                <div>  NOP</div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};