package com.ethan.todue.util;

import com.ethan.todue.model.RecurrenceType;
import lombok.AllArgsConstructor;
import lombok.Data;

import java.util.regex.Pattern;

public class RecurrenceParser {

    @Data
    @AllArgsConstructor
    public static class RecurrenceInfo {
        private RecurrenceType type;
        private String strippedText;
    }

    private static final Pattern DAILY_PATTERN = Pattern.compile("\\s+every\\s+day\\s*$", Pattern.CASE_INSENSITIVE);
    private static final Pattern WEEKLY_PATTERN = Pattern.compile("\\s+every\\s+week\\s*$", Pattern.CASE_INSENSITIVE);
    private static final Pattern BIWEEKLY_PATTERN = Pattern.compile("\\s+every\\s+other\\s+week\\s*$", Pattern.CASE_INSENSITIVE);
    private static final Pattern MONTHLY_PATTERN = Pattern.compile("\\s+every\\s+month\\s*$", Pattern.CASE_INSENSITIVE);
    private static final Pattern YEARLY_PATTERN = Pattern.compile("\\s+every\\s+year\\s*$", Pattern.CASE_INSENSITIVE);

    public static RecurrenceInfo parseText(String text) {
        if (text == null || text.trim().isEmpty()) {
            return null;
        }

        // Check for each pattern in order
        if (DAILY_PATTERN.matcher(text).find()) {
            return new RecurrenceInfo(RecurrenceType.DAILY, stripRecurrencePattern(text, DAILY_PATTERN));
        }
        if (BIWEEKLY_PATTERN.matcher(text).find()) {
            return new RecurrenceInfo(RecurrenceType.BIWEEKLY, stripRecurrencePattern(text, BIWEEKLY_PATTERN));
        }
        if (WEEKLY_PATTERN.matcher(text).find()) {
            return new RecurrenceInfo(RecurrenceType.WEEKLY, stripRecurrencePattern(text, WEEKLY_PATTERN));
        }
        if (MONTHLY_PATTERN.matcher(text).find()) {
            return new RecurrenceInfo(RecurrenceType.MONTHLY, stripRecurrencePattern(text, MONTHLY_PATTERN));
        }
        if (YEARLY_PATTERN.matcher(text).find()) {
            return new RecurrenceInfo(RecurrenceType.YEARLY, stripRecurrencePattern(text, YEARLY_PATTERN));
        }

        return null;
    }

    private static String stripRecurrencePattern(String text, Pattern pattern) {
        return pattern.matcher(text).replaceAll("").trim();
    }
}
