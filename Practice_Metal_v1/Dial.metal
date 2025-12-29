//
//  Dial.metal
//  Practice_Metal_v1
//
//  Created by Ivan Voznyi on 12/24/25.
//

#include <metal_stdlib>
using namespace metal;

[[stitchable]] half4 radialTicks(
    float2 position,
    half4 color,
    float handlerDegrees,
    float2 size,
    float isSmoothPointer
) {
    // --- 1. DESIGN & GEOMETRY SETTINGS ---
    const float TOTAL_TICKS = 120.0;           // Number of lines in the circle
    const float TICK_FILL_RATIO = 0.5;         // 0.5 = equal line and gap width
    const float FULL_CIRCLE_DEGREES = 360.0;
    const float HALF_CIRCLE_RATIO = 0.5;       // Used for centering calculations
    const float RADIUS_DIVISOR = 2.0;          // Used to find the center from size
    
    // --- 2. RADIUS & SIZING SETTINGS (PERCENTAGES) ---
    const float INNER_RADIUS_SCALE = 0.20;     // Hole in the middle
    const float OUTER_RADIUS_SCALE = 0.35;     // Normal height of ticks
    const float GROWTH_POINTER_SCALE = 0.10;   // How much the pointer grows
    
    // --- 3. ANIMATION & BEHAVIOR SETTINGS ---
    const float SMOOTH_SHARPNESS = 15.0;       // Higher = thinner flashlight beam
    const float PYRAMID_SPREAD = 5.0;          // Number of ticks affected by pointer
    const float SMOOTH_THRESHOLD = 0.5;        // Toggle switch limit
    
    // --- 4. COLOR SETTINGS ---
    const half  COLOR_VALUE_RGB = 0.5;         // 0.5 is medium grey
    const half  COLOR_OPACITY = 1.0;           // 1.0 is fully visible
    const half4 TICK_COLOR = half4(COLOR_VALUE_RGB, COLOR_VALUE_RGB, COLOR_VALUE_RGB, COLOR_OPACITY);
    const half4 TRANSPARENT = half4(0.0, 0.0, 0.0, 0.0);

    // --- 5. POSITIONING MATH ---
    // The algorithm calculates the center, measures the direction from the center to a pixel, and determines the distance.
    float2 center = size / RADIUS_DIVISOR;
    float2 pixelDirection = position - center;
    float pixelDistance = length(pixelDirection);
    
    // Angle math
    float angleRadians = atan2(pixelDirection.x, pixelDirection.y);
    /*
     atan2 is used to convert 2D coordinates into a single angular value.
     Here is a breakdown of why you need it and how it will be used later.

     Why do you need angleRadians?
     While your pixelDirection (x, y) tells you where the pixel is, it’s hard to use those two numbers if you want to know "rotation."

     The atan2 function calculates the polar angle of a point.
     By calculating this, you are converting Cartesian coordinates (x, y) into Polar coordinates (angle). This is necessary because:

        - It simplifies rotation: It’s much easier to say "rotate 45 degrees" than to calculate new x and y offsets manually.
        - Directional Logic: If you want to know if a pixel is "to the left," "above," or "behind" the center, the angle gives you a single number to check.
     */
    float normalizedAngle = (angleRadians + M_PI_F) / (RADIUS_DIVISOR * M_PI_F);
    /*
     This line of code is performing normalization.
     It takes the raw angle (which is hard for computers to use for colors or textures) and "squashes" it into a simple range, likely between 0.0 and 1.0.

     Here is the breakdown of why this math is happening:
     
     1. (angleRadians + M_PI_F)
     
     The atan2 function returns values from -π to +π.
        
        - The Problem: Working with negative numbers is difficult when you want to map things to colors or percentages.
        - The Fix: By adding π (M_PI_F), you shift the range from (-π, π) to (0, 2π). Now, all your values are positive.
     
     2. ... / (RADIUS_DIVISOR * M_PI_F)
     
     This part scales the value down.
     
        - If RADIUS_DIVISOR is 2.0, you are dividing by 2π. Since your shifted angle is now between 0 and 2π, dividing by 2π results in a value between 0.0 and 1.0.
        - This is a "percentage" of a full circle.
     
     If RADIUS_DIVISOR is anything other than 2.0, you are changing the "scale" or the "coverage" of your result.
     Effectively, you are telling the code that a "full unit" (1.0) is either more or less than a complete circle.
     
     Here is what happens in different scenarios:
     
     1. If RADIUS_DIVISOR is greater than 2.0 (e.g., 4.0)
     
     The range of your normalizedAngle will be smaller than 0.0 to 1.0.
     
        - The Math: A full circle is 2π. If you divide by 4π, your maximum value is 0.5.
        - The Result: If you are using this for colors, the rainbow will only go halfway around. The other half of the circle might look "unfinished" or stay stuck on one color.
     
     2. If RADIUS_DIVISOR is smaller than 2.0 (e.g., 1.0)
     
     The range will "overflow" 1.0.
     
        - The Math: If you divide by 1π, a full circle (2π) results in a value of 2.0.
        - The Result: If you are mapping this to a texture or color, the pattern will repeat or tile. In this case, you would see the full rainbow twice in a single circle.
     
     Comparison Table
     
     Assuming a full 360° circle:
     
     RADIUS_DIVISOR,    Divisor Value,  Range of normalizedAngle,   Visual Effect
        2.0,                 2π,             0.0 → 1.0,             Perfect fit (one full cycle).
        4.0,                 4π,             0.0 → 0.5,             Half-cycle (stretched/slow).
        1.0,                 1π,             0.0 → 2.0,             Double-cycle (tiled/fast).
        0.5,                 0.5π,           0.0 → 4.0,             Quadruple-cycle (very dense).
     */
    // Fit to screen
    float minCanvasSize = min(size.x, size.y);
    
    // --- 6. RADIUS CALCULATIONS ---
    float innerRadius = minCanvasSize * INNER_RADIUS_SCALE;
    float outerBaseRadius = minCanvasSize * OUTER_RADIUS_SCALE;
    float maxGrowthAmount = minCanvasSize * GROWTH_POINTER_SCALE;
    
    float finalOuterRadius = outerBaseRadius;

    // --- 7. POINTER LOGIC ---
    if (isSmoothPointer > SMOOTH_THRESHOLD) {
        // Smooth Mode (Flashlight)
        float targetRad = (handlerDegrees * M_PI_F / (FULL_CIRCLE_DEGREES * HALF_CIRCLE_RATIO)) - M_PI_F;
        /*
         This line of code "targetRad" is the inverse of your normalizedAngle.
         While the previous normalizedAngle turned an angle into a 0-to-1 value,
         this line turns a value (like a dial or a slider position) back into Radians so the computer can use it for rotation.

         Here is the breakdown of the formula:
         
         1. (handlerDegrees * M_PI_F / (FULL_CIRCLE_DEGREES * HALF_CIRCLE_RATIO))
         
         This part is calculating the total "positive" arc.
         
            - If FULL_CIRCLE_DEGREES is 180 and HALF_CIRCLE_RATIO is 0.5 (or similar combinations), it defines the scale of your input.
            - It converts your input "Degrees" into a Radian value, but at this stage, the result is likely between 0 and 2π.
         
         2. The - M_PI_F (The "Shift")
         
         This is the most important part for the computer's "brain."
         
            - As we discussed earlier, atan2 and most rotation functions like to work in a range from -π to +π.
            - By subtracting π at the end, you are shifting the value back. Instead of starting at 0, your "starting point" moves to the left side of the circle -π.
         
         Why do you need this?
         You use this when you want to control something.
            - The "Input" (handlerDegrees): This is likely a value from a UI slider, a mouse position, or a setting (e.g., "Set angle to 90").
            - The "Output" (targetRad): This is the raw math value you feed into a shader or a transformation matrix to actually move pixels.
         
         HALF_CIRCLE_RATIO
         
         In geometry and programming, a "ratio" is a multiplier that changes the scale of your values.
         When HALF_CIRCLE_RATIO is set to 0.5, it acts as a "divider" that usually balances the relationship between degrees and radians in your specific formula.
         
         Why is it 0.5?
         In your formula, you are likely trying to map a range of degrees to a range of radians.
         
            - A full circle is  360°
            - A full circle is also 2π radians.
            - The Math: 360 x 0.5 = 180.
         
         By using 0.5, the code is likely normalizing the input so that 180° (half a circle) corresponds to π radians.
         It acts as a bridge to ensure that when you input a degree value, the resulting radian value doesn't "spin" too far or too little.
         
         What happens if the value changes?
         Changing this ratio changes the sensitivity of your rotation.
         It determines how many "degrees" of input it takes to complete a physical circle on the screen.
         
         1. If it is LOWER than 0.5 (e.g., 0.25)
            
            - The Effect: The "Denominator" (the bottom number in your division) becomes smaller.
            - The Result: The rotation becomes Hyper-Sensitive.
            - Visual: A small change in handlerDegrees will cause the object to spin very fast.
              You might complete a full 360° visual rotation while the input variable has only reached 90.
         
         2. If it is HIGHER than 0.5 (e.g., 1.0)
         
            - The Effect: The "Denominator" becomes larger.
            - The Result: The rotation becomes Sluggish/Slow.
            - Visual: You will have to increase handlerDegrees significantly just to get the object to move a little bit.
              If you set it to 1.0, you might only see a half-turn on the screen even when your input says "360 degrees."
         
         HALF_CIRCLE_RATIO,  |  Sensitivity,    |   Visual Result
         --------------------------------------------------------------------------------------------
            0.1,                Extreme,            "One ""click"" spins the object multiple times."
            0.5                 (Standard),         Balanced,1∘ of input ≈ 1∘ of visual rotation.
            1.0,                Low,                The object moves half as much as it should.
            2.0,                Very Low,           "The object barely moves; feels ""heavy."""
        */
        float alignment = cos(angleRadians - targetRad);
        /*
         This line of code is measuring how closely two directions match.
         In programming and shaders, this is often called a Dot Product calculation for vectors, but expressed here using the difference between two angles.
         
         What does this line do?
         The cos (cosine) function compares the angleRadians (the actual pixel's position) with the targetRad (where you want the effect to be centered).
         
         The result of alignment will always stay between -1.0 and 1.0:
         
            - 1.0 (Perfect Match): The pixel is exactly at the target angle (0° difference).
            - 0.0 (Perpendicular): The pixel is 90° away from the target.
            - -1.0 (Opposite): The pixel is exactly on the opposite side of the circle 180° difference).
        */
        float bellCurve = pow(max(0.0, alignment), SMOOTH_SHARPNESS);
        /*
         
         1. INPUT (Degrees)   -90   -70   -50   -30   -10   0    +10   +30   +50   +70   +90
                               |     |     |     |     |    V     |     |     |     |     |
                               |     |     |     |     |    |     |     |     |     |     |
         2. MATH (cos)      cos(-90).....................cos(0).....................cos(90)
                               |     |     |     |     |    |     |     |     |     |     |
                               V     V     V     V     V    V     V     V     V     V     V
         3. ALIGNMENT         0.0   0.34  0.64  0.86  0.98  1.0   0.98  0.86  0.64  0.34  0.0

    
         (Degrees)   -90   -70   -50   -30   -10    0    +10   +30   +50   +70   +90
                       |     |     |     |     |    V    |     |     |     |     |
                       |     |     |     |     |    |    |     |     |     |     |
          <---------------------- [ angleRadians - targetRad ] ---------------------->
                                                    |
         -------------------------------------------|-------------------------------------------
          bellCurve |                               |
           (Height) |                               |
            1.0     |                               █  <-- alignment is 1.0 (cos 0°)
                    |                               |
            0.8     |                           ████|████
                    |                           |   |   |
            0.6     |                       ████|███|███|████  <-- alignment ≈ 0.96
                    |                       |   |   |   |   |
            0.4     |                   ████|███|███|███|███|████
                    |                   |   |   |   |   |   |   |
            0.2     |           ████████|███|███|███|███|███|███|████████  <-- alignment ≈ 0.9
                    |           |   |   |   |   |   |   |   |   |   |   |
            0.0     | ██████████|███|███|███|███|███|███|███|███|███|███|██████████
         -------------------------------------------|-------------------------------------------
                                                    ^
            [ alignment ] :  0.0   0.34  0.64  0.86  0.98  1.0  0.98  0.86  0.64  0.34  0.0
                                (This is the raw Cosine value before the Power)

=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
                             SMOOTH_SHARPNESS = 15.0
                             targetRad = 45°
                [ Step 1 ]:  ALIGNMENT = cos( angleRadians - targetRad )
                [ Step 2 ]:  bellCurve = pow( ALIGNMENT, 15.0 )

          (Degrees)   -45°           -5°            35°  45°  55°            95°          135°
                       |              |              |    V    |              |             |
           ------------|--------------|--------------|----|----|--------------|-------------|-----------
                                                          |                                         [ bellCurve ]   [ ALIGNMENT ]  [ Actual Degrees ] [ Calculate bellCurve ]
                                                          |
              Peak     |                                [1.0]                                       -->  1.0  🎯     ( 1.0 )         ( 45° )           [ 1.00^15.0 ] = 1.0
                       |                                  |
              Shoulder |                        █ [0.74]  █  [0.74] █                               -->  0.74        ( 0.98 )        ( 35°, 55° )      [ 0.98^15.0 ] = 0.74
                       |                                  |
              Slope    |               █ [0.10] █ [0.10]  █  [0.10] █ [0.10] █                      -->  0.10        ( 0.86 )        ( 15°, 75° )      [ 0.86^15.0 ] = 0.10
                       |               |        |         |         |        |
              Mid      |      █ [0.00] █ [0.00] █ [0.00]  █  [0.00] █ [0.00] █ [0.00] █             -->  0.00        ( 0.64 )        ( -5°, 95° )      [ 0.64^15.0 ] = 0.00
                       |      |        |        |         |         |        |        |
              Base     | [0.0][0.0]    [0.0]    [0.0]     [0.0]     [0.0]    [0.0]    [0.0][0.0]    -->  0.0         ( 0.0 )         ( -45°, 135° )    [ 0.00^15.0 ] = 0.0
           ------------|--------------|--------------|----|----|--------------|-------------|-----------
            Direction:  <-- Left      |                Center                 |       Right -->
            Distance:   90°            50°          10°   0°   10°            50°           90°
         */
        
        finalOuterRadius += (maxGrowthAmount * bellCurve);
    } else {
        // Pyramid Mode (Stepped)
        float targetTickIndex = (handlerDegrees / FULL_CIRCLE_DEGREES) * TOTAL_TICKS;
        /*
         This line of code is a classic example of linear mapping.
         It takes a value from one scale (degrees) and converts it to a corresponding value on another scale (ticks on a dial or slider).
         
         Linear scale (full 0–360° mapped to 0–120 ticks)
         Use this when thinking in sequences. It’s easier to see flooring behavior here.
         
         Angle (°):   0     3     6     9     12     15     18     21     24     ...   354     357     360
         Tick index:  0.0   1.0   2.0   3.0   4.0    5.0    6.0    7.0    8.0    ...   118.0   119.0   120.0
         
         The Logic Breakdown
         To understand this, think of it as finding a percentage and then applying that percentage to a new total.
         
            -   (handlerDegrees / FULL_CIRCLE_DEGREES): This calculates the "progress" or the fraction of the circle that has been covered.
                If the handler is at 180° and the full circle is 360°, this results in 0.5 (or 50%).
            -   * TOTAL_TICKS: This takes that fraction and multiplies it by the total number of segments (ticks) available.
                If the circle has 100 ticks, 50% of 100 gives you a target index of 50.
         */
        float currentTickIndex = floor(normalizedAngle * TOTAL_TICKS);
        /*
         This line of code is the bridge: it converts a smooth angle into a tick index that you can use in logic, rendering, or interaction.
         
         Linear scale (full 0–360° mapped to 0–120 ticks)
         Use this when thinking in sequences. It’s easier to see flooring behavior here.
         
         Angle (°):   0    3    6    9   12   15   18   21   24    ...   354  357  360
         Tick index:  0    1    2    3    4    5    6    7    8    ...   118  119  120

         */
        
        /*
         Why do we need targetTickIndex and currentTickIndex?
         
            - targetTickIndex → tells you the precise fractional position.
                - Good for smooth visuals, gradual animations, or calculating how far into the next tick you are.
        
            - currentTickIndex → tells you the discrete tick you’re currently on.
                - Good for snapping, logic decisions, or highlighting the last completed tick.
         
         targetTickIndex = where you ideally are (fractional, smooth).
         currentTickIndex = which tick you’ve actually reached (integer, snapped).
         
         Angle: 263°
         Ticks:  ... 87 ----|---- 88 ...
                            ^
                            |
         targetTickIndex = 87.67   (fractional, between ticks)
         currentTickIndex = 87     (floored, last passed tick)
         
         Angle (°):         0    3    6    9   12   15   18   21   24       ...   354   357   360
         targetTickIndex:   0.0  1.0  2.0  3.0  4.0  5.0  6.0  7.0  8.0     ...  118.0 119.0 120.0
         currentTickIndex:  0    1    2    3    4    5    6    7    8       ...   118   119   120
         
         👉 In short:

            - targetTickIndex = where you ideally are (fractional, smooth).
            - currentTickIndex = which tick you’ve actually reached (integer, snapped).

         They’re both needed because one gives precision for smoothness, and the other gives stability for logic.
         */
        
        float distanceToPointer = abs(currentTickIndex - targetTickIndex);
        /*
         distanceToPointer tells you how close the pointer is to the next tick boundary.
         It’s useful if you want to decide whether to snap forward, animate smoothly, or highlight proximity.
         
         Ticks: ...  3 ----|---- 4 ----|---- 5  ...
                           |           |
                           *           x
                           |           |
         currentTickIndex = 4     targetTickIndex = 4.1

         distanceToPointer = |4 - 4.1| = 0.1
         
         * = snapped tick (integer)
         x = smooth fractional tick (exact angle position)
         
         
         Think of abs (Absolute Value) as a "Distance Only" filter.
         It strips away the direction (left or right) and just tells the computer how many steps are between two points.

         Here is why it is essential for your circle:
         
         1. The "Left vs. Right" Problem
         
         Computers are very literal. Without abs, the math looks like this if you are pointing at Step 10:
            - To the Right: Step 12 minus Step 10 = +2 (The computer thinks: "Cool, a distance of 2").
            - To the Left:  Step 8 minus Step 10 = -2 (The computer thinks: "Wait, what is a distance of negative 2?").
         
         If you try to build a pyramid with negative distance, the math breaks.
         The left side of your pointer would try to grow "underground" or disappear!
         
         2. Making the Pyramid Symmetrical
         
         The abs function makes sure that Step 8 and Step 12 are treated exactly the same.
         They are both just "2 steps away."
         
         Here is what happens WITHOUT abs: The pyramid would only have one side (the right side), because the left side results in negative numbers that the computer ignores.
         
         Target (10)
             |
             █  _          <-- One-sided "Half-Pyramid"
             █  █  _            (The left side is missing!)
             █  █  █  _
         ____█__█__█__█____
             10 11 12 13
         
         WITH abs, it looks like this: The computer sees that -1, -2, and -3 are actually just 1, 2, and 3.
         
             Target (10)
                     |
                  _  █  _    <-- Perfect Symmetrical Pyramid
               _  █  █  █  _      (The left and right sides match!)
            _  █  █  █  █  █  _
         ___█__█__█__█__█__█__█___
            7  8  9  10 11 12 13
         
         3. Simple Logic for Growth
         
         By using abs, you can use one single rule for every tick mark in the circle:
         
            - "The smaller the distanceToPointer, the taller the line."
         
         Because abs ensures the distance is always a positive number (0, 1, 2, 3...),
         this rule works perfectly for all 120 lines, whether they are "ahead" of your finger or "behind" it.
         */
        
        // Wrap-around math
        if (distanceToPointer > (TOTAL_TICKS * HALF_CIRCLE_RATIO)) {
            distanceToPointer = TOTAL_TICKS - distanceToPointer;
        }
        /*
         We need that "Shortcut Math" because, in a circle, the end and the beginning are actually the same place.

         If you don't have that code, the computer gets "confused" at the top of the circle (the 12 o'clock position).
         
         Here are the three main reasons why it’s a "must-have":
         
         1. To Fix the "Crashed Pyramid"
         
         Imagine your finger is at Step 119 (the very end). You want the pyramid to spread to its neighbors. Its neighbors are Step 118 and Step 0.
         
            - Without the code: The distance to Step 0 is calculated as 119 - 0 = 119.
              The computer thinks Step 0 is on the other side of the world! The pyramid "breaks" and only shows one side.
            - With the code: The computer realizes 120 - 119 = 1. It sees that Step 0 is only 1 step away. The pyramid stays whole.
         
         -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
         
         Imagine your finger is at the TOP (Step 0). The if logic only starts working when the computer is looking at the bottom half of the circle.
         
                    [ FINGER @ 0 ]
                          |
                 ____________________
                /         |          \
               /  NORMAL  |  NORMAL   \  <-- Distance is 10, 20, 30...
              |   ZONE    |   ZONE     |     (Logic is SLEEPING 😴)
              |           |            |
              |-----------|------------| <-- THE 60-STEP LINE
              |           |            |
              |  IF LOGIC |  IF LOGIC  |     (Logic is AWAKE ⚡)
               \  PLAYS   |   PLAYS   /  <-- Distance is 70? No, it's 50!
                \_________|__________/       Distance is 100? No, it's 20!
                          |
                     [ STEP 60 ]
         
         The logic doesn't stay in the bottom right — it rotates with your finger.
         The logic always starts exactly halfway across the circle from wherever you are pointing.
         
         The "Shadow" Rule
         Imagine you are carrying a flashlight (your finger/pointer) around a circular room.
         The if logic is like a shadow that always stays on the opposite side of the room.
         
            - If you are at the Top (12 o'clock), the logic starts at the Bottom (6 o'clock).
            - If you are at the Right (3 o'clock), the logic starts at the Left (9 o'clock).

         -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

         Visualizing the "Logic Zone" as it Rotates
         
         Look at how the "Shortcut Zone" (where the logic plays) moves as you move your finger (🎯).
         
         1. Finger at the Top (0°) Logic triggers at the bottom.
         
                    [ 🎯 ]
              Normal  |  Normal
             ---------+---------
              LOGIC   |   LOGIC
                    [   ]
         
         2. Finger at the Right (90°) The "Mirror" turns sideways! Logic triggers on the left.
         
                    [   ]
               LOGIC  |  Normal
             ---------+--------- [🎯]
               LOGIC  |  Normal
                    [   ]
         
         3. Finger at the Bottom (180°) The whole world flips! Now the logic triggers at the top.
         
                    [   ]
              LOGIC   |   LOGIC
             ---------+---------
              Normal  |  Normal
                    [ 🎯 ]

         -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

         The "Jump" in the Numbers
         
         If we didn't have the if logic, the distance would just keep counting up like a regular clock.
         With the logic, the numbers "bounce" back down once they hit 60.

         Looking at the Distance from Step 0:
         
         Step:      0...10...30...50...60...70...90...110...119
         ------------------------------------------------------
         No Logic:  0...10...30...50...60...70...90...110...119  (Goes up to 119)
         With IF:   0...10...30...50...60...50...30...10....1    (Bounces at 60!)
                                        ^
                                 Logic starts here!
         */

        float pyramidHeightFactor = max(0.0, PYRAMID_SPREAD - distanceToPointer) / PYRAMID_SPREAD;
        /*
         1. The "Percent of Max" Rule
         
         Imagine your PYRAMID_SPREAD is 5. This means your pyramid is 5 steps wide.
         
         If you don't divide, your height numbers would be huge (5, 4, 3, 2, 1).
         If you try to use those for a color's brightness, the computer would get confused because it only understands brightness up to 1.0.
         
         By dividing, we "squash" the height into a percentage:
         
         Distance,          Subtraction (5 - dist)  The Division (/ 5), "Final ""Height"""
         0 (Center),        5−0=5,                  5/5,                1.0 (100% Height)
         1 (Next door),     5−1=4,                  4/5,                0.8 (80% Height)
         2,                 5−2=3,                  3/5,                0.6 (60% Height)
         5 (Edge),          5−5=0,                  0/5,                0.0 (0% Height)
         
         The "Squeeze"
         
         Imagine your raw math creates a giant mountain.
         Dividing by the spread is like putting a heavy board on top to flatten it down to a size the screen can actually show.
         
         RAW NUMBERS (Before /):      NORMALIZED (After /):
               [5]                          [1.0]
               [4]                          [0.8]
               [3]                          [0.6]
               [2]                          [0.4]
               [1]                          [0.2]
               [0]                          [0.0]
                |                             |
           TOO TALL FOR                    PERFECT
            THE SCREEN!                   FOR COLOR
         
         If your PYRAMID_SPREAD is 5, and you are pointing at Step 10, the heights look like this:
    
         Step Index:  5   6   7   8   9   10  11  12  13  14  15
                       
         Height:      0  0.2 0.4 0.6 0.8 1.0 0.8 0.6 0.4 0.2  0
                      _   _   _   _   _   █   _   _   _   _   _
                      |   |   |   |   █   █   █   |   |   |   |
                      |   |   |   █   █   █   █   █   |   |   |
                      |   |   █   █   █   █   █   █   █   |   |
                      |   █   █   █   █   █   █   █   █   █   |
                   ___█___█___█___█___█___█___█___█___█___█___█___
         
         */
        finalOuterRadius += (maxGrowthAmount * pyramidHeightFactor);
    }

    // --- 8. PIXEL RENDERING ---
    float patternPosition = fract(normalizedAngle * TOTAL_TICKS);
    bool isPixelInTick = patternPosition < TICK_FILL_RATIO;
    bool isPixelInRing = (pixelDistance > innerRadius) && (pixelDistance < finalOuterRadius);

    if (isPixelInRing && isPixelInTick) {
        return TICK_COLOR;
    } else {
        return TRANSPARENT;
    }
}
