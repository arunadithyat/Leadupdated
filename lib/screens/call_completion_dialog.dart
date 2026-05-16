import 'package:flutter/material.dart';
import 'package:lead_calling/api/call_log_api.dart';

class CallCompletionDialog extends StatefulWidget {
  final String doctype;
  final String docname;
  final String customerName;
  final String mobileNo;
  final Duration callDuration;

  const CallCompletionDialog({
    super.key,
    required this.doctype,
    required this.docname,
    required this.customerName,
    required this.mobileNo,
    required this.callDuration,
  });

  @override
  State<CallCompletionDialog> createState() => _CallCompletionDialogState();
}

class _CallCompletionDialogState extends State<CallCompletionDialog> {
  String _callStatus = "Connected";
  bool _attended = true;
  String _notes = "";
  bool _isSubmitting = false;

  final List<String> _statusOptions = [
    "Connected",
    "Missed",
    "Dropped",
    "Busy",
  ];

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Call Completed",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.customerName,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Duration display
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer, color: Colors.blue),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Call Duration",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            _formatDuration(widget.callDuration),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Call Status dropdown
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Call Status",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: _callStatus,
                      isExpanded: true,
                      items: _statusOptions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _callStatus = newValue;
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Attended checkbox
                CheckboxListTile(
                  value: _attended,
                  onChanged: (bool? value) {
                    setState(() {
                      _attended = value ?? true;
                    });
                  },
                  title: const Text("Customer Attended"),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 15),

                // Notes field
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Notes (Optional)",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      onChanged: (value) {
                        _notes = value;
                      },
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: "Add any notes about the call...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () {
                                Navigator.pop(context);
                              },
                        child: const Text("Cancel"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitCallCompletion,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text("Submit"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitCallCompletion() async {
    setState(() {
      _isSubmitting = true;
    });

    debugPrint("[COMPLETION] Submitting call completion...");

    try {
      // Log call completion to Error Log
      final result = await CallLogApi.updateCallLog(
        doctype: widget.doctype,
        docname: widget.docname,
        customerName: widget.customerName,
        mobileNo: widget.mobileNo,
        callDuration: widget.callDuration.inSeconds,
        callStatus: _callStatus,
        attended: _attended,
      );

      debugPrint("[COMPLETION] Result: $result");

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Call logged successfully"),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("❌ Failed to log call: ${result['message']}"),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("[COMPLETION] Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  String _formatDuration(Duration duration) {
    int seconds = duration.inSeconds;
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;

    if (minutes == 0) {
      return "$remainingSeconds seconds";
    } else if (remainingSeconds == 0) {
      return "$minutes minutes";
    } else {
      return "$minutes:${remainingSeconds.toString().padLeft(2, '0')} minutes";
    }
  }
}
