import 'package:flutter/material.dart';

class PestDetectionPage extends StatelessWidget {
  final String _pestName = "சாய்செட்டியா நைக்ரா  (Saissetia nigra)";
  final String _detectionResult = "⚠️ பூச்சி கண்டறியப்பட்டது!";
  final String _organicPesticide = "வேப்ப எண்ணெய் (Neem Oil)";
  final String _syntheticPesticide = "Imidacloprid";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('பூச்சி கண்டறிதல்')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Static Image
            Image.asset(
              'assets/images/Pest.jpeg', // Replace with your actual image path
              height: 300,
            ),

            SizedBox(height: 20),

            // Pest Name
            Text(
              _pestName,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),

            SizedBox(height: 10),

            // Result Box
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green),
              ),
              child: Text(
                _detectionResult,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 20),
            // Pesticides Recommendations
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "✅ கரிம பூச்சிக்கொல்லி (Organic Pesticide):",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  _organicPesticide,
                  style: TextStyle(fontSize: 16, color: Colors.green[700]),
                ),
                SizedBox(height: 10),
                Text(
                  "⚠️ செயற்கை பூச்சிக்கொல்லி (Synthetic Pesticide):",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  _syntheticPesticide,
                  style: TextStyle(fontSize: 16, color: Colors.red[700]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
