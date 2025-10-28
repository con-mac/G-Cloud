import { Routes, Route, Navigate } from 'react-router-dom';
import ProposalsList from './pages/ProposalsList';
import ProposalEditor from './pages/ProposalEditor';

function App() {
  return (
    <Routes>
      <Route path="/" element={<Navigate to="/proposals" replace />} />
      <Route path="/proposals" element={<ProposalsList />} />
      <Route path="/proposals/:id" element={<ProposalEditor />} />
      <Route path="*" element={<Navigate to="/proposals" replace />} />
    </Routes>
  );
}

export default App;

