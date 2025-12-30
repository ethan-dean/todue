import { format, parse, isSameDay as dateFnsIsSameDay, addDays as dateFnsAddDays, parseISO, startOfDay } from 'date-fns';

/**
 * Format a date for display
 */
export const formatDate = (date: Date | string, formatString: string = 'MMM d, yyyy'): string => {
  const dateObj = typeof date === 'string' ? parseISO(date) : date;
  return format(dateObj, formatString);
};

/**
 * Format a date for API (YYYY-MM-DD)
 */
export const formatDateForAPI = (date: Date): string => {
  return format(date, 'yyyy-MM-dd');
};

/**
 * Parse an API date string (YYYY-MM-DD) to Date object
 */
export const parseDate = (dateString: string): Date => {
  return parse(dateString, 'yyyy-MM-dd', new Date());
};

/**
 * Parse ISO date string
 */
export const parseDateISO = (dateString: string): Date => {
  return parseISO(dateString);
};

/**
 * Check if two dates are the same day
 */
export const isSameDay = (date1: Date | string, date2: Date | string): boolean => {
  const d1 = typeof date1 === 'string' ? parseISO(date1) : date1;
  const d2 = typeof date2 === 'string' ? parseISO(date2) : date2;
  return dateFnsIsSameDay(d1, d2);
};

/**
 * Add days to a date
 */
export const addDays = (date: Date | string, days: number): Date => {
  const dateObj = typeof date === 'string' ? parseISO(date) : date;
  return dateFnsAddDays(dateObj, days);
};

/**
 * Get current date (today)
 */
export const getCurrentDate = (): Date => {
  return startOfDay(new Date());
};

/**
 * Get a range of dates centered around a date
 * @param centerDate - The center date
 * @param numDays - Total number of days (1, 3, 5, or 7)
 * @returns Array of dates
 */
export const getDateRange = (centerDate: Date, numDays: 1 | 3 | 5 | 7): Date[] => {
  const dates: Date[] = [];
  const halfDays = Math.floor(numDays / 2);

  for (let i = -halfDays; i <= halfDays; i++) {
    dates.push(addDays(centerDate, i));
  }

  return dates;
};

/**
 * Get day of week name
 */
export const getDayOfWeek = (date: Date | string): string => {
  const dateObj = typeof date === 'string' ? parseISO(date) : date;
  return format(dateObj, 'EEEE');
};

/**
 * Get short day of week name
 */
export const getShortDayOfWeek = (date: Date | string): string => {
  const dateObj = typeof date === 'string' ? parseISO(date) : date;
  return format(dateObj, 'EEE');
};

/**
 * Check if date is today
 */
export const isToday = (date: Date | string): boolean => {
  return isSameDay(date, new Date());
};

/**
 * Check if date is in the past
 */
export const isPast = (date: Date | string): boolean => {
  const dateObj = typeof date === 'string' ? parseISO(date) : date;
  return startOfDay(dateObj) < startOfDay(new Date());
};

/**
 * Check if date is in the future
 */
export const isFuture = (date: Date | string): boolean => {
  const dateObj = typeof date === 'string' ? parseISO(date) : date;
  return startOfDay(dateObj) > startOfDay(new Date());
};
