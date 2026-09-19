import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export const useAuthStore = create(
  persist(
    (set) => ({
      token: null,
      admin: null,
      login: (token, admin) => set({ token, admin }),
      updateAdmin: (admin) => set({ admin }),
      logout: () => set({ token: null, admin: null }),
    }),
    { name: 'skincare-admin-auth' },
  ),
);
