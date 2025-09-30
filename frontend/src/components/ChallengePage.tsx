import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { NodeGrid } from './NodeGrid';
import { ResultDisplay } from './ResultDisplay';
import { LogViewer } from './LogViewer';
import { executeProgram } from '../utils/api';
import { decodeChallenge, challenges } from '../data/challenges';
import { logger } from '../utils/logger';
import type { Node, ExecutionResult } from '../types/zk100';

export const ChallengePage: React.FC = () => {
  const { challengeId } = useParams<{ challengeId: string }>();
  const navigate = useNavigate();
  
  const [nodes, setNodes] = useState<Node[]>([
    { id: '0,0', position: { x: 0, y: 0 }, code: '', lines: [], hasError: false },
    { id: '1,0', position: { x: 1, y: 0 }, code: '', lines: [], hasError: false },
    { id: '0,1', position: { x: 0, y: 1 }, code: '', lines: [], hasError: false },
    { id: '1,1', position: { x: 1, y: 1 }, code: '', lines: [], hasError: false },
  ]);

  const [result, setResult] = useState<ExecutionResult | null>(null);
  const [isExecuting, setIsExecuting] = useState(false);
  const [challenge, setChallenge] = useState<{ inputs: number[], outputs: number[] } | null>(null);
  const [challengeInfo, setChallengeInfo] = useState<typeof challenges[0] | null>(null);

  useEffect(() => {
    if (!challengeId) return;
    
    logger.info('Loading challenge', { challengeId });
    
    // Try to decode the challenge
    const decoded = decodeChallenge(challengeId);
    if (decoded) {
      setChallenge(decoded);
      logger.info('Decoded challenge', decoded);
      
      // Try to find matching predefined challenge
      const predefined = challenges.find(c => 
        JSON.stringify(c.inputs) === JSON.stringify(decoded.inputs) &&
        JSON.stringify(c.expectedOutputs) === JSON.stringify(decoded.outputs)
      );
      if (predefined) {
        setChallengeInfo(predefined);
        logger.info('Found predefined challenge', predefined);
      }
    } else {
      logger.error('Failed to decode challenge', { challengeId });
      navigate('/');
    }
  }, [challengeId, navigate]);

  const handleCodeChange = (nodeId: string, code: string) => {
    logger.logNodeCode(nodeId, code);
    setNodes(prev => prev.map(node => 
      node.id === nodeId 
        ? { ...node, code } 
        : node
    ));
  };

  const handleExecute = async () => {
    if (!challenge) return;
    
    setIsExecuting(true);
    setResult(null);
    
    logger.logExecution({ nodes, expectedInputs: challenge.inputs, expectedOutputs: challenge.outputs });
    
    try {
      const executionResult = await executeProgram(nodes, challenge.inputs);
      logger.logExecutionResult(executionResult);
      
      if (executionResult.logs) {
        logger.logCairoOutput(executionResult.logs.cairoOutput);
        logger.logProverOutput(executionResult.logs.proverOutput);
      }
      
      // Check if the solution is correct
      if (executionResult.success && executionResult.output) {
        const isCorrect = JSON.stringify(executionResult.output) === JSON.stringify(challenge.outputs);
        if (isCorrect) {
          logger.info('🎉 Challenge solved correctly!', { 
            expected: challenge.outputs, 
            actual: executionResult.output 
          });
        } else {
          logger.warn('❌ Incorrect solution', { 
            expected: challenge.outputs, 
            actual: executionResult.output 
          });
        }
      }
      
      setResult(executionResult);
    } catch (error) {
      logger.logBackendError(error);
      setResult({
        success: false,
        error: `Unexpected error: ${error instanceof Error ? error.message : 'Unknown error'}`,
      });
    } finally {
      setIsExecuting(false);
    }
  };

  const hasAnyCode = nodes.some(node => node.code.trim() !== '');

  if (!challenge) {
    return <div className="min-h-screen bg-zk-bg flex items-center justify-center text-white">
      Loading challenge...
    </div>;
  }

  return (
    <div className="min-h-screen bg-zk-bg pb-72">
      <div className="container mx-auto p-8">
        <header className="text-center mb-8">
          <button
            onClick={() => navigate('/')}
            className="absolute left-8 top-8 text-gray-400 hover:text-white transition-colors"
          >
            ← Back to Challenges
          </button>
          
          <h1 className="text-4xl font-bold text-zk-accent mb-2">
            {challengeInfo?.name || 'Custom Challenge'}
          </h1>
          <p className="text-gray-400 mb-4">
            {challengeInfo?.description || 'Solve this puzzle'}
          </p>
          
          <div className="flex justify-center gap-8 text-sm">
            <div>
              <span className="text-gray-500">Input: </span>
              <span className="text-white font-mono">[{challenge.inputs.join(', ')}]</span>
            </div>
            <div>
              <span className="text-gray-500">Expected: </span>
              <span className="text-zk-accent font-mono">[{challenge.outputs.join(', ')}]</span>
            </div>
            {challengeInfo?.difficulty && (
              <div>
                <span className="text-gray-500">Difficulty: </span>
                <span className={`font-bold ${
                  challengeInfo.difficulty === 'easy' ? 'text-green-400' :
                  challengeInfo.difficulty === 'medium' ? 'text-yellow-400' :
                  'text-red-400'
                }`}>
                  {challengeInfo.difficulty}
                </span>
              </div>
            )}
          </div>
          
          {challengeInfo?.hint && (
            <div className="mt-4 text-sm text-gray-500 italic">
              💡 Hint: {challengeInfo.hint}
            </div>
          )}
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
      
      <LogViewer executionLogs={result?.logs} />
    </div>
  );
};