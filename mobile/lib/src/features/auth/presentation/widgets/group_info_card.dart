import 'package:flutter/material.dart';

class GroupInfoRow {
  final String label;
  final String value;

  const GroupInfoRow(this.label, this.value);
}

class GroupInfoCard extends StatelessWidget {
  final List<GroupInfoRow> rows;

  const GroupInfoCard({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    rows[i].label,
                    style: TextStyle(fontFamily: 'PlusJakartaSans', 
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[500],
                    ),
                  ),
                  Flexible(
                    child: Text(
                      rows[i].value,
                      textAlign: TextAlign.right,
                      style: TextStyle(fontFamily: 'SpaceGrotesk', 
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1D3108),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (i != rows.length - 1) Divider(color: Colors.grey[200], height: 1),
          ],
        ],
      ),
    );
  }
}
