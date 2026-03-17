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

    const before = event.data.before.data();
    const after = event.data.after.data();
    const ticketId = event.params.ticketId;

    if (!before || !after) {
        return;
    }

    if (before.status === VERIFIED_STATUS) {
        return;
    }

    if (after.status !== VERIFIED_STATUS) {
        return;
    }

    console.log('Verification transition:', before.status, '->', after.status);

    const tripId = after?.tripId;
    if (!tripId) {
        logger.warn('Skipping ticket verification update. Missing tripId.', { ticketId });
        return;
    }

    const db = admin.firestore();
    const tripRef = db.collection('trips').doc(tripId);

    const tripSnap = await tripRef.get();

    if (!tripSnap.exists) {
        logger.warn('Trip not found for verified ticket.', { ticketId, tripId });
        return;
    }

    const tripUpdate = {
        verifiedTicketCount: FieldValue.increment(1),
        currentOccupancy: FieldValue.increment(1),
        availableSeats: FieldValue.increment(-1),
    };

    if (after.seatNumber !== undefined && after.seatNumber !== null) {
        tripUpdate[`seatMap.${after.seatNumber}`] = {
            ticketId,
            status: VERIFIED_STATUS,
            verifiedAt: FieldValue.serverTimestamp(),
        };
    }

    await tripRef.update(tripUpdate);

    await event.data.after.ref.update({
        verificationProcessedAt: FieldValue.serverTimestamp(),
    });

    logger.info('Ticket verification processed.', { ticketId, tripId });
});

module.exports = {
    handleTicketVerification,
};
