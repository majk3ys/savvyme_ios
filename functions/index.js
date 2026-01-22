const admin = require("firebase-admin");
const functions = require("firebase-functions");
const { CloudTasksClient } = require("@google-cloud/tasks");
const { DateTime } = require("luxon");

admin.initializeApp();

const TARGET_HOUR = 16;
const ROLLOVER_WINDOW_DAYS = 2;
const BROAD_CATEGORIES = [
  "Home",
  "Daily living",
  "Transport",
  "Entertainment & personal",
];

const db = admin.firestore();
const tasksClient = new CloudTasksClient();
const TASK_QUEUE =
  process.env.NOTIFICATIONS_TASK_QUEUE || "notification-dispatch";
const TASK_LOCATION = process.env.NOTIFICATIONS_TASK_LOCATION || "us-central1";
const TASK_URL =
  process.env.NOTIFICATIONS_TASK_URL ||
  functions.config().notifications?.task_url;

exports.enqueueDailyNotifications = functions.pubsub
  .schedule("every day 00:10")
  .timeZone("UTC")
  .onRun(async () => {
    if (!TASK_URL) {
      console.warn("Missing NOTIFICATIONS_TASK_URL; skipping enqueue.");
      return;
    }
    const nowUtc = DateTime.utc();
    const usersSnapshot = await db.collection("users").get();
    const tasks = usersSnapshot.docs.map((doc) =>
      enqueueUserNotificationTask(doc.id, doc.data(), nowUtc)
    );
    await Promise.all(tasks);
  });

exports.runNotificationForUser = functions.https.onRequest(async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method not allowed");
    return;
  }

  const userId = req.body?.userId;
  if (!userId) {
    res.status(400).send("Missing userId");
    return;
  }

  const userSnap = await db.collection("users").doc(userId).get();
  if (!userSnap.exists) {
    res.status(404).send("User not found");
    return;
  }

  await processUser(userId, userSnap.data(), DateTime.utc());
  res.status(200).send("OK");
});

async function enqueueUserNotificationTask(userId, userData, nowUtc) {
  const timezone = userData.timezone;
  if (!timezone) {
    return;
  }

  const localNow = nowUtc.setZone(timezone);
  const notificationStateRef = db
    .collection("users")
    .doc(userId)
    .collection("notificationState")
    .doc("state");
  const notificationStateSnap = await notificationStateRef.get();
  const notificationState = notificationStateSnap.exists
    ? notificationStateSnap.data()
    : {};

  const scheduledLocal = localNow.set({
    hour: TARGET_HOUR,
    minute: 0,
    second: 0,
    millisecond: 0,
  });
  const scheduledAt =
    scheduledLocal < localNow
      ? scheduledLocal.plus({ days: 1 })
      : scheduledLocal;
  const scheduledKey = scheduledAt.toFormat("yyyy-MM-dd");

  if (notificationState.lastEnqueuedDate === scheduledKey) {
    return;
  }

  const task = {
    httpRequest: {
      httpMethod: "POST",
      url: TASK_URL,
      headers: { "Content-Type": "application/json" },
      body: Buffer.from(JSON.stringify({ userId })).toString("base64"),
    },
    scheduleTime: {
      seconds: Math.floor(scheduledAt.toSeconds()),
    },
  };

  const project = process.env.GCLOUD_PROJECT;
  const parent = tasksClient.queuePath(project, TASK_LOCATION, TASK_QUEUE);
  await tasksClient.createTask({ parent, task });

  await notificationStateRef.set(
    { lastEnqueuedDate: scheduledKey },
    { merge: true }
  );
}

