/**
 * SharePoint API service for document management
 */

import apiService from './api';

export interface SearchRequest {
  query: string;
  doc_type?: 'SERVICE DESC' | 'Pricing Doc';
  gcloud_version?: '14' | '15';
}

export interface SearchResult {
  service_name: string;
  owner: string;
  sponsor: string;
  folder_path: string;
  doc_type: string;
  lot: string;
  gcloud_version: string;
}

export interface MetadataResponse {
  service: string;
  owner: string;
  sponsor: string;
}

export interface CreateFolderRequest {
  service_name: string;
  lot: '2' | '3';
  gcloud_version?: '14' | '15';
}

export interface CreateMetadataRequest {
  service_name: string;
  owner: string;
  sponsor: string;
  lot: '2' | '3';
  gcloud_version?: '14' | '15';
}

class SharePointApiService {
  /**
   * Search documents in SharePoint
   */
  async searchDocuments(request: SearchRequest): Promise<SearchResult[]> {
    try {
      const response = await apiService.post<SearchResult[]>('/sharepoint/search', request);
      return response.data;
    } catch (error: any) {
      console.error('Error searching documents:', error);
      throw error;
    }
  }

  /**
   * Get metadata for a service
   */
  async getMetadata(
    serviceName: string,
    lot: '2' | '3',
    gcloudVersion: '14' | '15' = '14'
  ): Promise<MetadataResponse> {
    try {
      const response = await apiService.get<MetadataResponse>(
        `/sharepoint/metadata/${encodeURIComponent(serviceName)}`,
        {
          params: { lot, gcloud_version: gcloudVersion },
        }
      );
      return response.data;
    } catch (error: any) {
      console.error('Error getting metadata:', error);
      throw error;
    }
  }

  /**
   * Get document info
   */
  async getDocument(
    serviceName: string,
    docType: 'SERVICE DESC' | 'Pricing Doc',
    lot: '2' | '3',
    gcloudVersion: '14' | '15' = '14'
  ): Promise<any> {
    try {
      const response = await apiService.get(`/sharepoint/document/${encodeURIComponent(serviceName)}`, {
        params: { doc_type: docType, lot, gcloud_version: gcloudVersion },
      });
      return response.data;
    } catch (error: any) {
      console.error('Error getting document:', error);
      throw error;
    }
  }

  /**
   * Create folder structure
   */
  async createFolder(request: CreateFolderRequest): Promise<any> {
    try {
      const response = await apiService.post('/sharepoint/create-folder', request);
      return response.data;
    } catch (error: any) {
      console.error('Error creating folder:', error);
      throw error;
    }
  }

  /**
   * Create metadata file
   */
  async createMetadata(request: CreateMetadataRequest): Promise<any> {
    try {
      const response = await apiService.post('/sharepoint/create-metadata', request);
      return response.data;
    } catch (error: any) {
      console.error('Error creating metadata:', error);
      throw error;
    }
  }
}

const sharepointApi = new SharePointApiService();
export default sharepointApi;

