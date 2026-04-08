import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";

admin.initializeApp();
const db = admin.firestore();

// ============================================================
// HOUSE FUNCTIONS
// ============================================================

// CREATE HOUSE — generates join code, makes creator the rep
export const createHouse = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in");
  }

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

  batch.update(db.collection("users").doc(request.auth.uid), {
    houseIds: FieldValue.arrayUnion(houseRef.id),
  });

  await batch.commit();

  return { houseId: houseRef.id, joinCode: joinCode };
});

// JOIN HOUSE — validates code, adds user as member
export const joinHouse = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in");
  }

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

  batch.update(db.collection("users").doc(request.auth.uid), {
    houseIds: FieldValue.arrayUnion(houseId),
  });

  await batch.commit();

  return { houseId: houseId, houseName: houseDoc.data()?.name };
});

// LEAVE HOUSE — removes member, cleans up
export const leaveHouse = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in");
  }

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

  batch.update(db.collection("users").doc(request.auth.uid), {
    houseIds: FieldValue.arrayRemove(houseId),
  });

  await batch.commit();

  return { success: true };
});

// ============================================================
// CHORE FUNCTIONS
// ============================================================

// CREATE CHORE
export const createChore = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in");
  }

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
});

// COMPLETE CHORE
export const completeChore = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in");
  }

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
});

// GENERATE RECURRING CHORES — runs every day at midnight
export const generateRecurringChores = onSchedule(
  "every day 00:00",
  async () => {
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
  }
);

// SEND CHORE REMINDERS — runs every morning at 8am
export const sendChoreReminders = onSchedule("every day 08:00", async () => {
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

      const userDoc = await db.collection("users").doc(chore.assignedTo).get();
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
});

// ============================================================
// EVENT FUNCTIONS
// ============================================================

// CREATE EVENT
export const createEvent = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in");
  }

  const { houseId, title, description, startDate, endDate } = request.data;

  if (!houseId || !title || !startDate) {
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

  const eventRef = db
    .collection("houses")
    .doc(houseId)
    .collection("events")
    .doc();

  await eventRef.set({
    title: title,
    description: description || "",
    startDate: new Date(startDate),
    endDate: endDate ? new Date(endDate) : null,
    createdBy: request.auth.uid,
    createdAt: FieldValue.serverTimestamp(),
  });

  return { eventId: eventRef.id };
});

// UPDATE EVENT
export const updateEvent = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in");
  }

  const { houseId, eventId, title, description, startDate, endDate } =
    request.data;

  if (!houseId || !eventId) {
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

  const eventRef = db
    .collection("houses")
    .doc(houseId)
    .collection("events")
    .doc(eventId);

  const eventDoc = await eventRef.get();
  if (!eventDoc.exists) {
    throw new HttpsError("not-found", "Event not found");
  }

  const updates: Record<string, any> = {};
  if (title !== undefined) updates.title = title;
  if (description !== undefined) updates.description = description;
  if (startDate !== undefined) updates.startDate = new Date(startDate);
  if (endDate !== undefined) updates.endDate = new Date(endDate);
  updates.updatedAt = FieldValue.serverTimestamp();

  await eventRef.update(updates);

  return { success: true };
});

// DELETE EVENT — rep only
export const deleteEvent = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in");
  }

  const { houseId, eventId } = request.data;

  if (!houseId || !eventId) {
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

  const memberData = memberDoc.data();
  if (memberData?.role !== "rep") {
    throw new HttpsError(
      "permission-denied",
      "Only the house rep can delete events"
    );
  }

  const eventRef = db
    .collection("houses")
    .doc(houseId)
    .collection("events")
    .doc(eventId);

  const eventDoc = await eventRef.get();
  if (!eventDoc.exists) {
    throw new HttpsError("not-found", "Event not found");
  }

  await eventRef.delete();

  return { success: true };
});

// GET UPCOMING EVENTS — returns events from today onward
export const getUpcomingEvents = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in");
  }

  const { houseId } = request.data;

  if (!houseId) {
    throw new HttpsError("invalid-argument", "House ID is required");
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

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const eventsSnapshot = await db
    .collection("houses")
    .doc(houseId)
    .collection("events")
    .where("startDate", ">=", today)
    .orderBy("startDate", "asc")
    .get();

  const events = eventsSnapshot.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
    startDate: doc.data().startDate.toDate().toISOString(),
    endDate: doc.data().endDate
      ? doc.data().endDate.toDate().toISOString()
      : null,
  }));

  return { events: events };
});

// ============================================================
// HOUSE INFO FUNCTIONS
// ============================================================

