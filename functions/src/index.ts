import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";

admin.initializeApp();
const db = admin.firestore();

// ============================================================
// HOUSE FUNCTIONS
// ============================================================

/*
createHouse
Allows authenticated user to create a new house. Generates a 6-character
join code, saves the house to Firestore, makes the creator 'rep', and adds
house ID to the user's profile.
*/
export const createHouse = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in");
  }

  try {
    const { name, rules } = request.data;
    if (!name || typeof name !== "string") {
      throw new HttpsError("invalid-argument", "House name is required");
    }

    const joinCode = Math.random().toString(36).substring(2, 8).toUpperCase();

    const houseRef = db.collection("houses").doc();
    const batch = db.batch();

    batch.set(houseRef, {
      name: name,
      joinCode: joinCode,
      rules: rules || "",
      createdBy: request.auth.uid,
      createdAt: FieldValue.serverTimestamp(),
    });

    batch.set(houseRef.collection("members").doc(request.auth.uid), {
      role: "rep",
      joinedAt: FieldValue.serverTimestamp(),
    });

    batch.set(
      db.collection("users").doc(request.auth.uid),
      { houseIds: FieldValue.arrayUnion(houseRef.id) },
      { merge: true }
    );

    await batch.commit();

    return { houseId: houseRef.id, joinCode: joinCode };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    console.error("createHouse error:", error);
    throw new HttpsError("internal", error.message || "Unexpected error");
  }
});

/*
joinHouse
Takes a code, looks up the matching house, checks if the user is already
a member, and if not adds them as a 'member'.
*/
export const joinHouse = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in");
  }

  try {
    const { joinCode } = request.data;
    if (!joinCode || typeof joinCode !== "string") {
      throw new HttpsError("invalid-argument", "Join code is required");
    }

    const snapshot = await db
      .collection("houses")
      .where("joinCode", "==", joinCode.toUpperCase())
      .limit(1)
      .get();

    if (snapshot.empty) {
      throw new HttpsError("not-found", "Invalid join code");
    }

    const houseDoc = snapshot.docs[0];
    const houseId = houseDoc.id;

    const memberDoc = await houseDoc.ref
      .collection("members")
      .doc(request.auth.uid)
      .get();

    if (memberDoc.exists) {
      throw new HttpsError("already-exists", "Already a member of this house");
    }

    const batch = db.batch();

    batch.set(houseDoc.ref.collection("members").doc(request.auth.uid), {
      role: "member",
      joinedAt: FieldValue.serverTimestamp(),
    });

    batch.set(
      db.collection("users").doc(request.auth.uid),
      { houseIds: FieldValue.arrayUnion(houseId) },
      { merge: true }
    );

    await batch.commit();

    return { houseId: houseId, houseName: houseDoc.data()?.name };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    console.error("joinHouse error:", error);
    throw new HttpsError("internal", error.message || "Unexpected error");
  }
});

/*
leaveHouse
Deletes the member document and removes the house ID from the user's record.
*/
export const leaveHouse = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in");
  }

  try {
    const { houseId } = request.data;
    if (!houseId || typeof houseId !== "string") {
      throw new HttpsError("invalid-argument", "House ID is required");
    }

    const memberRef = db
      .collection("houses")
      .doc(houseId)
      .collection("members")
      .doc(request.auth.uid);

    const memberDoc = await memberRef.get();
    if (!memberDoc.exists) {
      throw new HttpsError("not-found", "Not a member of this house");
    }

    const batch = db.batch();

    batch.delete(memberRef);

    batch.set(
      db.collection("users").doc(request.auth.uid),
      { houseIds: FieldValue.arrayRemove(houseId) },
      { merge: true }
    );

    await batch.commit();

    return { success: true };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    console.error("leaveHouse error:", error);
    throw new HttpsError("internal", error.message || "Unexpected error");
  }
});

// ============================================================
// CHORE FUNCTIONS
// ============================================================

/*
createChore
Lets any 'member' of a house create a chore with a name, assignee,
due date, and optional reccurrence (daily, weekly, biweekly, or monthly)
*/
export const createChore = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in");
  }

  try {
    const { houseId, name, assignedTo, dueDate, recurrence } = request.data;

    if (!houseId || !name || !assignedTo || !dueDate) {
      throw new HttpsError("invalid-argument", "Missing required fields");
    }

    const memberDoc = await db
      .collection("houses")
      .doc(houseId)
      .collection("members")
      .doc(request.auth.uid)
      .get();

    if (!memberDoc.exists) {
      throw new HttpsError("permission-denied", "Not a member of this house");
    }

    const choreRef = db
      .collection("houses")
      .doc(houseId)
      .collection("chores")
      .doc();

    await choreRef.set({
      name: name,
      assignedTo: assignedTo,
      dueDate: new Date(dueDate),
      recurrence: recurrence || "none",
      completed: false,
      createdBy: request.auth.uid,
      createdAt: FieldValue.serverTimestamp(),
    });

    return { choreId: choreRef.id };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    console.error("createChore error:", error);
    throw new HttpsError("internal", error.message || "Unexpected error");
  }
});

