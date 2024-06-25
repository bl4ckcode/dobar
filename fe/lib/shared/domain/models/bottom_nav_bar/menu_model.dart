import 'package:barz/shared/domain/models/bottom_nav_bar/rive_model.dart';

class Menu<T, RiveModel> {
  String? pageTitle;
  final T page;
  final RiveModel rive;

  Menu(this.page, this.rive, [this.pageTitle = '']);
}

List<Menu> sidebarMenus = [
  Menu(
    "Home",
    RiveModel(
        src: "assets/RiveAssets/icons.riv",
        artboard: "HOME",
        stateMachineName: "HOME_interactivity"),
  ),
  Menu(
    "Search",
    RiveModel(
        src: "assets/RiveAssets/icons.riv",
        artboard: "SEARCH",
        stateMachineName: "SEARCH_Interactivity"),
  ),
  Menu(
    "Favorites",
    RiveModel(
        src: "assets/RiveAssets/icons.riv",
        artboard: "LIKE/STAR",
        stateMachineName: "STAR_Interactivity"),
  ),
  Menu(
    "Help",
    RiveModel(
        src: "assets/RiveAssets/icons.riv",
        artboard: "CHAT",
        stateMachineName: "CHAT_Interactivity"),
  ),
];

List<Menu> sidebarMenus2 = [
  Menu(
    "History",
    RiveModel(
        src: "assets/RiveAssets/icons.riv",
        artboard: "TIMER",
        stateMachineName: "TIMER_Interactivity"),
  ),
  Menu(
    "Notifications",
    RiveModel(
        src: "assets/RiveAssets/icons.riv",
        artboard: "BELL",
        stateMachineName: "BELL_Interactivity"),
  ),
];
