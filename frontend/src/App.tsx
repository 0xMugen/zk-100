import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { ChallengeList } from './components/ChallengeList';
import { ChallengePage } from './components/ChallengePage';
import { logger } from './utils/logger';

// Initialize logger
logger.info('ZK-100 Frontend initialized');

function App() {
  return (
    <Router>
      <Routes>
        <Route path="/" element={<ChallengeList />} />
        <Route path="/challenge/:challengeId" element={<ChallengePage />} />
      </Routes>
    </Router>
  );
}

export default App;