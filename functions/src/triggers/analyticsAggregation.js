const admin = require('firebase-admin');
const { FieldValue } = require('firebase-admin/firestore');
const logger = require('firebase-functions/logger');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { runIdempotentTransaction, toDate, toNumber } = require('../utils/firestore');

function deriveTripSample(data) {
    if (!data) {
        return null;
    }

    const occupancy = toNumber(data.currentOccupancy);
    const availableSeats = toNumber(data.availableSeats);
    const capacity = Math.max(occupancy + availableSeats, 0);

    const utilization = capacity > 0 ? occupancy / capacity : null;

    const startedAt = toDate(data.startedAt);
    const endedAt = toDate(data.endedAt);
    const durationMs =
        startedAt && endedAt && endedAt.getTime() >= startedAt.getTime()
            ? endedAt.getTime() - startedAt.getTime()
            : null;

    const peakHourSource = startedAt || toDate(data.updatedAt);
    const peakHour = peakHourSource ? peakHourSource.getHours() : null;

    return {
        routeId: data.routeId || null,
        occupancy,
        utilization,
        durationMs,
        peakHour,
    };
}

function makeDelta(beforeSample, afterSample) {
    const toCount = (value) => (value === null || value === undefined ? 0 : 1);

    return {
        tripCountDelta: (afterSample ? 1 : 0) - (beforeSample ? 1 : 0),
        occupancySumDelta: (afterSample?.occupancy || 0) - (beforeSample?.occupancy || 0),
        occupancyCountDelta: toCount(afterSample?.occupancy) - toCount(beforeSample?.occupancy),
        utilizationSumDelta: (afterSample?.utilization || 0) - (beforeSample?.utilization || 0),
        utilizationCountDelta: toCount(afterSample?.utilization) - toCount(beforeSample?.utilization),
        durationSumMsDelta: (afterSample?.durationMs || 0) - (beforeSample?.durationMs || 0),
        durationCountDelta: toCount(afterSample?.durationMs) - toCount(beforeSample?.durationMs),
        beforeHour: beforeSample?.peakHour,
        afterHour: afterSample?.peakHour,
    };
}

function calculatePeakHour(hourCounts) {
    let selectedHour = null;
    let maxCount = -1;

    Object.entries(hourCounts).forEach(([hour, count]) => {
        if (count > maxCount) {
            selectedHour = Number(hour);
            maxCount = count;
        }
    });

    return selectedHour;
}

