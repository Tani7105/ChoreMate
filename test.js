const { initializeApp } = require("firebase/app");
const {
  getAuth,
  connectAuthEmulator,
  signInWithEmailAndPassword,
} = require("firebase/auth");
const {
  getFunctions,
  connectFunctionsEmulator,
  httpsCallable,
} = require("firebase/functions");
const {
  getFirestore,
  connectFirestoreEmulator,
} = require("firebase/firestore");

const app = initializeApp({
  projectId: "choremate-82c08",
  apiKey: "fake-api-key",
});
const auth = getAuth(app);
const functions = getFunctions(app);
const firestore = getFirestore(app);

connectAuthEmulator(auth, "http://127.0.0.1:9099");
connectFunctionsEmulator(functions, "127.0.0.1", 5001);
connectFirestoreEmulator(firestore, "127.0.0.1", 8080);

async function runTests() {
  // Sign in with the user you created in the Auth emulator
  const userCred = await signInWithEmailAndPassword(
    auth,
    "test@test.com",
    "password123"
  );
  console.log("Signed in as:", userCred.user.uid);

  // Test 1: Create a house
  console.log("\n--- Test 1: Creating house ---");
  const createHouse = httpsCallable(functions, "createHouse");
  const houseResult = await createHouse({
    name: "Test House",
    rules: "No shoes inside",
  });
  console.log("House created:", houseResult.data);

  const houseId = houseResult.data.houseId;
  const joinCode = houseResult.data.joinCode;

  // Test 2: Create a chore
  console.log("\n--- Test 2: Creating chore ---");
  const createChore = httpsCallable(functions, "createChore");
  const choreResult = await createChore({
    houseId: houseId,
    name: "Take out trash",
    assignedTo: userCred.user.uid,
    dueDate: new Date().toISOString(),
    recurrence: "weekly",
  });
  console.log("Chore created:", choreResult.data);

  // Test 3: Complete the chore
  console.log("\n--- Test 3: Completing chore ---");
  const completeChore = httpsCallable(functions, "completeChore");
  const completeResult = await completeChore({
    houseId: houseId,
    choreId: choreResult.data.choreId,
  });
  console.log("Chore completed:", completeResult.data);

  // Test 4: Create an event
  console.log("\n--- Test 4: Creating event ---");
  const createEvent = httpsCallable(functions, "createEvent");
  const eventResult = await createEvent({
    houseId: houseId,
    title: "House Meeting",
    description: "Discuss chore schedule",
    startDate: new Date(Date.now() + 86400000).toISOString(),
  });
  console.log("Event created:", eventResult.data);

  // Test 5: Update the event
  console.log("\n--- Test 5: Updating event ---");
  const updateEvent = httpsCallable(functions, "updateEvent");
  const updateResult = await updateEvent({
    houseId: houseId,
    eventId: eventResult.data.eventId,
    title: "House Meeting - URGENT",
  });
  console.log("Event updated:", updateResult.data);

  // Test 6: Get upcoming events
  console.log("\n--- Test 6: Getting upcoming events ---");
  const getUpcomingEvents = httpsCallable(functions, "getUpcomingEvents");
  const eventsResult = await getUpcomingEvents({ houseId: houseId });
  console.log("Upcoming events:", eventsResult.data);

  // Test 7: Delete event
  console.log("\n--- Test 7: Deleting event ---");
  const deleteEvent = httpsCallable(functions, "deleteEvent");
  const deleteResult = await deleteEvent({
    houseId: houseId,
    eventId: eventResult.data.eventId,
  });
  console.log("Event deleted:", deleteResult.data);

  // Test 8: Update house rules
  console.log("\n--- Test 8: Updating house rules ---");
  const updateHouseRules = httpsCallable(functions, "updateHouseRules");
  const rulesResult = await updateHouseRules({
    houseId: houseId,
    rules:
      "1. No shoes inside\n2. Quiet hours after 10pm\n3. Clean up after yourself",
  });
  console.log("Rules updated:", rulesResult.data);

  // Test 9: Get house info
  console.log("\n--- Test 9: Getting house info ---");
  const getHouseInfo = httpsCallable(functions, "getHouseInfo");
  const houseInfo = await getHouseInfo({ houseId: houseId });
  console.log("House info:", houseInfo.data);

  // Test 10: Add a contact
  console.log("\n--- Test 10: Adding contact ---");
  const addContact = httpsCallable(functions, "addContact");
  const contactResult = await addContact({
    houseId: houseId,
    name: "Bob the Plumber",
    phone: "555-123-4567",
    label: "plumber",
  });
  console.log("Contact added:", contactResult.data);

  // Test 11: Update the contact
  console.log("\n--- Test 11: Updating contact ---");
  const updateContact = httpsCallable(functions, "updateContact");
  const updateContactResult = await updateContact({
    houseId: houseId,
    contactId: contactResult.data.contactId,
    phone: "555-999-8888",
  });
  console.log("Contact updated:", updateContactResult.data);

  // Test 12: Get all contacts
  console.log("\n--- Test 12: Getting contacts ---");
  const getContacts = httpsCallable(functions, "getContacts");
  const contactsResult = await getContacts({ houseId: houseId });
  console.log("Contacts:", contactsResult.data);

  // Test 13: Delete contact
  console.log("\n--- Test 13: Deleting contact ---");
  const deleteContact = httpsCallable(functions, "deleteContact");
  const deleteContactResult = await deleteContact({
    houseId: houseId,
    contactId: contactResult.data.contactId,
  });
  console.log("Contact deleted:", deleteContactResult.data);

  // Test 14: Leave the house
  console.log("\n--- Test 14: Leaving house ---");
  const leaveHouse = httpsCallable(functions, "leaveHouse");
  const leaveResult = await leaveHouse({ houseId: houseId });
  console.log("Left house:", leaveResult.data);

  // Test 15: Join back with code
  console.log("\n--- Test 15: Joining with code ---");
  const joinHouse = httpsCallable(functions, "joinHouse");
  const joinResult = await joinHouse({ joinCode: joinCode });
  console.log("Joined house:", joinResult.data);

  console.log("\n✅ All 15 tests passed!");
  process.exit(0);
}

runTests().catch((err) => {
  console.error("❌ Test failed:", err.message);
  process.exit(1);
});
