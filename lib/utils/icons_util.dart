abstract final class CustomIcons {
  static const String man = 'assets/svg/wallet-icons/man-head.svg';
  static const String woman = 'assets/svg/wallet-icons/woman-head.svg';
  static const String baby = 'assets/svg/wallet-icons/child-head.svg';
  static const String home = 'assets/svg/wallet-icons/home-heart.svg';
  static const String smile = 'assets/svg/wallet-icons/smile-beam.svg';

  static const String shrimp = 'assets/svg/wallet-icons/shrimp.svg';
  static const String crab = 'assets/svg/wallet-icons/crab.svg';
  static const String fish = 'assets/svg/wallet-icons/fish.svg';
  static const String squid = 'assets/svg/wallet-icons/squid.svg';
  static const String dolphin = 'assets/svg/wallet-icons/dolphin.svg';
  static const String whale = 'assets/svg/wallet-icons/whale.svg';

  static const String hand_holding = 'assets/svg/wallet-icons/hand-holding-heart.svg';
  static const String finger = 'assets/svg/wallet-icons/cursor-finger.svg';
  static const String paw = 'assets/svg/wallet-icons/paw.svg';
  static const String paper_plane = 'assets/svg/wallet-icons/paper-plane.svg';
  static const String envelope = 'assets/svg/wallet-icons/envelope.svg';

  static const String flower = 'assets/svg/wallet-icons/flower.svg';
  static const String star = 'assets/svg/wallet-icons/star.svg';
  static const String music = 'assets/svg/wallet-icons/music.svg';
  static const String heart = 'assets/svg/wallet-icons/heart.svg';

  static const String hamburger = 'assets/svg/wallet-icons/hamburger.svg';
  static const String croissant = 'assets/svg/wallet-icons/croissant.svg';
  static const String pizza = 'assets/svg/wallet-icons/pizza-slice.svg';
  static const String chicken = 'assets/svg/wallet-icons/turkey.svg';
  static const String carrot = 'assets/svg/wallet-icons/carrot.svg';

  static const String diamond = 'assets/svg/wallet-icons/diamond.svg';
  static const String gift = 'assets/svg/wallet-icons/gift.svg';
  static const String rocket = 'assets/svg/wallet-icons/rocket-lunch.svg';
  static const String piggy_bank = 'assets/svg/wallet-icons/piggy-bank.svg';
  static const String unbrella = 'assets/svg/wallet-icons/umbrella.svg';

  static const String bank = 'assets/svg/wallet-icons/bank.svg';
  static const String building = 'assets/svg/wallet-icons/building.svg';
  static const String shop = 'assets/svg/wallet-icons/shop.svg';
  static const String car = 'assets/svg/wallet-icons/car.svg';
  static const String couch = 'assets/svg/wallet-icons/couch.svg';

  static const String triangleWarning = 'assets/svg/triangle-warning.svg';

  static List<String> icons = [
    'assets/svg/wallet-icons/man-head.svg',
    'assets/svg/wallet-icons/woman-head.svg',
    'assets/svg/wallet-icons/child-head.svg',
    'assets/svg/wallet-icons/home-heart.svg',
    'assets/svg/wallet-icons/smile-beam.svg',
    'assets/svg/wallet-icons/shrimp.svg',
    'assets/svg/wallet-icons/crab.svg',
    'assets/svg/wallet-icons/fish.svg',
    'assets/svg/wallet-icons/squid.svg',
    'assets/svg/wallet-icons/dolphin.svg',
    'assets/svg/wallet-icons/whale.svg',
    'assets/svg/wallet-icons/hand-holding-heart.svg',
    'assets/svg/wallet-icons/cursor-finger.svg',
    'assets/svg/wallet-icons/paw.svg',
    'assets/svg/wallet-icons/paper-plane.svg',
    'assets/svg/wallet-icons/envelope.svg',
    'assets/svg/wallet-icons/flower.svg',
    'assets/svg/wallet-icons/star.svg',
    'assets/svg/wallet-icons/music.svg',
    'assets/svg/wallet-icons/heart.svg',
    'assets/svg/wallet-icons/hamburger.svg',
    'assets/svg/wallet-icons/croissant.svg',
    'assets/svg/wallet-icons/pizza-slice.svg',
    'assets/svg/wallet-icons/turkey.svg',
    'assets/svg/wallet-icons/carrot.svg',
    'assets/svg/wallet-icons/diamond.svg',
    'assets/svg/wallet-icons/gift.svg',
    'assets/svg/wallet-icons/rocket-lunch.svg',
    'assets/svg/wallet-icons/piggy-bank.svg',
    'assets/svg/wallet-icons/umbrella.svg',
    'assets/svg/wallet-icons/bank.svg',
    'assets/svg/wallet-icons/building.svg',
    'assets/svg/wallet-icons/shop.svg',
    'assets/svg/wallet-icons/car.svg',
    'assets/svg/wallet-icons/couch.svg',
  ];

  static const totalCount = 35;

  static String getPathByIndex(int index) {
    if (index >= 0 && index < icons.length) {
      return icons[index];
    }
    return '';
  }
}
