import { Routes, Route, Navigate } from 'react-router-dom';
import Login from './pages/Login';
import ProposalFlow from './pages/ProposalFlow';
import ProposalsList from './pages/ProposalsList';
import ProposalEditor from './pages/ProposalEditor';
import CreateProposal from './pages/CreateProposal';
import ServiceDescriptionForm from './pages/ServiceDescriptionForm';
import AdminDashboard from './pages/AdminDashboard';

// Protected route wrapper
const ProtectedRoute = ({ children }: { children: React.ReactElement }) => {
  const isAuthenticated = sessionStorage.getItem('isAuthenticated') === 'true';
  return isAuthenticated ? children : <Navigate to="/login" replace />;
};

function App() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route path="/" element={<Navigate to="/login" replace />} />
      <Route
        path="/proposals/flow"
        element={
          <ProtectedRoute>
            <ProposalFlow />
          </ProtectedRoute>
        }
      />
      <Route
        path="/proposals"
        element={
          <ProtectedRoute>
            <ProposalsList />
          </ProtectedRoute>
        }
      />
      <Route
        path="/proposals/create"
        element={
          <ProtectedRoute>
            <CreateProposal />
          </ProtectedRoute>
        }
      />
      <Route
        path="/proposals/create/service-description"
        element={
          <ProtectedRoute>
            <ServiceDescriptionForm />
          </ProtectedRoute>
        }
      />
      <Route
        path="/proposals/:id"
        element={
          <ProtectedRoute>
            <ProposalEditor />
          </ProtectedRoute>
        }
      />
      <Route
        path="/admin/dashboard"
        element={
          <ProtectedRoute>
            <AdminDashboard />
          </ProtectedRoute>
        }
      />
      <Route path="*" element={<Navigate to="/login" replace />} />
    </Routes>
  );
}

export default App;

