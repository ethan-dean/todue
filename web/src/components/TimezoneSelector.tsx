import React, { useState, useMemo, useRef, useEffect } from 'react';
import { Check, ChevronDown, Search } from 'lucide-react';

const POPULAR_TIMEZONES = [
  'America/New_York',
  'America/Chicago',
  'America/Denver',
  'America/Los_Angeles',
  'America/Anchorage',
  'Pacific/Honolulu',
  'Europe/London',
  'Europe/Paris',
  'Europe/Berlin',
  'Asia/Tokyo',
  'Asia/Shanghai',
  'Asia/Kolkata',
  'Australia/Sydney',
  'Pacific/Auckland',
];

function getAllTimezones(): string[] {
  try {
    return Intl.supportedValuesOf('timeZone');
  } catch {
    return POPULAR_TIMEZONES;
  }
}

function getDetectedTimezone(): string {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone;
  } catch {
    return 'UTC';
  }
}

function formatTzLabel(tz: string): string {
  return tz.replace(/_/g, ' ');
}

interface TimezoneSelectorProps {
  value: string;
  onChange: (timezone: string) => void;
}

const TimezoneSelector: React.FC<TimezoneSelectorProps> = ({ value, onChange }) => {
  const [isOpen, setIsOpen] = useState(false);
  const [search, setSearch] = useState('');
  const containerRef = useRef<HTMLDivElement>(null);
  const searchInputRef = useRef<HTMLInputElement>(null);
  const listRef = useRef<HTMLDivElement>(null);

  const allTimezones = useMemo(() => getAllTimezones(), []);
  const detectedTz = useMemo(() => getDetectedTimezone(), []);

  const filtered = useMemo(() => {
    if (!search.trim()) return null; // show popular instead
    const q = search.toLowerCase().replace(/\s+/g, '_');
    const qSpace = search.toLowerCase();
    return allTimezones.filter(
      tz => tz.toLowerCase().includes(q) || tz.toLowerCase().replace(/_/g, ' ').includes(qSpace)
    );
  }, [search, allTimezones]);

  // Close on outside click
  useEffect(() => {
    if (!isOpen) return;
    const handleClick = (e: MouseEvent) => {
      if (containerRef.current && !containerRef.current.contains(e.target as Node)) {
        setIsOpen(false);
        setSearch('');
      }
    };
    document.addEventListener('mousedown', handleClick);
    return () => document.removeEventListener('mousedown', handleClick);
  }, [isOpen]);

  // Focus search input when opened
  useEffect(() => {
    if (isOpen && searchInputRef.current) {
      searchInputRef.current.focus();
    }
  }, [isOpen]);

  const handleSelect = (tz: string) => {
    onChange(tz);
    setIsOpen(false);
    setSearch('');
  };

  const displayList = filtered ?? [
    ...(detectedTz && !POPULAR_TIMEZONES.includes(detectedTz) ? [detectedTz] : []),
    ...POPULAR_TIMEZONES,
  ];

  return (
    <div className="timezone-selector" ref={containerRef}>
      <button
        className="timezone-trigger btn-secondary"
        onClick={() => setIsOpen(!isOpen)}
        type="button"
      >
        <span>{formatTzLabel(value)}</span>
        <ChevronDown size={16} />
      </button>

      {isOpen && (
        <div className="timezone-dropdown">
          <div className="timezone-search">
            <Search size={14} />
            <input
              ref={searchInputRef}
              type="text"
              placeholder="Search timezones..."
              value={search}
              onChange={e => setSearch(e.target.value)}
            />
          </div>
          <div className="timezone-list" ref={listRef}>
            {!search.trim() && detectedTz && (
              <div className="timezone-section-label">Detected</div>
            )}
            {!search.trim() && detectedTz && (
              <button
                className={`timezone-option ${value === detectedTz ? 'selected' : ''}`}
                onClick={() => handleSelect(detectedTz)}
                type="button"
              >
                <span>{formatTzLabel(detectedTz)}</span>
                {value === detectedTz && <Check size={14} />}
              </button>
            )}
            {!search.trim() && (
              <div className="timezone-section-label">Popular</div>
            )}
            {displayList.map(tz => {
              if (!search.trim() && tz === detectedTz) return null; // already shown above
              return (
                <button
                  key={tz}
                  className={`timezone-option ${value === tz ? 'selected' : ''}`}
                  onClick={() => handleSelect(tz)}
                  type="button"
                >
                  <span>{formatTzLabel(tz)}</span>
                  {value === tz && <Check size={14} />}
                </button>
              );
            })}
            {filtered && filtered.length === 0 && (
              <div className="timezone-empty">No timezones found</div>
            )}
          </div>
        </div>
      )}
    </div>
  );
};

export default TimezoneSelector;
