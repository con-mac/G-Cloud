import { Routes, Route, Navigate } from 'react-router-dom';
import { useIsAuthenticated } from '@azure/msal-react';
import Box from '@mui/material/Box';

// TODO: Import pages when created
// import HomePage from '@/pages/HomePage';
// import LoginPage from '@/pages/LoginPage';
// import ProposalsPage from '@/pages/ProposalsPage';
// import ProposalDetailPage from '@/pages/ProposalDetailPage';
// import DashboardPage from '@/pages/DashboardPage';

function App() {
  const isAuthenticated = useIsAuthenticated();

  return (
    <Box sx={{ display: 'flex', minHeight: '100vh' }}>
      {/* TODO: Add navigation/layout components */}
      <Box component="main" sx={{ flexGrow: 1, p: 3 }}>
        <Routes>
          <Route
            path="/"
            element={
              <div>
                <h1>G-Cloud Automation System</h1>
                <p>Welcome to the G-Cloud Proposal Automation System</p>
                <p>Authentication status: {isAuthenticated ? 'Authenticated' : 'Not authenticated'}</p>
              </div>
            }
          />
          {/* TODO: Add more routes */}
          {/* <Route path="/login" element={<LoginPage />} /> */}
          {/* <Route path="/dashboard" element={<DashboardPage />} /> */}
          {/* <Route path="/proposals" element={<ProposalsPage />} /> */}
          {/* <Route path="/proposals/:id" element={<ProposalDetailPage />} /> */}
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </Box>
    </Box>
  );
}

export default App;

