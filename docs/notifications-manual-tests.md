# Notifications Manual Test Plan (Server-Side)

This plan validates the server-side notification flow (Cloud Scheduler → Cloud Tasks → HTTP function → FCM).

## Prerequisites

- Firebase project deployed with Cloud Functions.
- Cloud Tasks queue exists in the configured region.
- `NOTIFICATIONS_TASK_URL` or `functions.config().notifications.task_url` set.
- A test user in Firestore with:
  - `users/{uid}.timezone` set (e.g., `"Australia/Sydney"`).
  - `users/{uid}/devices/{deviceId}.fcmToken` containing a valid test token.

## 1) Scheduler → Task Enqueue

**Goal:** confirm `enqueueDailyNotifications` enqueues one task per user per day.

1. Trigger the scheduler manually (or wait for daily run).
2. Confirm a Cloud Task is created for the user’s local 4pm.
3. Verify `users/{uid}/notificationState/state.lastEnqueuedDate` is set for the scheduled day.

**Expected:** one task per user per day; repeat runs do not enqueue duplicates.

## 2) Task → HTTP Handler

**Goal:** confirm Cloud Task invokes `runNotificationForUser`.

1. Use a manual POST to the function with `{"userId": "<uid>"}`.
2. Verify the function returns HTTP 200.

**Expected:** function executes without error and evaluates rules.

## 3) Data-Entry Reminders

### Current Month Reminder

1. Create a month where at least one broad category is missing data.
2. Set the user’s timezone so the local date is > 50% through the month.
3. Trigger the HTTP function at 4pm local.

**Expected:** notification includes missing broad categories and sets
`lastCurrentMonthReminderAt`.

### Previous Month Reminder

1. Ensure the previous month is missing at least one broad category.
2. Run the function within the first 2 days of a new month.

**Expected:** notification includes missing categories and sets
`lastPreviousMonthReminderAt`.

## 4) Overspend Alerts (Budget Only)

1. Add transactions that push at least one category over 110% of budget.
2. Add at least 3 overspend categories to validate aggregation.

**Expected:**
- 1–2 categories → per-category alerts.
- 3+ categories → single aggregate alert listing up to 3 categories.
- Weekly cap is enforced after 3 alerts.

## 5) Positive Reinforcement

### Monthly Reinforcement

1. Ensure month progress > 50%.
2. Total spending ≤ total budget.

**Expected:** one monthly reinforcement notification with `lastPositiveReinforcementAt`.

### 3-Month Streak

1. For the last 3 months, ensure spending ≤ budget.
2. Run within the first 2 days of a new month.

**Expected:** a streak notification is sent and `lastStreakNotificationAt` is set.
This should not replace the monthly reinforcement notification.

## 6) Goal Aggregation

1. Create multiple goals with deadlines in 0–7 days or 29–30 days.

**Expected:** one aggregate notification with the closest deadline or largest target.
Weekly cap allows up to 3 goal-related notifications per week.

## 7) State Validation

After sending notifications, verify state in:
`users/{uid}/notificationState/state`

Expected fields include:
- `lastCurrentMonthReminderAt`
- `lastPreviousMonthReminderAt`
- `lastPositiveReinforcementAt`
- `lastStreakNotificationAt`
- `overspendWeekKey` / `overspendCount`
- `goalWeekKey` / `goalCount`

---

If you want, I can add a companion script to seed Firestore for repeatable testing.
