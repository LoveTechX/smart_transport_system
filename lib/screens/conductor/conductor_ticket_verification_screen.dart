import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ConductorTicketVerificationScreen extends StatefulWidget {
  const ConductorTicketVerificationScreen({
    super.key,
    required this.conductorId,
    this.currentRouteId,
  });

  final String conductorId;
  final String? currentRouteId;

  @override
  State<ConductorTicketVerificationScreen> createState() =>
      _ConductorTicketVerificationScreenState();
}

class _ConductorTicketVerificationScreenState
    extends State<ConductorTicketVerificationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  bool _isProcessingScan = false;
  bool _isVerifying = false;

  String? _ticketId;
  String? _statusMessage;
  TicketValidationState _validationState = TicketValidationState.idle;
  DocumentReference<Map<String, dynamic>>? _ticketRef;
  Map<String, dynamic>? _ticketData;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessingScan || _isVerifying) {
      return;
    }

    final raw = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (raw == null || raw.isEmpty) {
      return;
    }

    await _scannerController.stop();

    setState(() {
      _isProcessingScan = true;
      _statusMessage = null;
      _ticketData = null;
      _ticketRef = null;
      _ticketId = null;
      _validationState = TicketValidationState.idle;
    });

    final parsedTicketId = _extractTicketId(raw);
    if (parsedTicketId == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isProcessingScan = false;
        _validationState = TicketValidationState.invalidPayload;
        _statusMessage = 'Invalid QR payload. Expected a ticketId.';
      });
      return;
    }

    await _loadTicket(parsedTicketId);
  }

  String? _extractTicketId(String rawPayload) {
    final payload = rawPayload.trim();
    if (payload.isEmpty) {
      return null;
    }

    // Handle JSON payloads like: {"ticketId":"abc123"}
    if (payload.startsWith('{') && payload.endsWith('}')) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, dynamic>) {
          final ticketId = decoded['ticketId']?.toString().trim();
          if (ticketId != null && ticketId.isNotEmpty) {
            return ticketId;
          }
        }
      } catch (_) {
        // Ignore and try other payload formats.
      }
    }

    // Handle URI payloads like: app://ticket?ticketId=abc123 or .../tickets/abc123
    final uri = Uri.tryParse(payload);
    if (uri != null) {
      final queryTicketId = uri.queryParameters['ticketId']?.trim();
      if (queryTicketId != null && queryTicketId.isNotEmpty) {
        return queryTicketId;
      }

      final segments = uri.pathSegments;
      final ticketsIndex = segments.indexOf('tickets');
      if (ticketsIndex >= 0 && ticketsIndex + 1 < segments.length) {
        final pathTicketId = segments[ticketsIndex + 1].trim();
        if (pathTicketId.isNotEmpty) {
          return pathTicketId;
        }
      }
    }

    // Handle prefixed payloads like: ticketId:abc123
    final lower = payload.toLowerCase();
    if (lower.startsWith('ticketid:')) {
      final split = payload.split(':');
      if (split.length >= 2) {
        final value = split.sublist(1).join(':').trim();
        if (value.isNotEmpty) {
          return value;
        }
      }
    }

    // Fallback: assume the payload is the ticketId itself.
    return payload;
  }

  Future<void> _loadTicket(String ticketId) async {
    try {
      final ref = _firestore.collection('tickets').doc(ticketId);
      final snapshot = await ref.get();

      if (!mounted) {
        return;
      }

      if (!snapshot.exists) {
        setState(() {
          _isProcessingScan = false;
          _ticketId = ticketId;
          _validationState = TicketValidationState.notFound;
          _statusMessage = 'Ticket not found.';
        });
        return;
      }

      final data = snapshot.data();
      if (data == null) {
        setState(() {
          _isProcessingScan = false;
          _ticketId = ticketId;
          _validationState = TicketValidationState.notFound;
          _statusMessage = 'Ticket data is empty.';
        });
        return;
      }

      final routeId = data['routeId']?.toString().trim();
      final status = data['status']?.toString().trim().toLowerCase() ?? '';

      TicketValidationState validationState = TicketValidationState.ready;
      String? statusMessage;

      if (_isAlreadyUsed(status)) {
        validationState = TicketValidationState.alreadyUsed;
        statusMessage = 'Ticket already used.';
      } else if (_hasRouteMismatch(routeId)) {
        validationState = TicketValidationState.routeMismatch;
        statusMessage =
            'Route mismatch. Expected ${widget.currentRouteId}, got ${routeId ?? 'unknown'}.';
      }

      setState(() {
        _isProcessingScan = false;
        _ticketId = ticketId;
        _ticketRef = ref;
        _ticketData = data;
        _validationState = validationState;
        _statusMessage = statusMessage;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isProcessingScan = false;
        _validationState = TicketValidationState.error;
        _statusMessage = 'Failed to load ticket. Please try again.';
      });
    }
  }

  bool _hasRouteMismatch(String? ticketRouteId) {
    final requiredRoute = widget.currentRouteId?.trim();
    if (requiredRoute == null || requiredRoute.isEmpty) {
      return false;
    }
    return ticketRouteId == null || ticketRouteId != requiredRoute;
  }

  bool _isAlreadyUsed(String status) {
    return status == 'verified' || status == 'used';
  }

  Future<void> _verifyTicket() async {
    final ticketRef = _ticketRef;
    if (ticketRef == null || _ticketId == null || _isVerifying) {
      return;
    }

    setState(() {
      _isVerifying = true;
      _statusMessage = null;
    });

    try {
      await _firestore.runTransaction((transaction) async {
        final freshSnapshot = await transaction.get(ticketRef);

        if (!freshSnapshot.exists) {
          throw const TicketVerificationException('Ticket not found.');
        }

        final data = freshSnapshot.data();
        if (data == null) {
          throw const TicketVerificationException('Ticket data is empty.');
        }

        final status = data['status']?.toString().trim().toLowerCase() ?? '';
        if (_isAlreadyUsed(status)) {
          throw const TicketVerificationException('Ticket already used.');
        }

        final routeId = data['routeId']?.toString().trim();
        if (_hasRouteMismatch(routeId)) {
          throw TicketVerificationException(
            'Route mismatch. Expected ${widget.currentRouteId}, got ${routeId ?? 'unknown'}.',
          );
        }

        final tripId = data['tripId']?.toString().trim();
        if (tripId == null || tripId.isEmpty) {
          throw const TicketVerificationException('Ticket is missing tripId.');
        }

        final seatNumber = data['seatNumber']?.toString().trim();
        if (seatNumber == null || seatNumber.isEmpty) {
          throw const TicketVerificationException(
              'Ticket is missing seatNumber.');
        }

        final tripRef = _firestore.collection('trips').doc(tripId);
        final tripSnapshot = await transaction.get(tripRef);
        if (!tripSnapshot.exists) {
          throw TicketVerificationException(
              'Trip not found for ticket ($tripId).');
        }

        final tripData = tripSnapshot.data();
        if (tripData == null) {
          throw const TicketVerificationException('Trip data is empty.');
        }

        final seatMap = Map<String, dynamic>.from(
          (tripData['seatMap'] as Map?) ?? const <String, dynamic>{},
        );
        seatMap[seatNumber] = true;

        transaction.update(ticketRef, {
          'status': 'verified',
          'verifiedBy': widget.conductorId,
          'verifiedAt': FieldValue.serverTimestamp(),
        });

        transaction.update(tripRef, {
          'verifiedTicketCount': FieldValue.increment(1),
          'currentOccupancy': FieldValue.increment(1),
          'availableSeats': FieldValue.increment(-1),
          'seatMap': seatMap,
        });
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _isVerifying = false;
        _validationState = TicketValidationState.verified;
        _statusMessage = 'Ticket verified successfully.';
        _ticketData = {
          ...?_ticketData,
          'status': 'verified',
          'verifiedBy': widget.conductorId,
          'verifiedAt': DateTime.now(),
        };
      });
    } on TicketVerificationException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isVerifying = false;
        _statusMessage = e.message;
        _validationState = _stateForKnownError(e.message);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isVerifying = false;
        _validationState = TicketValidationState.error;
        _statusMessage = 'Verification failed. Please try again.';
      });
    }
  }

  TicketValidationState _stateForKnownError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('not found')) {
      return TicketValidationState.notFound;
    }
    if (lower.contains('already used')) {
      return TicketValidationState.alreadyUsed;
    }
    if (lower.contains('route mismatch')) {
      return TicketValidationState.routeMismatch;
    }
    return TicketValidationState.error;
  }

  Future<void> _resumeScanning() async {
    setState(() {
      _ticketId = null;
      _ticketRef = null;
      _ticketData = null;
      _statusMessage = null;
      _validationState = TicketValidationState.idle;
      _isProcessingScan = false;
      _isVerifying = false;
    });
    await _scannerController.start();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conductor Ticket Verification'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                aspectRatio: 1.4,
                child: MobileScanner(
                  controller: _scannerController,
                  onDetect: _onDetect,
                ),
              ),
            ),
          ),
          if (_isProcessingScan || _isVerifying)
            const Padding(
              padding: EdgeInsets.only(top: 6, bottom: 6),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildStatusCard(context, colorScheme),
                const SizedBox(height: 12),
                _buildTicketDetailsCard(context),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: _canVerify ? _verifyTicket : null,
                  icon: const Icon(Icons.verified_rounded),
                  label: Text(
                    _isVerifying ? 'Verifying...' : 'Verify Ticket',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _resumeScanning,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Scan Another Ticket'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool get _canVerify {
    return _ticketData != null &&
        !_isProcessingScan &&
        !_isVerifying &&
        _validationState == TicketValidationState.ready;
  }

  Widget _buildStatusCard(BuildContext context, ColorScheme colorScheme) {
    final (icon, color) = switch (_validationState) {
      TicketValidationState.idle => (
          Icons.qr_code_scanner_rounded,
          colorScheme.primary
        ),
      TicketValidationState.ready => (Icons.info_outline_rounded, Colors.blue),
      TicketValidationState.verified => (
          Icons.check_circle_rounded,
          Colors.green
        ),
      TicketValidationState.notFound => (Icons.search_off_rounded, Colors.red),
      TicketValidationState.alreadyUsed => (
          Icons.cancel_rounded,
          colorScheme.secondary
        ),
      TicketValidationState.routeMismatch => (
          Icons.alt_route_rounded,
          colorScheme.secondary
        ),
      TicketValidationState.invalidPayload => (
          Icons.warning_amber_rounded,
          Colors.orange
        ),
      TicketValidationState.error => (Icons.error_rounded, Colors.red),
    };

    final message = _statusMessage ??
        'Scan a passenger QR code to fetch ticket details and verify.';

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.18),
          child: Icon(icon, color: color),
        ),
        title: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        subtitle: _ticketId == null
            ? null
            : Text(
                'Ticket: $_ticketId',
                style: Theme.of(context).textTheme.labelMedium,
              ),
      ),
    );
  }

  Widget _buildTicketDetailsCard(BuildContext context) {
    final data = _ticketData;
    if (data == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No ticket loaded.'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ticket Details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            _detailRow('Seat Number', data['seatNumber']),
            _detailRow('Passenger', data['passengerId']),
            _detailRow('Route', data['routeId']),
            _detailRow('Trip', data['tripId']),
            _detailRow('Vehicle', data['vehicleId']),
            _detailRow('Status', data['status']),
            _detailRow('Verified By', data['verifiedBy']),
            _detailRow('Verified At', _formatTimestamp(data['verifiedAt'])),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, Object? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 105,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          Expanded(
            child: Text(value?.toString() ?? '--'),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Object? value) {
    if (value is Timestamp) {
      return value.toDate().toLocal().toString();
    }
    if (value is DateTime) {
      return value.toLocal().toString();
    }
    return value?.toString() ?? '--';
  }
}

enum TicketValidationState {
  idle,
  ready,
  verified,
  notFound,
  alreadyUsed,
  routeMismatch,
  invalidPayload,
  error,
}

class TicketVerificationException implements Exception {
  const TicketVerificationException(this.message);

  final String message;
}
