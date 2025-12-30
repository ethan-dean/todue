package com.ethan.todue.util;

import com.ethan.todue.model.RecurrenceType;

import java.time.LocalDate;
import java.time.temporal.ChronoUnit;

public class RecurrenceCalculator {

    public static boolean shouldInstanceExist(RecurrenceType recurrenceType, LocalDate startDate, LocalDate targetDate) {
        if (targetDate.isBefore(startDate)) {
            return false;
        }

        return switch (recurrenceType) {
            case DAILY -> true;
            case WEEKLY -> calculateWeekly(startDate, targetDate);
            case BIWEEKLY -> calculateBiweekly(startDate, targetDate);
            case MONTHLY -> calculateMonthly(startDate, targetDate);
            case YEARLY -> calculateYearly(startDate, targetDate);
        };
    }

    private static boolean calculateWeekly(LocalDate startDate, LocalDate targetDate) {
        long daysBetween = ChronoUnit.DAYS.between(startDate, targetDate);
        return daysBetween % 7 == 0;
    }

    private static boolean calculateBiweekly(LocalDate startDate, LocalDate targetDate) {
        long daysBetween = ChronoUnit.DAYS.between(startDate, targetDate);
        return daysBetween % 14 == 0;
    }

    private static boolean calculateMonthly(LocalDate startDate, LocalDate targetDate) {
        // Same day of month
        int startDay = startDate.getDayOfMonth();

        // If the start day is greater than the last day of target month,
        // use the last day of target month
        int targetDay = Math.min(startDay, targetDate.lengthOfMonth());

        return targetDate.getDayOfMonth() == targetDay &&
               (targetDate.getYear() > startDate.getYear() ||
                (targetDate.getYear() == startDate.getYear() && targetDate.getMonthValue() > startDate.getMonthValue()));
    }

    private static boolean calculateYearly(LocalDate startDate, LocalDate targetDate) {
        // Same month and day each year
        // Handle leap year edge case: Feb 29 -> Feb 28 in non-leap years
        if (startDate.getMonthValue() == 2 && startDate.getDayOfMonth() == 29) {
            // Leap year birthday
            if (targetDate.getMonthValue() == 2 && targetDate.getYear() > startDate.getYear()) {
                if (targetDate.isLeapYear() && targetDate.getDayOfMonth() == 29) {
                    return true;
                } else if (!targetDate.isLeapYear() && targetDate.getDayOfMonth() == 28) {
                    return true;
                }
            }
            return false;
        }

        return targetDate.getMonthValue() == startDate.getMonthValue() &&
               targetDate.getDayOfMonth() == startDate.getDayOfMonth() &&
               targetDate.getYear() > startDate.getYear();
    }

    public static LocalDate getNextInstanceDate(RecurrenceType recurrenceType, LocalDate startDate, LocalDate afterDate) {
        LocalDate candidate = afterDate.plusDays(1);

        return switch (recurrenceType) {
            case DAILY -> candidate;
            case WEEKLY -> calculateNextWeekly(startDate, afterDate);
            case BIWEEKLY -> calculateNextBiweekly(startDate, afterDate);
            case MONTHLY -> calculateNextMonthly(startDate, afterDate);
            case YEARLY -> calculateNextYearly(startDate, afterDate);
        };
    }

    private static LocalDate calculateNextWeekly(LocalDate startDate, LocalDate afterDate) {
        long daysBetween = ChronoUnit.DAYS.between(startDate, afterDate);
        long remainder = daysBetween % 7;
        return afterDate.plusDays(7 - remainder);
    }

    private static LocalDate calculateNextBiweekly(LocalDate startDate, LocalDate afterDate) {
        long daysBetween = ChronoUnit.DAYS.between(startDate, afterDate);
        long remainder = daysBetween % 14;
        return afterDate.plusDays(14 - remainder);
    }

    private static LocalDate calculateNextMonthly(LocalDate startDate, LocalDate afterDate) {
        int targetDay = startDate.getDayOfMonth();
        LocalDate next = afterDate.plusMonths(1);
        int maxDay = next.lengthOfMonth();
        return next.withDayOfMonth(Math.min(targetDay, maxDay));
    }

    private static LocalDate calculateNextYearly(LocalDate startDate, LocalDate afterDate) {
        LocalDate next = afterDate.plusYears(1);
        if (startDate.getMonthValue() == 2 && startDate.getDayOfMonth() == 29 && !next.isLeapYear()) {
            return LocalDate.of(next.getYear(), 2, 28);
        }
        return LocalDate.of(next.getYear(), startDate.getMonthValue(), startDate.getDayOfMonth());
    }
}
