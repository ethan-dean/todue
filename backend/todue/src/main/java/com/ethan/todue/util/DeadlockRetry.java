package com.ethan.todue.util;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.CannotAcquireLockException;
import org.springframework.dao.OptimisticLockingFailureException;

import java.util.function.Supplier;

/**
 * Retries a transactional operation on MySQL deadlock or optimistic lock conflict.
 * Must be called from outside the @Transactional boundary
 * (e.g., from a controller) so each retry gets a fresh transaction.
 */
public final class DeadlockRetry {

    private static final Logger log = LoggerFactory.getLogger(DeadlockRetry.class);
    private static final int MAX_RETRIES = 3;

    private DeadlockRetry() {}

    public static <T> T execute(Supplier<T> operation) {
        int attempt = 0;
        while (true) {
            try {
                return operation.get();
            } catch (CannotAcquireLockException | OptimisticLockingFailureException e) {
                attempt++;
                log.warn("{} (attempt {}/{}), retrying...", e.getClass().getSimpleName(), attempt, MAX_RETRIES, e);
                if (attempt >= MAX_RETRIES) {
                    throw e;
                }
                try {
                    Thread.sleep(50L * attempt);
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                    throw e;
                }
            }
        }
    }

    public static void executeVoid(Runnable operation) {
        execute(() -> {
            operation.run();
            return null;
        });
    }
}
