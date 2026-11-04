# example bodyweight-hiit.yaml is valid, round-trips and compiles

    Code
      cat(describe_steps(steps), sep = "\n")
    Output
       1 prep     Get ready                                      10s auto                   ~10s
       2 warmup   March or jog in place                          120s auto                  ~120s
       3 exercise Squat Jumps                        R1/4        40s auto                   ~40s
       4 rest     Rest                               R1/4        20s auto                   ~20s
       5 exercise Mountain Climbers                  R1/4        40s auto                   ~40s
       6 rest     Rest                               R1/4        20s auto                   ~20s
       7 exercise Burpees                            R1/4        40s auto                   ~40s
       8 rest     Rest                               R1/4        20s auto                   ~20s
       9 exercise High knees                         R1/4        40s auto                   ~40s
      10 rest     Rest                               R1/4        60s auto                   ~60s
      11 exercise Squat Jumps                        R2/4        40s auto                   ~40s
      12 rest     Rest                               R2/4        20s auto                   ~20s
      13 exercise Mountain Climbers                  R2/4        40s auto                   ~40s
      14 rest     Rest                               R2/4        20s auto                   ~20s
      15 exercise Burpees                            R2/4        40s auto                   ~40s
      16 rest     Rest                               R2/4        20s auto                   ~20s
      17 exercise High knees                         R2/4        40s auto                   ~40s
      18 rest     Rest                               R2/4        60s auto                   ~60s
      19 exercise Squat Jumps                        R3/4        40s auto                   ~40s
      20 rest     Rest                               R3/4        20s auto                   ~20s
      21 exercise Mountain Climbers                  R3/4        40s auto                   ~40s
      22 rest     Rest                               R3/4        20s auto                   ~20s
      23 exercise Burpees                            R3/4        40s auto                   ~40s
      24 rest     Rest                               R3/4        20s auto                   ~20s
      25 exercise High knees                         R3/4        40s auto                   ~40s
      26 rest     Rest                               R3/4        60s auto                   ~60s
      27 exercise Squat Jumps                        R4/4        40s auto                   ~40s
      28 rest     Rest                               R4/4        20s auto                   ~20s
      29 exercise Mountain Climbers                  R4/4        40s auto                   ~40s
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
       2 warmup   Jumping Jacks                                  60s auto                   ~60s
       3 warmup   Arm Circles                                    30s auto                   ~30s
       4 exercise Push-ups                           R1/3        10 reps manual             ~30s
       5 exercise Bodyweight Squat                   R1/3        15 reps manual             ~45s
       6 exercise Reverse lunges               Left  R1/3        8 reps manual              ~24s
       7 switch   Switch sides                       R1/3        5s auto                    ~5s
       8 exercise Reverse lunges               Right R1/3        8 reps manual              ~24s
       9 exercise Glute Bridge                       R1/3        12 reps manual             ~36s
      10 exercise Plank                              R1/3        30s auto                   ~30s
      11 rest     Rest                               R1/3        60s auto                   ~60s
      12 exercise Push-ups                           R2/3        10 reps manual             ~30s
      13 exercise Bodyweight Squat                   R2/3        15 reps manual             ~45s
      14 exercise Reverse lunges               Left  R2/3        8 reps manual              ~24s
      15 switch   Switch sides                       R2/3        5s auto                    ~5s
      16 exercise Reverse lunges               Right R2/3        8 reps manual              ~24s
      17 exercise Glute Bridge                       R2/3        12 reps manual             ~36s
      18 exercise Plank                              R2/3        30s auto                   ~30s
      19 rest     Rest                               R2/3        60s auto                   ~60s
      20 exercise Push-ups                           R3/3        10 reps manual             ~30s
      21 exercise Bodyweight Squat                   R3/3        15 reps manual             ~45s
      22 exercise Reverse lunges               Left  R3/3        8 reps manual              ~24s
      23 switch   Switch sides                       R3/3        5s auto                    ~5s
      24 exercise Reverse lunges               Right R3/3        8 reps manual              ~24s
      25 exercise Glute Bridge                       R3/3        12 reps manual             ~36s
      26 exercise Plank                              R3/3        30s auto                   ~30s
      27 cooldown Stretch                                        manual                     ~open

