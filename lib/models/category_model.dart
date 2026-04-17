class CategoryModel {
  final String id;
  final String name;
  final String icon;
  final int priority;

  CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.priority,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> data, String id) {
    return CategoryModel(
      id: id,
      name: data['name'] ?? '',
      icon: data['icon'] ?? '',
      priority: data['priority'] ?? 0,
    );
  }
}