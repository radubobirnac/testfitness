import 'package:testfitness/models/exercise.dart';

/// Fine-grained muscles used by muscle-split workouts. Derived from the
/// exercise name (curated table → name heuristics → coarse muscleGroup);
/// nothing is stored in the database.
enum Muscle {
  chest,
  back,
  shoulders,
  biceps,
  triceps,
  forearms,
  quads,
  hamstrings,
  glutes,
  calves,
  core,
  cardio,
}

extension MuscleLabel on Muscle {
  /// Display label, e.g. "Chest", "Biceps".
  String get label => switch (this) {
        Muscle.chest => 'Chest',
        Muscle.back => 'Back',
        Muscle.shoulders => 'Shoulders',
        Muscle.biceps => 'Biceps',
        Muscle.triceps => 'Triceps',
        Muscle.forearms => 'Forearms',
        Muscle.quads => 'Quads',
        Muscle.hamstrings => 'Hamstrings',
        Muscle.glutes => 'Glutes',
        Muscle.calves => 'Calves',
        Muscle.core => 'Core',
        Muscle.cardio => 'Cardio',
      };
}

/// Which muscles an exercise trains. [primary] is ordered: the first entry is
/// the muscle the exercise is mainly known for.
class MuscleProfile {
  final Set<Muscle> primary;
  final Set<Muscle> secondary;

  /// Multi-joint movement (presses, rows, squats, hinges, pull-ups, dips…).
  final bool compound;

  const MuscleProfile({
    required this.primary,
    this.secondary = const {},
    this.compound = false,
  });

  /// Trains [m] at all (primary or secondary).
  bool hits(Muscle m) => primary.contains(m) || secondary.contains(m);

  /// [m] is a primary mover.
  bool primarily(Muscle m) => primary.contains(m);

  /// Every muscle trained, primary first.
  Set<Muscle> get all => {...primary, ...secondary};

  @override
  String toString() =>
      'MuscleProfile(primary: $primary, secondary: $secondary, compound: $compound)';
}

// Short aliases to keep the table readable.
const _chest = Muscle.chest;
const _back = Muscle.back;
const _shoulders = Muscle.shoulders;
const _biceps = Muscle.biceps;
const _triceps = Muscle.triceps;
const _forearms = Muscle.forearms;
const _quads = Muscle.quads;
const _hams = Muscle.hamstrings;
const _glutes = Muscle.glutes;
const _calves = Muscle.calves;
const _core = Muscle.core;
const _cardio = Muscle.cardio;

/// Compound entry.
MuscleProfile _c(Set<Muscle> primary, [Set<Muscle> secondary = const {}]) =>
    MuscleProfile(primary: primary, secondary: secondary, compound: true);

/// Isolation entry.
MuscleProfile _i(Set<Muscle> primary, [Set<Muscle> secondary = const {}]) =>
    MuscleProfile(primary: primary, secondary: secondary);

class MuscleMap {
  MuscleMap._();

