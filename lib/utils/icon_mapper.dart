import 'package:flutter/material.dart';

IconData getIcon(String name) {
  switch (name.toLowerCase().trim()) {
    case 'appliances':  return Icons.kitchen;
    case 'electronics': return Icons.electrical_services;
    case 'fashion':     return Icons.checkroom;
    case 'chair':       return Icons.chair;        // furniture uses "chair"
    case 'phone':       return Icons.smartphone;   // mobiles uses "phone"
    case 'tools':       return Icons.build;
    case 'car':         return Icons.directions_car; // vehicles uses "car"
    default:            return Icons.category;
  }
}