import 'package:testfitness/models/exercise.dart';

List<Exercise> buildDefaultExercises() {
  return [

    // Barbell Exercises - Chest
    Exercise.create(
      name: 'Bench Press',
      description: 'Lie on a flat bench and press the weight upward.',
      muscleGroup: 'Chest',
      category: 'Barbell',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Incline Bench Press',
      description: 'Press the barbell while lying on an inclined bench.',
      muscleGroup: 'Chest',
      category: 'Barbell',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Decline Bench Press',
      description: 'Press the barbell while lying on a declined bench.',
      muscleGroup: 'Chest',
      category: 'Barbell',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Close-Grip Bench Press',
      description:
          'Bench press with hands placed closer together to target triceps.',
      muscleGroup: 'Chest, Arms',
      category: 'Barbell',
      isCustom: false,
    ),

    // Barbell Exercises - Back
    Exercise.create(
      name: 'Deadlift',
      description:
          'A compound exercise that works many muscle groups including the back, glutes, and hamstrings.',
      muscleGroup: 'Back',
      category: 'Barbell',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Barbell Row',
      description:
          'Bend over and row the barbell to your lower chest/upper abdomen.',
      muscleGroup: 'Back',
      category: 'Barbell',
      isCustom: false,
    ),
    Exercise.create(
      name: 'T-Bar Row',
      description: 'Chest-supported row using a barbell with one end fixed.',
      muscleGroup: 'Back',
      category: 'Barbell',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Pendlay Row',
      description:
          'Row from floor to upper abdomen with each rep starting from a dead stop.',
      muscleGroup: 'Back',
      category: 'Barbell',
      isCustom: false,
    ),

    // Barbell Exercises - Legs
    Exercise.create(
      name: 'Squat',
      description:
          'A compound exercise that works primarily the quadriceps, hamstrings, and glutes.',
      muscleGroup: 'Legs',
      category: 'Barbell',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Front Squat',
      description:
          'Hold barbell across front of shoulders and perform a squat.',
      muscleGroup: 'Legs',
      category: 'Barbell',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Romanian Deadlift',
      description:
          'Deadlift variation focusing on hamstrings with less knee bend.',
      muscleGroup: 'Legs, Back',
      category: 'Barbell',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Barbell Lunge',
      description: 'Step forward with one leg while holding a barbell.',
      muscleGroup: 'Legs',
      category: 'Barbell',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Barbell Hip Thrust',
      description:
          'Rest upper back on bench, place barbell across hips, thrust upward.',
      muscleGroup: 'Legs',
      category: 'Barbell',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Barbell Calf Raise',
      description: 'Stand with barbell on shoulders and raise heels.',
      muscleGroup: 'Legs',
      category: 'Barbell',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Zercher Squat',
      description: 'Hold barbell in the crook of elbows and squat.',
      muscleGroup: 'Legs',
      category: 'Barbell',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Good Morning',
      description:
          'With barbell on shoulders, hinge at hips while keeping back straight.',
      muscleGroup: 'Back, Legs',
      category: 'Barbell',
      isCustom: false,
    ),

    // Barbell Exercises - Shoulders
    Exercise.create(
      name: 'Overhead Press',
      description: 'Press the barbell overhead from shoulder height.',
      muscleGroup: 'Shoulders',
      category: 'Barbell',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Push Press',
      description: 'Use leg drive to help press barbell overhead.',
      muscleGroup: 'Shoulders',
      category: 'Barbell',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Barbell Upright Row',
      description: 'Pull barbell vertically up along the body.',
      muscleGroup: 'Shoulders',
      category: 'Barbell',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Barbell Shrug',
      description: 'Hold barbell at arms length and elevate shoulders.',
      muscleGroup: 'Shoulders',
      category: 'Barbell',
      isCustom: false,
    ),

    // Barbell Exercises - Arms
    Exercise.create(
      name: 'Barbell Curl',
      description:
          'Curl the barbell with palms facing up to work the biceps.',
      muscleGroup: 'Arms',
      category: 'Barbell',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Reverse Grip Barbell Curl',
      description: 'Curl with palms facing down to target forearms.',
      muscleGroup: 'Arms',
      category: 'Barbell',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Skull Crushers',
      description:
          'Lie on a bench and lower the barbell toward your forehead, then extend arms.',
      muscleGroup: 'Arms',
      category: 'Barbell',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Barbell Wrist Curl',
      description:
          'Seated with forearms on thighs, curl barbell with wrists.',
      muscleGroup: 'Arms',
      category: 'Barbell',
      isCustom: false,
    ),

    // Dumbbell Exercises
    Exercise.create(
      name: 'Dumbbell Press',
      description: 'Press dumbbells upward while lying on a flat bench.',
      muscleGroup: 'Chest',
      category: 'Dumbbell',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Dumbbell Fly',
      description:
          'Lie on a bench and open your arms wide with a slight bend in the elbows.',
      muscleGroup: 'Chest',
      category: 'Dumbbell',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Lateral Raise',
      description:
          'Raise dumbbells to the sides to target the lateral deltoids.',
      muscleGroup: 'Shoulders',
      category: 'Dumbbell',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Dumbbell Curl',
      description:
          'Curl the dumbbells with palms facing up to work the biceps.',
      muscleGroup: 'Arms',
      category: 'Dumbbell',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Hammer Curl',
      description:
          'Curl the dumbbells with palms facing each other to work the biceps and forearms.',
      muscleGroup: 'Arms',
      category: 'Dumbbell',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Dumbbell Skull Crushers',
      description: 'Same as barbell version but with dumbbells.',
      muscleGroup: 'Arms',
      category: 'Dumbbell',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Triceps Extension',
      description: 'Extend the arm to work the triceps muscle.',
      muscleGroup: 'Arms',
      category: 'Dumbbell',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Dumbbell Row',
      description:
          'Row a dumbbell with one arm while supporting yourself with the other.',
      muscleGroup: 'Back',
      category: 'Dumbbell',
      isCustom: false,
    ),

    // Machine Exercises
    Exercise.create(
      name: 'Leg Press',
      description: 'Push the weight away using your legs while seated.',
      muscleGroup: 'Legs',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Chest Press Machine',
      description: 'Press the handles away from your chest while seated.',
      muscleGroup: 'Chest',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Lat Pulldown',
      description:
          'Pull the bar down toward your chest using your back muscles.',
      muscleGroup: 'Back',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Seated Row',
      description: 'Pull the handles toward your abdomen while seated.',
      muscleGroup: 'Back',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Leg Extension',
      description: 'Extend your legs to work the quadriceps.',
      muscleGroup: 'Legs',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Leg Curl',
      description: 'Curl your legs to work the hamstrings.',
      muscleGroup: 'Legs',
      category: 'Machine',
      isCustom: false,
    ),

    // Cable Exercises
    Exercise.create(
      name: 'Cable Fly',
      description: 'Bring cable handles together in front of your chest.',
      muscleGroup: 'Chest',
      category: 'Cable',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Triceps Pushdown',
      description:
          'Push the cable down to extend the elbows and work the triceps.',
      muscleGroup: 'Arms',
      category: 'Cable',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Cable Curl',
      description: 'Curl the cable upward to work the biceps.',
      muscleGroup: 'Arms',
      category: 'Cable',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Face Pull',
      description:
          'Pull the rope attachment toward your face to work the rear deltoids.',
      muscleGroup: 'Shoulders',
      category: 'Cable',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Cable Row',
      description: 'Pull the cable toward your abdomen while seated.',
      muscleGroup: 'Back',
      category: 'Cable',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Archer Curl',
      description:
          'A specialized cable curl variation that targets the biceps.',
      muscleGroup: 'Arms',
      category: 'Cable',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Cable Crunch',
      description: 'Kneel and crunch downward with cable.',
      muscleGroup: 'Core',
      category: 'Cable',
      isCustom: false,
    ),

    // Bodyweight Exercises
    Exercise.create(
      name: 'Push-up',
      description:
          'A compound exercise that works the chest, shoulders, and triceps.',
      muscleGroup: 'Chest',
      category: 'Bodyweight',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Pull-up',
      description:
          'A compound upper-body exercise that works the back, shoulders, and arms.',
      muscleGroup: 'Back',
      category: 'Bodyweight',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Bodyweight Squat',
      description:
          'Lower your body by bending your knees and hips, then return to standing.',
      muscleGroup: 'Legs',
      category: 'Bodyweight',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Lunge',
      description: 'Step forward and lower your body to work the legs.',
      muscleGroup: 'Legs',
      category: 'Bodyweight',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Dip',
      description: 'Lower and raise your body between parallel bars.',
      muscleGroup: 'Chest',
      category: 'Bodyweight',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Plank',
      description:
          'Hold a position similar to a push-up to strengthen the core.',
      muscleGroup: 'Core',
      category: 'Bodyweight',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Crunch',
      description:
          'Lie on your back and lift your shoulders to work the abs.',
      muscleGroup: 'Core',
      category: 'Bodyweight',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Mountain Climber',
      description: 'Alternate bringing knees to chest in a plank position.',
      muscleGroup: 'Core',
      category: 'Bodyweight',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Assisted Chin Up',
      description:
          'Pull your body up with assistance to work back and biceps.',
      muscleGroup: 'Back, Arms',
      category: 'Assisted bodyweight',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Assisted Dip',
      description:
          'Lower and raise your body with assistance to work chest and triceps.',
      muscleGroup: 'Chest, Arms',
      category: 'Assisted bodyweight',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Assisted Pull Up',
      description:
          'Pull your body up with assistance to work the back muscles.',
      muscleGroup: 'Back',
      category: 'Assisted bodyweight',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Dragon Flag',
      description: 'Advanced core exercise lying on bench.',
      muscleGroup: 'Core',
      category: 'Bodyweight',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Hanging Leg Raise',
      description: 'Raise legs while hanging from bar.',
      muscleGroup: 'Core',
      category: 'Bodyweight',
      isCustom: false,
    ),

    // Cardio Exercises
    Exercise.create(
      name: 'Treadmill',
      description: 'Walk or run on a treadmill for cardiovascular exercise.',
      muscleGroup: 'Cardio',
      category: 'Cardio',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Stationary Bike',
      description: 'Cycle on a stationary bike for cardiovascular exercise.',
      muscleGroup: 'Cardio',
      category: 'Cardio',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Elliptical',
      description:
          'Use an elliptical machine for low-impact cardiovascular exercise.',
      muscleGroup: 'Cardio',
      category: 'Cardio',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Rowing Machine',
      description:
          'Use a rowing machine for full-body cardiovascular exercise.',
      muscleGroup: 'Cardio',
      category: 'Cardio',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Jump Rope',
      description: 'Skip rope for cardiovascular exercise.',
      muscleGroup: 'Cardio',
      category: 'Cardio',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Air Bike',
      description:
          'Use an air bike for high-intensity cardiovascular exercise.',
      muscleGroup: 'Cardio',
      category: 'Cardio',
      isCustom: false,
    ),

    // Core Exercises
    Exercise.create(
      name: 'Ab Wheel',
      description: 'Roll the ab wheel forward and back to work the core.',
      muscleGroup: 'Core',
      category: 'Other',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Russian Twist',
      description: 'Twist your torso from side to side to work the obliques.',
      muscleGroup: 'Core',
      category: 'Other',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Leg Raise',
      description:
          'Raise your legs while lying on your back to work the lower abs.',
      muscleGroup: 'Core',
      category: 'Bodyweight',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Hollow Hold',
      description: 'Hold body in curved position on back.',
      muscleGroup: 'Core',
      category: 'Bodyweight',
      isCustom: false,
    ),


    // ADDITIONAL MACHINE EXERCISES - SHOULDERS
    Exercise.create(
      name: 'Lateral Raise Machine',
      description:
          'Machine version of lateral raises that guides the movement path for consistent shoulder abduction.',
      muscleGroup: 'Shoulders',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Shoulder Press Machine',
      description:
          'Seated machine that guides the pressing movement to target shoulders with reduced stabilization requirements.',
      muscleGroup: 'Shoulders',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Reverse Fly Machine',
      description:
          'Seated machine that targets the posterior deltoids through a controlled backward motion.',
      muscleGroup: 'Shoulders',
      category: 'Machine',
      isCustom: false,
    ),

    // ADDITIONAL MACHINE EXERCISES - CHEST
    Exercise.create(
      name: 'Pec Deck Machine',
      description:
          'Seated machine where arms move horizontally to adduct the shoulders, isolating the chest muscles.',
      muscleGroup: 'Chest',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Incline Chest Press Machine',
      description:
          'Angled press machine targeting the upper chest region with guided movement.',
      muscleGroup: 'Chest',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Decline Chest Press Machine',
      description:
          'Downward angled press machine focusing on the lower chest region.',
      muscleGroup: 'Chest',
      category: 'Machine',
      isCustom: false,
    ),

    // ADDITIONAL MACHINE EXERCISES - BACK
    Exercise.create(
      name: 'T-Bar Row Machine',
      description:
          'Chest-supported rowing machine allowing for targeted back development with reduced lower back stress.',
      muscleGroup: 'Back',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Pullover Machine',
      description:
          'Machine that guides arms through an arcing motion to target the latissimus dorsi.',
      muscleGroup: 'Back',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Low Row Machine',
      description:
          'Seated horizontal pulling machine targeting the mid-back with adjustable height settings.',
      muscleGroup: 'Back',
      category: 'Machine',
      isCustom: false,
    ),

    // ADDITIONAL MACHINE EXERCISES - LEGS
    Exercise.create(
      name: 'Seated Leg Curl',
      description:
          'Seated machine targeting the hamstrings through controlled knee flexion.',
      muscleGroup: 'Legs',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Standing Calf Raise Machine',
      description:
          'Vertical machine for isolating and loading the calf muscles through ankle extension.',
      muscleGroup: 'Legs',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Seated Calf Raise Machine',
      description:
          'Seated machine targeting the soleus muscle through ankle extension with knees bent.',
      muscleGroup: 'Legs',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Hack Squat Machine',
      description:
          'Angled sled machine that allows for back-supported squatting motions with reduced spinal loading.',
      muscleGroup: 'Legs',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Abductor Machine',
      description:
          'Seated machine where you push legs outward against resistance, targeting outer thighs and hips.',
      muscleGroup: 'Legs',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Adductor Machine',
      description:
          'Seated machine where you squeeze legs together against resistance, targeting inner thighs.',
      muscleGroup: 'Legs',
      category: 'Machine',
      isCustom: false,
    ),

    // ADDITIONAL MACHINE EXERCISES - ARMS
    Exercise.create(
      name: 'Bicep Curl Machine',
      description:
          'Isolated machine for bicep curls with fixed movement path for consistent training.',
      muscleGroup: 'Arms',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Tricep Extension Machine',
      description:
          'Seated machine that isolates the triceps through guided elbow extension.',
      muscleGroup: 'Arms',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Preacher Curl Machine',
      description:
          'Machine version of preacher curls with pad support for consistent bicep isolation.',
      muscleGroup: 'Arms',
      category: 'Machine',
      isCustom: false,
    ),

    // ADDITIONAL MACHINE EXERCISES - CORE
    Exercise.create(
      name: 'Rotary Torso Machine',
      description:
          'Seated twisting machine targeting the obliques and rotational core muscles.',
      muscleGroup: 'Core',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Ab Crunch Machine',
      description:
          'Resistance machine that guides the upper body through a controlled crunch motion.',
      muscleGroup: 'Core',
      category: 'Machine',
      isCustom: false,
    ),

    // SMITH MACHINE EXERCISES
    Exercise.create(
      name: 'Smith Machine Squat',
      description:
          'Barbell squat performed on a Smith machine with guided vertical bar path.',
      muscleGroup: 'Legs',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Smith Machine Bench Press',
      description:
          "Horizontal press using the Smith machine's guided bar path for chest development.",
      muscleGroup: 'Chest',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Smith Machine Shoulder Press',
      description:
          "Overhead press using Smith machine's guided path for safer shoulder loading.",
      muscleGroup: 'Shoulders',
      category: 'Machine',
      isCustom: false,
    ),

    // HAMMER STRENGTH MACHINES
    Exercise.create(
      name: 'Hammer Strength Chest Press',
      description:
          'Plate-loaded horizontal press with independent arm movement for balanced chest development.',
      muscleGroup: 'Chest',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Hammer Strength Row',
      description:
          'Plate-loaded seated row with independent arm movement for balanced back development.',
      muscleGroup: 'Back',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Hammer Strength Shoulder Press',
      description:
          'Plate-loaded overhead press with independent arm movement for shoulders.',
      muscleGroup: 'Shoulders',
      category: 'Machine',
      isCustom: false,
    ),

    // SPECIALIZED LEG MACHINES
    Exercise.create(
      name: 'Glute Drive Machine',
      description:
          'Specialized machine for performing hip thrusts with optimal glute activation.',
      muscleGroup: 'Legs',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Belt Squat Machine',
      description:
          'Lower body squat variation using a belt attachment to reduce spinal loading.',
      muscleGroup: 'Legs',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Leg Press Hack Squat Combo',
      description:
          'Dual-function machine allowing both leg press and hack squat movements.',
      muscleGroup: 'Legs',
      category: 'Machine',
      isCustom: false,
    ),

    // CABLE-BASED STATIONS
    Exercise.create(
      name: 'Cable Crossover Station',
      description:
          'Dual adjustable pulley system allowing for various chest, shoulder and back exercises.',
      muscleGroup: 'Multiple',
      category: 'Cable',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Functional Trainer',
      description:
          'Versatile cable machine with adjustable heights for full-body functional training.',
      muscleGroup: 'Multiple',
      category: 'Cable',
      isCustom: false,
    ),

    // SPECIALIZED CARDIO MACHINES
    Exercise.create(
      name: 'Stair Climber',
      description:
          'Simulates climbing stairs for intense lower body and cardiovascular workout.',
      muscleGroup: 'Cardio, Legs',
      category: 'Cardio',
      isCustom: false,
    ),
    Exercise.create(
      name: "Jacob's Ladder",
      description:
          'Self-paced climbing machine that provides a full-body cardio workout.',
      muscleGroup: 'Cardio',
      category: 'Cardio',
      isCustom: false,
    ),
    Exercise.create(
      name: 'VersaClimber',
      description:
          'Vertical climbing machine engaging both upper and lower body simultaneously.',
      muscleGroup: 'Cardio',
      category: 'Cardio',
      isCustom: false,
    ),

    // SPECIALIZED ISOLATION MACHINES
    Exercise.create(
      name: 'Neck Flexion Machine',
      description:
          'Specialized machine for safely training neck muscles through controlled resistance.',
      muscleGroup: 'Neck',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Forearm Machine',
      description:
          'Dedicated machine for targeted forearm development through wrist movements.',
      muscleGroup: 'Arms',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Assisted Pull-Up/Dip Machine',
      description:
          'Counterbalanced machine to assist pull-ups and dips with adjustable support.',
      muscleGroup: 'Back, Chest, Arms',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Seated Dip Machine',
      description:
          'Seated machine that targets triceps and chest with a dip motion.',
      muscleGroup: 'Arms, Chest',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Chest-Supported Row Machine',
      description:
          'Rowing machine with chest support to isolate the back and reduce lower back strain.',
      muscleGroup: 'Back',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'High Row Machine',
      description:
          'Machine row with a higher pulling angle to emphasize upper back and lats.',
      muscleGroup: 'Back',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Iso-Lateral High Row Machine',
      description:
          'Independent arm high row machine for balanced upper back and lat development.',
      muscleGroup: 'Back',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Chest-Supported T-Bar Row Machine',
      description:
          'Chest-supported T-bar row for controlled back training.',
      muscleGroup: 'Back',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Pendulum Squat Machine',
      description:
          'Squat machine with a pendulum arc to emphasize quads and glutes.',
      muscleGroup: 'Legs',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'V-Squat Machine',
      description:
          'Squat machine with a V-shaped pad that guides a deep squat pattern.',
      muscleGroup: 'Legs',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Hack Squat Press',
      description:
          'Hack squat variation with a pressing sled for quad-focused work.',
      muscleGroup: 'Legs',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Leg Press Calf Raise',
      description:
          'Calf raises performed on a leg press machine for heavy loading.',
      muscleGroup: 'Legs',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Donkey Calf Raise Machine',
      description:
          'Machine that targets calves with a bent-over donkey raise position.',
      muscleGroup: 'Legs',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Glute-Ham Raise Machine',
      description:
          'Machine for posterior chain development focusing on hamstrings and glutes.',
      muscleGroup: 'Legs, Back',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Hip Thrust Machine',
      description:
          'Dedicated hip thrust machine for glute and posterior chain focus.',
      muscleGroup: 'Legs',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Back Extension Machine',
      description:
          'Machine for lower back and glute endurance with controlled extension.',
      muscleGroup: 'Back, Legs',
      category: 'Machine',
      isCustom: false,
    ),
    Exercise.create(
      name: 'Seated Ab Crunch Machine',
      description:
          'Seated machine targeting abdominal crunch movement with fixed resistance.',
      muscleGroup: 'Core',
      category: 'Machine',
      isCustom: false,
    ),
  ];
}