/*
completeChore
Marks a chore as done, recording who completed it and when.
*/
export const completeChore = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in");
  }

  try {
    const { houseId, choreId } = request.data;

    if (!houseId || !choreId) {
      throw new HttpsError("invalid-argument", "Missing required fields");
    }

    const memberDoc = await db
      .collection("houses")
      .doc(houseId)
      .collection("members")
      .doc(request.auth.uid)
      .get();

    if (!memberDoc.exists) {
      throw new HttpsError("permission-denied", "Not a member of this house");
    }

    const choreRef = db
      .collection("houses")
      .doc(houseId)
      .collection("chores")
      .doc(choreId);

    const choreDoc = await choreRef.get();
    if (!choreDoc.exists) {
      throw new HttpsError("not-found", "Chore not found");
    }

    await choreRef.update({
      completed: true,
      completedBy: request.auth.uid,
      completedAt: FieldValue.serverTimestamp(),
    });

    return { success: true };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    console.error("completeChore error:", error);
    throw new HttpsError("internal", error.message || "Unexpected error");
  }
});

/*
generateRecurringChores
Fires at midnight every day, scans the household for completed chorse that have
a recurrence set, calculates the next due date, creates a new uncomplete chore
*/
export const generateRecurringChores = onSchedule(
  "every day 00:00",
  async () => {
    try {
      const housesSnapshot = await db.collection("houses").get();

      for (const houseDoc of housesSnapshot.docs) {
        const choresSnapshot = await houseDoc.ref
          .collection("chores")
          .where("completed", "==", true)
          .where("recurrence", "!=", "none")
          .get();

        for (const choreDoc of choresSnapshot.docs) {
          const chore = choreDoc.data();
          const lastDue = chore.dueDate.toDate();
          let nextDue: Date;

          switch (chore.recurrence) {
            case "daily":
              nextDue = new Date(lastDue);
              nextDue.setDate(nextDue.getDate() + 1);
              break;
            case "weekly":
              nextDue = new Date(lastDue);
              nextDue.setDate(nextDue.getDate() + 7);
              break;
            case "biweekly":
              nextDue = new Date(lastDue);
              nextDue.setDate(nextDue.getDate() + 14);
              break;
            case "monthly":
              nextDue = new Date(lastDue);
              nextDue.setMonth(nextDue.getMonth() + 1);
              break;
            default:
              continue;
          }

          const today = new Date();
          today.setHours(0, 0, 0, 0);

          if (nextDue >= today) {
            const existing = await houseDoc.ref
              .collection("chores")
              .where("name", "==", chore.name)
              .where("dueDate", "==", nextDue)
              .where("completed", "==", false)
              .get();

            if (existing.empty) {
              await houseDoc.ref.collection("chores").add({
                name: chore.name,
                assignedTo: chore.assignedTo,
                dueDate: nextDue,
                recurrence: chore.recurrence,
                completed: false,
                createdBy: "system",
                createdAt: FieldValue.serverTimestamp(),
              });
            }
          }
        }
      }
    } catch (error: any) {
      console.error("generateRecurringChores error:", error);
    }
  }
);

/*
sendChoreReminders
Runs at 8am daily, finds all incomplete chores for the day, sends a push notification
via FCM to the assigned user's device.
*/
export const sendChoreReminders = onSchedule("every day 08:00", async () => {
  try {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    const housesSnapshot = await db.collection("houses").get();

    for (const houseDoc of housesSnapshot.docs) {
      const choresSnapshot = await houseDoc.ref
        .collection("chores")
        .where("completed", "==", false)
        .where("dueDate", ">=", today)
        .where("dueDate", "<", tomorrow)
        .get();

      for (const choreDoc of choresSnapshot.docs) {
        const chore = choreDoc.data();

        const userDoc = await db
          .collection("users")
          .doc(chore.assignedTo)
          .get();
        const userData = userDoc.data();

        if (userData?.fcmToken) {
          await admin.messaging().send({
            token: userData.fcmToken,
            notification: {
              title: "Chore Reminder",
              body: `"${chore.name}" is due today!`,
            },
          });
        }
      }
    }
  } catch (error: any) {
    console.error("sendChoreReminders error:", error);
  }
});