  /// Curated profiles for every built-in exercise, keyed by lower-case name.
  static final Map<String, MuscleProfile> _curated = {
    // Barbell – chest
    'bench press': _c({_chest}, {_triceps, _shoulders}),
    'incline bench press': _c({_chest}, {_shoulders, _triceps}),
    'decline bench press': _c({_chest}, {_triceps, _shoulders}),
    'close-grip bench press': _c({_chest, _triceps}, {_shoulders}),
    // Barbell – back
    'deadlift': _c({_hams, _glutes, _back}, {_quads, _forearms, _core}),
    'barbell row': _c({_back}, {_biceps, _forearms}),
    't-bar row': _c({_back}, {_biceps, _forearms}),
    'pendlay row': _c({_back}, {_biceps, _forearms}),
    // Barbell – legs
    'squat': _c({_quads, _glutes}, {_hams, _core}),
    'front squat': _c({_quads, _glutes}, {_core, _back}),
    'romanian deadlift': _c({_hams, _glutes}, {_back, _forearms}),
    'barbell lunge': _c({_quads, _glutes}, {_hams, _core}),
    'barbell hip thrust': _c({_glutes}, {_hams}),
    'barbell calf raise': _i({_calves}),
    'zercher squat': _c({_quads, _glutes}, {_core, _back}),
    'good morning': _c({_hams, _back}, {_glutes, _core}),
    // Barbell – shoulders
    'overhead press': _c({_shoulders}, {_triceps, _core}),
    'push press': _c({_shoulders}, {_triceps, _quads}),
    'barbell upright row': _c({_shoulders}, {_back, _biceps}),
    'barbell shrug': _i({_shoulders}, {_back, _forearms}),
    // Barbell – arms
    'barbell curl': _i({_biceps}, {_forearms}),
    'reverse grip barbell curl': _i({_forearms}, {_biceps}),
    'skull crushers': _i({_triceps}),
    'barbell wrist curl': _i({_forearms}),
    // Dumbbell
    'dumbbell press': _c({_chest}, {_triceps, _shoulders}),
    'dumbbell fly': _i({_chest}, {_shoulders}),
    'lateral raise': _i({_shoulders}),
    'dumbbell curl': _i({_biceps}, {_forearms}),
    'hammer curl': _i({_biceps}, {_forearms}),
    'dumbbell skull crushers': _i({_triceps}),
    'triceps extension': _i({_triceps}),
    'dumbbell row': _c({_back}, {_biceps}),
    // Machine
    'leg press': _c({_quads, _glutes}, {_hams}),
    'chest press machine': _c({_chest}, {_triceps, _shoulders}),
    'lat pulldown': _c({_back}, {_biceps}),
    'seated row': _c({_back}, {_biceps}),
    'leg extension': _i({_quads}),
    'leg curl': _i({_hams}, {_calves}),
    // Cable
    'cable fly': _i({_chest}, {_shoulders}),
    'triceps pushdown': _i({_triceps}),
    'cable curl': _i({_biceps}, {_forearms}),
    'face pull': _i({_shoulders}, {_back}),
    'cable row': _c({_back}, {_biceps}),
    'archer curl': _i({_biceps}),
    'cable crunch': _i({_core}),
    // Bodyweight
    'push-up': _c({_chest}, {_triceps, _shoulders, _core}),
    'pull-up': _c({_back}, {_biceps, _forearms}),
    'bodyweight squat': _c({_quads, _glutes}, {_hams}),
    'lunge': _c({_quads, _glutes}, {_hams}),
    'dip': _c({_triceps}, {_chest, _shoulders}),
    'plank': _i({_core}, {_shoulders}),
    'crunch': _i({_core}),
    'mountain climber': _i({_core}, {_shoulders, _cardio}),
    'assisted chin up': _c({_back}, {_biceps}),
    'assisted dip': _c({_triceps}, {_chest, _shoulders}),
    'assisted pull up': _c({_back}, {_biceps}),
    'dragon flag': _i({_core}),
    'hanging leg raise': _i({_core}, {_forearms}),
    // Cardio
    'treadmill': _i({_cardio}, {_quads, _calves}),
    'stationary bike': _i({_cardio}, {_quads}),
    'elliptical': _i({_cardio}, {_quads, _glutes}),
    'rowing machine': _i({_cardio}, {_back, _quads}),
    'jump rope': _i({_cardio}, {_calves}),
    'air bike': _i({_cardio}, {_quads, _shoulders}),
    // Core
    'ab wheel': _i({_core}, {_shoulders, _back}),
    'russian twist': _i({_core}),
    'leg raise': _i({_core}),
    'hollow hold': _i({_core}),
    // Machine – shoulders
    'lateral raise machine': _i({_shoulders}),
    'shoulder press machine': _c({_shoulders}, {_triceps}),
    'reverse fly machine': _i({_shoulders}, {_back}),
    // Machine – chest
    'pec deck machine': _i({_chest}, {_shoulders}),
    'incline chest press machine': _c({_chest}, {_shoulders, _triceps}),
    'decline chest press machine': _c({_chest}, {_triceps}),
    // Machine – back
    't-bar row machine': _c({_back}, {_biceps}),
    'pullover machine': _i({_back}, {_chest}),
    'low row machine': _c({_back}, {_biceps}),
    // Machine – legs
    'seated leg curl': _i({_hams}),
    'standing calf raise machine': _i({_calves}),
    'seated calf raise machine': _i({_calves}),
    'hack squat machine': _c({_quads, _glutes}, {_hams}),
    'abductor machine': _i({_glutes}),
    'adductor machine': _i({_hams}, {_glutes}),
    // Machine – arms
    'bicep curl machine': _i({_biceps}),
    'tricep extension machine': _i({_triceps}),
    'preacher curl machine': _i({_biceps}),
    // Machine – core
    'rotary torso machine': _i({_core}),
    'ab crunch machine': _i({_core}),
    // Smith machine
    'smith machine squat': _c({_quads, _glutes}, {_hams}),
    'smith machine bench press': _c({_chest}, {_triceps, _shoulders}),
    'smith machine shoulder press': _c({_shoulders}, {_triceps}),
    // Hammer Strength
    'hammer strength chest press': _c({_chest}, {_triceps, _shoulders}),
    'hammer strength row': _c({_back}, {_biceps}),
    'hammer strength shoulder press': _c({_shoulders}, {_triceps}),
    // Specialised leg machines
    'glute drive machine': _c({_glutes}, {_hams}),
    'belt squat machine': _c({_quads, _glutes}, {_hams}),
    'leg press hack squat combo': _c({_quads, _glutes}, {_hams}),
    // Cable stations
    'cable crossover station': _i({_chest}, {_shoulders, _back}),
    'functional trainer': _c({_chest, _back}, {_shoulders, _core}),
    // Specialised cardio
    'stair climber': _i({_cardio}, {_quads, _glutes, _calves}),
    "jacob's ladder": _i({_cardio}, {_shoulders, _quads}),
    'versaclimber': _i({_cardio}, {_shoulders, _quads}),
    // Specialised isolation
    'neck flexion machine': _i({_shoulders}),
    'forearm machine': _i({_forearms}),
    'assisted pull-up/dip machine': _c({_back, _triceps}, {_biceps, _chest}),
    'seated dip machine': _c({_triceps}, {_chest, _shoulders}),
    'chest-supported row machine': _c({_back}, {_biceps}),
    'high row machine': _c({_back}, {_biceps}),
    'iso-lateral high row machine': _c({_back}, {_biceps}),
    'chest-supported t-bar row machine': _c({_back}, {_biceps}),
    'pendulum squat machine': _c({_quads, _glutes}),
    'v-squat machine': _c({_quads, _glutes}),
    'hack squat press': _c({_quads, _glutes}),
    'leg press calf raise': _i({_calves}),
    'donkey calf raise machine': _i({_calves}),
    'glute-ham raise machine': _c({_hams, _glutes}, {_back}),
    'hip thrust machine': _c({_glutes}, {_hams}),
    'back extension machine': _i({_back}, {_glutes, _hams}),
    'seated ab crunch machine': _i({_core}),
  };

