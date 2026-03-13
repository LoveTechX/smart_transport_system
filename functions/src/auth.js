const admin = require('firebase-admin');
const { beforeUserCreated } = require('firebase-functions/v2/identity');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');

const ALLOWED_ROLES = new Set(['passenger', 'driver', 'conductor', 'admin']);
const DEFAULT_ROLE = 'passenger';

const assignDefaultRole = beforeUserCreated((event) => {
    const user = event.data;

    if (!user) {
        logger.warn('User creation event did not include user data.');
        return {};
    }

    logger.info('Assigning default role claim for user creation.', {
        uid: user.uid,
        role: DEFAULT_ROLE,
    });

    return {
        customClaims: {
            role: DEFAULT_ROLE,
        },
    };
});

const setUserRole = onCall(async (request) => {
    const callerRole = request.auth?.token?.role;

    if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Authentication is required.');
    }

    if (callerRole !== 'admin') {
        throw new HttpsError('permission-denied', 'Only admins can change user roles.');
    }

    const uid = request.data?.uid;
    const role = request.data?.role;

    if (typeof uid !== 'string' || uid.trim().length === 0) {
        throw new HttpsError('invalid-argument', 'A valid uid is required.');
    }

    if (typeof role !== 'string' || !ALLOWED_ROLES.has(role)) {
        throw new HttpsError(
            'invalid-argument',
            'Role must be one of passenger, driver, conductor, or admin.'
        );
    }

    try {
        const user = await admin.auth().getUser(uid);
        const existingClaims = user.customClaims || {};

        await admin.auth().setCustomUserClaims(uid, {
            ...existingClaims,
            role,
        });

        logger.info('Updated user role.', {
            changedBy: request.auth.uid,
            uid,
            role,
        });

        return {
            success: true,
            uid,
            role,
            message: 'Role updated. The user must refresh their ID token to receive the new claim.',
        };
    } catch (error) {
        logger.error('Failed to update user role.', {
            changedBy: request.auth.uid,
            uid,
            role,
            error: error instanceof Error ? error.message : error,
        });

        if (error?.code === 'auth/user-not-found') {
            throw new HttpsError('not-found', 'User not found.');
        }

        throw new HttpsError('internal', 'Unable to update user role.');
    }
});

module.exports = {
    assignDefaultRole,
    setUserRole,
};
