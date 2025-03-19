import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert'; // For JSON parsing
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

// Maps
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sproutique/main.dart';
import 'package:sproutique/pest_detection_page.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

// Weather API URL
final String weatherApiKey = dotenv.env['OPEN_WEATHER_API_KEY']!;
final String weatherBaseUrl = "https://api.openweathermap.org/data/2.5/weather";

class _DashboardScreenState extends State<DashboardScreen> {
  final user = FirebaseAuth.instance.currentUser;

  // Variables for sensor data
  String temperature = "Loading...";
  String humidity = "Loading...";
  String pH = "Loading...";
  String risk = "Loading...";
  bool isLoading = true;

  // Weather data variables
  String weatherCondition = "Loading...";
  String weatherTemp = "Loading...";

  // Lists to hold chart data for each field
  List<FlSpot> temperatureData = [];
  List<FlSpot> humidityData = [];
  List<FlSpot> pHData = [];
  List<FlSpot> riskData = [];

  // List of sensors with their location
  List<Map<String, dynamic>> sensors = [
    {
      "channelId": "2795414",
      "readApiKey": dotenv.env['SENSOR_READ_API_KEY']!,
      "name": "சென்சார் 1",
      "location":
          LatLng(37.7749, -122.4194), // Example location (San Francisco)
    }
  ];
  Map<String, dynamic>? selectedSensor;

  // User's current location
  LatLng? userLocation;

  @override
  void initState() {
    super.initState();
    selectedSensor = sensors.first; // Set default sensor
    fetchSensorData();
    _getUserLocation();
    fetchWeatherData();
  }

  // Method to fetch weather data based on the user's location
  Future<void> fetchWeatherData() async {
    if (userLocation == null) {
      print("User location is null, cannot fetch weather.");
      return;
    }

    print(
        "Fetching weather data for: ${userLocation!.latitude}, ${userLocation!.longitude}");

    final weatherData =
        await fetchWeather(userLocation!.latitude, userLocation!.longitude);

    setState(() {
      if (weatherData.isNotEmpty && weatherData.containsKey('weather')) {
        weatherCondition = weatherData['weather'][0]['description'];
        weatherTemp =
            "${weatherData['main']['temp']} °C"; // Assuming metric units (Celsius)
        print("Weather Updated: $weatherCondition, $weatherTemp");
      } else {
        weatherCondition = "Error";
        weatherTemp = "Error";
        print("Failed to update weather");
      }
    });
  }

  // OpenWeatherMap API Call
  Future<Map<String, dynamic>> fetchWeather(double lat, double lon) async {
    final url = Uri.parse(
      '$weatherBaseUrl?lat=$lat&lon=$lon&appid=$weatherApiKey&units=metric', // Use units=metric for Celsius
    );

    try {
      print("Fetching weather from: $url");
      final response = await http.get(url);
      print("Response Code: ${response.statusCode}");
      if (response.statusCode == 200) {
        print("Weather Data: ${response.body}");
        // Parse the response
        return json.decode(response.body);
      } else {
        print(
            "Error: Failed to fetch weather. Status Code: ${response.statusCode}");
        return {};
      }
    } catch (e) {
      print('Error fetching weather: $e');
      return {};
    }
  }