  /// The curated profile for a built-in exercise name, or null.
  static MuscleProfile? curated(String name) =>
      _curated[name.trim().toLowerCase()];

  /// Lower-case names in the curated table.
  static Iterable<String> get curatedNames => _curated.keys;

  /// Curated table (by name, case-insensitive) → name heuristics → the
  /// coarse muscleGroup string. Unknown exercises get an empty profile.
  static MuscleProfile of(Exercise e) {
    return curated(e.name) ??
        fromName(e.name) ??
        fromGroups(e.muscleGroup) ??
        const MuscleProfile(primary: {});
  }

  /// Name heuristics for custom exercises; null when nothing matches.
  static MuscleProfile? fromName(String name) {
    final n =
        ' ${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim()} ';
    bool has(String k) => n.contains(k);
    bool any(List<String> ks) => ks.any(has);

    // Cardio machines / conditioning (not "mountain climber").
    if (any([
          ' treadmill ',
          ' bike ',
          ' cycling ',
          ' elliptical ',
          ' jog',
          ' running ',
          ' run ',
          ' rower ',
          ' rowing machine ',
          ' jump rope ',
          ' skipping ',
          ' stair',
          ' sprint',
          ' burpee'
        ]) ||
        (has('climber') && !has('mountain'))) {
      return _i({_cardio});
    }
    if (has('calf') || has('calves')) return _i({_calves});
    if (any([' wrist ', 'forearm', ' farmer'])) return _i({_forearms});
    if (any([' reverse curl', 'reverse grip curl', ' zottman'])) {
      return _i({_forearms}, {_biceps});
    }
    if (any([' leg curl', 'hamstring', ' nordic', ' glute ham', ' ghr '])) {
      return _i({_hams}, {_glutes});
    }
    if (any([' glute', ' hip thrust', ' bridge ', ' abduct', ' donkey kick'])) {
      return _c({_glutes}, {_hams});
    }
    if (any([' rdl ', 'romanian', 'stiff leg', 'good morning'])) {
      return _c({_hams, _glutes}, {_back});
    }
    if (has('deadlift')) {
      return _c({_hams, _glutes, _back}, {_quads, _forearms});
    }
    if (any([' leg extension', ' sissy'])) return _i({_quads});
    if (any([
      ' squat',
      ' leg press',
      ' lunge',
      ' step up',
      ' split squat',
      ' pistol'
    ])) {
      return _c({_quads, _glutes}, {_hams});
    }
    if (any([' adduct'])) return _i({_hams}, {_glutes});
    if (has(' curl')) return _i({_biceps}, {_forearms});
    if (any([
      ' pushdown',
      ' push down',
      ' pressdown',
      ' skull',
      ' kickback',
      ' tricep',
      ' french press',
      ' jm press'
    ])) {
      return _i({_triceps});
    }
    if (any([' close grip', ' diamond push'])) {
      return _c({_chest, _triceps}, {_shoulders});
    }
    if (any([' dip ', ' dips '])) return _c({_triceps}, {_chest, _shoulders});
    if (any([' shrug'])) return _i({_shoulders}, {_back});
    if (any([
      ' face pull',
      ' rear delt',
      ' reverse fly',
      ' reverse flye',
      ' band pull apart'
    ])) {
      return _i({_shoulders}, {_back});
    }
    if (has(' upright row')) return _c({_shoulders}, {_back, _biceps});
    if (any([' pullover', ' pull over', ' straight arm'])) {
      return _i({_back}, {_chest});
    }
    if (any([
      ' row ',
      ' rows ',
      ' pulldown',
      ' pull down',
      ' pull up',
      ' pullup',
      ' chin'
    ])) {
      return _c({_back}, {_biceps, _forearms});
    }
    if (any([' back extension', ' hyperextension', ' superman'])) {
      return _i({_back}, {_glutes, _hams});
    }
    if (any([
      ' lateral raise',
      ' side raise',
      ' front raise',
      ' delt',
      ' y raise'
    ])) {
      return _i({_shoulders});
    }
    if (any([
      ' overhead press',
      ' shoulder press',
      ' military',
      ' arnold',
      ' ohp ',
      ' landmine press'
    ])) {
      return _c({_shoulders}, {_triceps});
    }
    if (any([' fly ', ' flye', ' flys ', ' pec ', ' crossover'])) {
      return _i({_chest}, {_shoulders});
    }
    if (any(
        [' bench', ' chest press', ' push up', ' pushup', ' floor press'])) {
      return _c({_chest}, {_triceps, _shoulders});
    }
    if (any([
      ' plank',
      ' crunch',
      ' sit up',
      ' situp',
      ' ab ',
      ' abs ',
      ' leg raise',
      ' knee raise',
      ' twist',
      ' hollow',
      ' core',
      ' oblique',
      ' woodchop',
      ' wood chop',
      ' pallof',
      ' dead bug',
      ' v up',
      ' rollout',
      ' l sit',
      ' mountain climber'
    ])) {
      return _i({_core});
    }
    return null;
  }

