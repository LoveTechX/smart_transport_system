/**
 * Automated emulator integration test for the telemetry processing pipeline.
 *
 * Pipeline under test:
 *   telemetry -> processTelemetry -> tripState -> etas
 *
 * Run:
 *   cd functions
 *   node test-telemetry-pipeline.js
 */

'use strict';

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.GCLOUD_PROJECT = 'demo-no-project';

const admin = require('firebase-admin');
const { FieldValue, Timestamp } = require('firebase-admin/firestore');

admin.initializeApp({
    projectId: 'demo-no-project'
});

const db = admin.firestore();

const POLL_INTERVAL_MS = 500;
const POLL_TIMEOUT_MS = 10_000;

const VEHICLE_ID = 'bus101';
const ROUTE_ID = 'route_telemetry_pipeline';
const TRIP_ID = 'trip_telemetry_pipeline';

function sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

function assert(condition, message) {
    if (!condition) {
        throw new Error(message);
    }
}

async function pollUntil(label, checkFn, timeoutMs = POLL_TIMEOUT_MS, intervalMs = POLL_INTERVAL_MS) {
    const start = Date.now();

    while (Date.now() - start <= timeoutMs) {
        const result = await checkFn();
        if (result) {
            return result;
        }

        await sleep(intervalMs);
    }

    throw new Error(`Timeout waiting for ${label} after ${timeoutMs}ms`);
}

async function safeDelete(ref) {
    const snap = await ref.get();
    if (snap.exists) {
        await ref.delete();
    }
}

async function deleteQueryDocs(query) {
    const snap = await query.get();
    if (snap.empty) {
        return;
    }

    const batch = db.batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
}

function isTimestampLike(value) {
    return value instanceof Timestamp || Boolean(value && typeof value.toDate === 'function');
}

function validateRequiredFields(data, requiredFields, label) {
    requiredFields.forEach((field) => {
        assert(data[field] !== undefined && data[field] !== null, `${label} missing required field: ${field}`);
    });
}

async function seedPipelinePrerequisites() {
    const routeRef = db.collection('routes').doc(ROUTE_ID);
    const tripRef = db.collection('trips').doc(TRIP_ID);

    await routeRef.set({
        routeId: ROUTE_ID,
        name: 'Telemetry Pipeline Test Route',
        stops: [
            {
                stopId: 'stop_alpha',
                name: 'Alpha Stop',
                latitude: 30.7325,
                longitude: 76.7784,
                sequence: 1
            },
            {
                stopId: 'stop_beta',
                name: 'Beta Stop',
                latitude: 30.7344,
                longitude: 76.7806,
                sequence: 2
            },
            {
                stopId: 'stop_gamma',
                name: 'Gamma Stop',
                latitude: 30.736,
                longitude: 76.7823,
                sequence: 3
            }
        ],
        updatedAt: FieldValue.serverTimestamp()
    });

    await tripRef.set({
        vehicleId: VEHICLE_ID,
        routeId: ROUTE_ID,
        status: 'active',
        currentOccupancy: 0,
        availableSeats: 40,
        verifiedTicketCount: 0,
        seatMap: {},
        updatedAt: FieldValue.serverTimestamp()
    });
}

async function cleanupTestDocs() {
    await safeDelete(db.collection('telemetry').doc(VEHICLE_ID));
    await safeDelete(db.collection('tripState').doc(VEHICLE_ID));
    await safeDelete(db.collection('etas').doc(VEHICLE_ID));
    await safeDelete(db.collection('routes').doc(ROUTE_ID));
    await deleteQueryDocs(
        db.collection('trips').where('vehicleId', '==', VEHICLE_ID)
    );
}

async function insertTelemetry() {
    await db.collection('telemetry').doc(VEHICLE_ID).set({
        vehicleId: VEHICLE_ID,
        latitude: 30.7333,
        longitude: 76.7794,
        speed: 60,
        heading: 120,
        updatedAt: FieldValue.serverTimestamp()
    });
}

async function waitForTripState() {
    const tripStateRef = db.collection('tripState').doc(VEHICLE_ID);

    const tripState = await pollUntil(`tripState/${VEHICLE_ID}`, async () => {
        const snap = await tripStateRef.get();
        return snap.exists ? snap.data() : null;
    });

    validateRequiredFields(
        tripState,
        ['vehicleId', 'currentStopId', 'nextStopId', 'distanceToNextStop', 'latitude', 'longitude'],
        'tripState'
    );

    assert(tripState.vehicleId === VEHICLE_ID, `tripState vehicleId expected ${VEHICLE_ID}, got ${tripState.vehicleId}`);
    assert(typeof tripState.currentStopId === 'string', 'tripState currentStopId must be a string');
    assert(typeof tripState.nextStopId === 'string', 'tripState nextStopId must be a string');
    assert(
        Number.isFinite(Number(tripState.distanceToNextStop)),
        `tripState distanceToNextStop must be numeric, got ${tripState.distanceToNextStop}`
    );
    assert(typeof tripState.latitude === 'number', 'tripState latitude must be a number');
    assert(typeof tripState.longitude === 'number', 'tripState longitude must be a number');
}

async function waitForEta() {
    const etaRef = db.collection('etas').doc(VEHICLE_ID);

    const eta = await pollUntil(`etas/${VEHICLE_ID}`, async () => {
        const snap = await etaRef.get();
        return snap.exists ? snap.data() : null;
    });

    validateRequiredFields(
        eta,
        ['vehicleId', 'nextStopId', 'predictedArrival', 'confidence', 'distanceMeters'],
        'etas'
    );

    assert(eta.vehicleId === VEHICLE_ID, `etas vehicleId expected ${VEHICLE_ID}, got ${eta.vehicleId}`);
    assert(typeof eta.nextStopId === 'string', 'etas nextStopId must be a string');
    assert(isTimestampLike(eta.predictedArrival), 'etas predictedArrival must be a Firestore Timestamp');
    assert(Number.isFinite(Number(eta.confidence)), `etas confidence must be numeric, got ${eta.confidence}`);
    assert(Number.isFinite(Number(eta.distanceMeters)), `etas distanceMeters must be numeric, got ${eta.distanceMeters}`);
}

async function main() {
    console.log('=== Telemetry Pipeline Test ===\n');

    try {
        await cleanupTestDocs();
        await seedPipelinePrerequisites();

        console.log('[1/3] Inserting telemetry...');
        await insertTelemetry();

        console.log('[2/3] Waiting for trip state update...');
        try {
            await waitForTripState();
            console.log('✔ SUCCESS Trip State Engine\n');
        } catch (error) {
            throw new Error(`Trip State Engine failed: ${error.message}`);
        }

        console.log('[3/3] Waiting for ETA prediction...');
        try {
            await waitForEta();
            console.log('✔ SUCCESS ETA Engine\n');
        } catch (error) {
            throw new Error(`ETA Engine failed: ${error.message}`);
        }

        console.log('ALL TELEMETRY PIPELINE TESTS PASSED');
    } catch (error) {
        const message = error && error.message ? error.message : String(error);
        console.error(`✖ FAILURE ${message}`);
        process.exitCode = 1;
    } finally {
        try {
            await admin.app().delete();
        } catch (error) {
            console.error('Failed to shut down Firebase Admin app:', error);
            process.exitCode = 1;
        }
    }
}

main();