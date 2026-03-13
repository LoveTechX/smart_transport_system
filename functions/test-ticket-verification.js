/**
 * Automated emulator test for handleTicketVerification Cloud Function.
 *
 * Prerequisites:
 *   - Firebase emulators must be running (Firestore + Functions):
 *       firebase emulators:start
 *
 * How to run:
 *   cd functions
 *   node test-ticket-verification.js
 */

'use strict';

process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "demo-no-project";

const admin = require("firebase-admin");

// ---------------------------------------------------------------------------
// Initialise Admin SDK against the emulator (no real credentials needed)
// ---------------------------------------------------------------------------
admin.initializeApp({
    projectId: "demo-no-project",
});

const db = admin.firestore();

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
function sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

function pass(msg) {
    console.log(`\n\x1b[32m✔ SUCCESS\x1b[0m  ${msg}\n`);
}

function fail(msg) {
    console.error(`\n\x1b[31m✖ FAILURE\x1b[0m  ${msg}\n`);
    process.exitCode = 1;
}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------
const TRIP_ID = 'trip1';
const TICKET_ID = 'ticket1';

const tripData = {
    vehicleId: 'bus101',
    routeId: 'route1',
    currentOccupancy: 0,
    availableSeats: 40,
    verifiedTicketCount: 0,
    seatMap: {},
};

const ticketData = {
    tripId: TRIP_ID,
    routeId: 'route1',
    vehicleId: 'bus101',
    seatNumber: '12',
    status: 'pending',
};

// ---------------------------------------------------------------------------
// Main test routine
// ---------------------------------------------------------------------------
async function main() {
    console.log('=== Ticket Verification Cloud Function – Emulator Test ===\n');

    // ------------------------------------------------------------------
    // Step 1 – Clean up any leftover documents from a previous run
    // ------------------------------------------------------------------
    console.log('[ 1/7 ] Cleaning up previous test documents…');
    await db.collection('trips').doc(TRIP_ID).delete();
    await db.collection('tickets').doc(TICKET_ID).delete();

    // ------------------------------------------------------------------
    // Step 2 – Insert trip document
    // ------------------------------------------------------------------
    console.log('[ 2/7 ] Inserting trips/trip1…');
    await db.collection('trips').doc(TRIP_ID).set(tripData);

    // ------------------------------------------------------------------
    // Step 3 – Insert ticket document (status: "pending")
    // ------------------------------------------------------------------
    console.log('[ 3/7 ] Inserting tickets/ticket1 (status: pending)…');
    await db.collection('tickets').doc(TICKET_ID).set(ticketData);

    // ------------------------------------------------------------------
    // Step 4 – Wait 1 second (let Firestore settle)
    // ------------------------------------------------------------------
    console.log('[ 4/7 ] Waiting 1 s…');
    await sleep(1000);

    // ------------------------------------------------------------------
    // Step 5 – Update ticket status → "verified"  (triggers the function)
    // ------------------------------------------------------------------
    console.log('[ 5/7 ] Updating tickets/ticket1 → status: "verified"…');
    await db.collection('tickets').doc(TICKET_ID).update({ status: 'verified' });

    // ------------------------------------------------------------------
    // Step 6 – Poll trips/trip1 every 500 ms for up to 10 s until the
    //           Cloud Function increments verifiedTicketCount to 1
    // ------------------------------------------------------------------
    console.log('[ 6/7 ] Polling trips/trip1 for up to 10 s…');
    const tripRef = db.collection('trips').doc(TRIP_ID);
    let tripSnap;
    let functionCompleted = false;
    for (let i = 0; i < 20; i++) {
        tripSnap = await tripRef.get();
        if (tripSnap.data()?.verifiedTicketCount === 1) {
            functionCompleted = true;
            break;
        }
        await sleep(500);
    }

    if (!functionCompleted) {
        fail('Timed out after 10 s – verifiedTicketCount never reached 1.');
        return;
    }

    // ------------------------------------------------------------------
    // Step 7 – Inspect the polled trip document
    // ------------------------------------------------------------------
    console.log('[ 7/7 ] Cloud Function completed. Inspecting trips/trip1…\n');

    if (!tripSnap.exists) {
        fail('trips/trip1 does not exist after the trigger ran.');
        return;
    }

    const result = tripSnap.data();

    console.log('--- trips/trip1 result ---');
    console.log(JSON.stringify(result, null, 2));
    console.log('--------------------------\n');

    // ------------------------------------------------------------------
    // Step 8/9 – Assert expected values
    // ------------------------------------------------------------------
    const errors = [];

    if (result.verifiedTicketCount !== 1) {
        errors.push(`verifiedTicketCount: expected 1, got ${result.verifiedTicketCount}`);
    }

    if (result.currentOccupancy !== 1) {
        errors.push(`currentOccupancy: expected 1, got ${result.currentOccupancy}`);
    }

    if (result.availableSeats !== 39) {
        errors.push(`availableSeats: expected 39, got ${result.availableSeats}`);
    }

    // seatMap["12"] should exist (the function stores an object with ticketId/status,
    // meaning seatMap["12"] is truthy – treated here as seatMap[12] = <present>)
    const seatEntry = result.seatMap && result.seatMap['12'];
    if (!seatEntry) {
        errors.push(`seatMap["12"]: expected a truthy entry, got ${JSON.stringify(seatEntry)}`);
    }

    if (errors.length === 0) {
        pass('All assertions passed. The handleTicketVerification Cloud Function is working correctly.');
    } else {
        fail(`${errors.length} assertion(s) failed:\n  • ` + errors.join('\n  • '));
    }
}

main().catch((err) => {
    console.error('\nUnhandled error during test run:', err);
    process.exitCode = 1;
});
