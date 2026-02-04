Summary: Eliminating Stale Data Flicker During Rapid Mutations                                                            
                   
  The Problem                                                                                                               
   
  When a user makes rapid changes (reorders, completions, deletes) in quick succession, the UI would briefly flicker —      
  showing stale server state that overwrote correct optimistic updates before snapping back to the final state.

  Root Cause Chain

  Four issues combined to create the flicker:

  1. WebSocket notifications fired before database commit — The backend sent TODOS_CHANGED WebSocket messages inside
  @Transactional methods, meaning clients received "refetch now" signals before the data was actually committed to MySQL.
  2. Stale fetch guard was too weak — Both clients used a timestamp (lastMutationTime) to decide whether to discard fetch
  results. But this only tracked when the last mutation started, not whether all mutations had resolved. A fetch starting
  after the last mutation's timestamp would pass the guard even if earlier mutations' data hadn't settled.
  3. Database deadlocks on concurrent writes — Two rapid mutations touching the same date's todos could deadlock in MySQL
  when both transactions tried to lock overlapping rows in different orders.
  4. Lost updates from concurrent transactions — Hibernate does full-row UPDATEs via saveAll, so when two transactions
  (e.g., a reorder and a completion) read the same todo concurrently, whichever commits last overwrites all columns
  including changes made by the other. A completion could be silently undone by a reorder's saveAll writing back the
  stale isCompleted=false value it read before the completion committed.

  The Fixes

  1. Defer WebSocket notifications until after transaction commit

  File: WebSocketService.java — sendToUser() method

  When called inside an active transaction, the WebSocket send is now registered as a
  TransactionSynchronization.afterCommit() callback instead of firing immediately. This guarantees clients only receive
  invalidation signals after the data is queryable. When called outside a transaction, it sends immediately as before. This
  is transparent to all callers — no changes needed in any service method.

  2. Replace timestamp guard with pending mutation counter

  Files: TodoContext.tsx (web), todo_provider.dart (mobile) — all mutation methods and loadTodos/loadTodosForDate

  Instead of recording when the last mutation happened, both clients now increment a counter when a mutation starts and
  decrement it (after a 500ms delay) when it finishes. The fetch guard simply checks: if any mutations are still in flight,
  discard the fetch result entirely and trust the optimistic state.

  The 500ms delayed decrement is critical — without it, the HTTP response from a mutation decrements the counter before that
   mutation's afterCommit WebSocket message arrives, so the WS-triggered refetch would see count=0 and accept potentially
  stale data. The delay keeps the counter elevated through the entire window where WS-triggered refetches could arrive.

  Early-return paths (e.g., reorder with no actual index change) decrement immediately since no API call was made and no WS
  message will arrive.

  3. Remove the 300ms artificial delays

  Files: TodoContext.tsx (web), todo_provider.dart (mobile) — WebSocket message handlers

  Both clients previously wrapped WS-triggered refetches in a 300ms setTimeout/Future.delayed as a band-aid to wait for
  transaction commit. With afterCommit handling this properly on the backend, these delays were removed. The areTodosEqual
  deep comparison on web still prevents unnecessary re-renders if identical data arrives.

  4. Deadlock and optimistic lock retry on the backend

  Files: DeadlockRetry.java (new utility), TodoController.java

  A simple retry utility catches both MySQL deadlock exceptions (CannotAcquireLockException) and optimistic lock conflicts
  (OptimisticLockingFailureException) and retries the operation up to 3 times with incremental backoff (50ms, 100ms).
  Every mutating endpoint in TodoController wraps its service call with this. Since the retry happens at the controller
  level (outside @Transactional), each attempt gets a fresh transaction and reads current data from the database.

  5. Optimistic locking on the Todo entity

  File: Todo.java — @Version column

  Added a @Version field to the Todo entity. Hibernate now includes WHERE version = ? in every UPDATE statement. When two
  concurrent transactions both read and modify the same todo (e.g., a reorder and a completion), the second one to commit
  finds the version has changed and throws OptimisticLockingFailureException instead of silently overwriting the first
  transaction's changes. The DeadlockRetry utility catches this and retries with fresh data, preventing lost updates.

  6. Reorder validation against completion boundary

  File: TodoService.java — updateTodoPosition() method

  When rapid operations cause a reorder request to arrive after a completion has already committed, the reorder could
  move a now-completed todo back above incomplete ones (a state the UI would never allow). A validation check now rejects
  reorders that would place a completed todo above any incomplete todo, or an incomplete todo below any completed todo.
  The operation is silently ignored and returns the todo's current state, since this only occurs when network latency
  reorders operations that the user submitted in valid sequence.

  7. Source date renumbering after rollover

  File: RolloverService.java

  When rollover moves incomplete todos from past dates to the current date, the remaining todos on those source dates are
  left with position gaps. A new renumberPositions helper closes these gaps after rollover completes, collecting the
  distinct source dates before the rollover loop mutates them.

  8. Client-side position renumbering after delete

  Files: TodoContext.tsx (web), todo_provider.dart (mobile) — optimistic delete handlers

  The optimistic delete logic previously removed the todo from the local list but left the remaining todos with position
  gaps (e.g., positions 1, 3, 4 after deleting position 2). Since WS-triggered refetches are now discarded during
  in-flight mutations, the client-side positions need to stay consistent. After removing a todo, the remaining list is
  now renumbered sequentially (1, 2, 3...) to match what the backend's renumberPositionsAfterRemoval does. This covers
  all three delete paths: single real todo, single virtual instance, and delete-all-future recurring.
