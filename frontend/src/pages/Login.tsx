/**
 * Login page with email validation for PA Consulting employees
 * Validates @paconsulting.com domain
 */

import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Container,
  Box,
  Card,
  CardContent,
  TextField,
  Button,
  Typography,
  Alert,
} from '@mui/material';
import { Login as LoginIcon } from '@mui/icons-material';

export default function Login() {
  const navigate = useNavigate();
  const [email, setEmail] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const validateEmail = (emailValue: string): boolean => {
    // Must end with @paconsulting.com
    const emailRegex = /^[^\s@]+@paconsulting\.com$/i;
    return emailRegex.test(emailValue);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    // Validate email
    if (!email.trim()) {
      setError('Email is required');
      setLoading(false);
      return;
    }

    if (!validateEmail(email)) {
      setError('Email must end with @paconsulting.com');
      setLoading(false);
      return;
    }

    try {
      // Store email in sessionStorage for authenticated session
      sessionStorage.setItem('userEmail', email);
      sessionStorage.setItem('isAuthenticated', 'true');

      // Navigate to questionnaire flow
      navigate('/proposals/flow');
    } catch (err) {
      setError('An error occurred. Please try again.');
      setLoading(false);
    }
  };

  return (
    <Container maxWidth="sm" sx={{ mt: 8 }}>
      <Card>
        <CardContent sx={{ p: 4 }}>
          <Box display="flex" flexDirection="column" alignItems="center" mb={3}>
            <LoginIcon sx={{ fontSize: 48, color: 'primary.main', mb: 2 }} />
            <Typography variant="h4" component="h1" gutterBottom>
              G-Cloud Proposal System
            </Typography>
            <Typography variant="body2" color="text.secondary">
              PA Consulting Employee Login
            </Typography>
          </Box>

          <form onSubmit={handleSubmit}>
            <TextField
              fullWidth
              label="Email Address"
              type="email"
              value={email}
              onChange={(e) => {
                setEmail(e.target.value);
                setError('');
              }}
              placeholder="your.name@paconsulting.com"
              error={!!error}
              helperText={error || 'Enter your PA Consulting email address'}
              disabled={loading}
              sx={{ mb: 3 }}
              autoFocus
            />

            {error && (
              <Alert severity="error" sx={{ mb: 2 }}>
                {error}
              </Alert>
            )}

            <Button
              type="submit"
              fullWidth
              variant="contained"
              size="large"
              disabled={loading || !email.trim()}
              startIcon={<LoginIcon />}
            >
              {loading ? 'Signing in...' : 'Sign In'}
            </Button>
          </form>

          <Box mt={3}>
            <Typography variant="caption" color="text.secondary" align="center" display="block">
              Access is restricted to PA Consulting employees only.
              <br />
              Future versions will support Microsoft 365 SSO.
            </Typography>
          </Box>
        </CardContent>
      </Card>
    </Container>
  );
}

