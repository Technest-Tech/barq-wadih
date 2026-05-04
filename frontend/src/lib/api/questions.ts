import apiClient from './client';
import ENDPOINTS from './endpoints';
import type { PaginatedResponse, ApiResponse } from './types';

export interface QuestionUser {
  id: number;
  name: string;
  avatar: string | null;
}

export interface Question {
  id: number;
  body: string;
  user: QuestionUser;
  replies: Question[];
  created_at: string;
}

export async function fetchQuestions(adId: number): Promise<Question[]> {
  const res = await apiClient.getPaginated<Question>(ENDPOINTS.AD_QUESTIONS(adId));
  return (res as unknown as PaginatedResponse<Question>).data ?? [];
}

export async function postQuestion(adId: number, body: string): Promise<Question> {
  const res = await apiClient.post<Question>(ENDPOINTS.AD_QUESTION_POST(adId), { body });
  return (res as ApiResponse<Question>).data;
}

export async function postReply(questionId: number, body: string): Promise<Question> {
  const res = await apiClient.post<Question>(ENDPOINTS.QUESTION_REPLY(questionId), { body });
  return (res as ApiResponse<Question>).data;
}
