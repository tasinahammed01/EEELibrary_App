import 'package:flutter/material.dart';

/// Presentation fixtures only. Not a catalog, entitlement, or purchase model.
class MockHomeBook {
  const MockHomeBook({
    required this.title,
    required this.author,
    required this.price,
    required this.rating,
    required this.ratingCount,
    required this.icon,
  });
  final String title;
  final String author;
  final String price;
  final String rating;
  final String ratingCount;
  final IconData icon;
}

class MockHomeCategory {
  const MockHomeCategory(this.title, this.icon);
  final String title;
  final IconData icon;
}

abstract final class MockHomeData {
  static const categories = [
    MockHomeCategory('Academic', Icons.school_outlined),
    MockHomeCategory('Job Prep', Icons.work_outline),
    MockHomeCategory('Circuit', Icons.account_tree_outlined),
    MockHomeCategory('Electronics', Icons.memory_outlined),
    MockHomeCategory('Power', Icons.bolt_rounded),
    MockHomeCategory('Control', Icons.tune_rounded),
    MockHomeCategory('Machine', Icons.settings_outlined),
    MockHomeCategory('PDF Notes', Icons.description_outlined),
  ];
  static const featured = [
    MockHomeBook(
      title: 'Electrical Circuit Analysis',
      author: 'Study collection',
      price: '৳320',
      rating: '4.8',
      ratingCount: '124',
      icon: Icons.account_tree_outlined,
    ),
    MockHomeBook(
      title: 'Electric Power Systems',
      author: 'EEE essentials',
      price: '৳450',
      rating: '4.7',
      ratingCount: '98',
      icon: Icons.bolt_rounded,
    ),
    MockHomeBook(
      title: 'Principles of Electric Machines',
      author: 'Engineering collection',
      price: '৳390',
      rating: '4.9',
      ratingCount: '86',
      icon: Icons.settings_outlined,
    ),
    MockHomeBook(
      title: 'Modern Control Systems',
      author: 'Study collection',
      price: '৳420',
      rating: '4.8',
      ratingCount: '112',
      icon: Icons.tune_rounded,
    ),
  ];
  static const recommended = [
    MockHomeBook(
      title: 'EEE Job Preparation',
      author: 'Career preparation',
      price: '৳280',
      rating: '4.8',
      ratingCount: '72',
      icon: Icons.work_outline,
    ),
    MockHomeBook(
      title: 'Power System Protection',
      author: 'Power engineering',
      price: '৳350',
      rating: '4.7',
      ratingCount: '64',
      icon: Icons.shield_outlined,
    ),
    MockHomeBook(
      title: 'Digital Electronics',
      author: 'Electronics essentials',
      price: '৳300',
      rating: '4.9',
      ratingCount: '91',
      icon: Icons.memory_outlined,
    ),
    MockHomeBook(
      title: 'Engineering Mathematics',
      author: 'Academic foundations',
      price: '৳250',
      rating: '4.8',
      ratingCount: '108',
      icon: Icons.functions_rounded,
    ),
  ];
  static const quickAccess = [
    MockHomeCategory('Syllabus', Icons.assignment_outlined),
    MockHomeCategory('Previous Questions', Icons.quiz_outlined),
    MockHomeCategory('Bookmarks', Icons.bookmark_outline),
    MockHomeCategory('Free Samples', Icons.auto_stories_outlined),
    MockHomeCategory('Wishlist', Icons.favorite_border),
    MockHomeCategory('Downloads', Icons.download_outlined),
  ];
}