  /// Coarse fallback from a muscleGroup string such as "Chest, Arms".
  /// Null when nothing is recognised.
  static MuscleProfile? fromGroups(String? muscleGroup) {
    final raw = muscleGroup?.trim() ?? '';
    if (raw.isEmpty) return null;
    final primary = <Muscle>{};
    for (final part in raw.split(',')) {
      switch (part.trim().toLowerCase()) {
        case 'chest':
          primary.add(_chest);
        case 'back':
          primary.add(_back);
        case 'shoulder' || 'shoulders':
          primary.add(_shoulders);
        case 'arms':
          primary.addAll({_biceps, _triceps});
        case 'biceps' || 'bicep':
          primary.add(_biceps);
        case 'triceps' || 'tricep':
          primary.add(_triceps);
        case 'forearms' || 'forearm':
          primary.add(_forearms);
        case 'legs':
          primary.addAll({_quads, _hams, _glutes});
        case 'quads' || 'quadriceps':
          primary.add(_quads);
        case 'hamstrings':
          primary.add(_hams);
        case 'glutes':
          primary.add(_glutes);
        case 'calves':
          primary.add(_calves);
        case 'core' || 'abs':
          primary.add(_core);
        case 'cardio':
          primary.add(_cardio);
      }
    }
    if (primary.isEmpty) return null;
    return MuscleProfile(primary: primary, compound: primary.length >= 2);
  }
}
