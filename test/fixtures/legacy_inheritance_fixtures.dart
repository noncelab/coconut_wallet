class LegacyInheritanceFixture {
  final List<String> parentMnemonics;
  final int locktime;
  final String storedDescriptor;
  final String storedMiniscript;
  final String receive0;
  final String receive1;
  final String change0;

  const LegacyInheritanceFixture({
    required this.parentMnemonics,
    required this.locktime,
    required this.storedDescriptor,
    required this.storedMiniscript,
    required this.receive0,
    required this.receive1,
    required this.change0,
  });
}

const legacyParentMnemonic1 =
    "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";
const legacyParentMnemonic2 = "letter advice cage absurd amount doctor acoustic avoid letter advice cage above";
const legacyChildMnemonic = "legal winner thank year wave sausage worth useful legal winner thank yellow";
const legacyChildDescriptor =
    "tr([B8688DF1/86'/1'/0']tpubDDHnNFFb1gf8qGYVejVx4GwzQPwcphirPssHFMWFcL9iajxm1wWd5ye22T7UQrVPjwwifJaCJGBAphuu8oePzYTCN7eZgm1KnyfNDmcfnsu/<0;1>/*)#ruyyk6s4";

/// coconut_lib 1.1.1(볼트 3.3.0)로 계산한 testnet 상속 지갑 기대값
const legacyInheritanceFixtures = [
  LegacyInheritanceFixture(
    parentMnemonics: [legacyParentMnemonic1],
    locktime: 0,
    storedDescriptor:
        "tr([73C5DA0A/86'/1'/0']tpubDDfvzhdVV4unsoKt5aE6dcsNsfeWbTgmLZPi8LQDYU2xixrYemMfWJ3BaVneH3u7DBQePdTwhpybaKRU95pi6PMUtLPBJLVQRpzEnjfjZzX/<0;1>/*,{and_v(v:pk([B8688DF1/86'/1'/0']tpubDDHnNFFb1gf8qGYVejVx4GwzQPwcphirPssHFMWFcL9iajxm1wWd5ye22T7UQrVPjwwifJaCJGBAphuu8oePzYTCN7eZgm1KnyfNDmcfnsu/<0;1>/*),after(0))})#4afekgrf",
    storedMiniscript:
        "and_v(v:pk([B8688DF1/86'/1'/0']tpubDDHnNFFb1gf8qGYVejVx4GwzQPwcphirPssHFMWFcL9iajxm1wWd5ye22T7UQrVPjwwifJaCJGBAphuu8oePzYTCN7eZgm1KnyfNDmcfnsu/<0;1>/*),after(0))",
    receive0: "tb1pgyv30ufgwwngq7k4u9xhepfkwc5zmdc5tueg0mzlw4a6qmjrgw8spspv58",
    receive1: "tb1pkshcssv6slegp2ycxlv74pa9vkfjyqea7kwa6dc3fu8708msrfzs3dd4ar",
    change0: "tb1p59ecv45lvgp0xxf9z25rxsuqsrx2k4d4e7avm5rqlyzq7k2vvw0qlclu9z",
  ),
  LegacyInheritanceFixture(
    parentMnemonics: [legacyParentMnemonic1],
    locktime: 150,
    storedDescriptor:
        "tr([73C5DA0A/86'/1'/0']tpubDDfvzhdVV4unsoKt5aE6dcsNsfeWbTgmLZPi8LQDYU2xixrYemMfWJ3BaVneH3u7DBQePdTwhpybaKRU95pi6PMUtLPBJLVQRpzEnjfjZzX/<0;1>/*,{and_v(v:pk([B8688DF1/86'/1'/0']tpubDDHnNFFb1gf8qGYVejVx4GwzQPwcphirPssHFMWFcL9iajxm1wWd5ye22T7UQrVPjwwifJaCJGBAphuu8oePzYTCN7eZgm1KnyfNDmcfnsu/<0;1>/*),after(150))})#0t2mluhf",
    storedMiniscript:
        "and_v(v:pk([B8688DF1/86'/1'/0']tpubDDHnNFFb1gf8qGYVejVx4GwzQPwcphirPssHFMWFcL9iajxm1wWd5ye22T7UQrVPjwwifJaCJGBAphuu8oePzYTCN7eZgm1KnyfNDmcfnsu/<0;1>/*),after(150))",
    receive0: "tb1pcepc9ave6tyyuhsyteahmye227qyfwrjk8cawz9sa203qerj8fvqvhwhyp",
    receive1: "tb1pjxhvwcz5h4qnlu9y6cquhtuwzesw38sehme7h3g5rq4g7aqztt9qtmjnn4",
    change0: "tb1pgt2zntaeqlenhf0vzysh2rf9mm6fafty42w8d87qu9zmpdrxrt7slrqpvs",
  ),
  LegacyInheritanceFixture(
    parentMnemonics: [legacyParentMnemonic1],
    locktime: 800000,
    storedDescriptor:
        "tr([73C5DA0A/86'/1'/0']tpubDDfvzhdVV4unsoKt5aE6dcsNsfeWbTgmLZPi8LQDYU2xixrYemMfWJ3BaVneH3u7DBQePdTwhpybaKRU95pi6PMUtLPBJLVQRpzEnjfjZzX/<0;1>/*,{and_v(v:pk([B8688DF1/86'/1'/0']tpubDDHnNFFb1gf8qGYVejVx4GwzQPwcphirPssHFMWFcL9iajxm1wWd5ye22T7UQrVPjwwifJaCJGBAphuu8oePzYTCN7eZgm1KnyfNDmcfnsu/<0;1>/*),after(800000))})#g8eaxzy0",
    storedMiniscript:
        "and_v(v:pk([B8688DF1/86'/1'/0']tpubDDHnNFFb1gf8qGYVejVx4GwzQPwcphirPssHFMWFcL9iajxm1wWd5ye22T7UQrVPjwwifJaCJGBAphuu8oePzYTCN7eZgm1KnyfNDmcfnsu/<0;1>/*),after(800000))",
    receive0: "tb1pjqpjsjxdepr50e7qxaqe7jd8dzcxvczutkhz3y53kw8v5f6m3tdqgamqq3",
    receive1: "tb1p263v7lnhp3h8l3py4nu2dft6l2vwd5r9jfcmyguvyn00gy2e8jxqk4000r",
    change0: "tb1pr99v5h5vzsaq7trvkdgnq5d6ezl3al2s4xed8gd6dqd892yhju3qjyd5df",
  ),
  LegacyInheritanceFixture(
    parentMnemonics: [legacyParentMnemonic1],
    locktime: 1780012800,
    storedDescriptor:
        "tr([73C5DA0A/86'/1'/0']tpubDDfvzhdVV4unsoKt5aE6dcsNsfeWbTgmLZPi8LQDYU2xixrYemMfWJ3BaVneH3u7DBQePdTwhpybaKRU95pi6PMUtLPBJLVQRpzEnjfjZzX/<0;1>/*,{and_v(v:pk([B8688DF1/86'/1'/0']tpubDDHnNFFb1gf8qGYVejVx4GwzQPwcphirPssHFMWFcL9iajxm1wWd5ye22T7UQrVPjwwifJaCJGBAphuu8oePzYTCN7eZgm1KnyfNDmcfnsu/<0;1>/*),after(1780012800))})#vvmqzt23",
    storedMiniscript:
        "and_v(v:pk([B8688DF1/86'/1'/0']tpubDDHnNFFb1gf8qGYVejVx4GwzQPwcphirPssHFMWFcL9iajxm1wWd5ye22T7UQrVPjwwifJaCJGBAphuu8oePzYTCN7eZgm1KnyfNDmcfnsu/<0;1>/*),after(1780012800))",
    receive0: "tb1pck4vta7ng5rcdjeyz8x0gr2t0kpxk55z9775rpnfg435hu96ecxsgj80ar",
    receive1: "tb1paegn80z4f6pps9nthuf205442fsqz7qt9scrj9e239zav2hde5usqw865s",
    change0: "tb1p642uj4dph82szxcvewl3gvvvykf599wv38stgh4x7xp8udxpf8zq9qz59d",
  ),
  LegacyInheritanceFixture(
    parentMnemonics: [legacyParentMnemonic1, legacyParentMnemonic2],
    locktime: 150,
    storedDescriptor:
        "tr(musig(sorted([28645006/86'/1'/0']tpubDDPYViYqnxXydgHLMrt6W8KE7Cddw45SYv3iE1gCTYx8Ntd2GwBCYiRfDwTmRSC6N41meFb4qBBEWFVkYHVD8qnXNG6qr3o7jMxGBD3T9Zi/<0;1>/*,[73C5DA0A/86'/1'/0']tpubDDfvzhdVV4unsoKt5aE6dcsNsfeWbTgmLZPi8LQDYU2xixrYemMfWJ3BaVneH3u7DBQePdTwhpybaKRU95pi6PMUtLPBJLVQRpzEnjfjZzX/<0;1>/*)),{and_v(v:pk([B8688DF1/86'/1'/0']tpubDDHnNFFb1gf8qGYVejVx4GwzQPwcphirPssHFMWFcL9iajxm1wWd5ye22T7UQrVPjwwifJaCJGBAphuu8oePzYTCN7eZgm1KnyfNDmcfnsu/<0;1>/*),after(150))})#5d6vlduw",
    storedMiniscript:
        "and_v(v:pk([B8688DF1/86'/1'/0']tpubDDHnNFFb1gf8qGYVejVx4GwzQPwcphirPssHFMWFcL9iajxm1wWd5ye22T7UQrVPjwwifJaCJGBAphuu8oePzYTCN7eZgm1KnyfNDmcfnsu/<0;1>/*),after(150))",
    receive0: "tb1p43uym9s4vh23g5h60aqdpe03rn5k04xm7l0fznhj0yyuhvqgjc9qnuw8an",
    receive1: "tb1p39lctxfg3nuwx5ydcc37su26dmpc6kq4tlam6fd9gr6cdx6ufa7qetd8j4",
    change0: "tb1ptu54neukzp5xznhzj7vmy630vu5cx2wprclm05z3g8u9yj3svslqr5yldm",
  ),
  LegacyInheritanceFixture(
    parentMnemonics: [legacyParentMnemonic1, legacyParentMnemonic2],
    locktime: 1780012800,
    storedDescriptor:
        "tr(musig(sorted([28645006/86'/1'/0']tpubDDPYViYqnxXydgHLMrt6W8KE7Cddw45SYv3iE1gCTYx8Ntd2GwBCYiRfDwTmRSC6N41meFb4qBBEWFVkYHVD8qnXNG6qr3o7jMxGBD3T9Zi/<0;1>/*,[73C5DA0A/86'/1'/0']tpubDDfvzhdVV4unsoKt5aE6dcsNsfeWbTgmLZPi8LQDYU2xixrYemMfWJ3BaVneH3u7DBQePdTwhpybaKRU95pi6PMUtLPBJLVQRpzEnjfjZzX/<0;1>/*)),{and_v(v:pk([B8688DF1/86'/1'/0']tpubDDHnNFFb1gf8qGYVejVx4GwzQPwcphirPssHFMWFcL9iajxm1wWd5ye22T7UQrVPjwwifJaCJGBAphuu8oePzYTCN7eZgm1KnyfNDmcfnsu/<0;1>/*),after(1780012800))})#6mwe3j6p",
    storedMiniscript:
        "and_v(v:pk([B8688DF1/86'/1'/0']tpubDDHnNFFb1gf8qGYVejVx4GwzQPwcphirPssHFMWFcL9iajxm1wWd5ye22T7UQrVPjwwifJaCJGBAphuu8oePzYTCN7eZgm1KnyfNDmcfnsu/<0;1>/*),after(1780012800))",
    receive0: "tb1ptkvu0yzcpke3jy70qn6aahqutdmx54rgngxmdxfmlpuu0arsvd2qyjtr5r",
    receive1: "tb1pvwwvwshu8mm0dalvkf3myqenrgsk00vy0rtecytzyke6vdxdhgmqqeacjm",
    change0: "tb1pvdkscqycgugrvj0ynmh036jt8zlwepmqfaze4l7fvmepl0z3prrqtwu4km",
  ),
];
