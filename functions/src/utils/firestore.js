const admin = require('firebase-admin');
const { FieldValue } = require('firebase-admin/firestore');

function toNumber(value, fallback = 0) {
    const num = Number(value);
    return Number.isFinite(num) ? num : fallback;
}

function toDate(value) {
    if (!value) return null;
    if (value instanceof Date) return value;
    if (typeof value.toDate === 'function') return value.toDate();
    if (typeof value === 'number') {
        const date = new Date(value);
        return Number.isNaN(date.getTime()) ? null : date;
    }
    if (typeof value === 'string') {
        const date = new Date(value);
        return Number.isNaN(date.getTime()) ? null : date;
    }
    return null;
}

function startOfMinuteEpoch(date) {
    return Math.floor(date.getTime() / 60000) * 60000;
}

async function runIdempotentTransaction({ eventId, operationName, handler }) {
    const db = admin.firestore();
    const dedupeRef = db.collection('_functionEvents').doc(`${operationName}_${eventId}`);

    return db.runTransaction(async (tx) => {
        const dedupeSnap = await tx.get(dedupeRef);
        if (dedupeSnap.exists) {
            return { skipped: true };
        }

        const result = await handler(tx);

        tx.create(dedupeRef, {
            operationName,
            eventId,
            processedAt: FieldValue.serverTimestamp(),
        });

        return { skipped: false, result };
    });
}

module.exports = {
    runIdempotentTransaction,
    startOfMinuteEpoch,
    toDate,
    toNumber,
};
