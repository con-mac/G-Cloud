/**
 * G-Cloud Service Description Form - PA Consulting Style
 * 4 required sections with G-Cloud v15 validation
 */

import { useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Container, Box, Typography, TextField, Button, Card, CardContent,
  LinearProgress, Alert, IconButton, Chip, Dialog, DialogTitle,
  DialogContent, DialogActions, List, ListItem, ListItemText,
  CircularProgress,
} from '@mui/material';
import {
  ArrowBack, Add, Delete, CheckCircle, Error, Download, AttachFile,
} from '@mui/icons-material';
import { Tooltip } from '@mui/material';
import apiService from '../services/api';
import ReactQuill, { Quill } from 'react-quill';
import 'react-quill/dist/quill.snow.css';

// Import and register image resize module using blot-formatter
import BlotFormatter from 'quill-blot-formatter2';
Quill.register('modules/blotFormatter', BlotFormatter);

// Import and register table module
import QuillTable from 'quill-table';
Quill.register('modules/table', QuillTable);

interface ValidationState {
  isValid: boolean;
  message: string;
}

export default function ServiceDescriptionForm() {
  const navigate = useNavigate();
  
  // Form state
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [features, setFeatures] = useState<string[]>(['']);
  const [benefits, setBenefits] = useState<string[]>(['']);
  // Service Definition subsections
  const generateId = () => `${Date.now()}_${Math.random().toString(36).slice(2,8)}`;
  const [serviceDefinition, setServiceDefinition] = useState<Array<{
    id: string;
    subtitle: string;
    content: string; // HTML from editor
  }>>(() => [{ id: `${Date.now()}_${Math.random().toString(36).slice(2,8)}`, subtitle: '', content: '' }]);
  
  // Validation state
  const [titleValid, setTitleValid] = useState<ValidationState>({ isValid: true, message: '' });
  const [descValid, setDescValid] = useState<ValidationState>({ isValid: true, message: '' });
  const [featuresValid, setFeaturesValid] = useState<ValidationState>({ isValid: true, message: '' });
  const [benefitsValid, setBenefitsValid] = useState<ValidationState>({ isValid: true, message: '' });
  
  // UI state
  const [submitting, setSubmitting] = useState(false);
  const [successDialog, setSuccessDialog] = useState(false);
  const [generatedFiles, setGeneratedFiles] = useState<any>(null);
  const quillRefs = useRef<Record<string, any>>({});
  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const modulesByIdRef = useRef<Record<string, any>>({});
  const draftKey = 'service-description-draft-v1';

  // Word counting helper
  const countWords = (text: string): number => {
    return text.trim().split(/\s+/).filter(Boolean).length;
  };

  // Validation functions
  const validateTitle = (value: string) => {
    if (!value.trim()) {
      setTitleValid({ isValid: false, message: 'Title is required' });
      return false;
    }
    if (value.trim().split(/\s+/).length > 10) {
      setTitleValid({ isValid: false, message: 'Title should be concise - just the service name (max 10 words)' });
      return false;
    }
    setTitleValid({ isValid: true, message: 'Valid service name' });
    return true;
  };

  const validateDescription = (value: string) => {
    const words = countWords(value);
    if (words > 50) {
      setDescValid({ isValid: false, message: `Description must not exceed 50 words (currently ${words})` });
      return false;
    }
    setDescValid({ isValid: true, message: `Valid (${words}/50 words)` });
    return true;
  };

  const validateListItems = (items: string[], type: 'features' | 'benefits') => {
    const validItems = items.filter(item => item.trim().length > 0);
    
    if (validItems.length === 0) {
      const setState = type === 'features' ? setFeaturesValid : setBenefitsValid;
      setState({ isValid: false, message: `At least one ${type.slice(0, -1)} is required` });
      return false;
    }
    
    if (validItems.length > 10) {
      const setState = type === 'features' ? setFeaturesValid : setBenefitsValid;
      setState({ isValid: false, message: `Maximum 10 ${type} allowed (currently ${validItems.length})` });
      return false;
    }
    
    // Check each item is max 10 words
    for (const item of validItems) {
      const words = countWords(item);
      if (words > 10) {
        const setState = type === 'features' ? setFeaturesValid : setBenefitsValid;
        setState({ isValid: false, message: `Each ${type.slice(0, -1)} must be max 10 words (found ${words} words in one item)` });
        return false;
      }
    }
    
    const setState = type === 'features' ? setFeaturesValid : setBenefitsValid;
    setState({ isValid: true, message: `Valid (${validItems.length}/10 ${type})` });
    return true;
  };

  // Handlers
  const handleTitleChange = (value: string) => {
    setTitle(value);
    validateTitle(value);
  };

  const handleDescriptionChange = (value: string) => {
    setDescription(value);
    validateDescription(value);
  };

  const handleFeatureChange = (index: number, value: string) => {
    const newFeatures = [...features];
    newFeatures[index] = value;
    setFeatures(newFeatures);
    validateListItems(newFeatures, 'features');
  };

  const handleBenefitChange = (index: number, value: string) => {
    const newBenefits = [...benefits];
    newBenefits[index] = value;
    setBenefits(newBenefits);
    validateListItems(newBenefits, 'benefits');
  };

  // Service Definition handlers
  const addServiceDefBlock = () => {
    setServiceDefinition([...serviceDefinition, { id: generateId(), subtitle: '', content: '' }]);
  };

  const removeServiceDefBlock = (id: string) => {
    const next = serviceDefinition.filter((b) => b.id !== id);
    setServiceDefinition(next.length === 0 ? [{ id: generateId(), subtitle: '', content: '' }] : next);
  };

  const updateServiceDefBlock = (id: string, field: 'subtitle' | 'content', value: string) => {
    setServiceDefinition(prev => prev.map(b => b.id === id ? { ...b, [field]: value } : b));
  };

  // Stable toolbar modules per subsection (cached by id)
  const getModulesFor = (id: string) => {
    if (modulesByIdRef.current[id]) return modulesByIdRef.current[id];
    modulesByIdRef.current[id] = {
      toolbar: {
        container: [
          [{ header: [3, false] }],
          ['bold', 'italic', 'underline'],
          [{ list: 'ordered' }, { list: 'bullet' }],
          ['link', 'table'],
          ['clean'],
        ],
        handlers: {
          table: function(this: any) {
            const table = this.quill.getModule('table');
            if (table && table.insertTable) {
              table.insertTable(2, 2);
            }
          },
        },
      },
      imageResize: {
        parchment: Quill.import('parchment'),
        modules: ['Resize', 'DisplaySize', 'Toolbar'],
      },
      table: {
        operationMenu: true,
      },
    };
    return modulesByIdRef.current[id];
  };

  // Draft persistence: load on mount
  useEffect(() => {
    try {
      const raw = localStorage.getItem(draftKey);
      if (raw) {
        const data = JSON.parse(raw);
        if (typeof data.title === 'string') setTitle(data.title);
        if (typeof data.description === 'string') setDescription(data.description);
        if (Array.isArray(data.features)) setFeatures(data.features);
        if (Array.isArray(data.benefits)) setBenefits(data.benefits);
        if (Array.isArray(data.serviceDefinition)) {
          const restored = data.serviceDefinition.map((b: any) => ({
            id: typeof b.id === 'string' ? b.id : generateId(),
            subtitle: b.subtitle || '',
            content: b.content || '',
          }));
          setServiceDefinition(restored.length ? restored : [{ id: generateId(), subtitle: '', content: '' }]);
        }
      }
    } catch {}
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Draft persistence: save (debounced) on changes
  const saveTimeoutRef = useRef<number | null>(null);
  const scheduleSave = () => {
    if (saveTimeoutRef.current) window.clearTimeout(saveTimeoutRef.current);
    saveTimeoutRef.current = window.setTimeout(() => {
      try {
        const payload = {
          title,
          description,
          features,
          benefits,
          serviceDefinition,
        };
        localStorage.setItem(draftKey, JSON.stringify(payload));
      } catch {}
    }, 600);
  };
  useEffect(() => {
    scheduleSave();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [title, description, JSON.stringify(features), JSON.stringify(benefits), JSON.stringify(serviceDefinition)]);
  
  const addFeature = () => {
    if (features.length < 10) {
      setFeatures([...features, '']);
    }
  };

  const addBenefit = () => {
    if (benefits.length < 10) {
      setBenefits([...benefits, '']);
    }
  };

  const removeFeature = (index: number) => {
    const newFeatures = features.filter((_, i) => i !== index);
    setFeatures(newFeatures.length === 0 ? [''] : newFeatures);
    validateListItems(newFeatures, 'features');
  };

  const removeBenefit = (index: number) => {
    const newBenefits = benefits.filter((_, i) => i !== index);
    setBenefits(newBenefits.length === 0 ? [''] : newBenefits);
    validateListItems(newBenefits, 'benefits');
  };

  const handleSubmit = async () => {
    // Validate all fields
    const titleOk = validateTitle(title);
    const descOk = validateDescription(description);
    const featuresOk = validateListItems(features, 'features');
    const benefitsOk = validateListItems(benefits, 'benefits');

    if (!titleOk || !descOk || !featuresOk || !benefitsOk) {
      return;
    }

    setSubmitting(true);

    try {
      const response = await apiService.post('/templates/service-description/generate', {
        title: title.trim(),
        description: description.trim(),
        features: features.filter(f => f.trim().length > 0),
        benefits: benefits.filter(b => b.trim().length > 0),
        service_definition: serviceDefinition.map(b => ({
          subtitle: b.subtitle.trim(),
          content: b.content,
        })),
      });

      setGeneratedFiles(response);
      setSuccessDialog(true);
    } catch (error: any) {
      alert(`Error: ${error.response?.data?.detail || 'Failed to generate documents'}`);
    } finally {
      setSubmitting(false);
    }
  };

  const handleDownload = (url: string) => {
    // Use the presigned URL directly from the API response
    if (url && url.startsWith('http')) {
      window.open(url, '_blank');
    } else {
      // Fallback: construct download URL if we only have a filename
      const apiBaseUrl = import.meta.env.VITE_API_BASE_URL || import.meta.env.VITE_API_URL || 'https://jqms1xopz9.execute-api.eu-west-2.amazonaws.com';
      const downloadUrl = `${apiBaseUrl}/api/v1/templates/service-description/download/${url}`;
      window.open(downloadUrl, '_blank');
    }
  };

  const descWords = countWords(description);
  const descProgress = Math.min((descWords / 50) * 100, 100);

  return (
    <Container maxWidth="md" sx={{ py: 4 }}>
      <Box mb={4}>
        <Button
          startIcon={<ArrowBack />}
          onClick={() => navigate('/proposals/create')}
          sx={{ mb: 2 }}
        >
          Back to Templates
        </Button>

        <Typography variant="h3" gutterBottom sx={{ fontWeight: 700 }}>
          G-Cloud Service Description
        </Typography>
        <Typography variant="body1" color="text.secondary">
          Complete all 4 required sections following G-Cloud v15 guidelines
        </Typography>
      </Box>

      {/* Section 1: Title */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Box display="flex" alignItems="center" justifyContent="space-between" mb={2}>
            <Typography variant="h6" sx={{ fontWeight: 600 }}>
              Service Name
            </Typography>
            {titleValid.isValid ? (
              <Chip icon={<CheckCircle />} label="Valid" color="success" size="small" />
            ) : (
              <Chip icon={<Error />} label="Invalid" color="error" size="small" />
            )}
          </Box>

          <TextField
            fullWidth
            placeholder="ENTER TITLE HERE"
            value={title}
            onChange={(e) => handleTitleChange(e.target.value)}
            error={!titleValid.isValid && title.length > 0}
            helperText={titleValid.message || 'Just your service name - no extra keywords'}
            sx={{ mb: 1 }}
          />
        </CardContent>
      </Card>

      {/* Section 2: Short Service Description */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Box display="flex" alignItems="center" justifyContent="space-between" mb={2}>
            <Typography variant="h6" sx={{ fontWeight: 600 }}>
              Short Service Description
            </Typography>
            {descValid.isValid ? (
              <Chip icon={<CheckCircle />} label={descValid.message} color="success" size="small" />
            ) : (
              <Chip icon={<Error />} label="Invalid" color="error" size="small" />
            )}
          </Box>

          <TextField
            fullWidth
            multiline
            rows={6}
            placeholder="Provide a summary describing what your service is for..."
            value={description}
            onChange={(e) => handleDescriptionChange(e.target.value)}
            error={!descValid.isValid && description.length > 0}
            helperText={`${descWords}/50 words • ${descValid.message}`}
            sx={{ mb: 1 }}
          />

          <LinearProgress
            variant="determinate"
            value={descProgress}
            color={descValid.isValid ? 'success' : 'error'}
            sx={{ height: 8, borderRadius: 4 }}
          />
        </CardContent>
      </Card>

      {/* Section 3: Key Service Features */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Box display="flex" alignItems="center" justifyContent="space-between" mb={2}>
            <Typography variant="h6" sx={{ fontWeight: 600 }}>
              Key Service Features
            </Typography>
            {featuresValid.isValid ? (
              <Chip icon={<CheckCircle />} label={featuresValid.message} color="success" size="small" />
            ) : (
              <Chip icon={<Error />} label="Invalid" color="error" size="small" />
            )}
          </Box>

          <Typography variant="caption" color="text.secondary" display="block" sx={{ mb: 2 }}>
            10 words maximum for each feature, up to 10 features
          </Typography>

          {features.map((feature, index) => (
            <Box key={index} display="flex" alignItems="start" gap={1} mb={2}>
              <TextField
                fullWidth
                size="small"
                placeholder={`Feature ${index + 1}`}
                value={feature}
                onChange={(e) => handleFeatureChange(index, e.target.value)}
                helperText={`${countWords(feature)}/10 words`}
              />
              {features.length > 1 && (
                <IconButton onClick={() => removeFeature(index)} color="error" size="small">
                  <Delete />
                </IconButton>
              )}
            </Box>
          ))}

          {features.length < 10 && (
            <Button
              startIcon={<Add />}
              onClick={addFeature}
              variant="outlined"
              size="small"
            >
              Add Feature
            </Button>
          )}

          {!featuresValid.isValid && (
            <Alert severity="error" sx={{ mt: 2 }}>
              {featuresValid.message}
            </Alert>
          )}
        </CardContent>
      </Card>

      {/* Section 4: Key Service Benefits */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Box display="flex" alignItems="center" justifyContent="space-between" mb={2}>
            <Typography variant="h6" sx={{ fontWeight: 600 }}>
              Key Service Benefits
            </Typography>
            {benefitsValid.isValid ? (
              <Chip icon={<CheckCircle />} label={benefitsValid.message} color="success" size="small" />
            ) : (
              <Chip icon={<Error />} label="Invalid" color="error" size="small" />
            )}
          </Box>

          <Typography variant="caption" color="text.secondary" display="block" sx={{ mb: 2 }}>
            10 words maximum for each benefit, up to 10 benefits
          </Typography>

          {benefits.map((benefit, index) => (
            <Box key={index} display="flex" alignItems="start" gap={1} mb={2}>
              <TextField
                fullWidth
                size="small"
                placeholder={`Benefit ${index + 1}`}
                value={benefit}
                onChange={(e) => handleBenefitChange(index, e.target.value)}
                helperText={`${countWords(benefit)}/10 words`}
              />
              {benefits.length > 1 && (
                <IconButton onClick={() => removeBenefit(index)} color="error" size="small">
                  <Delete />
                </IconButton>
              )}
            </Box>
          ))}

          {benefits.length < 10 && (
            <Button
              startIcon={<Add />}
              onClick={addBenefit}
              variant="outlined"
              size="small"
            >
              Add Benefit
            </Button>
          )}

          {!benefitsValid.isValid && (
            <Alert severity="error" sx={{ mt: 2 }}>
              {benefitsValid.message}
            </Alert>
          )}
        </CardContent>
      </Card>

      {/* Section 5: Service Definition (optional, unlimited subsections) */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Box display="flex" alignItems="center" justifyContent="space-between" mb={2}>
            <Typography variant="h6" sx={{ fontWeight: 600 }}>
              Service Definition
            </Typography>
            <Chip label={`${serviceDefinition.length} subsection(s)`} size="small" />
          </Box>

          <Typography variant="caption" color="text.secondary" display="block" sx={{ mb: 2 }}>
            Add as many subsections as needed. Subtitles will be styled as Heading 3 in the Word document.
          </Typography>

          {serviceDefinition.map((block, index) => {
            const modules = getModulesFor(block.id);
            return (
            <Box key={block.id} sx={{ border: '1px solid', borderColor: 'divider', borderRadius: 1, p: 2, mb: 2 }}>
              <Box display="flex" justifyContent="space-between" alignItems="center" mb={1}>
                <Typography variant="subtitle2">Subsection {index + 1}</Typography>
                {serviceDefinition.length > 1 && (
                  <IconButton size="small" color="error" onClick={() => removeServiceDefBlock(block.id)}>
                    <Delete />
                  </IconButton>
                )}
              </Box>

              <TextField
                fullWidth
                size="small"
                label="Subtitle (Heading 3)"
                placeholder="e.g., AI Security advisory"
                value={block.subtitle}
                onChange={(e) => updateServiceDefBlock(block.id, 'subtitle', e.target.value)}
                sx={{ mb: 2 }}
              />

              <Box sx={{ 
                mb: 2,
                position: 'relative',
                '& .ql-container': { minHeight: 260 },
                '& .ql-editor': { minHeight: 260 },
                // Hide the default attach button (we're using custom one)
                '& .ql-toolbar .ql-attach': {
                  display: 'none',
                },
                // Image resize handles styling
                '& .ql-editor img': {
                  maxWidth: '100%',
                  height: 'auto',
                  cursor: 'move', // Indicate image can be moved/repositioned
                },
                // Tooltips on toolbar buttons - CSS-based for guaranteed visibility
                '& .ql-toolbar button, & .ql-toolbar select': {
                  position: 'relative',
                  '&:hover::after': {
                    content: 'attr(title)',
                    position: 'absolute',
                    bottom: '100%',
                    left: '50%',
                    transform: 'translateX(-50%)',
                    backgroundColor: '#333',
                    color: '#fff',
                    padding: '6px 10px',
                    borderRadius: '4px',
                    fontSize: '12px',
                    whiteSpace: 'nowrap',
                    zIndex: 10000,
                    marginBottom: '5px',
                    pointerEvents: 'none',
                    boxShadow: '0 2px 8px rgba(0,0,0,0.2)',
                    opacity: 1,
                    display: 'block',
                  },
                  '&:hover::before': {
                    content: '""',
                    position: 'absolute',
                    bottom: '100%',
                    left: '50%',
                    transform: 'translateX(-50%) translateY(100%)',
                    border: '5px solid transparent',
                    borderTopColor: '#333',
                    zIndex: 10001,
                    marginBottom: '-5px',
                    pointerEvents: 'none',
                  },
                },
              }}>
                <Typography variant="caption" color="text.secondary" display="block" sx={{ mb: 1 }}>
                  Content (use Heading 3 for subsections when needed; toolbar allows Bold/Italic/Lists/Tables. Images can be resized and repositioned.)
                </Typography>
                <ReactQuill
                  theme="snow"
                  value={block.content}
                  onChange={(html: string) => updateServiceDefBlock(block.id, 'content', html)}
                  modules={modules}
                  ref={(el: any) => {
                    quillRefs.current[block.id] = el;
                    if (el) {
                      // Use multiple attempts to ensure toolbar is ready
                      const addTooltips = () => {
                        const editor = el.getEditor?.();
                        if (!editor) return;
                        const toolbar = editor.container?.querySelector('.ql-toolbar');
                        if (!toolbar) return;
                        
                        // More specific selectors for Quill buttons
                        const tooltips: Array<{ selector: string; title: string }> = [
                          { selector: 'button.ql-header', title: 'Heading 3' },
                          { selector: 'button.ql-bold', title: 'Bold' },
                          { selector: 'button.ql-italic', title: 'Italic' },
                          { selector: 'button.ql-underline', title: 'Underline' },
                          { selector: 'button.ql-list[value="ordered"]', title: 'Ordered List' },
                          { selector: 'button.ql-list[value="bullet"]', title: 'Bullet List' },
                          { selector: 'button.ql-link', title: 'Insert Link' },
                          { selector: 'button.ql-table', title: 'Insert Table' },
                          { selector: 'button.ql-clean', title: 'Clear Formatting' },
                          // Also handle select dropdowns
                          { selector: 'select.ql-header', title: 'Heading 3' },
                          { selector: 'select.ql-list', title: 'List Type' },
                        ];
                        
                        tooltips.forEach(({ selector, title }) => {
                          const elements = toolbar.querySelectorAll(selector);
                          elements.forEach((element: Element) => {
                            (element as HTMLElement).setAttribute('title', title);
                            // Also set aria-label for accessibility
                            (element as HTMLElement).setAttribute('aria-label', title);
                          });
                        });
                      };
                      
                      // Try immediately, then after delays
                      addTooltips();
                      setTimeout(addTooltips, 100);
                      setTimeout(addTooltips, 300);
                      setTimeout(addTooltips, 500);
                      
                      // Use MutationObserver to catch dynamic toolbar updates
                      const observer = new MutationObserver(() => {
                        addTooltips();
                      });
                      
                      const editor = el.getEditor?.();
                      if (editor) {
                        const toolbar = editor.container?.querySelector('.ql-toolbar');
                        if (toolbar) {
                          observer.observe(toolbar, {
                            childList: true,
                            subtree: true,
                            attributes: true,
                          });
                        }
                      }
                    }
                  }}
                />
                {/* Custom attach button with MUI icon and tooltip - positioned absolutely after toolbar */}
                <Tooltip title="Attach file or image">
                  <Box
                    component="button"
                    type="button"
                    onClick={() => {
                      (fileInputRef.current as any).dataset.id = String(block.id);
                      fileInputRef.current?.click();
                    }}
                    sx={{
                      position: 'absolute',
                      top: 8,
                      right: 'calc(100% - 220px)', // Position after toolbar buttons
                      width: 28,
                      height: 28,
                      border: 'none',
                      background: 'transparent',
                      cursor: 'pointer',
                      display: 'inline-flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      zIndex: 10,
                      borderRadius: '2px',
                      '&:hover': {
                        backgroundColor: 'rgba(0,0,0,0.06)',
                      },
                    }}
                  >
                    <AttachFile sx={{ fontSize: 18 }} />
                  </Box>
                </Tooltip>
              </Box>
            </Box>
          );})}

          <Button startIcon={<Add />} variant="outlined" size="small" onClick={addServiceDefBlock}>
            Add Subsection
          </Button>
        </CardContent>
      </Card>

      {/* Submit Button */}
      <Box display="flex" justifyContent="flex-end" gap={2}>
        <Button
          variant="outlined"
          onClick={() => navigate('/proposals/create')}
        >
          Cancel
        </Button>
        <Button
          variant="contained"
          size="large"
          onClick={handleSubmit}
          disabled={submitting || !titleValid.isValid || !descValid.isValid || !featuresValid.isValid || !benefitsValid.isValid}
        >
          {submitting ? <CircularProgress size={24} /> : 'Generate Documents'}
        </Button>
      </Box>

      {/* Success Dialog */}
      <Dialog open={successDialog} onClose={() => setSuccessDialog(false)} maxWidth="sm" fullWidth>
        <DialogTitle>
          <Box display="flex" alignItems="center" gap={1}>
            <CheckCircle color="success" />
            <Typography variant="h6">Documents Generated Successfully!</Typography>
          </Box>
        </DialogTitle>
        <DialogContent>
          <Typography variant="body2" color="text.secondary" paragraph>
            Your G-Cloud Service Description documents have been generated with PA Consulting branding.
          </Typography>

          <List>
            <ListItem>
              <ListItemText
                primary="Word Document (.docx)"
                secondary={generatedFiles?.word_filename}
              />
              <Button
                startIcon={<Download />}
                variant="outlined"
                size="small"
                onClick={() => handleDownload(generatedFiles?.word_path || generatedFiles?.word_filename)}
              >
                Download
              </Button>
            </ListItem>
            <ListItem>
              <ListItemText
                primary="PDF Document"
                secondary={generatedFiles?.pdf_filename}
              />
              <Button
                startIcon={<Download />}
                variant="outlined"
                size="small"
                onClick={() => handleDownload(generatedFiles?.pdf_path || generatedFiles?.pdf_filename)}
                disabled={!generatedFiles?.pdf_path || !generatedFiles?.pdf_path.startsWith('http')}
              >
                {generatedFiles?.pdf_path && generatedFiles?.pdf_path.startsWith('http') ? 'Download' : 'Coming Soon'}
              </Button>
            </ListItem>
          </List>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => {
            setSuccessDialog(false);
            navigate('/proposals');
          }}>
            Done
          </Button>
          <Button variant="contained" onClick={() => {
            setSuccessDialog(false);
            // Reset form
            setTitle('');
            setDescription('');
            setFeatures(['']);
            setBenefits(['']);
          }}>
            Create Another
          </Button>
        </DialogActions>
      </Dialog>

      {/* Hidden file input for attachments */}
      <input
        type="file"
        ref={fileInputRef}
        style={{ display: 'none' }}
        onChange={async (e) => {
          const file = e.target.files?.[0];
          if (!file) return;
          try {
            const id = String((fileInputRef.current as any).dataset.id || '');
            const editor = quillRefs.current[id]?.getEditor?.();
            if (!editor) return;
            const range = editor.getSelection(true) || { index: editor.getLength(), length: 0 };
            if (file.type.startsWith('image/')) {
              const reader = new FileReader();
              reader.onload = () => {
                const dataUrl = reader.result as string;
                // Insert image with default size and make it resizable
                const html = `<img src="${dataUrl}" style="max-width: 100%; height: auto;" />`;
                editor.clipboard.dangerouslyPasteHTML(range.index, html);
                // Trigger image resize module to activate
                setTimeout(() => {
                  const img = editor.root.querySelector(`img[src="${dataUrl}"]`);
                  if (img) {
                    // Image resize module will handle resizing
                    editor.setSelection(range.index + 1, 0);
                  }
                }, 100);
              };
              reader.readAsDataURL(file);
            } else {
              const html = `<span>${file.name}</span>`;
              editor.clipboard.dangerouslyPasteHTML(range.index, html);
              editor.setSelection(range.index + 1, 0);
            }
          } finally {
            if (fileInputRef.current) fileInputRef.current.value = '';
          }
        }}
      />
    </Container>
  );
}

