import 'package:barz/features/home/presentation/pages/drinks/drinks_home_page.dart';
import 'package:barz/features/home/presentation/pages/profile/profile_home_page.dart';
import 'package:barz/features/home/presentation/pages/search/search_home_page.dart';
import 'package:barz/shared/domain/models/bottom_nav_bar/nav_item_model.dart';
import 'package:flutter/material.dart';

class Menu<T> {
  String? pageTitle;
  final T page;
  final NavItemModel navItem;

  Menu(this.page, this.navItem, [this.pageTitle = '']);
}

List<Menu> homeBottomNavItems = [
  Menu(
    const DrinksHomePage(),
    const NavItemModel(
      title: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
    ),
  ),
  Menu(
    const SearchHomePage(),
    const NavItemModel(
      title: 'Search',
      icon: Icons.search_outlined,
      activeIcon: Icons.search,
    ),
  ),
  Menu(
    const ProfileHomePage(),
    const NavItemModel(
      title: 'Profile',
      icon: Icons.person_outline,
      activeIcon: Icons.person,
    ),
  ),
];

List<Menu> sidebarMenus = [
  Menu(
    "Home",
    const NavItemModel(
      title: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
    ),
  ),
  Menu(
    "Search",
    const NavItemModel(
      title: 'Search',
      icon: Icons.search_outlined,
      activeIcon: Icons.search,
    ),
  ),
  Menu(
    "Favorites",
    const NavItemModel(
      title: 'Favorites',
      icon: Icons.star_outline,
      activeIcon: Icons.star,
    ),
  ),
  Menu(
    "Help",
    const NavItemModel(
      title: 'Help',
      icon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble,
    ),
  ),
];

List<Menu> sidebarMenus2 = [
  Menu(
    "History",
    const NavItemModel(
      title: 'History',
      icon: Icons.history_outlined,
      activeIcon: Icons.history,
    ),
  ),
  Menu(
    "Notifications",
    const NavItemModel(
      title: 'Notifications',
      icon: Icons.notifications_outlined,
      activeIcon: Icons.notifications,
    ),
  ),
];
