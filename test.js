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

const app = initializeApp({
  projectId: "choremate-82c08",
  apiKey: "fake-api-key",
});
const auth = getAuth(app);
const functions = getFunctions(app);

connectAuthEmulator(auth, "http://127.0.0.1:9099");
connectFunctionsEmulator(functions, "127.0.0.1", 5001);

async function runTests() {
  // Sign in with the user you created in the Auth emulator
  const userCred = await signInWithEmailAndPassword(
    auth,
    "test@test.com",
    "password123"
  );
  console.log("Signed in as:", userCred.user.uid);

  // Test 1: Create a house
  console.log("\n--- Creating house ---");
  const createHouse = httpsCallable(functions, "createHouse");
  const houseResult = await createHouse({
    name: "Test House",
    rules: "No shoes inside",
  });
  console.log("House created:", houseResult.data);

  const houseId = houseResult.data.houseId;
  const joinCode = houseResult.data.joinCode;

  // Test 2: Create a chore
  console.log("\n--- Creating chore ---");
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
  console.log("\n--- Completing chore ---");
  const completeChore = httpsCallable(functions, "completeChore");
  const completeResult = await completeChore({
    houseId: houseId,
    choreId: choreResult.data.choreId,
  });
  console.log("Chore completed:", completeResult.data);

  // Test 4: Leave the house
  console.log("\n--- Leaving house ---");
  const leaveHouse = httpsCallable(functions, "leaveHouse");
  const leaveResult = await leaveHouse({ houseId: houseId });
  console.log("Left house:", leaveResult.data);

  // Test 5: Join back with code
  console.log("\n--- Joining with code ---");
  const joinHouse = httpsCallable(functions, "joinHouse");
  const joinResult = await joinHouse({ joinCode: joinCode });
  console.log("Joined house:", joinResult.data);

  console.log("\n✅ All tests passed!");
  process.exit(0);
}

runTests().catch((err) => {
  console.error("❌ Test failed:", err.message);
  process.exit(1);
});
