import React from 'react';
import { useNavigate } from 'react-router-dom';
import { challenges, encodeChallenge } from '../data/challenges';

export const ChallengeList: React.FC = () => {
  const navigate = useNavigate();

  const handleChallengeSelect = (challenge: typeof challenges[0]) => {
    const encoded = encodeChallenge(challenge.inputs, challenge.expectedOutputs);
    navigate(`/challenge/${encoded}`);
  };

  const getDifficultyColor = (difficulty: string) => {
    switch (difficulty) {
      case 'easy': return 'text-green-400 border-green-400';
      case 'medium': return 'text-yellow-400 border-yellow-400';
      case 'hard': return 'text-red-400 border-red-400';
      default: return 'text-gray-400 border-gray-400';
    }
  };

  return (
    <div className="min-h-screen bg-zk-bg">
      <div className="container mx-auto p-8">
        <header className="text-center mb-12">
          <h1 className="text-5xl font-bold text-zk-accent mb-4">ZK-100 Puzzle VM</h1>
          <p className="text-xl text-gray-400">Select a challenge to begin</p>
        </header>

        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6 max-w-6xl mx-auto">
          {challenges.map((challenge) => (
            <button
              key={challenge.id}
              onClick={() => handleChallengeSelect(challenge)}
              className="bg-zk-node border border-zk-border rounded-lg p-6 text-left hover:border-zk-accent transition-all hover:shadow-lg hover:shadow-green-900/20"
            >
              <div className="flex justify-between items-start mb-3">
                <h3 className="text-xl font-bold text-white">{challenge.name}</h3>
                <span className={`text-xs px-2 py-1 border rounded ${getDifficultyColor(challenge.difficulty)}`}>
                  {challenge.difficulty}
                </span>
              </div>
              
              <p className="text-gray-400 mb-4">{challenge.description}</p>
              
              <div className="space-y-2 text-sm">
                <div>
                  <span className="text-gray-500">Input: </span>
                  <span className="text-gray-300 font-mono">[{challenge.inputs.join(', ')}]</span>
                </div>
                <div>
                  <span className="text-gray-500">Expected: </span>
                  <span className="text-zk-accent font-mono">[{challenge.expectedOutputs.join(', ')}]</span>
                </div>
              </div>
            </button>
          ))}
        </div>

        <div className="mt-12 text-center">
          <div className="text-gray-500 mb-4">Or create a custom challenge</div>
          <button
            onClick={() => {
              const inputStr = prompt('Enter input values (comma-separated):');
              const outputStr = prompt('Enter expected output values (comma-separated):');
              
              if (inputStr && outputStr) {
                try {
                  const inputs = inputStr.split(',').map(s => parseInt(s.trim()));
                  const outputs = outputStr.split(',').map(s => parseInt(s.trim()));
                  
                  if (inputs.some(isNaN) || outputs.some(isNaN)) {
                    alert('Invalid input. Please enter only numbers.');
                    return;
                  }
                  
                  const encoded = encodeChallenge(inputs, outputs);
                  navigate(`/challenge/${encoded}`);
                } catch (error) {
                  alert('Invalid input format');
                }
              }
            }}
            className="px-6 py-3 bg-zk-node border border-zk-border rounded hover:border-zk-accent transition-colors"
          >
            Create Custom Challenge
          </button>
        </div>
      </div>
    </div>
  );
};