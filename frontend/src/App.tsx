import { Routes, Route, Navigate } from 'react-router-dom';
import ProposalsList from './pages/ProposalsList';
import ProposalEditor from './pages/ProposalEditor';
import CreateProposal from './pages/CreateProposal';
import ServiceDescriptionForm from './pages/ServiceDescriptionForm';

function App() {
  return (
    <Routes>
      <Route path="/" element={<Navigate to="/proposals" replace />} />
      <Route path="/proposals" element={<ProposalsList />} />
      <Route path="/proposals/create" element={<CreateProposal />} />
      <Route path="/proposals/create/service-description" element={<ServiceDescriptionForm />} />
      <Route path="/proposals/:id" element={<ProposalEditor />} />
      <Route path="*" element={<Navigate to="/proposals" replace />} />
    </Routes>
  );
}

export default App;

