import 'package:flutter/material.dart';

class ExamStudentMonitoring extends StatefulWidget {
  @override
  _ExamStudentMonitoringState createState() => _ExamStudentMonitoringState();
}

class _ExamStudentMonitoringState extends State<ExamStudentMonitoring> {
  List<Student> students = [];
  String filter = '';

  @override
  void initState() {
    super.initState();
    // Initialize with fetching data
    fetchStudentData();
  }

  void fetchStudentData() {
    // Fetch student data from API or database
  }

  void resetStudentStatus() {
    // Reset the status of all students
  }

  void filterStudents() {
    // Implement filtering logic based on the filter value
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Exam Student Monitoring'),
      ),
      body: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              labelText: 'Filter by name or status',
            ),
            onChanged: (value) {
              setState(() {
                filter = value;
              });
              filterStudents();
            },
          ),
          Expanded(
            child: ListView.builder(
              itemCount: students.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(students[index].name),
                  subtitle: Text('Status: ${students[index].status}'),
                  trailing: IconButton(
                    icon: Icon(Icons.reset_tv),
                    onPressed: () {
                      // Handle reset for this student
                    },
                  ),
                );
              },
            ),
          ),
          ElevatedButton(
            onPressed: resetStudentStatus,
            child: Text('Reset All Student Statuses'),
          ),
        ],
      ),
    );
  }
}

class Student {
  String name;
  String status;

  Student(this.name, this.status);
}