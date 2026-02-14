export interface ApiResponse<T> {
  data: T;
  meta?: {
    pagination?: { current_page: number; total_pages: number; per_page: number };
    timestamp?: string;
  };
  errors?: Array<{ code: string; message: string; field?: string }>;
}