async function processUser(userId, userData, nowUtc) {
  const timezone = userData.timezone;
  if (!timezone) {
    return;
  }

  const localNow = nowUtc.setZone(timezone);
  if (localNow.hour !== TARGET_HOUR) {
    return;
  }

  const notificationStateRef = db
    .collection("users")
    .doc(userId)
    .collection("notificationState")
    .doc("state");
  const notificationStateSnap = await notificationStateRef.get();
  const notificationState = notificationStateSnap.exists
    ? notificationStateSnap.data()
    : {};

  const monthStart = localNow.startOf("month");
  const monthKey = monthStart.toFormat("yyyy-MM");
  const previousMonthStart = monthStart.minus({ months: 1 });
  const previousMonthKey = previousMonthStart.toFormat("yyyy-MM");
  const streakStart = monthStart.minus({ months: 3 });

  const transactions = await fetchTransactions(
    userId,
    streakStart.toJSDate()
  );
  const goals = await fetchGoals(userId);

  const monthlyTotals = buildMonthlyTotals(transactions);
  const currentMonth = monthlyTotals[monthKey] || emptyMonthTotals();
  const previousMonth =
    monthlyTotals[previousMonthKey] || emptyMonthTotals();

  const actions = [];

  actions.push(
    ...handleDataEntryReminders({
      localNow,
      currentMonth,
      previousMonth,
      notificationState,
    })
  );

  actions.push(
    ...handleOverspend({
      localNow,
      currentMonth,
      notificationState,
    })
  );

  actions.push(
    ...handlePositiveReinforcement({
      localNow,
      currentMonth,
      monthlyTotals,
      notificationState,
    })
  );

  actions.push(
    ...handleGoalProgress({
      localNow,
      goals,
      notificationState,
    })
  );

  if (actions.length === 0) {
    return;
  }

  const deviceTokens = await fetchDeviceTokens(userId);
  if (deviceTokens.length === 0) {
    return;
  }

  const sent = await sendNotifications(deviceTokens, actions);
  if (sent.length > 0) {
    const updates = buildNotificationStateUpdates({
      localNow,
      notificationState,
      sent,
    });
    await notificationStateRef.set(updates, { merge: true });
  }
}

async function fetchTransactions(userId, startDate) {
  const snapshot = await db
    .collection("users")
    .doc(userId)
    .collection("transactions")
    .where("date", ">=", admin.firestore.Timestamp.fromDate(startDate))
    .get();

  return snapshot.docs.map((doc) => doc.data());
}

async function fetchGoals(userId) {
  const snapshot = await db
    .collection("users")
    .doc(userId)
    .collection("goals")
    .get();
  return snapshot.docs.map((doc) => doc.data());
}

async function fetchDeviceTokens(userId) {
  const snapshot = await db
    .collection("users")
    .doc(userId)
    .collection("devices")
    .get();
  return snapshot.docs
    .map((doc) => doc.data().fcmToken)
    .filter(Boolean);
}

function buildMonthlyTotals(transactions) {
  return transactions.reduce((acc, transaction) => {
    const date = transaction.date?.toDate
      ? transaction.date.toDate()
      : transaction.date;
    if (!date) {
      return acc;
    }
    const monthKey = DateTime.fromJSDate(date).toFormat("yyyy-MM");
    acc[monthKey] = acc[monthKey] || emptyMonthTotals();
    const category = transaction.type;
    if (category) {
      acc[monthKey].categoryTotals[category] =
        (acc[monthKey].categoryTotals[category] || 0) + transaction.amount;
      if (transaction.budget) {
        acc[monthKey].categoryBudgets[category] =
          (acc[monthKey].categoryBudgets[category] || 0) + transaction.budget;
      }
    }
    acc[monthKey].totalSpending += transaction.amount;
    if (transaction.budget) {
      acc[monthKey].totalBudget += transaction.budget;
    }
    return acc;
  }, {});
}

function emptyMonthTotals() {
  return {
    categoryTotals: {},
    categoryBudgets: {},
    totalSpending: 0,
    totalBudget: 0,
  };
}