# example core-plank-ladder.yaml is valid, round-trips and compiles

    Code
      cat(describe_steps(steps), sep = "\n")
    Output
       1 prep     Get ready                                      10s auto                   ~10s
       2 warmup   Cat-Cow                                        60s auto                   ~60s
       3 exercise Plank                                          20s auto                   ~20s
       4 rest     Rest                                           15s auto                   ~15s
       5 exercise Plank                                          40s auto                   ~40s
       6 rest     Rest                                           15s auto                   ~15s
       7 exercise Plank                                          60s manual                 ~60s
       8 rest     Rest                                           30s auto                   ~30s
       9 exercise Side Plank                   Left  R1/2        30s auto                   ~30s
      10 switch   Switch sides                       R1/2        5s auto                    ~5s
      11 exercise Side Plank                   Right R1/2        30s auto                   ~30s
      12 exercise Dead Bug                           R1/2        10 reps manual             ~30s
      13 exercise Bird Dog                     Left  R1/2        8 reps manual              ~24s
      14 switch   Switch sides                       R1/2        5s auto                    ~5s
      15 exercise Bird Dog                     Right R1/2        8 reps manual              ~24s
      16 rest     Rest                               R1/2        30s auto                   ~30s
      17 exercise Side Plank                   Left  R2/2        30s auto                   ~30s
      18 switch   Switch sides                       R2/2        5s auto                    ~5s
      19 exercise Side Plank                   Right R2/2        30s auto                   ~30s
      20 exercise Dead Bug                           R2/2        10 reps manual             ~30s
      21 exercise Bird Dog                     Left  R2/2        8 reps manual              ~24s
      22 switch   Switch sides                       R2/2        5s auto                    ~5s
      23 exercise Bird Dog                     Right R2/2        8 reps manual              ~24s
      24 rest     Rest                               R2/2        30s auto                   ~30s
      25 cooldown Child's Pose                                   60s auto                   ~60s

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
      14 exercise Wall-sit                           R1/2        30s auto                   ~30s
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
      25 exercise Wall-sit                           R2/2        30s auto                   ~30s
      26 cooldown Hamstring Stretch            Left              30s auto                   ~30s
      27 switch   Switch sides                                   10s auto                   ~10s
      28 cooldown Hamstring Stretch            Right             30s auto                   ~30s

# example mobility-morning.yaml is valid, round-trips and compiles

    Code
      cat(describe_steps(steps), sep = "\n")
    Output
       1 prep     Get ready                                      5s auto                    ~5s
       2 exercise Neck rolls                                     45s auto                   ~45s
       3 exercise Shoulder rolls                                 45s auto                   ~45s
       4 exercise Thoracic rotation, quadruped Left              8 reps manual              ~24s
       5 switch   Switch sides                                   5s auto                    ~5s
       6 exercise Thoracic rotation, quadruped Right             8 reps manual              ~24s
       7 exercise Hip Circles                  Left              10 reps manual             ~30s
       8 switch   Switch sides                                   5s auto                    ~5s
       9 exercise Hip Circles                  Right             10 reps manual             ~30s
      10 exercise World's Greatest Stretch     Left              5 reps manual              ~15s
      11 switch   Switch sides                                   5s auto                    ~5s
      12 exercise World's Greatest Stretch     Right             5 reps manual              ~15s
      13 exercise Foam roller, upper back                        60s auto                   ~60s
      14 exercise Hamstring Stretch            Left              45s auto                   ~45s
      15 switch   Switch sides                                   5s auto                    ~5s
      16 exercise Hamstring Stretch            Right             45s auto                   ~45s
      17 exercise Ankle Circles                Left              10 reps manual             ~30s
      18 switch   Switch sides                                   5s auto                    ~5s
      19 exercise Ankle Circles                Right             10 reps manual             ~30s

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
      12 exercise Side kick, up and down       Left              10 reps manual             ~30s
      13 switch   Switch sides                                   5s auto                    ~5s
      14 exercise Side kick, up and down       Right             10 reps manual             ~30s
      15 exercise Swimming                                       30s auto                   ~30s
      16 cooldown Child's Pose                                   60s auto                   ~60s

# example yoga-gentle-flow.yaml is valid, round-trips and compiles

    Code
      cat(describe_steps(steps), sep = "\n")
    Output
       1 prep     Get ready                                      10s auto                   ~10s
       2 warmup   Easy seat                                      60s auto                   ~60s
       3 exercise Mountain pose                      R1/3        20s auto                   ~20s
       4 exercise Standing Forward Bend              R1/3        30s auto                   ~30s
       5 exercise Downward-Facing Dog                R1/3        30s auto                   ~30s
       6 exercise Cobra pose                         R1/3        20s auto                   ~20s
       7 exercise Mountain pose                      R2/3        20s auto                   ~20s
       8 exercise Standing Forward Bend              R2/3        30s auto                   ~30s
       9 exercise Downward-Facing Dog                R2/3        30s auto                   ~30s
      10 exercise Cobra pose                         R2/3        20s auto                   ~20s
      11 exercise Mountain pose                      R3/3        20s auto                   ~20s
      12 exercise Standing Forward Bend              R3/3        30s auto                   ~30s
      13 exercise Downward-Facing Dog                R3/3        30s auto                   ~30s
      14 exercise Cobra pose                         R3/3        20s auto                   ~20s
      15 exercise Warrior Two                  Left              30s auto                   ~30s
      16 switch   Switch sides                                   5s auto                    ~5s
      17 exercise Warrior Two                  Right             30s auto                   ~30s
      18 exercise Triangle                     Left              30s auto                   ~30s
      19 switch   Switch sides                                   5s auto                    ~5s
      20 exercise Triangle                     Right             30s auto                   ~30s
      21 exercise Tree                         Left              30s auto                   ~30s
      22 switch   Switch sides                                   5s auto                    ~5s
      23 exercise Tree                         Right             30s auto                   ~30s
      24 exercise Seated Forward Bend                            45s auto                   ~45s
      25 exercise Supine twist                 Left              30s auto                   ~30s
      26 switch   Switch sides                                   5s auto                    ~5s
      27 exercise Supine twist                 Right             30s auto                   ~30s
      28 cooldown Corpse                                         manual                     ~open

