const admin = require('firebase-admin');
const { FieldValue } = require('firebase-admin/firestore');
const logger = require('firebase-functions/logger');
const { onDocumentUpdated } = require('firebase-functions/v2/firestore');

const VERIFIED_STATUS = 'verified';

const handleTicketVerification = onDocumentUpdated('tickets/{ticketId}', async (event) => {
    console.log("Ticket verification trigger fired:", event.params.ticketId);
    console.log("Before snapshot:", event.data?.before?.data());
    console.log("After snapshot:", event.data?.after?.data());

    if (!event.data) {
        console.log("Event data missing:", event);
        return;
    }

    if (!event.data.before || !event.data.after) {
        return;
    }

    const before = event.data.before.data();
    const after = event.data.after.data();
    const ticketId = event.params.ticketId;

    if (after?.status !== VERIFIED_STATUS) {
        return;
    }

    if (before?.status === VERIFIED_STATUS) {
        return;
    }

    const tripId = after?.tripId;
    if (!tripId) {
        logger.warn('Skipping ticket verification update. Missing tripId.', { ticketId });
        return;
    }

    const db = admin.firestore();
    const tripRef = db.collection('trips').doc(tripId);

    await db.runTransaction(async (tx) => {
        const tripSnap = await tx.get(tripRef);

        if (!tripSnap.exists) {
            logger.warn('Trip not found for verified ticket.', { ticketId, tripId });
            return;
        }

        tx.update(tripRef, {
            verifiedTicketCount: FieldValue.increment(1),
            currentOccupancy: FieldValue.increment(1),
            availableSeats: FieldValue.increment(-1),
            [`seatMap.${after.seatNumber}`]: {
                ticketId,
                status: VERIFIED_STATUS,
                verifiedAt: FieldValue.serverTimestamp(),
            },
        });

        tx.update(event.data.after.ref, {
            verificationProcessedAt: FieldValue.serverTimestamp(),
        });
    });

    logger.info('Ticket verification processed.', { ticketId, tripId });
});

module.exports = {
    handleTicketVerification,
};