function handleDataEntryReminders({
  localNow,
  currentMonth,
  previousMonth,
  notificationState,
}) {
  const actions = [];
  const monthProgress = localNow.day / localNow.daysInMonth;
  const missingCurrent = missingBroadCategories(currentMonth.categoryTotals);
  const missingPrevious = missingBroadCategories(previousMonth.categoryTotals);

  const hasSentCurrent =
    notificationState.lastCurrentMonthReminderAt &&
    DateTime.fromJSDate(notificationState.lastCurrentMonthReminderAt.toDate())
      .toFormat("yyyy-MM") === localNow.toFormat("yyyy-MM");

  if (
    monthProgress > 0.5 &&
    missingCurrent.length > 0 &&
    !hasSentCurrent
  ) {
    actions.push({
      type: "data-entry-current",
      title: "Finish this month’s totals",
      body: `Missing: ${missingCurrent.join(", ")}.`,
    });
  }

  const hasSentPrevious =
    notificationState.lastPreviousMonthReminderAt &&
    DateTime.fromJSDate(notificationState.lastPreviousMonthReminderAt.toDate())
      .toFormat("yyyy-MM") === localNow.toFormat("yyyy-MM");

  if (
    localNow.day <= ROLLOVER_WINDOW_DAYS &&
    missingPrevious.length > 0 &&
    !hasSentPrevious
  ) {
    actions.push({
      type: "data-entry-previous",
      title: "Complete last month’s totals",
      body: `Missing: ${missingPrevious.join(", ")}.`,
    });
  }

  return actions;
}

function handleOverspend({ localNow, currentMonth, notificationState }) {
  const actions = [];
  const overspendItems = [];

  Object.entries(currentMonth.categoryTotals).forEach(([category, total]) => {
    const budget = currentMonth.categoryBudgets[category];
    if (!budget || budget <= 0) {
      return;
    }

    if (total >= budget * 1.2) {
      overspendItems.push({ category, severity: "severe" });
    } else if (total >= budget * 1.1) {
      overspendItems.push({ category, severity: "soft" });
    }
  });

  if (overspendItems.length === 0) {
    return actions;
  }

  const weekKey = localNow.startOf("week").toISODate();
  const overspendWeekKey = notificationState.overspendWeekKey;
  const overspendCount =
    overspendWeekKey === weekKey ? notificationState.overspendCount || 0 : 0;
  if (overspendCount >= 3) {
    return actions;
  }

  if (overspendItems.length > 2) {
    const categories = overspendItems
      .slice(0, 3)
      .map((item) => item.category);
    actions.push({
      type: "overspend-aggregate",
      title: "Budget alert",
      body: `You’re over budget in ${overspendItems.length} categories: ${categories.join(
        ", "
      )}.`,
    });
  } else {
    overspendItems.forEach((item) => {
      const title =
        item.severity === "severe" ? "Budget alert" : "Overspending alert";
      actions.push({
        type: "overspend",
        title,
        body: `You’re ${
          item.severity === "severe" ? "well over" : "over"
        } budget in ${item.category} this month.`,
      });
    });
  }

  return actions.slice(0, Math.max(0, 3 - overspendCount));
}

function handlePositiveReinforcement({
  localNow,
  currentMonth,
  monthlyTotals,
  notificationState,
}) {
  const actions = [];
  const monthProgress = localNow.day / localNow.daysInMonth;
  if (monthProgress <= 0.5) {
    return actions;
  }

  const monthKey = localNow.toFormat("yyyy-MM");
  const hasSentMonthly =
    notificationState.lastPositiveReinforcementAt &&
    DateTime.fromJSDate(notificationState.lastPositiveReinforcementAt.toDate())
      .toFormat("yyyy-MM") === monthKey;

  if (!hasSentMonthly && currentMonth.totalBudget > 0) {
    if (currentMonth.totalSpending <= currentMonth.totalBudget) {
      actions.push({
        type: "positive-monthly",
        title: "Nice work!",
        body: "You’re under budget this month. Keep it going 🎉",
      });
    }
  }

  if (localNow.day <= ROLLOVER_WINDOW_DAYS) {
    const streakMonths = getRecentMonthKeys(localNow, 3);
    const streakMet = streakMonths.every((key) => {
      const data = monthlyTotals[key];
      return data && data.totalBudget > 0 && data.totalSpending <= data.totalBudget;
    });

    const hasSentStreak =
      notificationState.lastStreakNotificationAt &&
      DateTime.fromJSDate(notificationState.lastStreakNotificationAt.toDate())
        .toFormat("yyyy-MM") === monthKey;

    if (streakMet && !hasSentStreak) {
      actions.push({
        type: "positive-streak",
        title: "3-month streak!",
        body: "You’ve stayed under budget for three months in a row. Amazing consistency 🔥",
      });
    }
  }

  return actions;
}

