import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

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
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  batch.set(houseRef.collection("members").doc(request.auth.uid), {
    role: "rep",
    joinedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  batch.update(db.collection("users").doc(request.auth.uid), {
    houseIds: admin.firestore.FieldValue.arrayUnion(houseRef.id),
  });

  await batch.commit();

  return { houseId: houseRef.id, joinCode: joinCode };
});

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
    joinedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  batch.update(db.collection("users").doc(request.auth.uid), {
    houseIds: admin.firestore.FieldValue.arrayUnion(houseId),
  });

  await batch.commit();

  return { houseId: houseId, houseName: houseDoc.data()?.name };
});

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
    houseIds: admin.firestore.FieldValue.arrayRemove(houseId),
  });

  await batch.commit();

  return { success: true };
});
