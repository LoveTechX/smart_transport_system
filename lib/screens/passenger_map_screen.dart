import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PassengerMapScreen extends StatefulWidget {
  const PassengerMapScreen({super.key});

  @override
  State<PassengerMapScreen> createState() =>
      _PassengerMapScreenState();
}

class _PassengerMapScreenState
    extends State<PassengerMapScreen> {

  LatLng busLocation =
      const LatLng(31.3260, 75.5762);

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("Passenger Bus Tracking"),
      ),

      body: StreamBuilder(

        stream: FirebaseFirestore.instance
            .collection("buses")
            .snapshots(),

        builder: (context, snapshot) {

          /// Firebase data read
          if(snapshot.hasData &&
             snapshot.data!.docs.isNotEmpty){

            var data =
            snapshot.data!.docs.first.data();

            if(data["latitude"] != null &&
               data["longitude"] != null){

              busLocation = LatLng(
                (data["latitude"] as num).toDouble(),
                (data["longitude"] as num).toDouble(),
              );

            }
          }

          return FlutterMap(

            options: MapOptions(
              initialCenter: busLocation,
              initialZoom: 15,
            ),

            children: [

              TileLayer(

                urlTemplate:
                "https://tile.openstreetmap.org/{z}/{x}/{y}.png",

                userAgentPackageName:
                "bus_tracking_system",

              ),

              MarkerLayer(

                markers: [

                  Marker(

                    point: busLocation,

                    width: 80,
                    height: 80,

                    child: const Icon(
                      Icons.directions_bus,
                      size: 45,
                      color: Colors.red,
                    ),

                  )

                ],

              ),

            ],

          );

        },

      ),

    );

  }

}