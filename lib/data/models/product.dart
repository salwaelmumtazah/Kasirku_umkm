class Product {
  final int? id;
  final String name;
  final String category;
  final int price;
  final int stock;
  final String? imagePath;

  const Product({
    this.id,
    required this.name,
    this.category = 'Umum',
    required this.price,
    this.stock = 0,
    this.imagePath,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'category': category,
      'price': price,
      'stock': stock,
      'image_path': imagePath,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String,
      category: (map['category'] as String?) ?? 'Umum',
      price: map['price'] as int,
      stock: (map['stock'] as int?) ?? 0,
      imagePath: map['image_path'] as String?,
    );
  }

  Product copyWith({
    int? id,
    String? name,
    String? category,
    int? price,
    int? stock,
    String? imagePath,
    bool clearImage = false,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      imagePath: clearImage ? null : (imagePath ?? this.imagePath),
    );
  }
}

