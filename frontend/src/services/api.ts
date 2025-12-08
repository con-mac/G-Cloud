/**
 * API service for backend communication
 */

import axios, { AxiosInstance, AxiosError } from 'axios';
import { toast } from 'react-toastify';

// Support both VITE_API_BASE_URL (for AWS) and VITE_API_URL (for Docker)
const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || import.meta.env.VITE_API_URL || 'http://localhost:8000';
const API_VERSION = import.meta.env.VITE_API_VERSION || 'v1';

class ApiService {
  private client: AxiosInstance;

  constructor() {
    // Check if API_BASE_URL already includes /api/v1 (Azure Function App)
    // If it does, use it as-is; otherwise add /api/v1 prefix
    let baseURL: string;
    if (API_BASE_URL.includes('/api/v1')) {
      baseURL = API_BASE_URL;
    } else {
      baseURL = `${API_BASE_URL}/api/${API_VERSION}`;
    }
    
    this.client = axios.create({
      baseURL: baseURL,
      timeout: 30000,
      headers: {
        'Content-Type': 'application/json',
      },
    });

    this.setupInterceptors();
  }

  private setupInterceptors() {
    // Request interceptor
    this.client.interceptors.request.use(
      (config) => {
        // Add authentication token if available (from MSAL)
        const token = localStorage.getItem('access_token');
        if (token) {
          config.headers.Authorization = `Bearer ${token}`;
        }

        // Add user email and name headers from Entra ID user profile
        const userEmail = sessionStorage.getItem('user_email');
        const userName = sessionStorage.getItem('user_name');
        if (userEmail) {
          config.headers['X-User-Email'] = userEmail;
        }
        if (userName) {
          config.headers['X-User-Name'] = userName;
        }

        // Add correlation ID for request tracking
        config.headers['X-Correlation-ID'] = crypto.randomUUID();

        return config;
      },
      (error) => {
        return Promise.reject(error);
      }
    );

    // Response interceptor
    this.client.interceptors.response.use(
      (response) => {
        return response;
      },
      (error: AxiosError) => {
        this.handleError(error);
        return Promise.reject(error);
      }
    );
  }

  private handleError(error: AxiosError) {
    if (error.response) {
      const status = error.response.status;
      const data = error.response.data as any;

      switch (status) {
        case 400:
          toast.error(data.message || 'Invalid request');
          break;
        case 401:
          toast.error('Unauthorised. Please log in.');
          // Redirect to login
          window.location.href = '/login';
          break;
        case 403:
          toast.error('You do not have permission to perform this action');
          break;
        case 404:
          toast.error('Resource not found');
          break;
        case 500:
          toast.error('Server error. Please try again later.');
          break;
        default:
          toast.error('An unexpected error occurred');
      }
    } else if (error.request) {
      toast.error('Network error. Please check your connection.');
    } else {
      toast.error('An error occurred. Please try again.');
    }
  }

  // Generic GET request
  async get<T>(url: string, params?: Record<string, any>): Promise<T> {
    // Add cache-busting timestamp to prevent browser caching
    const cacheBustParams = {
      ...params,
      _t: Date.now(), // Timestamp to bust cache
    };
    const response = await this.client.get<T>(url, { 
      params: cacheBustParams,
      headers: {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      },
    });
    return response.data;
  }

  // Generic POST request
  async post<T>(url: string, data?: any): Promise<T> {
    const response = await this.client.post<T>(url, data);
    return response.data;
  }

  // Generic PUT request
  async put<T>(url: string, data?: any): Promise<T> {
    const response = await this.client.put<T>(url, data);
    return response.data;
  }

  // Generic PATCH request
  async patch<T>(url: string, data?: any): Promise<T> {
    const response = await this.client.patch<T>(url, data);
    return response.data;
  }

  // Generic DELETE request
  async delete<T>(url: string, params?: any): Promise<T> {
    const response = await this.client.delete<T>(url, { params });
    return response.data;
  }

  // File upload
  async uploadFile<T>(url: string, file: File, onProgress?: (progress: number) => void): Promise<T> {
    const formData = new FormData();
    formData.append('file', file);

    const response = await this.client.post<T>(url, formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
      onUploadProgress: (progressEvent) => {
        if (onProgress && progressEvent.total) {
          const progress = Math.round((progressEvent.loaded * 100) / progressEvent.total);
          onProgress(progress);
        }
      },
    });

    return response.data;
  }
}

export const apiService = new ApiService();
export default apiService;