async function applyRouteAnalyticsDelta(tx, analyticsRef, delta) {
    const snap = await tx.get(analyticsRef);
    const current = snap.exists ? snap.data() : {};

    const tripCount = Math.max(0, toNumber(current._tripCount) + delta.tripCountDelta);

    const occupancySum = toNumber(current._occupancySum) + delta.occupancySumDelta;
    const occupancyCount = Math.max(0, toNumber(current._occupancyCount) + delta.occupancyCountDelta);

    const utilizationSum = toNumber(current._utilizationSum) + delta.utilizationSumDelta;
    const utilizationCount =
        Math.max(0, toNumber(current._utilizationCount) + delta.utilizationCountDelta);

    const durationSumMs = toNumber(current._durationSumMs) + delta.durationSumMsDelta;
    const durationCount = Math.max(0, toNumber(current._durationCount) + delta.durationCountDelta);

    const hourCounts = {
        ...(current._hourCounts || {}),
    };

    if (delta.beforeHour !== null && delta.beforeHour !== undefined) {
        const hourKey = String(delta.beforeHour);
        hourCounts[hourKey] = Math.max(0, toNumber(hourCounts[hourKey]) - 1);
        if (hourCounts[hourKey] === 0) {
            delete hourCounts[hourKey];
        }
    }

    if (delta.afterHour !== null && delta.afterHour !== undefined) {
        const hourKey = String(delta.afterHour);
        hourCounts[hourKey] = Math.max(0, toNumber(hourCounts[hourKey]) + 1);
    }

    const averageOccupancy = occupancyCount > 0 ? occupancySum / occupancyCount : 0;
    const averageTripDuration = durationCount > 0 ? durationSumMs / durationCount : 0;
    const utilization = utilizationCount > 0 ? utilizationSum / utilizationCount : 0;
    const peakHour = calculatePeakHour(hourCounts);

    tx.set(
        analyticsRef,
        {
            averageOccupancy,
            peakHour,
            averageTripDuration,
            utilization,
            _tripCount: tripCount,
            _occupancySum: occupancySum,
            _occupancyCount: occupancyCount,
            _utilizationSum: utilizationSum,
            _utilizationCount: utilizationCount,
            _durationSumMs: durationSumMs,
            _durationCount: durationCount,
            _hourCounts: hourCounts,
            updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
    );
}

const aggregateTripAnalytics = onDocumentWritten('trips/{tripId}', async (event) => {
    const beforeData = event.data?.before?.exists ? event.data.before.data() : null;
    const afterData = event.data?.after?.exists ? event.data.after.data() : null;

    const beforeSample = deriveTripSample(beforeData);
    const afterSample = deriveTripSample(afterData);

    if (!beforeSample && !afterSample) {
        return;
    }

    const db = admin.firestore();

    const outcome = await runIdempotentTransaction({
        eventId: event.id,
        operationName: 'analyticsAggregation',
        handler: async (tx) => {
            const beforeRouteId = beforeSample?.routeId;
            const afterRouteId = afterSample?.routeId;

            if (!beforeRouteId && !afterRouteId) {
                return;
            }

            if (beforeRouteId && afterRouteId && beforeRouteId !== afterRouteId) {
                const removeDelta = makeDelta(beforeSample, null);
                const addDelta = makeDelta(null, afterSample);

                await applyRouteAnalyticsDelta(
                    tx,
                    db.collection('analytics').doc(beforeRouteId),
                    removeDelta
                );

                await applyRouteAnalyticsDelta(
                    tx,
                    db.collection('analytics').doc(afterRouteId),
                    addDelta
                );

                return;
            }

            const routeId = afterRouteId || beforeRouteId;
            const delta = makeDelta(beforeSample, afterSample);

            await applyRouteAnalyticsDelta(tx, db.collection('analytics').doc(routeId), delta);
        },
    });

    if (outcome.skipped) {
        logger.debug('Analytics event already processed.', {
            eventId: event.id,
            tripId: event.params.tripId,
        });
        return;
    }

    logger.info('Trip analytics aggregated.', {
        eventId: event.id,
        tripId: event.params.tripId,
    });

    const crowdSource = afterData || beforeData;
    if (!crowdSource?.vehicleId) {
        return;
    }

    const vehicleId = crowdSource.vehicleId;
    const currentOccupancy = toNumber(crowdSource.currentOccupancy);
    const availableSeats = toNumber(crowdSource.availableSeats);
    const capacity = currentOccupancy + availableSeats;
    const occupancyRatio = capacity > 0 ? currentOccupancy / capacity : 0;

    let crowdLevel = 'HIGH';
    if (occupancyRatio < 0.3) {
        crowdLevel = 'LOW';
    } else if (occupancyRatio < 0.7) {
        crowdLevel = 'MEDIUM';
    }

    await db
        .collection('crowdStatus')
        .doc(vehicleId)
        .set(
            {
                vehicleId,
                currentOccupancy,
                capacity,
                occupancyRatio,
                crowdLevel,
                updatedAt: FieldValue.serverTimestamp(),
            },
            { merge: true }
        );

    console.log('Crowd status updated:', vehicleId, crowdLevel);

    const routeId = crowdSource.routeId;
    if (!routeId) {
        return;
    }

    const tripStateSnap = await db.collection('tripState').doc(vehicleId).get();
    const tripState = tripStateSnap.exists ? tripStateSnap.data() : null;
    const currentStopId = tripState?.currentStopId;
    const nextStopId = tripState?.nextStopId;

    if (!currentStopId || !nextStopId) {
        return;
    }

    const segmentId = currentStopId + '_to_' + nextStopId;

    await db
        .collection('routeCrowdHeatmap')
        .doc(routeId)
        .set(
            {
                segments: {
                    [segmentId]: crowdLevel,
                },
                updatedAt: FieldValue.serverTimestamp(),
            },
            { merge: true }
        );

    console.log('Route heatmap updated:', routeId, segmentId, crowdLevel);
});

module.exports = {
    aggregateTripAnalytics,
};
