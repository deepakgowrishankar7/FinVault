import 'package:flutter/material.dart';
import '../../models/user_role.dart';
import '../../services/storage_service.dart';
import '../../theme/fin_theme.dart';

class TeamManagementScreen extends StatefulWidget {
  final SecuritySettings settings;
  final ValueChanged<SecuritySettings> onSettingsUpdated;

  const TeamManagementScreen({
    super.key,
    required this.settings,
    required this.onSettingsUpdated,
  });

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  late SecuritySettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  void _showAddAgentDialog() {
    final nameCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Add Field Agent", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "Agent Full Name *", prefixIcon: Icon(Icons.person)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(labelText: "4-Digit Agent PIN *", prefixIcon: Icon(Icons.lock)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: "Agent Phone Number", prefixIcon: Icon(Icons.phone)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final pin = pinCtrl.text.trim();
              if (name.isEmpty || pin.length != 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Name and 4-digit PIN are required")),
                );
                return;
              }

              final newAgent = StaffAgent(
                id: "ag_${DateTime.now().millisecondsSinceEpoch}",
                name: name,
                pin: pin,
                phone: phoneCtrl.text.trim(),
              );

              final updatedAgents = List<StaffAgent>.from(_settings.agents)..add(newAgent);
              final updated = _settings.copyWith(agents: updatedAgents);
              await StorageService.saveSettings(updated);
              setState(() => _settings = updated);
              widget.onSettingsUpdated(updated);
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text("Add Agent"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAgent(StaffAgent agent) async {
    final updatedAgents = List<StaffAgent>.from(_settings.agents)..removeWhere((a) => a.id == agent.id);
    final updated = _settings.copyWith(agents: updatedAgents);
    await StorageService.saveSettings(updated);
    setState(() => _settings = updated);
    widget.onSettingsUpdated(updated);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Team & Staff Management"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Admin Card
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: FinTheme.primary,
                  child: Text("👑", style: TextStyle(fontSize: 18)),
                ),
                title: Text(_settings.adminName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Master Admin • Full Access (Unrestricted)"),
                trailing: const Icon(Icons.check_circle, color: FinTheme.primary),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Field Collection Agents",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _showAddAgentDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text("Add Agent"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FinTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            if (_settings.agents.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.group_outlined, size: 48, color: Colors.grey.withOpacity(0.5)),
                      const SizedBox(height: 12),
                      const Text("No staff agents added yet", style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(
                        "Add field agents so they can record payments with their own PIN.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: isDark ? FinTheme.textDarkSecondary : FinTheme.textLightSecondary),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _settings.agents.length,
                  itemBuilder: (context, index) {
                    final ag = _settings.agents[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: FinTheme.success.withOpacity(0.2),
                          child: const Icon(Icons.person, color: FinTheme.success),
                        ),
                        title: Text(ag.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("PIN: ${ag.pin} • ${ag.phone ?? 'No Phone'}"),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: FinTheme.danger),
                          onPressed: () => _deleteAgent(ag),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
