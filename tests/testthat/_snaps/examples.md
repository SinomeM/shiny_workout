# example bodyweight-hiit.yaml is valid, round-trips and compiles

    Code
      cat(describe_steps(steps), sep = "\n")
    Output
       1 prep     Get ready                                      10s auto                   ~10s
       2 warmup   March in place                                 120s auto                  ~120s
       3 exercise Squat jumps                        R1/4        40s auto                   ~40s
       4 rest     Rest                               R1/4        20s auto                   ~20s
       5 exercise Mountain climbers                  R1/4        40s auto                   ~40s
       6 rest     Rest                               R1/4        20s auto                   ~20s
       7 exercise Burpees                            R1/4        40s auto                   ~40s
       8 rest     Rest                               R1/4        20s auto                   ~20s
       9 exercise High knees                         R1/4        40s auto                   ~40s
      10 rest     Rest                               R1/4        60s auto                   ~60s
      11 exercise Squat jumps                        R2/4        40s auto                   ~40s
      12 rest     Rest                               R2/4        20s auto                   ~20s
      13 exercise Mountain climbers                  R2/4        40s auto                   ~40s
      14 rest     Rest                               R2/4        20s auto                   ~20s
      15 exercise Burpees                            R2/4        40s auto                   ~40s
      16 rest     Rest                               R2/4        20s auto                   ~20s
      17 exercise High knees                         R2/4        40s auto                   ~40s
      18 rest     Rest                               R2/4        60s auto                   ~60s
      19 exercise Squat jumps                        R3/4        40s auto                   ~40s
      20 rest     Rest                               R3/4        20s auto                   ~20s
      21 exercise Mountain climbers                  R3/4        40s auto                   ~40s
      22 rest     Rest                               R3/4        20s auto                   ~20s
      23 exercise Burpees                            R3/4        40s auto                   ~40s
      24 rest     Rest                               R3/4        20s auto                   ~20s
      25 exercise High knees                         R3/4        40s auto                   ~40s
      26 rest     Rest                               R3/4        60s auto                   ~60s
      27 exercise Squat jumps                        R4/4        40s auto                   ~40s
      28 rest     Rest                               R4/4        20s auto                   ~20s
      29 exercise Mountain climbers                  R4/4        40s auto                   ~40s
      30 rest     Rest                               R4/4        20s auto                   ~20s
      31 exercise Burpees                            R4/4        40s auto                   ~40s
      32 rest     Rest                               R4/4        20s auto                   ~20s
      33 exercise High knees                         R4/4        40s auto                   ~40s
      34 cooldown Walk and breathe                               120s auto                  ~120s

# example bodyweight-strength.yaml is valid, round-trips and compiles

    Code
      cat(describe_steps(steps), sep = "\n")
    Output
       1 prep     Get ready                                      10s auto                   ~10s
       2 warmup   Jumping jacks                                  60s auto                   ~60s
       3 warmup   Arm circles                                    30s auto                   ~30s
       4 exercise Push-ups                           R1/3        10 reps manual             ~30s
       5 exercise Bodyweight squats                  R1/3        15 reps manual             ~45s
       6 exercise Reverse lunges               Left  R1/3        8 reps manual              ~24s
       7 switch   Switch sides                       R1/3        5s auto                    ~5s
       8 exercise Reverse lunges               Right R1/3        8 reps manual              ~24s
       9 exercise Glute bridge                       R1/3        12 reps manual             ~36s
      10 exercise Plank                              R1/3        30s auto                   ~30s
      11 rest     Rest                               R1/3        60s auto                   ~60s
      12 exercise Push-ups                           R2/3        10 reps manual             ~30s
      13 exercise Bodyweight squats                  R2/3        15 reps manual             ~45s
      14 exercise Reverse lunges               Left  R2/3        8 reps manual              ~24s
      15 switch   Switch sides                       R2/3        5s auto                    ~5s
      16 exercise Reverse lunges               Right R2/3        8 reps manual              ~24s
      17 exercise Glute bridge                       R2/3        12 reps manual             ~36s
      18 exercise Plank                              R2/3        30s auto                   ~30s
      19 rest     Rest                               R2/3        60s auto                   ~60s
      20 exercise Push-ups                           R3/3        10 reps manual             ~30s
      21 exercise Bodyweight squats                  R3/3        15 reps manual             ~45s
      22 exercise Reverse lunges               Left  R3/3        8 reps manual              ~24s
      23 switch   Switch sides                       R3/3        5s auto                    ~5s
      24 exercise Reverse lunges               Right R3/3        8 reps manual              ~24s
      25 exercise Glute bridge                       R3/3        12 reps manual             ~36s
      26 exercise Plank                              R3/3        30s auto                   ~30s
      27 cooldown Stretch                                        manual                     ~open

