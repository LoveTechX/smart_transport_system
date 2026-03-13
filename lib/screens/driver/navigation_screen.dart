import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {

  GoogleMapController? mapController;

  static const LatLng startPoint =
      LatLng(31.3260, 75.5762);

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("Driver Navigation"),
        centerTitle: true,
      ),

      body: GoogleMap(

        initialCameraPosition:
        const CameraPosition(
          target: startPoint,
          zoom: 15,
        ),

        onMapCreated: (controller) {
          mapController = controller;
        },

        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        zoomControlsEnabled: true,

        markers: {
          Marker(
            markerId: const MarkerId("bus"),
            position: startPoint,
          )
        },

      ),

    );

  }
}