const { initializeApp, cert } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");

// Connect to emulators
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";

const app = initializeApp({ projectId: "choremate-82c08" });
const db = getFirestore(app);
const auth = getAuth(app);

async function seed() {
  console.log("🌱 Seeding emulator data...\n");

  // ---- CREATE USERS IN AUTH ----
  console.log("--- Creating auth users ---");

  let user1, user2, user3;

  try {
    user1 = await auth.createUser({
      uid: "user1",
      email: "test@test.com",
      password: "password123",
      displayName: "Alex Johnson",
    });
    console.log("Created user1:", user1.uid);
  } catch (e) {
    console.log("user1 already exists, skipping");
    user1 = { uid: "user1" };
  }

  try {
    user2 = await auth.createUser({
      uid: "user2",
      email: "jamie@test.com",
      password: "password123",
      displayName: "Jamie Smith",
    });
    console.log("Created user2:", user2.uid);
  } catch (e) {
    console.log("user2 already exists, skipping");
    user2 = { uid: "user2" };
  }

  try {
    user3 = await auth.createUser({
      uid: "user3",
      email: "riley@test.com",
      password: "password123",
      displayName: "Riley Chen",
    });
    console.log("Created user3:", user3.uid);
  } catch (e) {
    console.log("user3 already exists, skipping");
    user3 = { uid: "user3" };
  }

  // ---- CREATE USER DOCUMENTS IN FIRESTORE ----
  console.log("\n--- Creating user documents ---");

  const houseId = "test-house-001";

  await db
    .collection("users")
    .doc("user1")
    .set({
      displayName: "Alex Johnson",
      email: "test@test.com",
      houseIds: [houseId],
    });
  console.log("Created user1 document");

  await db
    .collection("users")
    .doc("user2")
    .set({
      displayName: "Jamie Smith",
      email: "jamie@test.com",
      houseIds: [houseId],
    });
  console.log("Created user2 document");

  await db
    .collection("users")
    .doc("user3")
    .set({
      displayName: "Riley Chen",
      email: "riley@test.com",
      houseIds: [houseId],
    });
  console.log("Created user3 document");

  // ---- CREATE HOUSE ----
  console.log("\n--- Creating house ---");

  await db.collection("houses").doc(houseId).set({
    name: "Elm Street House",
    joinCode: "ELM123",
    rules:
      "1. No shoes inside\n2. Quiet hours after 10pm\n3. Clean up after yourself\n4. Take turns buying shared supplies",
    createdBy: "user1",
    createdAt: new Date(),
  });
  console.log("Created house: Elm Street House (join code: ELM123)");

  // ---- ADD MEMBERS ----
  console.log("\n--- Adding members ---");

  const membersRef = db.collection("houses").doc(houseId).collection("members");

  await membersRef.doc("user1").set({
    role: "rep",
    joinedAt: new Date(),
  });
  console.log("Added user1 as rep");

  await membersRef.doc("user2").set({
    role: "member",
    joinedAt: new Date(),
  });
  console.log("Added user2 as member");

  await membersRef.doc("user3").set({
    role: "member",
    joinedAt: new Date(),
  });
  console.log("Added user3 as member");

  // ---- CREATE CHORES ----
  console.log("\n--- Creating chores ---");

  const choresRef = db.collection("houses").doc(houseId).collection("chores");

  const today = new Date();
  const tomorrow = new Date(today);
  tomorrow.setDate(tomorrow.getDate() + 1);
  const nextWeek = new Date(today);
  nextWeek.setDate(nextWeek.getDate() + 7);

  await choresRef.add({
    name: "Take out trash",
    assignedTo: "user1",
    dueDate: today,
    recurrence: "weekly",
    completed: false,
    createdBy: "user1",
    createdAt: new Date(),
  });
  console.log("Created chore: Take out trash (user1, weekly)");

  await choresRef.add({
    name: "Vacuum living room",
    assignedTo: "user2",
    dueDate: tomorrow,
    recurrence: "weekly",
    completed: false,
    createdBy: "user1",
    createdAt: new Date(),
  });
  console.log("Created chore: Vacuum living room (user2, weekly)");

  await choresRef.add({
    name: "Clean bathroom",
    assignedTo: "user3",
    dueDate: tomorrow,
    recurrence: "biweekly",
    completed: false,
    createdBy: "user1",
    createdAt: new Date(),
  });
  console.log("Created chore: Clean bathroom (user3, biweekly)");

  await choresRef.add({
    name: "Wash dishes",
    assignedTo: "user1",
    dueDate: today,
    recurrence: "daily",
    completed: true,
    completedBy: "user1",
    completedAt: new Date(),
    createdBy: "user1",
    createdAt: new Date(),
  });
  console.log("Created chore: Wash dishes (user1, daily, completed)");

  await choresRef.add({
    name: "Mow the lawn",
    assignedTo: "user2",
    dueDate: nextWeek,
    recurrence: "biweekly",
    completed: false,
    createdBy: "user1",
    createdAt: new Date(),
  });
  console.log("Created chore: Mow the lawn (user2, biweekly)");

  await choresRef.add({
    name: "Buy groceries",
    assignedTo: "user3",
    dueDate: tomorrow,
    recurrence: "weekly",
    completed: false,
    createdBy: "user3",
    createdAt: new Date(),
  });
  console.log("Created chore: Buy groceries (user3, weekly)");

  // ---- CREATE EVENTS ----
  console.log("\n--- Creating events ---");

  const eventsRef = db.collection("houses").doc(houseId).collection("events");

  const thisWeekend = new Date(today);
  thisWeekend.setDate(thisWeekend.getDate() + (6 - thisWeekend.getDay()));
  thisWeekend.setHours(18, 0, 0, 0);

  const nextMonday = new Date(today);
  nextMonday.setDate(nextMonday.getDate() + ((8 - nextMonday.getDay()) % 7));
  nextMonday.setHours(19, 0, 0, 0);

  const inTwoWeeks = new Date(today);
  inTwoWeeks.setDate(inTwoWeeks.getDate() + 14);
  inTwoWeeks.setHours(10, 0, 0, 0);

  await eventsRef.add({
    title: "House Movie Night",
    description: "Voting on movies in the group chat. Bring snacks!",
    startDate: thisWeekend,
    endDate: null,
    createdBy: "user2",
    createdAt: new Date(),
  });
  console.log("Created event: House Movie Night");

  await eventsRef.add({
    title: "House Meeting",
    description: "Discuss chore rotation and quiet hours",
    startDate: nextMonday,
    endDate: null,
    createdBy: "user1",
    createdAt: new Date(),
  });
  console.log("Created event: House Meeting");

  await eventsRef.add({
    title: "Deep Clean Day",
    description: "Everyone pitches in for a full house deep clean",
    startDate: inTwoWeeks,
    endDate: null,
    createdBy: "user1",
    createdAt: new Date(),
  });
  console.log("Created event: Deep Clean Day");

  // ---- CREATE CONTACTS ----
  console.log("\n--- Creating contacts ---");

  const contactsRef = db
    .collection("houses")
    .doc(houseId)
    .collection("contacts");

  await contactsRef.add({
    name: "Bob Martinez",
    phone: "555-123-4567",
    label: "landlord",
    createdBy: "user1",
    createdAt: new Date(),
  });
  console.log("Created contact: Bob Martinez (landlord)");

  await contactsRef.add({
    name: "QuickFix Plumbing",
    phone: "555-234-5678",
    label: "plumber",
    createdBy: "user1",
    createdAt: new Date(),
  });
  console.log("Created contact: QuickFix Plumbing (plumber)");

  await contactsRef.add({
    name: "Sparky Electric",
    phone: "555-345-6789",
    label: "electrician",
    createdBy: "user1",
    createdAt: new Date(),
  });
  console.log("Created contact: Sparky Electric (electrician)");

  await contactsRef.add({
    name: "City Water Department",
    phone: "555-456-7890",
    label: "utility",
    createdBy: "user1",
    createdAt: new Date(),
  });
  console.log("Created contact: City Water Department (utility)");

  console.log("\n✅ Seed complete!");
  console.log("\nTest accounts:");
  console.log("  test@test.com / password123 (Alex - rep)");
  console.log("  jamie@test.com / password123 (Jamie - member)");
  console.log("  riley@test.com / password123 (Riley - member)");
  console.log("  Join code: ELM123");

  process.exit(0);
}

seed().catch((err) => {
  console.error("❌ Seed failed:", err.message);
  process.exit(1);
});