# example core-plank-ladder.yaml is valid, round-trips and compiles

    Code
      cat(describe_steps(steps), sep = "\n")
    Output
       1 prep     Get ready                                      10s auto                   ~10s
       2 warmup   Cat-cow                                        60s auto                   ~60s
       3 exercise Front plank                                    20s auto                   ~20s
       4 rest     Rest                                           15s auto                   ~15s
       5 exercise Front plank                                    40s auto                   ~40s
       6 rest     Rest                                           15s auto                   ~15s
       7 exercise Front plank                                    60s manual                 ~60s
       8 rest     Rest                                           30s auto                   ~30s
       9 exercise Side plank                   Left  R1/2        30s auto                   ~30s
      10 switch   Switch sides                       R1/2        5s auto                    ~5s
      11 exercise Side plank                   Right R1/2        30s auto                   ~30s
      12 exercise Dead bug                           R1/2        10 reps manual             ~30s
      13 exercise Bird dog                     Left  R1/2        8 reps manual              ~24s
      14 switch   Switch sides                       R1/2        5s auto                    ~5s
      15 exercise Bird dog                     Right R1/2        8 reps manual              ~24s
      16 rest     Rest                               R1/2        30s auto                   ~30s
      17 exercise Side plank                   Left  R2/2        30s auto                   ~30s
      18 switch   Switch sides                       R2/2        5s auto                    ~5s
      19 exercise Side plank                   Right R2/2        30s auto                   ~30s
      20 exercise Dead bug                           R2/2        10 reps manual             ~30s
      21 exercise Bird dog                     Left  R2/2        8 reps manual              ~24s
      22 switch   Switch sides                       R2/2        5s auto                    ~5s
      23 exercise Bird dog                     Right R2/2        8 reps manual              ~24s
      24 rest     Rest                               R2/2        30s auto                   ~30s
      25 cooldown Child's pose                                   60s auto                   ~60s

# example knee-rehab.yaml is valid, round-trips and compiles

    Code
      cat(describe_steps(steps), sep = "\n")
    Output
       1 prep     Get ready                                      10s auto                   ~10s
       2 warmup   Heel slides                  Left              10 reps manual             ~30s
       3 switch   Switch sides                                   10s auto                   ~10s
       4 warmup   Heel slides                  Right             10 reps manual             ~30s
       5 exercise Quad sets                    Left  R1/2        10 reps hold 5s relax 3s auto ~77s
       6 switch   Switch sides                       R1/2        10s auto                   ~10s
       7 exercise Quad sets                    Right R1/2        10 reps hold 5s relax 3s auto ~77s
       8 exercise Straight-leg raise           Left  R1/2        10 reps hold 3s relax 3s auto ~57s
       9 switch   Switch sides                       R1/2        10s auto                   ~10s
      10 exercise Straight-leg raise           Right R1/2        10 reps hold 3s relax 3s auto ~57s
      11 exercise Clamshell                    Left  R1/2        12 reps manual             ~36s
      12 switch   Switch sides                       R1/2        10s auto                   ~10s
      13 exercise Clamshell                    Right R1/2        12 reps manual             ~36s
      14 exercise Wall sit                           R1/2        30s auto                   ~30s
      15 rest     Rest                               R1/2        60s auto                   ~60s
      16 exercise Quad sets                    Left  R2/2        10 reps hold 5s relax 3s auto ~77s
      17 switch   Switch sides                       R2/2        10s auto                   ~10s
      18 exercise Quad sets                    Right R2/2        10 reps hold 5s relax 3s auto ~77s
      19 exercise Straight-leg raise           Left  R2/2        10 reps hold 3s relax 3s auto ~57s
      20 switch   Switch sides                       R2/2        10s auto                   ~10s
      21 exercise Straight-leg raise           Right R2/2        10 reps hold 3s relax 3s auto ~57s
      22 exercise Clamshell                    Left  R2/2        12 reps manual             ~36s
      23 switch   Switch sides                       R2/2        10s auto                   ~10s
      24 exercise Clamshell                    Right R2/2        12 reps manual             ~36s
      25 exercise Wall sit                           R2/2        30s auto                   ~30s
      26 cooldown Hamstring stretch            Left              30s auto                   ~30s
      27 switch   Switch sides                                   10s auto                   ~10s
      28 cooldown Hamstring stretch            Right             30s auto                   ~30s

