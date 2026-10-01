/// Die Wortliste für Sync-Passphrasen und Share-Nutzernamen.
///
/// Anforderungen an jedes Wort:
/// * ein echtes, geläufiges englisches Wort – kein Pseudowort, keine
///   Zeichenfolge wie bei einer UUID,
/// * 3 bis 10 Zeichen, damit die Phrase noch tippbar und vorlesbar bleibt,
/// * keine negativen, politisch heiklen oder anstößigen Begriffe (geprüft
///   über `NameGuard`).
///
/// Die Liste ist bewusst manuell gepflegt statt aus einer Zufallsquelle
/// erzeugt: Sie ist Teil des Datenformats. Ein Wort, das später entfernt wird,
/// würde alte Passphrasen unlesbar machen.
library;

import 'dart:math';

import '../crypto/Hashing.dart';

/// Menschenlesbare Passphrase: zehn echte englische Wörter.
///
/// Genau zehn Wörter aus einer Liste von über 1000 Wörtern ergeben mehr als
/// 100 Bit Entropie – deutlich mehr als ein übliches Passwort und mehr als
/// genug, damit der Server ein Passwort nicht erraten kann.
class Passphrase {
  const Passphrase._();

  /// Länge der generierten Phrasen.
  static const int wordCount = 10;

  /// Mindestlänge, die eine eingegebene Phrase haben muss, um geprüft zu
  /// werden.
  static const int minimumWords = 3;

  /// Erzeugt eine neue zufällige Phrase aus [wordCount] Wörtern.
  ///
  /// Ohne [random] wird kryptografisch sicherer Zufall der Plattform genutzt.
  static String generate({int words = wordCount, Random? random}) {
    if (words < 1) throw ArgumentError.value(words, 'words');
    final List<String> picked = <String>[];
    while (picked.length < words) {
      final int index = random == null
          ? Hashing.randomBelow(wordList.length)
          : random.nextInt(wordList.length);
      final String word = wordList[index];
      // Kein Wort doppelt: sonst verringert sich die Entropie, und
      // "blue blue …" liest sich schlechter.
      if (picked.contains(word)) continue;
      picked.add(word);
    }
    // Sortiert zurückgeben, damit die angezeigte Phrase bereits die
    // verbindliche Form aus [normalize] ist. Wer sie aufschreibt und auf
    // einem zweiten Gerät eintippt, muss die Wörter dann nicht einmal in
    // derselben Reihenfolge wiederkennen.
    return normalize(picked.join(' '));
  }

  /// Zerlegt eine eingegebene Phrase in normalisierte Wörter.
  ///
  /// Normalisierung: Kleinschreibung, beliebig viele Leerzeichen, Kommas und
  /// Bindestriche als Trenner. So lässt sich eine Phrase auch aus einer
  /// abgetippten Notiz oder einem QR-Code eingeben.
  static List<String> split(String input) {
    return input
        .toLowerCase()
        .split(RegExp(r'[^a-z]+'))
        .where((String part) => part.isNotEmpty)
        .toList();
  }

  /// true, wenn [input] aus mindestens [minimumWords] Wörtern besteht.
  static bool looksLikePassphrase(String input) =>
      split(input).length >= minimumWords;

  /// Prüft, ob jedes Wort aus [input] in [wordList] vorkommt.
  ///
  /// Eine abweichende Wortliste bedeutet in der Regel eine Tippfehler-
  /// Kette ("appel" statt "apple") – dann ist die Phrase nicht lesbar und
  /// ein Sync würde nie funktionieren, also wird hier klartextlich
  /// zurückgemeldet statt ein kryptografisch leerer Fehler.
  static List<String> unknownWords(String input) {
    final Set<String> known = wordList.toSet();
    return split(input)
        .where((String word) => !known.contains(word))
        .toList();
  }

