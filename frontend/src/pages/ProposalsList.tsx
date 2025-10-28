/**
 * Proposals List Page - PA Consulting Style
 */

import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Container,
  Typography,
  Grid,
  Card,
  CardContent,
  CardActions,
  Button,
  Chip,
  LinearProgress,
  Box,
  CircularProgress,
} from '@mui/material';
import {
  CheckCircle as CheckIcon,
  Warning as WarningIcon,
  Error as ErrorIcon,
  Schedule as ScheduleIcon,
} from '@mui/icons-material';
import { proposalsService } from '../services/proposals';
import type { Proposal } from '../types';

export default function ProposalsList() {
  const [proposals, setProposals] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    loadProposals();
  }, []);

  const loadProposals = async () => {
    try {
      const data = await proposalsService.getAllProposals();
      setProposals(data);
    } catch (error) {
      console.error('Failed to load proposals:', error);
    } finally {
      setLoading(false);
    }
  };

  const getStatusColor = (status: string) => {
    const colors: Record<string, string> = {
      draft: 'default',
      in_review: 'primary',
      ready_for_submission: 'success',
      submitted: 'info',
      approved: 'success',
      rejected: 'error',
    };
    return colors[status] || 'default';
  };

  const getValidationIcon = (validSections: number, totalSections: number) => {
    if (validSections === totalSections) {
      return <CheckIcon color="success" />;
    } else if (validSections > 0) {
      return <WarningIcon color="warning" />;
    }
    return <ErrorIcon color="error" />;
  };

  if (loading) {
    return (
      <Box display="flex" justifyContent="center" alignItems="center" minHeight="80vh">
        <CircularProgress />
      </Box>
    );
  }

  return (
    <Container maxWidth="xl" sx={{ py: 6 }}>
      <Box mb={5}>
        <Typography variant="h2" gutterBottom sx={{ fontWeight: 700 }}>
          G-Cloud Proposals
        </Typography>
        <Typography variant="body1" color="text.secondary">
          Manage and validate your G-Cloud framework proposals
        </Typography>
      </Box>

      <Grid container spacing={3}>
        {proposals.map((proposal) => (
          <Grid item xs={12} md={6} lg={4} key={proposal.id}>
            <Card
              sx={{
                height: '100%',
                display: 'flex',
                flexDirection: 'column',
                position: 'relative',
              }}
            >
              <CardContent sx={{ flexGrow: 1 }}>
                <Box display="flex" justifyContent="space-between" alignItems="start" mb={2}>
                  <Typography variant="h5" component="h2" sx={{ flexGrow: 1, pr: 1 }}>
                    {proposal.title}
                  </Typography>
                  {getValidationIcon(proposal.valid_sections, proposal.section_count)}
                </Box>

                <Chip
                  label={proposal.status.replace(/_/g, ' ').toUpperCase()}
                  color={getStatusColor(proposal.status) as any}
                  size="small"
                  sx={{ mb: 2 }}
                />

                <Typography variant="body2" color="text.secondary" gutterBottom>
                  {proposal.framework_version}
                </Typography>

                <Box mt={2} mb={1}>
                  <Box display="flex" justifyContent="space-between" mb={0.5}>
                    <Typography variant="caption" color="text.secondary">
                      Completion
                    </Typography>
                    <Typography variant="caption" fontWeight="bold">
                      {proposal.completion_percentage}%
                    </Typography>
                  </Box>
                  <LinearProgress
                    variant="determinate"
                    value={proposal.completion_percentage}
                    sx={{ height: 8, borderRadius: 4 }}
                  />
                </Box>

                <Box display="flex" alignItems="center" gap={1} mt={2}>
                  <ScheduleIcon fontSize="small" color="action" />
                  <Typography variant="caption" color="text.secondary">
                    Deadline: {proposal.deadline ? new Date(proposal.deadline).toLocaleDateString() : 'Not set'}
                  </Typography>
                </Box>

                <Typography variant="caption" color="text.secondary" display="block" mt={1}>
                  Sections: {proposal.valid_sections}/{proposal.section_count} valid
                </Typography>
              </CardContent>

              <CardActions sx={{ p: 2, pt: 0 }}>
                <Button
                  fullWidth
                  variant="contained"
                  onClick={() => navigate(`/proposals/${proposal.id}`)}
                >
                  Edit Proposal
                </Button>
              </CardActions>
            </Card>
          </Grid>
        ))}
      </Grid>

      {proposals.length === 0 && (
        <Box textAlign="center" py={8}>
          <Typography variant="h5" color="text.secondary" gutterBottom>
            No proposals found
          </Typography>
          <Typography variant="body2" color="text.secondary">
            Create your first G-Cloud proposal to get started
          </Typography>
        </Box>
      )}
    </Container>
  );
}