# example mobility-morning.yaml is valid, round-trips and compiles

    Code
      cat(describe_steps(steps), sep = "\n")
    Output
       1 prep     Get ready                                      5s auto                    ~5s
       2 exercise Neck rolls                                     45s auto                   ~45s
       3 exercise Shoulder rolls                                 45s auto                   ~45s
       4 exercise Thoracic rotation            Left              8 reps manual              ~24s
       5 switch   Switch sides                                   5s auto                    ~5s
       6 exercise Thoracic rotation            Right             8 reps manual              ~24s
       7 exercise Hip circles                  Left              10 reps manual             ~30s
       8 switch   Switch sides                                   5s auto                    ~5s
       9 exercise Hip circles                  Right             10 reps manual             ~30s
      10 exercise World's greatest stretch     Left              5 reps manual              ~15s
      11 switch   Switch sides                                   5s auto                    ~5s
      12 exercise World's greatest stretch     Right             5 reps manual              ~15s
      13 exercise Foam roller, upper back                        60s auto                   ~60s
      14 exercise Hamstring stretch            Left              45s auto                   ~45s
      15 switch   Switch sides                                   5s auto                    ~5s
      16 exercise Hamstring stretch            Right             45s auto                   ~45s
      17 exercise Ankle circles                Left              10 reps manual             ~30s
      18 switch   Switch sides                                   5s auto                    ~5s
      19 exercise Ankle circles                Right             10 reps manual             ~30s

# example pilates-mat-basics.yaml is valid, round-trips and compiles

    Code
      cat(describe_steps(steps), sep = "\n")
    Output
       1 prep     Get ready                                      10s auto                   ~10s
       2 warmup   Breathing, lying down                          60s auto                   ~60s
       3 warmup   Pelvic curl                                    8 reps manual              ~24s
       4 exercise The hundred                                    60s auto                   ~60s
       5 exercise Roll-up                                        6 reps manual              ~18s
       6 exercise Single-leg circles           Left              5 reps manual              ~15s
       7 switch   Switch sides                                   5s auto                    ~5s
       8 exercise Single-leg circles           Right             5 reps manual              ~15s
       9 exercise Rolling like a ball                            8 reps manual              ~24s
      10 exercise Single-leg stretch                             10 reps manual             ~30s
      11 exercise Spine stretch forward                          5 reps manual              ~15s
      12 exercise Side-lying leg lifts         Left              10 reps manual             ~30s
      13 switch   Switch sides                                   5s auto                    ~5s
      14 exercise Side-lying leg lifts         Right             10 reps manual             ~30s
      15 exercise Swimming                                       30s auto                   ~30s
      16 cooldown Child's pose                                   60s auto                   ~60s

# example yoga-gentle-flow.yaml is valid, round-trips and compiles

    Code
      cat(describe_steps(steps), sep = "\n")
    Output
       1 prep     Get ready                                      10s auto                   ~10s
       2 warmup   Easy seat, breathing                           60s auto                   ~60s
       3 exercise Mountain pose                      R1/3        20s auto                   ~20s
       4 exercise Forward fold                       R1/3        30s auto                   ~30s
       5 exercise Downward-facing dog                R1/3        30s auto                   ~30s
       6 exercise Cobra                              R1/3        20s auto                   ~20s
       7 exercise Mountain pose                      R2/3        20s auto                   ~20s
       8 exercise Forward fold                       R2/3        30s auto                   ~30s
       9 exercise Downward-facing dog                R2/3        30s auto                   ~30s
      10 exercise Cobra                              R2/3        20s auto                   ~20s
      11 exercise Mountain pose                      R3/3        20s auto                   ~20s
      12 exercise Forward fold                       R3/3        30s auto                   ~30s
      13 exercise Downward-facing dog                R3/3        30s auto                   ~30s
      14 exercise Cobra                              R3/3        20s auto                   ~20s
      15 exercise Warrior II                   Left              30s auto                   ~30s
      16 switch   Switch sides                                   5s auto                    ~5s
      17 exercise Warrior II                   Right             30s auto                   ~30s
      18 exercise Triangle                     Left              30s auto                   ~30s
      19 switch   Switch sides                                   5s auto                    ~5s
      20 exercise Triangle                     Right             30s auto                   ~30s
      21 exercise Tree pose                    Left              30s auto                   ~30s
      22 switch   Switch sides                                   5s auto                    ~5s
      23 exercise Tree pose                    Right             30s auto                   ~30s
      24 exercise Seated forward fold                            45s auto                   ~45s
      25 exercise Supine twist                 Left              30s auto                   ~30s
      26 switch   Switch sides                                   5s auto                    ~5s
      27 exercise Supine twist                 Right             30s auto                   ~30s
      28 cooldown Corpse pose                                    manual                     ~open

