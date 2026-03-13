const admin = require('firebase-admin');
const { assignDefaultRole, setUserRole } = require('./src/auth');
const { handleTicketVerification } = require('./src/triggers/ticketVerification');
const { processTelemetry } = require('./src/triggers/telemetryProcessing');
const { aggregateTripAnalytics } = require('./src/triggers/analyticsAggregation');

admin.initializeApp();

exports.assignDefaultRole = assignDefaultRole;
exports.setUserRole = setUserRole;

exports.handleTicketVerification = handleTicketVerification;
exports.processTelemetry = processTelemetry;
exports.aggregateTripAnalytics = aggregateTripAnalytics;
