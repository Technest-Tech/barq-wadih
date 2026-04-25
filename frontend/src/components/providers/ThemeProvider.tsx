'use client';

import { createContext, useContext, useEffect } from 'react';

type Theme = 'light' | 'dark' | 'system';

type ThemeContextType = {
  theme: Theme;
  setTheme: (theme: Theme) => void;
  resolvedTheme: 'light' | 'dark';
};

const ThemeContext = createContext<ThemeContextType | undefined>(undefined);

export function useTheme(): ThemeContextType {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error('useTheme must be used within ThemeProvider');
  return ctx;
}

// ── Always-light ThemeProvider ────────────────────────────────────────────────
// Dark mode is disabled site-wide. The .dark class is never applied and the
// device's prefers-color-scheme preference is intentionally ignored.
export default function ThemeProvider({ children }: { children: React.ReactNode }) {
  useEffect(() => {
    // Ensure .dark class is removed on mount and can never be re-added
    document.documentElement.classList.remove('dark');
  }, []);

  const noop = () => {};

  return (
    <ThemeContext.Provider value={{ theme: 'light', setTheme: noop, resolvedTheme: 'light' }}>
      {children}
    </ThemeContext.Provider>
  );
}
