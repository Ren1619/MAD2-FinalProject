class Company {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String city;
  final String state;
  final String zipcode;
  final String website;
  final String size;
  final String industry;
  final String createdAt;

  Company({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.city,
    required this.state,
    required this.zipcode,
    required this.website,
    required this.size,
    required this.industry,
    required this.createdAt,
  });

  // Convert a Company object into a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'city': city,
      'state': state,
      'zipcode': zipcode,
      'website': website,
      'size': size,
      'industry': industry,
      'createdAt': createdAt,
    };
  }

  // Create a Company object from a Map
  factory Company.fromMap(Map<String, dynamic> map) {
    return Company(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      zipcode: map['zipcode'] ?? '',
      website: map['website'] ?? '',
      size: map['size'] ?? '',
      industry: map['industry'] ?? '',
      createdAt: map['createdAt'] ?? '',
    );
  }
}