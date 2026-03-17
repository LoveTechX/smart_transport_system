const admin = require('firebase-admin');
const { Timestamp, FieldValue } = require('firebase-admin/firestore');
const logger = require('firebase-functions/logger');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { startOfMinuteEpoch, toDate, toNumber } = require('../utils/firestore');

const OVERSPEED_THRESHOLD_KMH = 80;
const OFFLINE_THRESHOLD_MS = 2 * 60 * 1000;

function toRadians(degrees) {
    return (degrees * Math.PI) / 180;
}

function haversineDistanceMeters(lat1, lon1, lat2, lon2) {
    const earthRadiusMeters = 6371000;
    const dLat = toRadians(lat2 - lat1);
    const dLon = toRadians(lon2 - lon1);

    const a =
        Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) *
        Math.sin(dLon / 2) * Math.sin(dLon / 2);

    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return earthRadiusMeters * c;
}

function createAlertId(type, vehicleId, date) {
    return `${type}_${vehicleId}_${startOfMinuteEpoch(date)}`;
}

function findStopSequence(stops, stopId) {
    if (!stopId) {
        return null;
    }

    const match = stops.find((stop) => stop.stopId === stopId);
    return match ? match.sequence : null;
}

function chooseStopWithMinDistance(stopsWithDistance) {
    if (!stopsWithDistance.length) {
        return null;
    }

    return stopsWithDistance.reduce((best, current) =>
        current.distanceMeters < best.distanceMeters ? current : best
    );
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

    const db = admin.firestore();
    const latitude = toNumber(telemetry.latitude);
    const longitude = toNumber(telemetry.longitude);

    if (Number.isFinite(latitude) && Number.isFinite(longitude)) {
        const activeTrip = await getActiveTripForVehicle(vehicleId);
        const routeId = activeTrip?.data?.routeId;

        if (routeId) {
            const routeDoc = await db.collection('routes').doc(routeId).get();
            const stops = Array.isArray(routeDoc.data()?.stops)
                ? routeDoc
                    .data()
                    .stops
                    .filter(
                        (stop) =>
                            stop &&
                            stop.stopId &&
                            Number.isFinite(toNumber(stop.latitude)) &&
                            Number.isFinite(toNumber(stop.longitude)) &&
                            Number.isFinite(toNumber(stop.sequence))
                    )
                    .map((stop) => ({
                        ...stop,
                        latitude: toNumber(stop.latitude),
                        longitude: toNumber(stop.longitude),
                        sequence: toNumber(stop.sequence),
                    }))
                    .sort((a, b) => a.sequence - b.sequence)
                : [];

            if (stops.length) {
                const tripStateRef = db.collection('tripState').doc(vehicleId);
                const tripStateSnap = await tripStateRef.get();
                const previousCurrentStopId = tripStateSnap.exists ? tripStateSnap.data()?.currentStopId : null;
                const previousCurrentSequence = findStopSequence(stops, previousCurrentStopId);

                const stopsWithDistance = stops.map((stop) => ({
                    ...stop,
                    distanceMeters: haversineDistanceMeters(
                        latitude,
                        longitude,
                        stop.latitude,
                        stop.longitude
                    ),
                }));

                const nearestStop = chooseStopWithMinDistance(stopsWithDistance) || stopsWithDistance[0];

                const currentStop = previousCurrentSequence !== null
                    ? stopsWithDistance.find((stop) => stop.sequence === previousCurrentSequence) || nearestStop
                    : nearestStop;

                const aheadStops = stopsWithDistance.filter((stop) => stop.sequence > currentStop.sequence);
                const nextStop = chooseStopWithMinDistance(aheadStops);
                const distanceToCurrentStop = currentStop.distanceMeters;
                const distanceToNextCandidate = nextStop ? nextStop.distanceMeters : null;

                // Promote progress when the vehicle gets closer to the next stop than the current one.
                const resolvedCurrentStop =
                    nextStop &&
                        distanceToNextCandidate !== null &&
                        distanceToCurrentStop !== null &&
                        distanceToNextCandidate <= distanceToCurrentStop
                        ? nextStop
                        : currentStop;

                const refreshedAheadStops = stopsWithDistance.filter(
                    (stop) => stop.sequence > resolvedCurrentStop.sequence
                );
                const resolvedNextStop = chooseStopWithMinDistance(refreshedAheadStops);
                const distanceToNextStop = resolvedNextStop ? resolvedNextStop.distanceMeters : 0;

                await tripStateRef.set(
                    {
                        vehicleId,
                        routeId,
                        currentStopId: resolvedCurrentStop.stopId,
                        nextStopId: resolvedNextStop ? resolvedNextStop.stopId : null,
                        distanceToNextStop,
                        latitude,
                        longitude,
                        updatedAt: FieldValue.serverTimestamp(),
                    },
                    { merge: true }
                );

                console.log('Trip state updated:', vehicleId);
            } else {
                logger.warn('Route has no valid stops. Trip state not updated.', {
                    eventId: event.id,
                    vehicleId,
                    routeId,
                });
            }
        } else {
            logger.warn('No active trip route found for vehicle. Trip state not updated.', {
                eventId: event.id,
                vehicleId,
            });
        }
    }

    const speedKmh = toNumber(telemetry.speedKmh);
    if (!Number.isFinite(speedKmh) || speedKmh <= 0) {
        return;
    }

    const afterData = telemetry;
    const beforeData = event.data.before?.exists ? event.data.before.data() || {} : null;

    const afterUpdatedAt = toDate(afterData.updatedAt) || new Date();
    const beforeUpdatedAt = toDate(beforeData?.updatedAt);

    const isOverspeedTransition =
        speedKmh > OVERSPEED_THRESHOLD_KMH && toNumber(beforeData?.speedKmh) <= OVERSPEED_THRESHOLD_KMH;

    if (isOverspeedTransition) {
        const alertId = createAlertId('overspeed', vehicleId, afterUpdatedAt);
        await upsertAlert({
            alertId,
            payload: {
                type: 'overspeed',
                severity: 'high',
                vehicleId,
                speedKmh,
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

    const tripStateSnap = await db.collection('tripState').doc(vehicleId).get();
    if (!tripStateSnap.exists) {
        return;
    }

    const tripState = tripStateSnap.data() || {};
    const distanceToNextStop = toNumber(tripState.distanceToNextStop);
    const nextStopId = tripState.nextStopId || null;

    const etaSeconds = (distanceToNextStop * 3.6) / speedKmh;
    const predictedArrival = Timestamp.fromMillis(Date.now() + etaSeconds * 1000);

    await db.collection('etas').doc(vehicleId).set(
        {
            vehicleId,
            nextStopId,
            predictedArrival,
            confidence: 0.9,
            distanceMeters: distanceToNextStop,
            usedFallbackSpeed: false,
            updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
    );

    console.log('Real ETA predicted:', vehicleId);

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
