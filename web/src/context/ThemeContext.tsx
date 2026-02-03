import React, { createContext, useContext, useState, useEffect, useCallback, type ReactNode } from 'react';

type Theme = 'light' | 'dark';

interface ThemeContextType {
  theme: Theme;
  toggleTheme: () => void;
  setTheme: (theme: Theme) => void;
  accentColor: string;
  setAccentColor: (color: string | null) => void;
}

const DEFAULT_ACCENT = '#4CAF50';

const ThemeContext = createContext<ThemeContextType | undefined>(undefined);

interface ThemeProviderProps {
  children: ReactNode;
}

function hexToRgb(hex: string): { r: number; g: number; b: number } | null {
  const result = /^#([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})$/.exec(hex);
  if (!result) return null;
  return {
    r: parseInt(result[1], 16),
    g: parseInt(result[2], 16),
    b: parseInt(result[3], 16),
  };
}

function adjustBrightness(hex: string, amount: number): string {
  const rgb = hexToRgb(hex);
  if (!rgb) return hex;
  const clamp = (v: number) => Math.max(0, Math.min(255, Math.round(v)));
  const r = clamp(rgb.r + amount);
  const g = clamp(rgb.g + amount);
  const b = clamp(rgb.b + amount);
  return `#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}`;
}

function applyAccentColor(hex: string, isDark: boolean) {
  const root = document.documentElement;
  const rgb = hexToRgb(hex);
  if (!rgb) return;

  if (isDark) {
    const lightened = adjustBrightness(hex, 38);
    root.style.setProperty('--color-primary', lightened);
    root.style.setProperty('--color-primary-hover', adjustBrightness(hex, 55));
    const lightRgb = hexToRgb(lightened);
    if (lightRgb) {
      root.style.setProperty('--color-primary-light', `rgba(${lightRgb.r}, ${lightRgb.g}, ${lightRgb.b}, 0.1)`);
    }
  } else {
    root.style.setProperty('--color-primary', hex);
    root.style.setProperty('--color-primary-hover', adjustBrightness(hex, -25));
    root.style.setProperty('--color-primary-light', `rgba(${rgb.r}, ${rgb.g}, ${rgb.b}, 0.1)`);
  }
}

export const ThemeProvider: React.FC<ThemeProviderProps> = ({ children }) => {
  const [theme, setThemeState] = useState<Theme>('light');
  const [accentColor, setAccentColorState] = useState<string>(() => {
    return localStorage.getItem('accentColor') || DEFAULT_ACCENT;
  });

  // Initialize theme on mount
  useEffect(() => {
    const storedTheme = localStorage.getItem('theme') as Theme | null;

    if (storedTheme) {
      setThemeState(storedTheme);
      applyTheme(storedTheme);
    } else {
      const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
      const systemTheme: Theme = prefersDark ? 'dark' : 'light';
      setThemeState(systemTheme);
      applyTheme(systemTheme);
    }
  }, []);

  // Apply accent color on mount and when theme/color changes
  useEffect(() => {
    applyAccentColor(accentColor, theme === 'dark');
  }, [accentColor, theme]);

  // Listen for system theme changes
  useEffect(() => {
    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');

    const handleChange = (e: MediaQueryListEvent) => {
      const storedTheme = localStorage.getItem('theme');
      if (!storedTheme) {
        const newTheme: Theme = e.matches ? 'dark' : 'light';
        setThemeState(newTheme);
        applyTheme(newTheme);
      }
    };

    mediaQuery.addEventListener('change', handleChange);
    return () => mediaQuery.removeEventListener('change', handleChange);
  }, []);

  const applyTheme = (newTheme: Theme) => {
    const root = document.documentElement;

    if (newTheme === 'dark') {
      root.classList.add('dark-theme');
      root.classList.remove('light-theme');
    } else {
      root.classList.add('light-theme');
      root.classList.remove('dark-theme');
    }
  };

  const setTheme = (newTheme: Theme) => {
    setThemeState(newTheme);
    localStorage.setItem('theme', newTheme);
    applyTheme(newTheme);
  };

  const toggleTheme = () => {
    const newTheme: Theme = theme === 'light' ? 'dark' : 'light';
    setTheme(newTheme);
  };

  const setAccentColor = useCallback((color: string | null) => {
    const resolved = color || DEFAULT_ACCENT;
    setAccentColorState(resolved);
    if (color) {
      localStorage.setItem('accentColor', resolved);
    } else {
      localStorage.removeItem('accentColor');
    }
  }, []);

  const value: ThemeContextType = {
    theme,
    toggleTheme,
    setTheme,
    accentColor,
    setAccentColor,
  };

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
};

// Custom hook to use theme context
export const useTheme = (): ThemeContextType => {
  const context = useContext(ThemeContext);
  if (context === undefined) {
    throw new Error('useTheme must be used within a ThemeProvider');
  }
  return context;
};
