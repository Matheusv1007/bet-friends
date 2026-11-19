import 'package:flutter/material.dart';

class CartaoAmigoDesafio extends StatelessWidget {
  final String uid;
  final String displayName;
  final String? username;
  final bool isSelected;
  final VoidCallback onTap;

  const CartaoAmigoDesafio({
    super.key,
    required this.uid,
    required this.displayName,
    this.username,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF00D084);
    const cardBg = Color(0xFF151E2E);

    return InkWell(
      key: Key('amigo_item_$uid'),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0E2924) : cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? primaryGreen
                : Colors.white.withValues(alpha: 0.05),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 15,
              backgroundColor: Color(0xFF334155),
              child: Icon(
                Icons.person_outline,
                size: 17,
                color: Colors.white70,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      color: isSelected ? primaryGreen : Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (username != null)
                    Text(
                      '@$username',
                      style: const TextStyle(
                        color: Color(0xFF8E9CAB),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? primaryGreen : const Color(0xFF94A3B8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