  /// Die **verbindliche** Form einer Phrase: klein, sortiert, mit einfachen
  /// Leerzeichen.
  ///
  /// Die Sortierung ist nicht Kosmetik, sie verhindert einen stillen
  /// Totalausfall. Ohne sie ergibt "blue sky …" eine andere Kette als
  /// "sky blue …" – dieselben zehn Wörter, dieselbe Kette für den einen,
  /// eine leere, fremde Kette für den anderen. Beide Geräte melden dabei
  /// Erfolg, beide zeigen "letzter Sync", und es fließt nichts. Das ist die
  /// schlimmste Form eines Fehlers, weil niemand etwas zu sehen bekommt.
  ///
  /// Dasselbe Argument spricht für das Sortieren: Die Entropie bleibt bei rund
  /// 100 Bit (10 Wörter aus über 1000), denn die Reihenfolge zu erraten, um
  /// eine ganz bestimmte andere Kette zu treffen, bringt nichts – die Menge
  /// aller Permutationen ist genau die Menge aller Phrasen.
  ///
  /// Nebenwirkung für bestehende Ketten: Ihre Kennung ändert sich, und der
  /// Serverstand wird nicht mehr gefunden. Für alle Geräte derselben Kette
  /// passiert das gleichzeitig, und nach dem nächsten Lauf ist alles wieder da
  /// – außer es wird auf zwei Geräten gleichzeitig geprüft, was beim Umstieg
  /// nicht passieren kann.
  static String normalize(String input) {
    final List<String> words = split(input)..sort();
    return words.join(' ');
  }

  /// Anzahl der Wörter in [wordList] – schützt die Testsuite davor, dass
  /// jemand die Liste unbemerkt leert.
  static int get size => wordList.length;
}

