import 'package:flutter/material.dart';

import '../../models/bus_routes_repository.dart';
import '../../services/smart_transport_ai_service.dart';

class TicketScreen extends StatefulWidget {
  const TicketScreen({super.key});

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  final service = SmartTransportAIService.instance;
  final passengerController = TextEditingController(text: 'Passenger');

  String selectedRouteId = BusRoutesRepository.allRoutes.first.id;
  int seatNumber = 1;
  String generatedTicket = '';

  @override
  void dispose() {
    passengerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final route = BusRoutesRepository.getRouteById(selectedRouteId) ??
        BusRoutesRepository.allRoutes.first;

    final occupied = service.occupiedSeats(route.id);
    final available = service.availableSeats(route.id);

    return Scaffold(
      appBar: AppBar(title: const Text('QR Ticket System')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Generate Ticket',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passengerController,
                    decoration:
                        const InputDecoration(labelText: 'Passenger Name'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    key: ValueKey(selectedRouteId),
                    initialValue: selectedRouteId,
                    decoration: const InputDecoration(labelText: 'Route'),
                    items: BusRoutesRepository.allRoutes
                        .take(30)
                        .map(
                          (r) => DropdownMenuItem(
                            value: r.id,
                            child: Text(
                                '${r.routeNumber} • ${r.source} → ${r.destination}'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(
                        () => selectedRouteId = value ?? selectedRouteId),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Seat: $seatNumber'),
                      ),
                      Expanded(
                        flex: 3,
                        child: Slider(
                          value: seatNumber.toDouble(),
                          min: 1,
                          max: 40,
                          divisions: 39,
                          onChanged: (value) =>
                              setState(() => seatNumber = value.round()),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      final ticket = service.generateQrTicket(
                        passengerName: passengerController.text.trim().isEmpty
                            ? 'Passenger'
                            : passengerController.text.trim(),
                        routeId: selectedRouteId,
                        seatNumber: seatNumber,
                      );
                      setState(() => generatedTicket = ticket.ticketId);
                    },
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('Generate QR Ticket'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Smart Seat Availability',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Occupied: $occupied / 40'),
                  Text('Available: $available / 40'),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: occupied / 40,
                    minHeight: 8,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    service.isCrowded(route.id)
                        ? 'AI Crowd Detection: Overcrowding detected'
                        : 'AI Crowd Detection: Crowd level normal',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Generated Ticket',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (generatedTicket.isEmpty)
                    const Text('No ticket generated yet')
                  else ...[
                    SelectableText('Ticket ID / QR Payload:\n$generatedTicket'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Theme.of(context).colorScheme.primary),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '[QR] $generatedTicket',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
