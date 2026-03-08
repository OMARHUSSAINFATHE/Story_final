import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class StatusPrivacy extends StatefulWidget {
  const StatusPrivacy({super.key});

  @override
  State<StatusPrivacy> createState() => _StatusPrivacyState();
}
List<String> option=["Friends","Public"];
class _StatusPrivacyState extends State<StatusPrivacy> {
  String currentOption=option[0];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black26,
      appBar: AppBar(
        backgroundColor: Colors.black26,
      ),

      body:Column(
        children: [
          Container(
            decoration: BoxDecoration(color: Colors.black12),
            child: ListTile(
              title: Text(
                "Friends",
                style: TextStyle(fontSize: 20, color: Colors.white54),
              ),
              leading: Radio<String>(
                value: option[0],
                groupValue: currentOption,
                onChanged: (value) {
                  setState(() {
                    currentOption = value!;
                  });
                },
              ),
              onTap: () {
                setState(() {
                  currentOption = option[0];
                });
              },
            ),
          ),

          SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(color: Colors.black12),
            child: ListTile(
              title: Text(
                "Public",
                style: TextStyle(fontSize: 20, color: Colors.white54),
              ),
              leading: Radio<String>(
                value: option[1],
                groupValue: currentOption,
                onChanged: (value) {
                  setState(() {
                    currentOption = value!;
                  });
                },
              ),
              onTap: () {
                setState(() {
                  currentOption = option[1];
                });
              },
            ),
          ),
        ],
      )
    );
  }
}
