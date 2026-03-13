const admin = require('firebase-admin');
const { Timestamp, FieldValue } = require('firebase-admin/firestore');
const logger = require('firebase-functions/logger');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { startOfMinuteEpoch, toDate, toNumber } = require('../utils/firestore');

const OVERSPEED_THRESHOLD_KMH = 80;
const OFFLINE_THRESHOLD_MS = 2 * 60 * 1000;

function createAlertId(type, vehicleId, date) {
    return `${type}_${vehicleId}_${startOfMinuteEpoch(date)}`;
}

async function upsertAlert({ alertId, payload }) {
    const db = admin.firestore();
    await db.collection('alerts').doc(alertId).set(
        {
            ...payload,
            updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
    );
}

async function getActiveTripForVehicle(vehicleId) {
    const db = admin.firestore();
    const querySnap = await db
        .collection('trips')
        .where('vehicleId', '==', vehicleId)
        .limit(1)
        .get();

    if (querySnap.empty) {
        return null;
    }

    const tripDoc = querySnap.docs[0];
    return {
        id: tripDoc.id,
        data: tripDoc.data(),
    };
}

const processTelemetry = onDocumentWritten('telemetry/{vehicleId}', async (event) => {
    if (!event.data?.after?.exists) {
        return;
    }

    const vehicleId = event.params.vehicleId;
    const telemetry = event.data.after.data();
    if (!telemetry) {
        return;
    }

    const speed = toNumber(telemetry.speed);
    if (!Number.isFinite(speed) || speed <= 0) {
        return;
    }

    const afterData = telemetry;
    const beforeData = event.data.before?.exists ? event.data.before.data() || {} : null;

    const afterUpdatedAt = toDate(afterData.updatedAt) || new Date();
    const beforeUpdatedAt = toDate(beforeData?.updatedAt);

    const isOverspeedTransition =
        speed > OVERSPEED_THRESHOLD_KMH && toNumber(beforeData?.speed) <= OVERSPEED_THRESHOLD_KMH;

    if (isOverspeedTransition) {
        const alertId = createAlertId('overspeed', vehicleId, afterUpdatedAt);
        await upsertAlert({
            alertId,
            payload: {
                type: 'overspeed',
                severity: 'high',
                vehicleId,
                speed,
                thresholdKmh: OVERSPEED_THRESHOLD_KMH,
                telemetryAt: afterData.updatedAt || FieldValue.serverTimestamp(),
                resolved: false,
            },
        });
    }

    const heartbeatGapMs =
        beforeUpdatedAt && afterUpdatedAt
            ? Math.max(0, afterUpdatedAt.getTime() - beforeUpdatedAt.getTime())
            : 0;

    const isOffline =
        heartbeatGapMs > OFFLINE_THRESHOLD_MS || Date.now() - afterUpdatedAt.getTime() > OFFLINE_THRESHOLD_MS;

    if (isOffline) {
        const alertId = createAlertId('offline', vehicleId, afterUpdatedAt);
        await upsertAlert({
            alertId,
            payload: {
                type: 'offline',
                severity: 'medium',
                vehicleId,
                heartbeatGapMs,
                telemetryAt: afterData.updatedAt || FieldValue.serverTimestamp(),
                resolved: false,
            },
        });
    }

    const speedMps = speed / 3.6;
    const distanceMeters = 2000;
    const etaSeconds = distanceMeters / speedMps;
    const predictedArrival = Timestamp.fromMillis(Date.now() + etaSeconds * 1000);

    const db = admin.firestore();
    await db.collection('etas').doc(vehicleId).set(
        {
            vehicleId,
            nextStopId: 'stop_demo',
            predictedArrival,
            confidence: 0.75,
            updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
    );

    console.log('ETA predicted for vehicle:', vehicleId);

    logger.info('Telemetry processed.', {
        eventId: event.id,
        vehicleId,
        overspeed: isOverspeedTransition,
        offline: isOffline,
        predictedArrival: predictedArrival.toMillis(),
    });
});

module.exports = {
    processTelemetry,
};
