String formatAddress(String address) {
  if (address.isEmpty) return '—';
  
  // Clean up common extra parts
  final parts = address.split(',').map((e) => e.trim()).toList();
  
  // Requirement: Cap it at "Davao City"
  // If "Davao City" is present, we only show parts up to "Davao City"
  int davaoIndex = -1;
  for (int i = 0; i < parts.length; i++) {
    if (parts[i].toLowerCase().contains('davao city')) {
      davaoIndex = i;
      break;
    }
  }

  if (davaoIndex != -1) {
    // Show everything before and including Davao City
    final relevantParts = parts.sublist(0, davaoIndex + 1);
    return relevantParts.join(', ');
  }

  // Fallback: Show first two parts if available
  if (parts.length > 1) {
    return "${parts[0]}, ${parts[1]}";
  }
  
  return address;
}
