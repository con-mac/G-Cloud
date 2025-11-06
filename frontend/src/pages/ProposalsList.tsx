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
  Dialog,
  DialogTitle,
  DialogContent,
  DialogContentText,
  DialogActions,
} from '@mui/material';
import {
  CheckCircle as CheckIcon,
  Warning as WarningIcon,
  Error as ErrorIcon,
  Schedule as ScheduleIcon,
  Add as AddIcon,
} from '@mui/icons-material';
import { proposalsService } from '../services/proposals';
import sharepointApi from '../services/sharepointApi';

export default function ProposalsList() {
  const [proposals, setProposals] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [confirmDialogOpen, setConfirmDialogOpen] = useState(false);
  const [selectedProposal, setSelectedProposal] = useState<any>(null);
  const [loadingDocument, setLoadingDocument] = useState(false);
  const navigate = useNavigate();

  useEffect(() => {
    loadProposals();
  }, []);

  const loadProposals = async () => {
    try {
      // Get user email from sessionStorage
      const userEmail = sessionStorage.getItem('userEmail');
      
      if (!userEmail) {
        setError('Please log in to view your proposals');
        setLoading(false);
        return;
      }
      
      const data = await proposalsService.getAllProposals(userEmail);
      setProposals(data);
      setError(null);
    } catch (error: any) {
      console.error('Failed to load proposals:', error);
      setError(error.message || 'Failed to load proposals. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const getStatusColor = (status: string) => {
    const colors: Record<string, string> = {
      draft: 'default',
      incomplete: 'warning',
      complete: 'success',
      in_review: 'primary',
      ready_for_submission: 'success',
      submitted: 'info',
      approved: 'success',
      rejected: 'error',
    };
    return colors[status] || 'default';
  };
  
  const formatDate = (dateStr: string | null) => {
    if (!dateStr) return 'Not updated';
    try {
      const date = new Date(dateStr);
      return date.toLocaleDateString('en-GB', { 
        day: 'numeric', 
        month: 'short', 
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
      });
    } catch {
      return 'Not updated';
    }
  };

  const handleOpenProposal = async (proposal: any) => {
    // Show confirmation for completed proposals
    if (proposal.status === 'complete') {
      setSelectedProposal(proposal);
      setConfirmDialogOpen(true);
      return;
    }
    
    // For incomplete proposals, load directly
    await loadAndOpenProposal(proposal);
  };

  const loadAndOpenProposal = async (proposal: any) => {
    try {
      setLoadingDocument(true);
      
      // Load document content
      const documentContent = await sharepointApi.getDocumentContent(
        proposal.title,
        'SERVICE DESC',
        proposal.lot as '2' | '3',
        proposal.gcloud_version as '14' | '15'
      );

      // Store in sessionStorage for template to load
      const updateMetadata = {
        service_name: proposal.title,
        lot: proposal.lot,
        doc_type: 'SERVICE DESC',
        gcloud_version: proposal.gcloud_version,
        folder_path: '', // Will be resolved by backend
      };

      sessionStorage.setItem('updateDocument', JSON.stringify({
        ...updateMetadata,
        content: documentContent,
      }));

      sessionStorage.setItem('updateMetadata', JSON.stringify(updateMetadata));

      // Navigate to template
      navigate('/proposals/create/service-description');
    } catch (error: any) {
      console.error('Error loading proposal:', error);
      alert(`Failed to load proposal: ${error.response?.data?.detail || error.message}`);
    } finally {
      setLoadingDocument(false);
    }
  };

  const handleConfirmOpen = () => {
    setConfirmDialogOpen(false);
    if (selectedProposal) {
      loadAndOpenProposal(selectedProposal);
    }
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
      <Box mb={5} display="flex" justifyContent="space-between" alignItems="center">
        <Box>
          <Typography variant="h2" gutterBottom sx={{ fontWeight: 700 }}>
            G-Cloud Proposals
          </Typography>
          <Typography variant="body1" color="text.secondary">
            Manage and validate your G-Cloud framework proposals
          </Typography>
        </Box>
        <Button
          variant="contained"
          size="large"
          startIcon={<AddIcon />}
          onClick={() => {
            // Clear any previous proposal data for security
            sessionStorage.removeItem('updateDocument');
            sessionStorage.removeItem('updateMetadata');
            sessionStorage.removeItem('newProposal');
            navigate('/proposals/create');
          }}
        >
          Create New Proposal
        </Button>
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
                  {proposal.status === 'complete' ? (
                    <CheckIcon color="success" />
                  ) : proposal.status === 'incomplete' ? (
                    <WarningIcon color="warning" />
                  ) : (
                    <ErrorIcon color="error" />
                  )}
                </Box>

                <Box display="flex" gap={1} mb={2} flexWrap="wrap">
                  <Chip
                    label={proposal.status === 'complete' ? 'Complete' : proposal.status === 'incomplete' ? 'Incomplete' : 'Draft'}
                    color={getStatusColor(proposal.status) as any}
                    size="small"
                  />
                  <Chip
                    label={`G-Cloud ${proposal.gcloud_version || proposal.framework_version?.replace('G-Cloud ', '') || '14'}`}
                    color="primary"
                    size="small"
                    variant="outlined"
                  />
                  <Chip
                    label={`LOT ${proposal.lot || '2'}`}
                    color="secondary"
                    size="small"
                    variant="outlined"
                  />
                </Box>

                <Box mt={2} mb={1}>
                  <Box display="flex" justifyContent="space-between" mb={0.5}>
                    <Typography variant="caption" color="text.secondary">
                      Completion
                    </Typography>
                    <Typography variant="caption" fontWeight="bold">
                      {Math.round(proposal.completion_percentage || 0)}%
                    </Typography>
                  </Box>
                  <LinearProgress
                    variant="determinate"
                    value={proposal.completion_percentage || 0}
                    sx={{ height: 8, borderRadius: 4 }}
                  />
                </Box>

                <Box display="flex" alignItems="center" gap={1} mt={2}>
                  <ScheduleIcon fontSize="small" color="action" />
                  <Typography variant="caption" color="text.secondary">
                    Last updated: {formatDate(proposal.last_update || proposal.updated_at)}
                  </Typography>
                </Box>

                <Box mt={1.5}>
                  <Typography variant="caption" color="text.secondary" display="block">
                    Documents: {proposal.service_desc_exists ? '✓' : '✗'} Service Description{' '}
                    {proposal.pricing_doc_exists ? '✓' : '✗'} Pricing Document
                  </Typography>
                </Box>
              </CardContent>

              <CardActions sx={{ p: 2, pt: 0 }}>
                <Button
                  fullWidth
                  variant="contained"
                  onClick={() => handleOpenProposal(proposal)}
                  disabled={loadingDocument}
                >
                  {loadingDocument ? 'Loading...' : proposal.status === 'complete' ? 'Update Proposal' : 'Continue Proposal'}
                </Button>
              </CardActions>
            </Card>
          </Grid>
        ))}
      </Grid>

      {error && (
        <Box textAlign="center" py={8}>
          <Typography variant="h5" color="error" gutterBottom>
            {error}
          </Typography>
        </Box>
      )}

      {!error && proposals.length === 0 && (
        <Box textAlign="center" py={8}>
          <Typography variant="h5" color="text.secondary" gutterBottom>
            No proposals found
          </Typography>
          <Typography variant="body2" color="text.secondary">
            Create your first G-Cloud proposal to get started
          </Typography>
        </Box>
      )}

      {/* Confirmation Dialog for Completed Proposals */}
      <Dialog
        open={confirmDialogOpen}
        onClose={() => setConfirmDialogOpen(false)}
        aria-labelledby="confirm-dialog-title"
        aria-describedby="confirm-dialog-description"
      >
        <DialogTitle id="confirm-dialog-title">
          Edit Completed Proposal?
        </DialogTitle>
        <DialogContent>
          <DialogContentText id="confirm-dialog-description">
            Are you sure you want to edit this previously completed proposal? This will allow you to make changes to the document.
          </DialogContentText>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setConfirmDialogOpen(false)} color="secondary">
            No
          </Button>
          <Button onClick={handleConfirmOpen} color="primary" variant="contained" autoFocus>
            Yes
          </Button>
        </DialogActions>
      </Dialog>
    </Container>
  );
}