function handleGoalProgress({ localNow, goals, notificationState }) {
  if (!goals || goals.length === 0) {
    return [];
  }

  const actionableGoals = goals
    .filter((goal) => goal.deadline)
    .map((goal) => {
      const deadline = goal.deadline.toDate
        ? goal.deadline.toDate()
        : goal.deadline;
      const daysRemaining = Math.floor(
        DateTime.fromJSDate(deadline).diff(localNow, "days").days
      );
      return { ...goal, daysRemaining };
    })
    .filter(
      (goal) =>
        (goal.daysRemaining >= 29 && goal.daysRemaining <= 30) ||
        (goal.daysRemaining >= 0 && goal.daysRemaining <= 7)
    );

  if (actionableGoals.length === 0) {
    return [];
  }

  const weekKey = localNow.startOf("week").toISODate();
  const goalWeekKey = notificationState.goalWeekKey;
  const goalCount = goalWeekKey === weekKey ? notificationState.goalCount || 0 : 0;
  if (goalCount >= 3) {
    return [];
  }

  const sortedGoals = actionableGoals.sort((a, b) => {
    if (a.daysRemaining === b.daysRemaining) {
      return b.targetAmount - a.targetAmount;
    }
    return a.daysRemaining - b.daysRemaining;
  });

  const callout = sortedGoals[0];
  const descriptor =
    callout.daysRemaining <= 7 ? "Closest deadline" : "Upcoming deadline";

  return [
    {
      type: "goal-aggregate",
      title: "Goals need attention",
      body: `${actionableGoals.length} goals need attention. ${descriptor}: ${callout.name}.`,
    },
  ];
}

function missingBroadCategories(categoryTotals) {
  return BROAD_CATEGORIES.filter(
    (category) => !categoryTotals[category] || categoryTotals[category] === 0
  );
}

function getRecentMonthKeys(localNow, count) {
  return Array.from({ length: count }, (_, index) =>
    localNow.minus({ months: index + 1 }).toFormat("yyyy-MM")
  );
}

async function sendNotifications(tokens, actions) {
  const payloads = actions.map((action) => ({
    notification: {
      title: action.title,
      body: action.body,
    },
    data: {
      type: action.type,
    },
    tokens,
  }));

  const results = [];
  for (const payload of payloads) {
    const response = await admin.messaging().sendMulticast(payload);
    if (response.failureCount > 0) {
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          console.warn("Notification failure", tokens[idx], resp.error);
        }
      });
    }
    if (response.successCount > 0) {
      results.push(payload.data.type);
    }
  }

  return results;
}

function buildNotificationStateUpdates({ localNow, notificationState, sent }) {
  const updates = {};
  const weekKey = localNow.startOf("week").toISODate();

  if (sent.includes("data-entry-current")) {
    updates.lastCurrentMonthReminderAt = admin.firestore.Timestamp.fromDate(
      localNow.toJSDate()
    );
  }
  if (sent.includes("data-entry-previous")) {
    updates.lastPreviousMonthReminderAt = admin.firestore.Timestamp.fromDate(
      localNow.toJSDate()
    );
  }
  if (sent.includes("positive-monthly")) {
    updates.lastPositiveReinforcementAt = admin.firestore.Timestamp.fromDate(
      localNow.toJSDate()
    );
  }
  if (sent.includes("positive-streak")) {
    updates.lastStreakNotificationAt = admin.firestore.Timestamp.fromDate(
      localNow.toJSDate()
    );
  }

  const overspendCount =
    notificationState.overspendWeekKey === weekKey
      ? notificationState.overspendCount || 0
      : 0;
  if (sent.includes("overspend") || sent.includes("overspend-aggregate")) {
    updates.overspendWeekKey = weekKey;
    updates.overspendCount =
      overspendCount +
      sent.filter((type) => type.startsWith("overspend")).length;
  }

  const goalCount =
    notificationState.goalWeekKey === weekKey
      ? notificationState.goalCount || 0
      : 0;
  if (sent.includes("goal-aggregate")) {
    updates.goalWeekKey = weekKey;
    updates.goalCount = goalCount + 1;
  }

  return updates;
}
