import 'package:flutter/material.dart';
import 'package:lead_calling/models/call_queue.dart';

class CallQueueScreen extends StatefulWidget {
  final CallQueue callQueue;
  final Function(int index) onCancel;
  final Function() onClearAll;

  const CallQueueScreen({
    super.key,
    required this.callQueue,
    required this.onCancel,
    required this.onClearAll,
  });

  @override
  State<CallQueueScreen> createState() => _CallQueueScreenState();
}

class _CallQueueScreenState extends State<CallQueueScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Call Queue"),
        elevation: 0,
      ),
      body: widget.callQueue.isEmpty
          ? _buildEmptyState()
          : _buildQueueList(),
      floatingActionButton: widget.callQueue.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showClearAllDialog,
              label: const Text("Clear All"),
              icon: const Icon(Icons.delete_sweep),
              backgroundColor: Colors.red,
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.done_all,
            size: 80,
            color: Colors.green.withOpacity(0.5),
          ),
          const SizedBox(height: 20),
          const Text(
            "No Calls in Queue",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "All calls have been processed!",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueList() {
    return ListView.builder(
      itemCount: widget.callQueue.length,
      padding: const EdgeInsets.all(10),
      itemBuilder: (context, index) {
        final callItem = widget.callQueue.get(index);
        if (callItem == null) return const SizedBox.shrink();

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  "${index + 1}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
            ),
            title: Text(
              callItem.customerName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  callItem.mobileNo,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Queued: ${callItem.formattedTime}",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
            trailing: SizedBox(
              width: 100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Call button
                  IconButton(
                    icon: const Icon(Icons.call, color: Colors.green),
                    onPressed: () {
                      Navigator.pop(context, index);
                    },
                    tooltip: "Call Now",
                  ),
                  // Cancel button
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () {
                      _showCancelDialog(index, callItem.customerName);
                    },
                    tooltip: "Cancel",
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCancelDialog(int index, String customerName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cancel Call?"),
        content: Text(
          "Are you sure you want to cancel the call to $customerName?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onCancel(index);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("✅ Call canceled"),
                  duration: Duration(seconds: 2),
                ),
              );
              setState(() {});
            },
            child: const Text(
              "Yes, Cancel",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear All Calls?"),
        content: Text(
          "Are you sure you want to clear all ${widget.callQueue.length} calls from the queue?\nThis cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onClearAll();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("✅ Queue cleared"),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 2),
                ),
              );
              setState(() {});
            },
            child: const Text(
              "Yes, Clear All",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
