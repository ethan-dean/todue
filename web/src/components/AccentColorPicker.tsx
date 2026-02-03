import React, { useRef, useCallback } from 'react';
import { Check, Plus } from 'lucide-react';
import { useTheme } from '../context/ThemeContext';
import { userApi } from '../services/userApi';

const PRESET_COLORS = [
  { hex: '#4CAF50', dark: '#81C784', label: 'Green' },
  { hex: '#2196F3', dark: '#64B5F6', label: 'Blue' },
  { hex: '#9C27B0', dark: '#CE93D8', label: 'Purple' },
  { hex: '#F44336', dark: '#EF9A9A', label: 'Red' },
  { hex: '#FF9800', dark: '#FFCC80', label: 'Orange' },
  { hex: '#009688', dark: '#80CBC4', label: 'Teal' },
  { hex: '#E91E63', dark: '#F48FB1', label: 'Pink' },
];

const AccentColorPicker: React.FC = () => {
  const { accentColor, setAccentColor } = useTheme();
  const colorInputRef = useRef<HTMLInputElement>(null);
  const debounceRef = useRef<ReturnType<typeof setTimeout>>();

  const isPreset = PRESET_COLORS.some(c => c.hex.toLowerCase() === accentColor.toLowerCase());

  const persistColor = useCallback((color: string | null) => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => {
      userApi.updateAccentColor(color).catch(console.error);
    }, 500);
  }, []);

  const handleSelect = (hex: string) => {
    const isDefault = hex === '#4CAF50';
    setAccentColor(isDefault ? null : hex);
    persistColor(isDefault ? null : hex);
  };

  const handleCustomChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const hex = e.target.value;
    setAccentColor(hex);
    persistColor(hex);
  };

  return (
    <div className="accent-color-picker">
      {PRESET_COLORS.map((color) => {
        const selected = accentColor.toLowerCase() === color.hex.toLowerCase();
        return (
          <button
            key={color.hex}
            className={`color-swatch ${selected ? 'selected' : ''}`}
            onClick={() => handleSelect(color.hex)}
            title={color.label}
            type="button"
          >
            <svg viewBox="0 0 32 32" width="32" height="32">
              <defs>
                <clipPath id={`clip-${color.hex.slice(1)}`}>
                  <circle cx="16" cy="16" r="15" />
                </clipPath>
              </defs>
              <g clipPath={`url(#clip-${color.hex.slice(1)})`}>
                {/* Bottom-right half (dark mode color) */}
                <circle cx="16" cy="16" r="15" fill={color.dark} />
                {/* Top-left half (light mode color) */}
                <polygon points="0,0 32,0 0,32" fill={color.hex} />
              </g>
            </svg>
            {selected && (
              <span className="swatch-check">
                <Check size={14} strokeWidth={3} color="#fff" />
              </span>
            )}
          </button>
        );
      })}
      <button
        className={`color-swatch custom-swatch ${!isPreset ? 'selected' : ''}`}
        onClick={() => colorInputRef.current?.click()}
        title="Custom color"
        type="button"
      >
        <svg viewBox="0 0 36 36" width="36" height="36">
          <defs>
            <linearGradient id="rainbow-ring" gradientTransform="rotate(0)">
              <stop offset="0%" stopColor="#F44336" />
              <stop offset="17%" stopColor="#FF9800" />
              <stop offset="33%" stopColor="#FFEB3B" />
              <stop offset="50%" stopColor="#4CAF50" />
              <stop offset="67%" stopColor="#2196F3" />
              <stop offset="83%" stopColor="#9C27B0" />
              <stop offset="100%" stopColor="#F44336" />
            </linearGradient>
            <clipPath id="clip-custom-inner">
              <circle cx="18" cy="18" r={!isPreset ? 13.5 : 14.5} />
            </clipPath>
          </defs>
          {/* Rainbow border */}
          <circle cx="18" cy="18" r="17" fill="url(#rainbow-ring)" />
          <g clipPath="url(#clip-custom-inner)">
            {/* Bottom-right half (grey) */}
            <circle cx="18" cy="18" r="15" fill="var(--swatch-custom-bg, #ccc)" />
            {/* Top-left half (custom color if selected) */}
            {!isPreset && (
              <polygon points="0,0 36,0 0,36" fill={accentColor} />
            )}
          </g>
        </svg>
        <span className="swatch-plus">
          <Plus size={16} />
        </span>
        <input
          ref={colorInputRef}
          type="color"
          value={accentColor}
          onChange={handleCustomChange}
          style={{ position: 'absolute', opacity: 0, width: 0, height: 0, pointerEvents: 'none' }}
        />
      </button>
    </div>
  );
};

export default AccentColorPicker;