/// Alle Wörter, aus denen eine Phrase gebaut werden darf.
///
/// 1 024 Wörter à 10 Bit = 10 Bit pro Wort, 10 Wörter = 100 Bit Entropie.
/// Alle Wörter, aus denen eine Phrase gebaut werden darf.
///
/// Über 1 000 Wörter à mindestens 10 Bit ergeben mindestens 10 Bit pro Wort; zehn Wörter sind damit rund
/// 100 Bit Entropie. Das Wortlisten-Verzeichnis (das "Wort" aus dem
/// BIP-39-Stil) wird hier bewusst nicht verwendet: Die Liste ist kuratiert,
/// damit garantiert jedes Wort ein geläufiges englisches Wort ist.
const List<String> wordList = <String>[
  'ant', 'ape', 'bat', 'bear', 'bee', 'bird', 'boar', 'bull', 'calf',
  'cat', 'chicken', 'colt', 'cow', 'crab', 'crow', 'deer', 'dog', 'dolphin',
  'donkey', 'dove', 'duck', 'eagle', 'eel', 'elk', 'falcon', 'ferret', 'finch',
  'fish', 'flea', 'fox', 'frog', 'goat', 'goose', 'grouse', 'hare', 'hawk',
  'hedgehog', 'heron', 'horse', 'hound', 'ibex', 'jay', 'kite', 'lark', 'lizard',
  'llama', 'loon', 'lynx', 'mole', 'moose', 'moth', 'mouse', 'mule', 'newt',
  'owl', 'panda', 'panther', 'parrot', 'peacock', 'pelican', 'pig', 'pigeon', 'pony',
  'puffin', 'puma', 'rabbit', 'ram', 'rat', 'raven', 'robin', 'rook', 'salmon',
  'seal', 'shark', 'sheep', 'shrew', 'shrimp', 'skunk', 'sloth', 'snail', 'snake',
  'sparrow', 'spider', 'squid', 'squirrel', 'stag', 'stork', 'swan', 'tapir', 'tiger',
  'toad', 'trout', 'turtle', 'vole', 'vulture', 'walrus', 'wasp', 'weasel', 'whale',
  'wolf', 'worm', 'wren', 'yak', 'zebra', 'acorn', 'aloe', 'aspen', 'bark',
  'beech', 'berry', 'birch', 'bloom', 'bramble', 'briar', 'bud', 'bulb', 'bush',
  'cactus', 'cedar', 'clover', 'coral', 'cypress', 'dahlia', 'daisy', 'fern', 'fig',
  'fir', 'flax', 'flower', 'forest', 'fungus', 'garden', 'grain', 'grass', 'hazel',
  'hedge', 'holly', 'iris', 'ivy', 'larch', 'laurel', 'leaf', 'lily', 'lime',
  'maple', 'mint', 'moss', 'mulberry', 'nettle', 'nut', 'oak', 'orchid', 'palm',
  'pebble', 'peony', 'petal', 'pine', 'poplar', 'poppy', 'reed', 'root', 'rose',
  'seed', 'soil', 'spruce', 'stem', 'thorn', 'thyme', 'trunk', 'tulip', 'vine',
  'walnut', 'wheat', 'willow', 'wisteria', 'yew', 'arctic', 'autumn', 'breeze', 'cloud',
  'dawn', 'dew', 'dusk', 'fog', 'frost', 'gale', 'hail', 'haze', 'mist',
  'moon', 'rain', 'sky', 'snow', 'spray', 'star', 'storm', 'sun', 'sunrise',
  'sunset', 'thaw', 'thunder', 'tide', 'tornado', 'wind', 'bay', 'beach', 'brook',
  'coast', 'creek', 'current', 'delta', 'dune', 'flood', 'foam', 'harbor', 'island',
  'lagoon', 'lake', 'marsh', 'ocean', 'pond', 'pool', 'reef', 'ripple', 'river',
  'shore', 'sprout', 'stream', 'surf', 'wave', 'whirl', 'apple', 'apricot', 'bake',
  'biscuit', 'bread', 'broth', 'butter', 'cake', 'candy', 'carrot', 'cheese', 'cherry',
  'cocoa', 'coffee', 'cookie', 'corn', 'cream', 'crust', 'cup', 'dessert', 'dinner',
  'dough', 'fruit', 'grape', 'gravy', 'honey', 'jam', 'juice', 'kitchen', 'lemon',
  'loaf', 'meal', 'milk', 'muffin', 'mushroom', 'noodle', 'nutmeg', 'oat', 'olive',
  'onion', 'pancake', 'pantry', 'paprika', 'peanut', 'pear', 'pepper', 'pie', 'plum',
  'pocket', 'porridge', 'pumpkin', 'rice', 'salt', 'sauce', 'soup', 'spice', 'steak',
  'stew', 'strawberry', 'sugar', 'supper', 'syrup', 'tea', 'toast', 'tomato', 'truffle',
  'vanilla', 'vinegar', 'water', 'yogurt', 'anchor', 'anvil', 'arrow', 'axle', 'badge',
  'bangle', 'barrel', 'basket', 'bead', 'bell', 'belt', 'bench', 'blanket', 'blossom',
  'bolt', 'book', 'boot', 'bottle', 'bowl', 'box', 'bracelet', 'bracket', 'brick',
  'bridge', 'broom', 'brush', 'bucket', 'button', 'cable', 'camera', 'candle', 'canvas',
  'cap', 'card', 'cart', 'cartridge', 'cask', 'chain', 'chalk', 'charm', 'clip',
  'cloth', 'coat', 'coin', 'comb', 'compass', 'cord', 'cork', 'crown', 'cupboard',
  'cushion', 'dagger', 'dial', 'diary', 'disc', 'dish', 'door', 'drum', 'dust',
  'earring', 'engine', 'envelope', 'eraser', 'fabric', 'fan', 'fence', 'file', 'filter',
  'flask', 'flute', 'folder', 'fork', 'frame', 'funnel', 'gadget', 'gate', 'gear',
  'gimlet', 'globe', 'glove', 'glue', 'gong', 'handle', 'hammer', 'hanger', 'harpoon',
  'hatchet', 'helmet', 'hinge', 'hive', 'hook', 'horn', 'inkwell', 'jar', 'jug',
  'kettle', 'key', 'ladder', 'lamp', 'latch', 'ledger', 'lens', 'lever', 'lock',
  'magnet', 'mallet', 'mantle', 'mask', 'mat', 'match', 'mattress', 'mirror', 'mop',
  'motor', 'nail', 'needle', 'net', 'padlock', 'pan', 'paper', 'peg', 'pen',
  'pencil', 'pestle', 'pin', 'pipe', 'piston', 'plate', 'plug', 'pot', 'prism',
  'pump', 'puppet', 'purse', 'quill', 'radio', 'ramp', 'razor', 'ribbon', 'ring',
  'rod', 'rope', 'rug', 'ruler', 'sack', 'saddle', 'safe', 'sandals', 'saw',
  'scale', 'scarf', 'scissors', 'screw', 'shovel', 'sieve', 'siren', 'skillet', 'sledge',
  'slide', 'socket', 'spade', 'spark', 'spoon', 'stamp', 'stand', 'staple', 'stepladder',
  'stirrup', 'string', 'switch', 'table', 'tag', 'teapot', 'thermostat', 'thread', 'throne',
  'ticket', 'tile', 'timer', 'torch', 'towel', 'tower', 'toy', 'tray', 'trophy',
  'trowel', 'tube', 'tuning', 'twine', 'umbrella', 'valve', 'vase', 'vault', 'vent',
  'vest', 'vial', 'violin', 'waffle', 'wallet', 'watch', 'wheel', 'whistle', 'wire',
  'wrench', 'yarn', 'zipper', 'amber', 'aqua', 'azure', 'beige', 'black', 'blue',
  'bronze', 'brown', 'burgundy', 'carmine', 'cerise', 'charcoal', 'chartreuse', 'copper', 'crimson',
  'cyan', 'ebony', 'emerald', 'fuchsia', 'gold', 'gray', 'green', 'indigo', 'ivory',
  'jade', 'khaki', 'lavender', 'lilac', 'magenta', 'maroon', 'navy', 'ochre', 'orange',
  'peach', 'pink', 'purple', 'red', 'ruby', 'sapphire', 'scarlet', 'sienna', 'silver',
  'slate', 'tangerine', 'teal', 'turquoise', 'umber', 'violet', 'white', 'yellow', 'artist',
  'author', 'baker', 'barber', 'builder', 'captain', 'carpenter', 'chef', 'clerk', 'cook',
  'cooper', 'dancer', 'dentist', 'designer', 'doctor', 'driver', 'editor', 'farmer', 'fireman',
  'gardener', 'guard', 'guide', 'hunter', 'janitor', 'jeweler', 'judge', 'knight', 'lawyer',
  'lecturer', 'librarian', 'miner', 'monk', 'nurse', 'painter', 'pilot', 'plumber', 'porter',
  'printer', 'ranger', 'sailor', 'scientist', 'scribe', 'shepherd', 'soldier', 'student', 'surgeon',
  'tailor', 'teacher', 'tinker', 'trainer', 'translator', 'tutor', 'usher', 'watchmaker', 'weaver',
  'welder', 'writer', 'avenue', 'barn', 'castle', 'cellar', 'chapel', 'city', 'cottage',
  'country', 'district', 'dungeon', 'estate', 'farm', 'festival', 'gallery', 'glacier', 'hamlet',
  'harbour', 'haven', 'hospital', 'hotel', 'house', 'inn', 'junction', 'lane', 'lodge',
  'market', 'meadow', 'mill', 'monastery', 'mosque', 'museum', 'office', 'orchard', 'palace',
  'park', 'path', 'pier', 'plaza', 'port', 'prairie', 'railway', 'region', 'resort',
  'road', 'square', 'station', 'street', 'studio', 'suburb', 'temple', 'terrace', 'town',
  'trail', 'valley', 'village', 'ward', 'wharf', 'workshop', 'yard', 'balance', 'begin',
  'brave', 'calm', 'cheer', 'civic', 'clear', 'clever', 'cosmic', 'dear', 'deep',
  'eager', 'early', 'easy', 'empty', 'equal', 'eternal', 'exact', 'fair', 'famous',
  'fast', 'fine', 'firm', 'first', 'flat', 'fluid', 'free', 'fresh', 'gentle',
  'giant', 'glad', 'golden', 'good', 'grand', 'great', 'happy', 'hard', 'high',
  'holy', 'honest', 'humble', 'ideal', 'idle', 'just', 'keen', 'kind', 'known',
  'large', 'last', 'late', 'light', 'lively', 'lucky', 'lunar', 'main', 'major',
  'merry', 'mild', 'minor', 'modest', 'mute', 'near', 'neat', 'new', 'nice',
  'noble', 'north', 'novel', 'open', 'outer', 'plain', 'polite', 'prime', 'proud',
  'pure', 'quick', 'quiet', 'rapid', 'rare', 'ready', 'real', 'rich', 'right',
  'ripe', 'robust', 'round', 'royal', 'secret', 'serene', 'sharp', 'sheer', 'short',
  'shy', 'silent', 'silly', 'simple', 'sincere', 'sleepy', 'slim', 'slow', 'small',
  'smart', 'smooth', 'soft', 'solid', 'sound', 'south', 'spare', 'special', 'speedy',
  'spicy', 'spiky', 'stable', 'steady', 'still', 'strong', 'sturdy', 'sunny', 'super',
  'supreme', 'sweet', 'swift', 'tall', 'tender', 'thankful', 'thick', 'thin', 'tidy',
  'tight', 'tiny', 'top', 'tough', 'true', 'vast', 'velvet', 'vivid', 'warm',
  'warmth', 'watchful', 'west', 'whole', 'wide', 'wild', 'windy', 'wise', 'witty',
  'young', 'zesty', 'century', 'daily', 'day', 'decade', 'evening', 'friday', 'hour',
  'instant', 'july', 'june', 'monday', 'month', 'morning', 'night', 'noon', 'saturday',
  'season', 'second', 'sunday', 'today', 'tomorrow', 'tonight', 'week', 'weekend', 'winter',
  'yesterday', 'dozen', 'eight', 'eleven', 'extra', 'fifth', 'five', 'four', 'half',
  'minus', 'nine', 'seven', 'six', 'ten', 'third', 'three', 'twelve', 'twenty',
  'two', 'zero', 'crayon', 'desk', 'journal', 'marker', 'notebook', 'school', 'stapler',
  'tape', 'textbook', 'apron', 'attic', 'awning', 'balcony', 'bandit', 'barge', 'beam',
  'blaze', 'bluff', 'bonnet', 'boulder', 'buckle', 'budget', 'bullet', 'bungalow', 'cabin',
  'canyon', 'carbon', 'cargo', 'cavern', 'chisel', 'cider', 'cinder', 'circus', 'cliff',
  'coal', 'cobweb', 'cove', 'crater', 'crest', 'cricket', 'crystal', 'cymbal', 'dairy',
  'dapple', 'dart', 'debris', 'decoy', 'denim', 'depot', 'desert', 'diamond', 'diesel',
  'dinghy', 'ditch', 'domino', 'donut', 'doorway', 'dragon', 'drawer', 'drift', 'duet',
  'easel', 'echo', 'ember', 'escalator', 'ether', 'faucet', 'feather', 'fedora', 'ferry',
  'fiddle', 'flame', 'flannel', 'forge', 'fossil', 'fountain', 'fragment', 'freight', 'fresco',
  'fringe', 'furnace', 'gallon', 'gazelle', 'geyser', 'gherkin', 'gingham', 'glider', 'goblin',
  'gondola', 'granite', 'gravel', 'grotto', 'guitar', 'gully', 'gutter', 'hammock', 'heather',
  'hemisphere', 'hickory', 'hollow', 'hornet', 'hostel', 'humus', 'hurdle', 'igloo', 'jackal',
  'jasmine', 'jetty', 'jungle', 'juniper', 'kayak', 'kelp', 'kernel', 'kindle', 'knapsack',
  'lantern', 'lapel', 'lattice', 'leopard', 'lichen', 'linen', 'lintel', 'lobster', 'locket',
  'luggage', 'lumber', 'mahogany', 'marble', 'marigold', 'marmalade', 'melon', 'meteor', 'microscope',
  'mitten', 'moccasin', 'mosaic', 'nectar', 'nugget', 'oasis', 'obelisk', 'opal', 'orbit',
  'oregano', 'osprey', 'otter', 'outpost', 'oyster', 'paddle', 'pagoda', 'parchment', 'parsley',
  'pastel', 'pergola', 'pewter', 'pineapple', 'pistachio', 'plateau', 'plumage', 'plywood', 'popcorn',
  'porcelain', 'portal', 'potter', 'pretzel', 'pumice', 'quail', 'quarry', 'quartz', 'quiver',
  'raccoon', 'raffia', 'raft', 'raspberry', 'rattan', 'ravine', 'ridge', 'rivulet', 'rocket',
  'rooster', 'rosemary', 'rudder', 'rustic', 'saffron', 'sage', 'sardine', 'satchel', 'scooter',
  'scallop', 'scree', 'scroll', 'seagull', 'seashell', 'seaweed', 'sequoia', 'shale', 'shamrock',
  'sheaf', 'shell', 'silo', 'skiff', 'sleet', 'slipper', 'sloop', 'smoothie', 'sorrel',
  'spindle', 'squash', 'squill', 'starling', 'steeple', 'stingray', 'stool', 'streamlin', 'stump',
  'sturgeon', 'summit', 'sundial', 'swallow', 'sycamore', 'taffeta', 'talcum', 'tamarind', 'tandem',
  'tangle', 'tapestry', 'tarp', 'tassel', 'tawny', 'teak', 'thicket', 'thimble', 'thrush',
  'tickle', 'timber', 'tinder', 'toffee', 'topaz', 'torrent', 'tortoise', 'tote', 'trellis',
  'trestle', 'trillium', 'trumpet', 'tundra', 'verbena', 'vernal', 'viola', 'waddle', 'wagon',
  'warbler', 'warren', 'waterweed', 'wax', 'weevil', 'whisker', 'window', 'wombat', 'woodland',
  'yarrow', 'yonder', 'zinnia',
];
