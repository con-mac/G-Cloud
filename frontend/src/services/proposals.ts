/**
 * Proposals API service
 */

import apiService from './api';
import type { Proposal, Section } from '../types';

export const proposalsService = {
  async getAllProposals(): Promise<Proposal[]> {
    return apiService.get<Proposal[]>('/proposals');
  },

  async getProposalById(id: string): Promise<Proposal & { sections: Section[] }> {
    return apiService.get(`/proposals/${id}`);
  },

  async updateSection(sectionId: string, content: string): Promise<any> {
    return apiService.put(`/sections/${sectionId}`, {
      content,
      user_id: 'fe3d34b2-3538-4550-89b8-0fc96eee953a', // Test user
    });
  },

  async validateSection(sectionId: string): Promise<any> {
    return apiService.post(`/sections/${sectionId}/validate`, {});
  },
};