// UPDATE HOUSE RULES — rep only
export const updateHouseRules = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in");
  }

  const { houseId, rules } = request.data;

  if (!houseId || rules === undefined) {
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

  const memberData = memberDoc.data();
  if (memberData?.role !== "rep") {
    throw new HttpsError(
      "permission-denied",
      "Only the house rep can update rules"
    );
  }

  await db.collection("houses").doc(houseId).update({
    rules: rules,
    updatedAt: FieldValue.serverTimestamp(),
  });

  return { success: true };
});

// GET HOUSE INFO — returns house details and member list
export const getHouseInfo = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in");
  }

  const { houseId } = request.data;

  if (!houseId) {
    throw new HttpsError("invalid-argument", "House ID is required");
  }

  const currentMemberDoc = await db
    .collection("houses")
    .doc(houseId)
    .collection("members")
    .doc(request.auth.uid)
    .get();

  if (!currentMemberDoc.exists) {
    throw new HttpsError("permission-denied", "Not a member of this house");
  }

  const houseDoc = await db.collection("houses").doc(houseId).get();
  if (!houseDoc.exists) {
    throw new HttpsError("not-found", "House not found");
  }

  const membersSnapshot = await db
    .collection("houses")
    .doc(houseId)
    .collection("members")
    .get();

  const members = [];
  for (const memberDoc of membersSnapshot.docs) {
    const userDoc = await db.collection("users").doc(memberDoc.id).get();
    const userData = userDoc.data();
    members.push({
      uid: memberDoc.id,
      role: memberDoc.data().role,
      displayName: userData?.displayName || "Unknown",
      email: userData?.email || "",
    });
  }

  const houseData = houseDoc.data();
  return {
    name: houseData?.name,
    rules: houseData?.rules,
    joinCode: houseData?.joinCode,
    members: members,
  };
});

// ============================================================
// CONTACTS FUNCTIONS
// ============================================================

// ADD CONTACT — rep only
export const addContact = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in");
  }

  const { houseId, name, phone, label } = request.data;

  if (!houseId || !name || !phone) {
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

  const memberData = memberDoc.data();
  if (memberData?.role !== "rep") {
    throw new HttpsError(
      "permission-denied",
      "Only the house rep can add contacts"
    );
  }

  const contactRef = db
    .collection("houses")
    .doc(houseId)
    .collection("contacts")
    .doc();

  await contactRef.set({
    name: name,
    phone: phone,
    label: label || "",
    createdBy: request.auth.uid,
    createdAt: FieldValue.serverTimestamp(),
  });

  return { contactId: contactRef.id };
});

// UPDATE CONTACT — rep only
export const updateContact = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in");
  }

  const { houseId, contactId, name, phone, label } = request.data;

  if (!houseId || !contactId) {
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

  const memberData = memberDoc.data();
  if (memberData?.role !== "rep") {
    throw new HttpsError(
      "permission-denied",
      "Only the house rep can update contacts"
    );
  }

  const contactRef = db
    .collection("houses")
    .doc(houseId)
    .collection("contacts")
    .doc(contactId);

  const contactDoc = await contactRef.get();
  if (!contactDoc.exists) {
    throw new HttpsError("not-found", "Contact not found");
  }

  const updates: Record<string, any> = {};
  if (name !== undefined) updates.name = name;
  if (phone !== undefined) updates.phone = phone;
  if (label !== undefined) updates.label = label;
  updates.updatedAt = FieldValue.serverTimestamp();

  await contactRef.update(updates);

  return { success: true };
});

// DELETE CONTACT — rep only
export const deleteContact = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in");
  }

  const { houseId, contactId } = request.data;

  if (!houseId || !contactId) {
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

  const memberData = memberDoc.data();
  if (memberData?.role !== "rep") {
    throw new HttpsError(
      "permission-denied",
      "Only the house rep can delete contacts"
    );
  }

  const contactRef = db
    .collection("houses")
    .doc(houseId)
    .collection("contacts")
    .doc(contactId);

  const contactDoc = await contactRef.get();
  if (!contactDoc.exists) {
    throw new HttpsError("not-found", "Contact not found");
  }

  await contactRef.delete();

  return { success: true };
});

// GET CONTACTS — any member can view
export const getContacts = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in");
  }

  const { houseId } = request.data;

  if (!houseId) {
    throw new HttpsError("invalid-argument", "House ID is required");
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

  const contactsSnapshot = await db
    .collection("houses")
    .doc(houseId)
    .collection("contacts")
    .get();

  const contacts = contactsSnapshot.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  }));

  return { contacts: contacts };
});
