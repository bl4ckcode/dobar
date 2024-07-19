enum CardType {
  circle,
  square,
  rectangular;

  double cardHeight() {
    switch (this) {
      case CardType.circle:
        return 150;
      case CardType.square:
        return 200;
      case CardType.rectangular:
        return 200;
    }
  }
}
