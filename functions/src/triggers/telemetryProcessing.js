const admin = require('firebase-admin');
const { FieldValue } = require('firebase-admin/firestore');
const logger = require('firebase-functions/logger');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { haversineKm } = require('../utils/geo');
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

function computeEtaMinutes({ latitude, longitude, speedKmh, tripData }) {
    const nextStopLat = toNumber(tripData?.nextStopLatitude, NaN);
    const nextStopLng = toNumber(tripData?.nextStopLongitude, NaN);

    if (!Number.isFinite(nextStopLat) || !Number.isFinite(nextStopLng)) {
        return null;
    }

    if (!Number.isFinite(latitude) || !Number.isFinite(longitude) || speedKmh <= 0) {
        return null;
    }

    const distanceKm = haversineKm(latitude, longitude, nextStopLat, nextStopLng);
    const etaMinutes = (distanceKm / speedKmh) * 60;

    if (!Number.isFinite(etaMinutes) || etaMinutes < 0) {
        return null;
    }

    return {
        distanceKm,
        etaMinutes,
        nextStopLatitude: nextStopLat,
        nextStopLongitude: nextStopLng,
    };
}

const processTelemetry = onDocumentWritten('telemetry/{vehicleId}', async (event) => {
    if (!event.data?.after?.exists) {
        return;
    }

    const vehicleId = event.params.vehicleId;
    const afterData = event.data.after.data() || {};
    const beforeData = event.data.before?.exists ? event.data.before.data() || {} : null;

    const speed = toNumber(afterData.speed);
    const latitude = toNumber(afterData.latitude, NaN);
    const longitude = toNumber(afterData.longitude, NaN);

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

    const activeTrip = await getActiveTripForVehicle(vehicleId);
    const etaPrediction = computeEtaMinutes({
        latitude,
        longitude,
        speedKmh: speed,
        tripData: activeTrip?.data,
    });

    const db = admin.firestore();
    await db.collection('etas').doc(vehicleId).set(
        {
            vehicleId,
            tripId: activeTrip?.id || null,
            routeId: activeTrip?.data?.routeId || null,
            speed,
            offline: isOffline,
            etaMinutes: etaPrediction?.etaMinutes ?? null,
            distanceKm: etaPrediction?.distanceKm ?? null,
            nextStopLatitude: etaPrediction?.nextStopLatitude ?? null,
            nextStopLongitude: etaPrediction?.nextStopLongitude ?? null,
            latitude: Number.isFinite(latitude) ? latitude : null,
            longitude: Number.isFinite(longitude) ? longitude : null,
            predictedAt: FieldValue.serverTimestamp(),
            sourceTelemetryAt: afterData.updatedAt || FieldValue.serverTimestamp(),
        },
        { merge: true }
    );

    logger.info('Telemetry processed.', {
        eventId: event.id,
        vehicleId,
        overspeed: isOverspeedTransition,
        offline: isOffline,
        etaMinutes: etaPrediction?.etaMinutes ?? null,
    });
});

module.exports = {
    processTelemetry,
};