  // Method to fetch data from ThingSpeak
  Future<void> fetchSensorData() async {
    if (selectedSensor == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final url = Uri.parse(
          'https://api.thingspeak.com/channels/${selectedSensor!['channelId']}/feeds.json?api_key=${selectedSensor!['readApiKey']}&results=10');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final feeds = data['feeds'];

        // Check if there are any feeds
        if (feeds == null || feeds.isEmpty) {
          throw Exception('No data available.');
        }

        List<FlSpot> tempData = [];
        List<FlSpot> humidityDataList = [];
        List<FlSpot> pHDataList = [];
        List<FlSpot> riskDataList = [];

        for (var i = 0; i < feeds.length; i++) {
          // Make sure we have valid data before adding it
          tempData.add(
            FlSpot(
                i.toDouble(), double.tryParse(feeds[i]['field1'] ?? '0') ?? 0),
          );
          humidityDataList.add(
            FlSpot(
                i.toDouble(), double.tryParse(feeds[i]['field2'] ?? '0') ?? 0),
          );
          pHDataList.add(
            FlSpot(
                i.toDouble(), double.tryParse(feeds[i]['field3'] ?? '0') ?? 0),
          );
          riskDataList.add(
            FlSpot(
                i.toDouble(), double.tryParse(feeds[i]['field4'] ?? '0') ?? 0),
          );
        }

        // Extract latest values
        double latestTemperature =
            double.tryParse(feeds.last['field1'] ?? '0') ?? 0;
        double latestHumidity =
            double.tryParse(feeds.last['field2'] ?? '0') ?? 0;
        double latestPH = double.tryParse(feeds.last['field3'] ?? '0') ?? 0;

        setState(() {
          // Set the last valid value, or "No Data" if there are issues
          temperature = double.tryParse(feeds.last['field1'] ?? 'No Data')
                  ?.toStringAsFixed(1) ??
              "No Data";
          humidity = double.tryParse(feeds.last['field2'] ?? 'No Data')
                  ?.toStringAsFixed(1) ??
              "No Data";
          pH = double.tryParse(feeds.last['field3'] ?? 'No Data')
                  ?.toStringAsFixed(1) ??
              "No Data";
          risk = double.tryParse(feeds.last['field4'] ?? 'No Data')
                  ?.toStringAsFixed(1) ??
              "No Data";
          isLoading = false;
          temperatureData = tempData;
          humidityData = humidityDataList;
          pHData = pHDataList;
          riskData = riskDataList;
        });

        // Check conditions & trigger notifications
        checkSoilAndWeatherConditions(
            latestPH, latestHumidity, latestTemperature);
      } else {
        throw Exception('Failed to fetch data from ThingSpeak');
      }
    } catch (e) {
      setState(() {
        temperature = "Error";
        humidity = "Error";
        pH = "Error";
        risk = "Error";
        isLoading = false;
      });
      print("Error: $e");
    }
  }

  // Method to add a new sensor with location
  void _showAddSensorDialog() {
    String newChannelId = "";
    String newApiKey = "";
    String sensorName = "";
    LatLng selectedLocation = LatLng(37.7749, -122.4194); // Default location

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text("Add Sensor"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(labelText: "சென்சார் பெயர்"),
                  onChanged: (value) {
                    sensorName = value;
                  },
                ),
                TextField(
                  decoration: InputDecoration(labelText: "சேனல் ஐடி"),
                  onChanged: (value) {
                    newChannelId = value;
                  },
                ),
                TextField(
                  decoration:
                      InputDecoration(labelText: "API விசையைப் படிக்கவும்"),
                  onChanged: (value) {
                    newApiKey = value;
                  },
                ),
                SizedBox(height: 20),
                Text("சென்சார் இருப்பிடத்தைத் தேர்ந்தெடுக்கவும்",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(
                  height: 300,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: selectedLocation,
                      initialZoom: 12.0,
                      onTap: (tapPosition, point) {
                        setState(() {
                          selectedLocation = point;
                        });
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                              point: selectedLocation,
                              width: 80.0,
                              height: 80.0,
                              child: Icon(Icons.location_pin,
                                  size: 40, color: Colors.red))
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text("ரத்து செய்"),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  sensors.add({
                    "name": sensorName,
                    "channelId": newChannelId,
                    "readApiKey": newApiKey,
                    "location": selectedLocation
                  });
                  selectedSensor = sensors.last;
                  fetchSensorData();
                });
                Navigator.pop(context);
              },
              child: Text("சேமிக்க"),
            ),
          ],
        ),
      ),
    );
  }

  // Method to delete a sensor
  void _deleteSensor(Map<String, dynamic> sensorToDelete) {
    setState(() {
      sensors.remove(sensorToDelete);
      selectedSensor = sensors.isNotEmpty ? sensors.first : null;
      fetchSensorData();
    });
  }

  void showNotification(String title, String body) async {
    var androidDetails = AndroidNotificationDetails(
        'channel_id', 'Soil & Climate Alerts',
        importance: Importance.max,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(body));
    var generalNotificationDetails =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
        0, title, body, generalNotificationDetails);
  }

  void checkSoilAndWeatherConditions(
      double pH, double humidity, double temperature) {
    if (pH < 5.5) {
      showNotification("Nutrient Deficiency Alert!",
          "Low pH detected. Risk of Phosphorus, Calcium, and Magnesium deficiency.");
    }
    if (pH > 7.5) {
      showNotification("Nutrient Deficiency Alert!",
          "High pH detected. Risk of Iron, Zinc, and Manganese deficiency.");
    }
    if (humidity > 80 && temperature < 20) {
      showNotification("Waterlogging Risk!",
          "High soil humidity and low temperature detected.");
    }
    if (humidity < 30 && temperature > 35) {
      showNotification(
          "Drought Risk!", "Very low humidity and high temperature detected.");
    }
    if (temperature < 5) {
      showNotification(
          "Frost Alert!", "Temperature below 5°C. Risk of frost damage.");
    }
    if (temperature > 40 && humidity < 30) {
      showNotification("Heat Stress Warning!",
          "Temperature above 40°C with low humidity detected.");
    }
    if (humidity > 80 && (temperature >= 20 && temperature <= 30)) {
      showNotification("Fungal Disease Risk!",
          "High humidity and moderate temperature detected.");
    }
  }

  // Method to get the user's current location
  Future<void> _getUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('இருப்பிடச் சேவைகள் முடக்கப்பட்டுள்ளன.');
      return;
    }

    // Check if the user has granted location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print('இருப்பிட அனுமதிகள் மறுக்கப்பட்டன.');
        return;
      }
    }

    try {
      // Fetch the user's current location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        userLocation = LatLng(position.latitude, position.longitude);
      });

      // Now that the location is available, fetch weather data
      fetchWeatherData();
    } catch (e) {
      print("❌ இருப்பிடம் பெறுவதில் பிழை: $e");
    }
  }

  Widget _buildMapView() {
    // If userLocation is not available, use a default location (Chennai)
    LatLng mapCenter = userLocation ?? LatLng(13.0843, 80.2705);

    return FlutterMap(
      options: MapOptions(
        initialCenter: mapCenter, // Use userLocation if available
        initialZoom: 12.0,
        interactionOptions:
            const InteractionOptions(flags: ~InteractiveFlag.doubleTapZoom),
      ),
      children: [
        TileLayer(
          urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
        ),
        MarkerLayer(
          markers: sensors.map((sensor) {
            return Marker(
                point: sensor['location'],
                width: 80.0,
                height: 80.0,
                child: Icon(Icons.location_pin, size: 40, color: Colors.red));
          }).toList(),
        ),
        if (userLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: userLocation!,
                width: 80.0,
                height: 80.0,
                child: Icon(Icons.person_pin, size: 40, color: Colors.blue),
              ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('டாஷ்போர்டு'),
        actions: [
          DropdownButton<Map<String, dynamic>>(
            value: selectedSensor,
            onChanged: (newSensor) {
              setState(() {
                selectedSensor = newSensor;
                fetchSensorData();
              });
            },
            items: sensors.map((sensor) {
              return DropdownMenuItem<Map<String, dynamic>>(
                value: sensor,
                child: Text(sensor['name']),
              );
            }).toList(),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: const Color(0xFF6BF06B)),
              child: Text(
                'மெனு',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.dashboard),
              title: Text('டாஷ்போர்டு'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.map),
              title: Text('சென்சார் இடங்கள்'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(title: Text('சென்சார் இடங்கள்')),
                      body: _buildMapView(),
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.add),
              title: Text('சென்சார் சேர்க்கவும்'),
              onTap: () {
                Navigator.pop(context);
                _showAddSensorDialog();
              },
            ),
            ListTile(
              leading: Icon(Icons.delete),
              title: Text('சென்சார் அழிக்கவும்'),
              onTap: () {
                Navigator.pop(context);
                if (selectedSensor != null) {
                  _deleteSensor(selectedSensor!);
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.car_rental),
              title: Text('வாகன இயந்திர வாடகை'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(title: Text('வாகன இயந்திர வாடகை')),
                      body: Center(
                        child: Text(
                          'வாகன இயந்திர வாடகை விரைவில்!',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.language),
              title: Text('மொழி மாற்றம்'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text('மொழியைத் தேர்ந்தெடுக்கவும்'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            title: Text('English'),
                            onTap: () {
                              Navigator.pop(context);
                              // Add logic to change language (UI only)
                            },
                          ),
                          ListTile(
                            title: Text('தமிழ்'),
                            onTap: () {
                              Navigator.pop(context);
                              // Add logic to change language (UI only)
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.bug_report),
              title: Text('பூச்சி கண்டறிதல்'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PestDetectionPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('வெளியேறுதல்'),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: fetchSensorData,
        child: isLoading
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'வணக்கம், ${user?.phoneNumber ?? "User"}!',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    // Add weather data below the phone number
                    ListTile(
                      leading: Icon(Icons.cloud, color: Colors.blue),
                      title: Text('வானிலை'),
                      subtitle: Text('$weatherCondition, $weatherTemp'),
                    ),
                    SizedBox(height: 20),
                    ListTile(
                      leading: Icon(Icons.thermostat, color: Colors.red),
                      title: Text('வெப்பநிலை'),
                      subtitle: Text('$temperature °C'),
                    ),
                    _buildChart(temperatureData, Colors.red, "வெப்பநிலை"),
                    SizedBox(height: 20),
                    ListTile(
                      leading: Icon(Icons.water_drop, color: Colors.blue),
                      title: Text('ஈரப்பதம்'),
                      subtitle: Text('$humidity %'),
                    ),
                    _buildChart(humidityData, Colors.blue, "ஈரப்பதம்"),
                    SizedBox(height: 20),
                    ListTile(
                      leading: Icon(Icons.water, color: Colors.green),
                      title: Text('pH'),
                      subtitle: Text('$pH pH'),
                    ),
                    _buildChart(pHData, Colors.green, "pH"),
                    SizedBox(height: 20),
                    ListTile(
                      leading: Icon(Icons.warning, color: Colors.orange),
                      title: Text('மண் ஆரோக்கியம்'),
                      subtitle: Text(risk),
                      tileColor: _getRiskColor(double.tryParse(risk ?? '0')),
                    ),
                    _buildChart(riskData, Colors.orange, "மண் ஆரோக்கியம்"),
                  ],
                ),
              ),
      ),
    );
  }

  // Generic method to build a chart
  Widget _buildChart(List<FlSpot> data, Color color, String label) {
    if (data.isEmpty) {
      return Center(
        child: Text("No data available for $label"),
      );
    }

    double minY = getMinY(data);
    double maxY = getMaxY(data);

    // Adjust interval specifically for pH
    double interval = (label == "pH")
        ? 2 // Use fixed interval of 2 for pH chart
        : (maxY - minY) > 0
            ? (maxY - minY) / 4
            : 1;

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: interval,
                getTitlesWidget: (value, _) => Text(
                  value.toStringAsFixed(0), // Use whole numbers for pH
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 20,
                getTitlesWidget: (value, _) => Text(value.toInt().toString()),
              ),
            ),
          ),
          borderData: FlBorderData(show: true),
          minX: 0,
          maxX: data.length.toDouble(),
          minY: (label == "pH") ? 0 : minY - 1, // Set min Y to 0 for pH
          maxY: (label == "pH") ? 14 : maxY + 1, // Set max Y to 14 for pH
          lineBarsData: [
            LineChartBarData(
              spots: data,
              isCurved: true,
              color: color,
              barWidth: 4,
            ),
          ],
        ),
      ),
    );
  }

  double getMinY(List<FlSpot> data) {
    if (data.isEmpty) return 0;
    return data.map((spot) => spot.y).reduce((a, b) => a < b ? a : b);
  }

  double getMaxY(List<FlSpot> data) {
    if (data.isEmpty) return 100;
    return data.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);
  }

  // Get the risk color based on the value
  Color _getRiskColor(double? riskValue) {
    if (riskValue == null) return Colors.transparent;
    if (riskValue > 75) return Colors.red;
    if (riskValue > 50) return Colors.orange;
    return Colors.green;
  }
}
