///////////////////////////////////////////////////////////////////////////////
// sh4.asl
///////////////////////////////////////////////////////////////////////////////

// This script is used by LiveSplit for the game "Silent Hill 4: The Room" to
// automatically split upon leaving each room in an NTSC-U Any% PC speedrun.


///////////////////////////////////////////////////////////////////////////////
// DEVELOPER'S NOTES
///////////////////////////////////////////////////////////////////////////////

// GENERAL INFORMATION
// -------------------
// This script was developed and tested using an NTSC-U copy of SH4 for PC.
//
// We can determine which room is loaded by checking a static address in memory
// that holds an identifier of the current world, and an identifier of the
// current room.
//
// The route used in this script is based on the current Any% PC WR by
// 'funkyorange' (https://www.youtube.com/watch?v=jLmksgLZxC0). This file
// should come with another file that contains the splits for this route.
//
// HOW TO APPROACH SPLITTING?
// --------------------------
// We should avoid splitting whenever the current room changes, because runners
// may have to return to a previous room because they forgot something. In
// addition, the world/room identifiers are sometimes set to 0 when unloading
// and loading a new room, which makes this behavior very unpredictable.
//
// Instead, a gated approach is used where we divide the route up into
// sections, typically one section per room, and split whenever the goal of
// that section is met, typically, reaching the next room of the optimal route.
//
// If one has to deviate from the optimal route, the next few splits may be
// messed up in some very specific situations (e.g. when the next room of the
// optimal route is also the room that you have to return to), but due to
// gating the splits, this will be corrected eventually, so the runner never
// has to worry about undoing splits. However, this also means that the
// runner's route has to be hardcoded into this script.
//
// If your route does not follow these splits, you will have to change the
// 'split' method of this script yourself. Comments and descriptive constants
// have been used to ensure that it is easy to change this script.
//
// INGAME TIMER
// ------------
// SH4 speedruns are timed using the in-game timer, not an RTA timer. It is
// important that all timing methods in the layout settings are set to
// 'Game Time', because otherwise, the splits and timer will display RTA times:
//  - 'Subsplits > Section Header > Timing Method'
//  - 'Subsplits > Columns > Column: +/- > Timing Method'
//  - 'Subsplits > Columns > Column: Time > Timing Method'
//  - '(Detailed) Timer > Timing Method'
//
// PROBLEM: SPLITTING WHEN FINDING THE KEY, AND FINDING EILEEN
// -----------------------------------------------------------
// During the hospital section, this script splits AFTER leaving the room with
// the hospital key and after leaving the room with Eileen. This prevents that
// runners know that they've found these rooms while these rooms are still
// loading in.
//
// PROBLEM: CUTSCENES THAT PLAY IN SEPARATE ROOMS
// ----------------------------------------------
// There are several situations where we technically enter a new room, but
// where we do not actually enter a new room from the player's point of view:
//  - when travelling through the hole, a "cutscene" plays in a separate room
//    for every hole, one unique room per world
//  - end of first visits to worlds, cutscene plays in cutscene's room
//  - cutscene at the start of Hospital World happens in the emergency room
//  - at the start of the 2nd visit to water prison world, a part of the
//    cutscene plays in the rooftop
//
// These cutscenes can be skipped, and the in-game timer runs while they play,
// thus it is in the interest of the runner to skip these as fast as possible.
// I have decided to add separate splits for the cutscenes at the end of every
// first visit to a world, and the cutscene at the beginning of Hospital World.
//
// I have decided not to add splits for travelling through the hole, because
// these are much more common, and would mostly cause clutter. I also decided
// against adding a separate room split for the cutscene at the beginning of
// the second visit to Water Prison World, because it "passes through" the
// rooftop's room.
//
// PROBLEM: LOADING NEW WORLDS
// ---------------------------
// Before explaining this problem, it is important to know that when Henry
// travels through The Hole, this is done in a separate world, and a separate
// room, depending on which world Henry is currently visiting.
// 
// Whenever the current world changes, even when going through The Hole, the
// variables that contain information about the current room update in steps:
//  * first update:  world identifier is updated to proper value
//  * second update: room identifier is set to zero
//  * third update:  room identifier is set to proper value
//
// This can result in false early splits. For example, when first visiting the
// Forest World, we should split when reaching the next room, whose worldId is
// 3, and whose roomId is 2. However, when we enter the hole in the bathroom,
// the values of the world and room identifiers update in the following way:
//
//                                    WORLD ID      ROOM ID
//  * bathroom                           1             3
//  *                                    10            3
//  *                                    10            0
//  * hole                               10            2
//  *                                    3             2  <-- EARLY SPLIT!
//  *                                    3             0
//  * forest, cliff                      3             1
//  * forest, path to factory            3             2  <-- EXPECTED SPLIT!
//
// Because the updates do not happen simultaneously, this can result in
// unexpected early splits, whenever the world has changed, including when 
// going through the hole. This is not a problem when moving between two rooms
// that belong to the same world. These updates happen instantly.
// 
// As a general recommendation, we should specify the following:
// * ROOM BEFORE LEAVING WORLD:
//   - check that world identifier does not match anymore when leaving world
// * ROOM AFTER ENTERING WORLD:
//   - check world and room identifier of previous room
//   - check world and room identifier of next room
// * ROOM IN SAME WORLD
//   - check world and room identifier of next room
//
// PROBLEM: AUTOMATICALLY RESETTING RUNS
// -------------------------------------
// When you exit to the main menu, the old game's state is still loaded in
// memory. At the same time, we can easily determine when a new run starts, and
// thus instead of resetting upon exiting the game, we reset automatically upon
// starting a new run.
//


///////////////////////////////////////////////////////////////////////////////
// GAME STATE
///////////////////////////////////////////////////////////////////////////////

state("silent hill 4")
{
    // This state variable is used to access the value of the in-game timer.
    //  - a static 32-bit integer
    //  - value = 30 * seconds
    //  - value is set to zero before starting/loading a game for the first
    //    time, but retains its value when returning to the main menu
    //  - value is set to zero when starting a new game
    //  - value increases during most cutscenes and/or gameplay
    //  - value does not increase while paused, reading, etc.
    int inGameTimer: "Silent Hill 4.exe", 0x00BD5C50;

    // This state variable is used to access identifier of current world.
    //  - a static 32-bit integer
    //  - value depends on world loaded
    //  - value is set to zero before starting/loading a game for the first
    //    time, but retains its value when returning to the main menu
    int currentWorldId: "Silent Hill 4.exe", 0x00BD5B10;

    // This state variable is used to access identifier of current room.
    //  - a static 32-bit integer
    //  - value depends on room loaded
    //  - value is set to zero before starting/loading a game for the first
    //    time, but retains its value when returning to the main menu
    int currentRoomId: "Silent Hill 4.exe", 0x00BD5B14;

    // This state variable is used to access identifier of previous room.
    //  - a static 32-bit integer
    //  - value depends on previous room loaded
    //  - currently not used
    int previousRoomId: "Silent Hill 4.exe", 0x00BD5B18;

    // This state variable is used to access identifier of room that Henry
    // travels back to when entering the hole in The Room.
    //  - a static 32-bit integer
    //  - value depends on room where hole was entered
    //  - currently not used
    int returnRoomId: "Silent Hill 4.exe", 0x00C905E8;
}


///////////////////////////////////////////////////////////////////////////////
// TIMER
///////////////////////////////////////////////////////////////////////////////

// Return true whenever timer is paused.
isLoading
{
    return old.inGameTimer == current.inGameTimer;
}


// Return a TimeSpan object that contains the current time of the game.
gameTime
{
    float inGameTime = ((float) current.inGameTimer) / 30f;
    return TimeSpan.FromSeconds(inGameTime);
}


///////////////////////////////////////////////////////////////////////////////
// RUN MANAGEMENT
///////////////////////////////////////////////////////////////////////////////

// This action is triggered when the script first loads.
startup
{
   vars.currentSegment = 0;
}


// This action is triggered whenever a game process has been found.
init
{
    // do nothing
}


// Is used for generic updating.
update
{
    // reset variables when starting a new run
    if (current.inGameTimer == 0) {
        vars.currentSegment = 0;
    }
}


// Return true whenever you want the timer to start. Note that the start
// action will only be run if the timer is currently not running.
start
{
    return current.inGameTimer > 0;
}


// Return true whenever you want to reset the run.
reset
{
    return current.inGameTimer == 0;
}


//////////////////////////////////////////////////////////////////////////////
// SPLITS
//////////////////////////////////////////////////////////////////////////////

// Return true whenever you want to split.
split
{
    //////////////////////////////////////////////////////////////////////////
    // DEBUG INFORMATION
    //////////////////////////////////////////////////////////////////////////

    // output is viewable through DebugView
    if (old.currentWorldId != current.currentWorldId || 
        old.currentRoomId != current.currentRoomId) {
      print(
        "current section: " + vars.currentSegment + ", " +
        "current world ID: " + current.currentWorldId + ", " +
        "current room ID: " + current.currentRoomId);
    }

    //////////////////////////////////////////////////////////////////////////
    // WORLD IDENTIFIERS
    //////////////////////////////////////////////////////////////////////////

    const int WORLD_ROOM_302 = 1;
    const int WORLD_SUBWAY = 2;
    const int WORLD_FOREST = 3;
    const int WORLD_WATER_PRISON = 4;
    const int WORLD_BUILDING = 5;
    const int WORLD_APARTMENT = 6;
    const int WORLD_HOSPITAL = 7;
    const int WORLD_OUTSIDE_ROOM_302 = 8;
    const int WORLD_THE_END = 9;
    const int WORLD_THE_HOLE = 10;
    const int WORLD_SPIRAL_STAIRCASE = 11;

    ///////////////////////////////////////////////////////////////////////////
    // ROOM IDENTIFIERS
    ///////////////////////////////////////////////////////////////////////////

    const int ROOM_302__LIVING_ROOM = 1;
    const int ROOM_302__BEDROOM = 2;
    const int ROOM_302__BATHROOM = 3;
    const int ROOM_302__STORAGE_ROOM = 4;
    const int ROOM_302__HIDDEN_BACK_ROOM = 5;

    const int SUBWAY__ENTRANCE_NORTH = 1;               // 1st visit start
    const int SUBWAY__HALLWAY = 2;
    const int SUBWAY__BATHROOMS = 3;                    // both are one room
    const int SUBWAY__TURNSTILES_1 = 4;                 // 1st visit only
    const int SUBWAY__ENTRANCE_SOUTH = 5;
    // MISSING 6
    const int SUBWAY__B2_PASSAGE = 7;                   // well-connected room
    const int SUBWAY__B3_PLATFORM_EAST = 8;
    const int SUBWAY__B3_PLATFORM_WEST_CLOSED = 9;      // w trapped Cynthia
    const int SUBWAY__MAINTENANCE_ROOM_EAST = 10;       // room with hole
    const int SUBWAY__MAINTENANCE_ROOM_WEST = 11;
    const int SUBWAY__MAINTENANCE_TUNNEL = 12;
    const int SUBWAY__ESCALATORS = 13;
    const int SUBWAY__B4_PLATFORM = 14;                 // platform with hole
    const int SUBWAY__TRAIN_OPERATOR_ROOM = 15;
    const int SUBWAY__TRAIN_CARTS_NORTH = 16;
    const int SUBWAY__TRAIN_CARTS_MIDDLE = 17;
    const int SUBWAY__TRAIN_CARTS_SOUTH = 18;
    const int SUBWAY__GENERATOR_ROOM = 19;              // 2nd visit start
    const int SUBWAY__TURNSTILES_2 = 20;                // 2nd visit only
    const int SUBWAY__B3_PLATFORM_WEST_OPEN = 21;       // w free Cynthia
    const int SUBWAY__B4_PLATFORM_MOVED_TRAIN = 22;     // 2nd visit only
    const int SUBWAY__ENCOUNTER_WITH_WALTER = 23;       // 2nd visit only
    const int SUBWAY__TICKET_OFFICE_INSIDE = 24;
    const int SUBWAY__TICKET_OFFICE_OUTSIDE = 25;       // 1st visit only

    const int FOREST__CLIFF = 1;                        // 1st visit start
    const int FOREST__PATH_TO_FACTORY = 2;
    const int FOREST__FACTORY_EAST = 3;
    const int FOREST__FACTORY_WEST = 4;
    const int FOREST__CAR = 5;
    const int FOREST__MOTHER_STONE = 6;
    const int FOREST__SPIKE_TRAP = 7;
    const int FOREST__PATH_TO_WISH_HOUSE_A = 8;         // North East
    const int FOREST__WISH_HOUSE_COURTYARD_1 = 9;       // 1st visit only
    const int FOREST__PATH_TO_MINES = 10;
    const int FOREST__MINE = 11;
    const int FOREST__PATH_TO_WISH_HOUSE_B = 12;        // South East
    const int FOREST__PATH_OF_ETERNAL_MIST = 13;
    const int FOREST__PATH_TO_GRAVEYARD_A = 14;
    const int FOREST__PATH_TO_GRAVEYARD_B = 15;
    const int FOREST__LAKE = 16;
    const int FOREST__TREE_ROOT = 17;
    const int FOREST__DEAD_END = 18;                    // hole to rid of key
    const int FOREST__GRAVEYARD = 19;                   // 2nd visit start
    const int FOREST__WISH_HOUSE_INSIDE = 20;           // 1st visit only
    const int FOREST__WISH_HOUSE_ALTAR = 21;            // 1st visit only
    const int FOREST__WISH_HOUSE_BASEMENT = 22;         // 2nd visit only
    const int FOREST__WISH_HOUSE_COURTYARD_2 = 23;      // 2nd visit only

    const int WATER_PRISON__1F_PRISON_HALLWAY = 1;      // 1st visit start
    const int WATER_PRISON__1F_PRISON_CELL_A = 2;
    const int WATER_PRISON__1F_OBSERVATION_ROOM = 3;
    const int WATER_PRISON__1F_PRISON_CELL_B = 4;
    const int WATER_PRISON__1F_PRISON_CELL_C = 5;
    const int WATER_PRISON__1F_PRISON_CELL_D = 6;       // 2nd/3rd jump
    const int WATER_PRISON__1F_PRISON_CELL_E = 7;
    const int WATER_PRISON__1F_PRISON_CELL_F = 8;
    const int WATER_PRISON__1F_PRISON_CELL_G = 9;       // 1st jump
    const int WATER_PRISON__1F_PRISON_CELL_H = 10;
    const int WATER_PRISON__2F_PRISON_HALLWAY = 11;
    const int WATER_PRISON__2F_PRISON_CELL_A = 12;
    const int WATER_PRISON__2F_OBSERVATION_ROOM = 13;
    const int WATER_PRISON__2F_PRISON_CELL_B = 14;
    const int WATER_PRISON__2F_PRISON_CELL_C = 15;
    const int WATER_PRISON__2F_PRISON_CELL_D = 16;
    const int WATER_PRISON__2F_PRISON_CELL_E = 17;
    const int WATER_PRISON__2F_PRISON_CELL_F = 18;
    const int WATER_PRISON__2F_PRISON_CELL_G = 19;      // 1st jump
    const int WATER_PRISON__2F_PRISON_CELL_H = 20;      // 2nd/3rd jump
    const int WATER_PRISON__3F_PRISON_HALLWAY = 21;
    const int WATER_PRISON__3F_PRISON_CELL_A = 22;
    const int WATER_PRISON__3F_OBSERVATION_ROOM = 23;
    const int WATER_PRISON__3F_PRISON_CELL_B = 24;
    const int WATER_PRISON__3F_PRISON_CELL_C = 25;
    const int WATER_PRISON__3F_PRISON_CELL_D = 26;
    const int WATER_PRISON__3F_PRISON_CELL_E = 27;
    const int WATER_PRISON__3F_PRISON_CELL_F = 28;      // 2nd/3rd jump
    const int WATER_PRISON__3F_PRISON_CELL_G = 29;      // 1st jump
    const int WATER_PRISON__3F_PRISON_CELL_H = 30;
    const int WATER_PRISON__OUTSIDE = 31;
    const int WATER_PRISON__WATERWHEEL_ROOM = 32;
    const int WATER_PRISON__ROOFTOP = 33;
    const int WATER_PRISON__SPIRAL_STAIRWAY_ACCESS = 34;
    const int WATER_PRISON__BASEMENT_HALLWAY = 35;
    const int WATER_PRISON__DINING_HALL = 36;
    const int WATER_PRISON__SHOWER_ROOM = 37;
    const int WATER_PRISON__KITCHEN = 38;
    const int WATER_PRISON__MURDER_ROOM = 39;
    const int WATER_PRISON__SPIRAL_STAIRWAY = 40;       // to waterwheel room
    // MISSING 41
    const int WATER_PRISON__GENERATOR_ROOM = 42;        // 2nd visit only
    const int WATER_PRISON__INSIDE_WATER_TANK = 43;     // 2nd visit start/only

    const int BUILDING__HOTEL_ROOF = 1;
    const int BUILDING__STAIRWELL_A = 2;                // sports - elevators
    const int BUILDING__ELEVATOR_ACCESS_TOP = 3;
    const int BUILDING__PARKING_LOT = 3;                // 2nd visit only
    const int BUILDING__ELEVATOR_ACCESS_BOTTOM = 4;     // separated by fence
    const int BUILDING__DANGER_ALLEYWAY_1 = 4;          // separated by fence
    const int BUILDING__DANGER_ALLEYWAY_2 = 5;
    const int BUILDING__STAIRWELL_B = 6;                // fan room - bar
    const int BUILDING__HOUSE = 7; // dinner party
    const int BUILDING__SPORTS_SHOP = 8;
    const int BUILDING__STORAGE_ROOM = 9;
    const int BUILDING__STAIRWELL_C = 10;               // house - sm hallway
    const int BUILDING__SHOWER_ROOM = 11;
    const int BUILDING__INSIDE_ELEVATORS = 12;
    const int BUILDING__SWORD_CORRIDOR = 13;
    const int BUILDING__RUSTY_AXE_BAR = 14;
    const int BUILDING__ROOM_207 = 15;                  // end of first visit
    const int BUILDING__STAIRWELL_D_1 = 16;             // after bar, 1st visit
    const int BUILDING__FAN_ROOM = 17;
    const int BUILDING__LONG_ALLEYWAY = 18;             // 1st visit start
    const int BUILDING__STAIRWELL_E = 19;               // sports - pets
    const int BUILDING__STAIRWELL_F = 20;               // pets - upside down
    // MISSING 21
    // MISSING 22
    const int BUILDING__PET_SHOP = 23;
    const int BUILDING__UPSIDE_DOWN = 24;
    // MISSING 25
    const int BUILDING__SMALL_HALLWAY = 26;
    const int BUILDING__STAIRWELL_D_2 = 27;             // after bar, 2nd visit

    const int APARTMENT__MAIN_HALL = 1;
    const int APARTMENT__1F_HALLWAY_EAST = 2;
    const int APARTMENT__1F_HALLWAY_WEST = 3;
    const int APARTMENT__ROOM_103 = 4;
    const int APARTMENT__ROOM_102 = 5;                  // has slug fridge
    const int APARTMENT__ROOM_101 = 6;
    const int APARTMENT__ROOM_106 = 7;
    const int APARTMENT__ROOM_107 = 8;
    const int APARTMENT__ROOM_105 = 9;                  // super's room
    const int APARTMENT__ROOM_104 = 10;
    const int APARTMENT__2F_HALLWAY_EAST = 11;
    const int APARTMENT__2F_HALLWAY_WEST = 12;
    const int APARTMENT__ROOM_203 = 13;
    const int APARTMENT__ROOM_202 = 14;
    const int APARTMENT__ROOM_201 = 15;
    const int APARTMENT__ROOM_206 = 16;
    const int APARTMENT__ROOM_207 = 17;
    const int APARTMENT__ROOM_205 = 18;
    const int APARTMENT__ROOM_204 = 19;
    const int APARTMENT__ROOM_303 = 20;
    // MISSING 21
    const int APARTMENT__ROOM_301 = 22;                 // has super's keys
    const int APARTMENT__ROOM_304 = 23;
    const int APARTMENT__3F_HALLWAY = 24;               // 1st visit start

    const int HOSPITAL__EMERGENCY_ROOM_A = 1;           // 1st visit start
    const int HOSPITAL__EMERGENCY_ROOM_B = 2;
    const int HOSPITAL__SUPPLY_ROOM = 3;
    const int HOSPITAL__LOBBY = 4;
    const int HOSPITAL__OFFICE = 5;
    const int HOSPITAL__WASH_ROOM = 6;                  // room with hole
    const int HOSPITAL__DOCTORS_LOUNGE = 7;
    const int HOSPITAL__STAIRWELL = 8;
    const int HOSPITAL__RECEPTION = 9;
    const int HOSPITAL__PR_EILEENS_ROOM = 10;           // room with Eileen
    const int HOSPITAL__PR_RAINY = 11;
    const int HOSPITAL__PR_STICKY = 12;
    const int HOSPITAL__PR_SPIKE_TRAP = 13;
    const int HOSPITAL__PR_HOSPITAL_KEY = 14;           // room with key
    const int HOSPITAL__PR_DRIED_FLOWERS = 15;
    const int HOSPITAL__PR_INCUBATORS = 16;
    const int HOSPITAL__PR_FOUR_IRON = 17;
    const int HOSPITAL__PR_TRAPPED_BUGS = 18;
    const int HOSPITAL__PR_BODY_FUNGUS = 19;
    const int HOSPITAL__PR_BIG_HEAD = 20;
    const int HOSPITAL__PR_SQUEAKY_METAL = 21;
    const int HOSPITAL__PR_STERILE_ROOM = 22;
    const int HOSPITAL__PR_ONE_NURSE = 23;
    const int HOSPITAL__PR_PILLS_AND_NEEDLES = 24;
    const int HOSPITAL__PR_XRAYS = 25;
    const int HOSPITAL__PR_HOOKS = 26;
    const int HOSPITAL__PR_SMASHED = 27;
    const int HOSPITAL__PR_HANGING_CLOTH = 28;
    const int HOSPITAL__PR_SUNLIGHT = 29;
    const int HOSPITAL__PR_TWO_NURSES = 30;
    const int HOSPITAL__PR_SPOOKY_WHEELCHAIR = 31;
    const int HOSPITAL__RNG_HALLWAY = 32;
    const int HOSPITAL__INSIDE_ELEVATOR = 33;
    const int HOSPITAL__LONG_STAIRS_DOWN = 34;          // end of hospital

    const int OUTSIDE_ROOM_302__CENTRAL_STAIRWAY = 1;
    const int OUTSIDE_ROOM_302__1F_HALLWAY_EAST = 2;
    const int OUTSIDE_ROOM_302__1F_HALLWAY_WEST = 3;    // stairs to 2F
    const int OUTSIDE_ROOM_302__ROOM_103 = 4;
    const int OUTSIDE_ROOM_302__ROOM_102 = 5;
    const int OUTSIDE_ROOM_302__ROOM_101 = 6;
    const int OUTSIDE_ROOM_302__ROOM_106 = 7;
    const int OUTSIDE_ROOM_302__ROOM_107 = 8;
    const int OUTSIDE_ROOM_302__ROOM_105 = 9;           // super's room
    const int OUTSIDE_ROOM_302__ROOM_104 = 10;
    const int OUTSIDE_ROOM_302__2F_HALLWAY_EAST = 11;
    const int OUTSIDE_ROOM_302__2F_HALLWAY_WEST = 12;   // stairs to 1F
    const int OUTSIDE_ROOM_302__ROOM_203 = 13;
    const int OUTSIDE_ROOM_302__ROOM_202 = 14;
    const int OUTSIDE_ROOM_302__ROOM_201_301 = 15;
    const int OUTSIDE_ROOM_302__ROOM_206 = 16;
    const int OUTSIDE_ROOM_302__ROOM_207 = 17;
    const int OUTSIDE_ROOM_302__PAST_LIVING_ROOM = 21;
    const int OUTSIDE_ROOM_302__3F_HALLWAY = 24;
    const int OUTSIDE_ROOM_302__PAST_BEDROOM = 25;

    const int THE_END__ABOVE_RITUAL_ROOM = 1;
    const int THE_END__BOSS_ROOM = 2;

    const int THE_HOLE__SUBWAY_HOLE = 1;
    const int THE_HOLE__FOREST_HOLE = 2;
    const int THE_HOLE__WATER_PRISON_HOLE = 3;
    const int THE_HOLE__BUILDING_HOLE = 4;
    const int THE_HOLE__APARTMENT_HOLE = 5;
    const int THE_HOLE__HOSPITAL_HOLE = 6;
    const int THE_HOLE__SUBWAY_2_HOLE = 7;
    const int THE_HOLE__FOREST_2_HOLE = 8;
    const int THE_HOLE__WATER_PRISON_2_HOLE = 9;
    const int THE_HOLE__BUILDING_2_HOLE = 10;
    const int THE_HOLE__PAST_ROOM_302_HOLE = 11;

    const int SPIRAL_STAIRCASE_TO_SUBWAY = 1;
    const int SPIRAL_STAIRCASE_TO_FOREST = 2;
    const int SPIRAL_STAIRCASE_TO_WATER_PRISON = 3;
    const int SPIRAL_STAIRCASE_TO_BUILDING = 4;
    const int SPIRAL_STAIRCASE_TO_ROOM_302 = 5;
    const int SPIRAL_STAIRCASE_ABOVE_WATER_PRISON = 6;
    const int SPIRAL_STAIRCASE_THE_ONE_TRUTH_ROOM = 7;

    //////////////////////////////////////////////////////////////////////
    // SPLIT BASES
    //////////////////////////////////////////////////////////////////////

    // IMPORTANT!
    // Be sure to update this part when changing route and/or sections.

    const int NIGHTMARE_SPLITS_BASE =
        0;
    const int ROOM_302_SPLITS_BASE =
        NIGHTMARE_SPLITS_BASE + 2;
    const int SUBWAY_1_SPLITS_BASE =
        ROOM_302_SPLITS_BASE + 6;
    const int FOREST_1_SPLITS_BASE =
        SUBWAY_1_SPLITS_BASE + 30;
    const int WATER_PRISON_1_SPLITS_BASE =
        FOREST_1_SPLITS_BASE + 36;
    const int BUILDING_1_SPLITS_BASE =
        WATER_PRISON_1_SPLITS_BASE + 33;
    const int APARTMENT_1_SPLITS_BASE =
        BUILDING_1_SPLITS_BASE + 25;
    const int HOSPITAL_SPLITS_BASE =
        APARTMENT_1_SPLITS_BASE + 25;
    const int SUBWAY_2_SPLITS_BASE =
        HOSPITAL_SPLITS_BASE + 19;
    const int FOREST_2_SPLITS_BASE =
        SUBWAY_2_SPLITS_BASE + 38;
    const int WATER_PRISON_2_SPLITS_BASE =
        FOREST_2_SPLITS_BASE + 36;
    const int BUILDING_2_SPLITS_BASE =
        WATER_PRISON_2_SPLITS_BASE + 27;
    const int ONE_TRUTH_SPLITS_BASE =
        BUILDING_2_SPLITS_BASE + 12;
    const int PAST_ROOM_302_SPLITS_BASE =
        ONE_TRUTH_SPLITS_BASE + 1;
    const int OUTSIDE_ROOM_302_SPLITS_BASE =
        PAST_ROOM_302_SPLITS_BASE + 8;
    const int THE_END_SPLITS_BASE =
        OUTSIDE_ROOM_302_SPLITS_BASE + 39;

    ///////////////////////////////////////////////////////////////////////////
    // SPLIT GOALS
    ///////////////////////////////////////////////////////////////////////////

    bool progress = false;
    switch((int) vars.currentSegment)
    {
        ///////////////////////////////////////////////////////////////////////
        // NIGHTMARE
        ///////////////////////////////////////////////////////////////////////

        case NIGHTMARE_SPLITS_BASE + 0:
            // BEDROOM
            // Move to living room after waking up as Joseph.
            progress = (
                old.currentWorldId == WORLD_ROOM_302 &&
                old.currentRoomId == ROOM_302__BEDROOM &&
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__LIVING_ROOM);
            break;
        case NIGHTMARE_SPLITS_BASE + 1:
            // LIVING ROOM (FACE)
            // Check out wall with face, run backwards, and skip cutscene.
            progress = (
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__BEDROOM);
            break;

        ///////////////////////////////////////////////////////////////////////
        // ROOM 302
        ///////////////////////////////////////////////////////////////////////

        case ROOM_302_SPLITS_BASE + 0:
            // BEDROOM
            // Move to living room after waking up as Henry.
            progress = (
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__LIVING_ROOM);
            break;
        case ROOM_302_SPLITS_BASE + 1:
            // LIVING ROOM (BOX, FRIDGE, +MILK, DOOR)
            // Check storage box, get chocolate milk from the fridge, approach
            // the door, and return to the bedroom.
            progress = (
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__BEDROOM);
            break;
        case ROOM_302_SPLITS_BASE + 2:
            // BEDROOM (WINDOW)
            // Check out the window in the bedroom, and move back to
            // the living room after hearing loud noise.
            progress = (
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__LIVING_ROOM);
            break;
        case ROOM_302_SPLITS_BASE + 3:
            // LIVING ROOM
            // Move to the bathroom.
            progress = (
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__BATHROOM);
            break;
        case ROOM_302_SPLITS_BASE + 4:
            // BATHROOM (+STEEL PIPE)
            // Approach hole, take steel pipe, and enter hole.
            progress = (current.currentWorldId != WORLD_ROOM_302);
            break;
        case ROOM_302_SPLITS_BASE + 5:
            // THE HOLE
            // Crawl to the end of the hole, and enter Subway World.
            progress = (current.currentWorldId != WORLD_THE_HOLE);
            break;

        ///////////////////////////////////////////////////////////////////////
        // SUBWAY WORLD
        ///////////////////////////////////////////////////////////////////////

        case SUBWAY_1_SPLITS_BASE + 0:
            // ENTRANCE
            // Approach Cynthia, skip cutscene, and move to hallway.
            progress = (
                old.currentWorldId == WORLD_SUBWAY &&
                old.currentRoomId == SUBWAY__ENTRANCE_NORTH &&
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__HALLWAY);
            break;
        case SUBWAY_1_SPLITS_BASE + 1:
            // HALLWAY
            // Move forward, skip the cutscene, and enter women's bathroom.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__BATHROOMS);
            break;
        case SUBWAY_1_SPLITS_BASE + 2:
            // WOMEN'S BATHROOM
            // Enter the hole in the women's bathroom.
            progress = (current.currentWorldId != WORLD_SUBWAY);
            break;
        case SUBWAY_1_SPLITS_BASE + 3:
            // ROOM 302: BEDROOM
            // Move to living room after waking up.
            progress = (
                old.currentWorldId == WORLD_ROOM_302 &&
                old.currentRoomId == ROOM_302__BEDROOM &&
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__LIVING_ROOM);
            break;
        case SUBWAY_1_SPLITS_BASE + 4:
            // ROOM 302: LIVING ROOM (+GUN, PEEPING HOLE)
            // Check out moved furniture, pick up the gun, check out the
            // peeking hole, and then return to bedroom.
            progress = (
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__BEDROOM);
            break;
        case SUBWAY_1_SPLITS_BASE + 5:
            // ROOM 302: BEDROOM (PHONE)
            // Pick up phone, and move back to living room.
            progress = (
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__LIVING_ROOM);
            break;
        case SUBWAY_1_SPLITS_BASE + 6:
            // ROOM 302: LIVING ROOM
            // Move to bathroom.
            progress = (
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__BATHROOM);
            break;
        case SUBWAY_1_SPLITS_BASE + 7:
            // ROOM 302: BATHROOM
            // Enter the hole.
            progress = (current.currentWorldId != WORLD_ROOM_302);
            break;
        case SUBWAY_1_SPLITS_BASE + 8:
            // WOMEN'S BATHROOM (+COIN)
            // Take the coin out of the doll's hand, and leave bathroom.
            progress = (
                old.currentWorldId == WORLD_SUBWAY &&
                old.currentRoomId == SUBWAY__BATHROOMS &&
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__HALLWAY);
            break;
        case SUBWAY_1_SPLITS_BASE + 9:
            // HALLWAY
            // Move to room with turnstiles.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__TURNSTILES_1);
            break;
        case SUBWAY_1_SPLITS_BASE + 10:
            // TURNSTILES
            // Go through turnstiles using coin, and go down the stairs.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__B2_PASSAGE);
            break;
        case SUBWAY_1_SPLITS_BASE + 11:
            // B2 PASSAGE
            // Skip custcene with ghosts, and go down the stairs.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__B3_PLATFORM_WEST_CLOSED);
            break;
        case SUBWAY_1_SPLITS_BASE + 12:
            // B3 SUBWAY PLATFORM A
            // Move to train operator's room at the front of train.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__TRAIN_OPERATOR_ROOM);
            break;
        case SUBWAY_1_SPLITS_BASE + 13:
            // TRAIN OPERATOR'S ROOM (BUTTON)
            // Push button and go back outside.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__B3_PLATFORM_WEST_OPEN);
            break;
        case SUBWAY_1_SPLITS_BASE + 14:
            // B3 SUBWAY PLATFORM A
            // Enter southern section of carts.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__TRAIN_CARTS_SOUTH);
            break;
        case SUBWAY_1_SPLITS_BASE + 15:
            // B3 SUBWAY CARTS
            // Move to middle section of carts.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__TRAIN_CARTS_MIDDLE);
            break;
        case SUBWAY_1_SPLITS_BASE + 16:
            // B3 SUBWAY CARTS
            // Move to northern section of carts.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__TRAIN_CARTS_NORTH);
            break;
        case SUBWAY_1_SPLITS_BASE + 17:
            // B3 SUBWAY CARTS
            // Move to other train carts, and go down to the middle section.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__TRAIN_CARTS_MIDDLE);
            break;
        case SUBWAY_1_SPLITS_BASE + 18:
            // B3 SUBWAY CARTS
            // Move to southern section of carts.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__TRAIN_CARTS_SOUTH);
            break;
        case SUBWAY_1_SPLITS_BASE + 19:
            // B3 SUBWAY CARTS
            // Leave cart and access platform on other side.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__B3_PLATFORM_EAST);
            break;
        case SUBWAY_1_SPLITS_BASE + 20:
            // B3 SUBWAY PLATFORM B
            // Move to maintenance room with hole.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__MAINTENANCE_ROOM_EAST);
            break;
        case SUBWAY_1_SPLITS_BASE + 21:
            // MAINTENANCE ROOM A
            // Skip cutscene, and go down the ladder.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__MAINTENANCE_TUNNEL);
            break;
        case SUBWAY_1_SPLITS_BASE + 22:
            // MAINTENANCE TUNNEL
            // Run to other side of maintenance tunnel, and go up the ladder.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__MAINTENANCE_ROOM_WEST);
            break;
        case SUBWAY_1_SPLITS_BASE + 23:
            // MAINTENANCE ROOM B (+BULLETS, DOOR)
            // Pick up the bullets, unlock the door, and go back down.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__MAINTENANCE_TUNNEL);
            break;
        case SUBWAY_1_SPLITS_BASE + 24:
            // MAINTENANCE TUNNEL
            // Run down to subway platform.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__B4_PLATFORM);
            break;
        case SUBWAY_1_SPLITS_BASE + 25:
            // B4 SUBWAY PLATFORM
            // Move to the escalators.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__ESCALATORS);
            break;
        case SUBWAY_1_SPLITS_BASE + 26:
            // ESCALATORS
            // Run up the escalators.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__B2_PASSAGE);
            break;
        case SUBWAY_1_SPLITS_BASE + 27:
            // B2 PASSAGE
            // Go up the stairs to the ticket office.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__TICKET_OFFICE_OUTSIDE);
            break;
        case SUBWAY_1_SPLITS_BASE + 28:
            // OUTSIDE TICKET OFFICE (+PLACARD)
            // Remove the plate, and go inside the ticket office.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__TICKET_OFFICE_INSIDE);
            break;
        case SUBWAY_1_SPLITS_BASE + 29:
            // END OF WORLD_SUBWAY WORLD
            // Skip cutscene.
            progress = (current.currentWorldId != WORLD_SUBWAY);
            break;

        ///////////////////////////////////////////////////////////////////////
        // WORLD_FOREST WORLD
        ///////////////////////////////////////////////////////////////////////

        case FOREST_1_SPLITS_BASE + 0:
            // ROOM 302: BEDROOM
            // Skip cutscenes/loading screens and move to living room.
            progress = (
                old.currentWorldId == WORLD_ROOM_302 &&
                old.currentRoomId == ROOM_302__BEDROOM &&
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__LIVING_ROOM);
            break;
        case FOREST_1_SPLITS_BASE + 1:
            // ROOM 302: LIVING ROOM
            // Move to bathroom.
            progress = (
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__BATHROOM);
            break;
        case FOREST_1_SPLITS_BASE + 2:
            // ROOM 302: BATHROOM
            // Enter the hole.
            progress = (current.currentWorldId != WORLD_ROOM_302);
            break;
        case FOREST_1_SPLITS_BASE + 3:
            // CLIFF
            // Skip cutscenes, and go through gate.
            progress = (
                old.currentWorldId == WORLD_FOREST &&
                old.currentRoomId == FOREST__CLIFF &&
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__PATH_TO_FACTORY);
            break;
        case FOREST_1_SPLITS_BASE + 4:
            // PATH TO FACTORY
            // Enter factory.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__FACTORY_EAST);
            break;
        case FOREST_1_SPLITS_BASE + 5:
            // FACTORY EAST
            // Go down and enter the door to the next part of factory.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__FACTORY_WEST);
            break;
        case FOREST_1_SPLITS_BASE + 6:
            // FACTORY WEST
            // Go through the gate.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__CAR);
            break;
        case FOREST_1_SPLITS_BASE + 7:
            // CAR
            // Move to the gate on the other side.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__MOTHER_STONE);
            break;
        case FOREST_1_SPLITS_BASE + 8:
            // MOTHER STONE
            // Move to the gate on the other side.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__SPIKE_TRAP);
            break;
        case FOREST_1_SPLITS_BASE + 9:
            // SPIKE TRAP
            // Move to the gate on the other side.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__PATH_TO_WISH_HOUSE_A);
            break;
        case FOREST_1_SPLITS_BASE + 10:
            // PATH TO WISH HOUSE A
            // Enter the door to Wish House's courtyard.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__WISH_HOUSE_COURTYARD_1);
            break;
        case FOREST_1_SPLITS_BASE + 11:
            // WISH HOUSE COURTYARD (+SPADE)
            // Move to the door leading to the graveyard.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__PATH_TO_GRAVEYARD_A);
            break;
        case FOREST_1_SPLITS_BASE + 12:
            // PATH TO GRAVEYARD A
            // Move to the gate on the other side.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__PATH_TO_GRAVEYARD_B);
            break;
        case FOREST_1_SPLITS_BASE + 13:
            // PATH TO GRAVEYARD B
            // Enter the graveyard.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__GRAVEYARD);
                break;
        case FOREST_1_SPLITS_BASE + 14:
            // GRAVEYARD
            // Approach the kid, skip the cutscene, and leave.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__PATH_TO_GRAVEYARD_B);
            break;
        case FOREST_1_SPLITS_BASE + 15:
            // PATH TO GRAVEYARD B
            // Return to Wish House.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__PATH_TO_GRAVEYARD_A);
            break;
        case FOREST_1_SPLITS_BASE + 16:
            // PATH TO GRAVEYARD A
            // Return to Wish House.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__WISH_HOUSE_COURTYARD_1);
            break;
        case FOREST_1_SPLITS_BASE + 17:
            // WISH HOUSE COURTYARD
            // Approach Jasper, give him the chocolate milk, pick up the spade,
            // and go through the south east gate.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__PATH_TO_WISH_HOUSE_B);
            break;
        case FOREST_1_SPLITS_BASE + 18:
            // PATH TO WISH HOUSE B
            // Enter the gate on the other side.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__PATH_OF_ETERNAL_MIST);
            break;
        case FOREST_1_SPLITS_BASE + 19:
            // PATH OF ETERNAL MIST
            // Enter the gate on the other side.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__TREE_ROOT);
            break;
        case FOREST_1_SPLITS_BASE + 20:
            // PATH WITH WEIRD TREE
            // Use spade to dig up key, and move to dead end.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__DEAD_END);
            break;
        case FOREST_1_SPLITS_BASE + 21:
            // DEAD END
            // Enter the hole.
            progress = (current.currentWorldId != WORLD_FOREST);
            break;
        case FOREST_1_SPLITS_BASE + 22:
            // ROOM 302: BEDROOM
            // Move to the living room.
            progress = (
                old.currentWorldId == WORLD_ROOM_302 &&
                old.currentRoomId == ROOM_302__BEDROOM &&
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__LIVING_ROOM);
            break;
        case FOREST_1_SPLITS_BASE + 23:
            // ROOM 302: LIVING ROOM
            // Drop the steel pipe, bullets, and key in the box, and then 
            // enter the bathroom.
            progress = (
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__BATHROOM);
            break;
        case FOREST_1_SPLITS_BASE + 24:
            // ROOM 302: BATHROOM
            // Enter the hole.
            progress = (current.currentWorldId != WORLD_ROOM_302);
            break;
        case FOREST_1_SPLITS_BASE + 25:
            // DEAD END
            // Return to Wish House.
            progress = (
                old.currentWorldId == WORLD_FOREST &&
                old.currentRoomId == FOREST__DEAD_END &&
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__TREE_ROOT);
            break;
        case FOREST_1_SPLITS_BASE + 26:
            // PATH WITH WEIRD TREE
            // Return to Wish House.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__PATH_OF_ETERNAL_MIST);
            break;
        case FOREST_1_SPLITS_BASE + 27:
            // PATH OF ETERNAL MIST
            // Return to Wish House.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__PATH_TO_WISH_HOUSE_B);
            break;
        case FOREST_1_SPLITS_BASE + 28:
            // PATH TO WISH HOUSE B
            // Return to Wish House.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__WISH_HOUSE_COURTYARD_1);
            break;
        case FOREST_1_SPLITS_BASE + 29:
            // WISH HOUSE COURTYARD
            // Enter the hole.
            progress = (current.currentWorldId != WORLD_FOREST);
            break;
        case FOREST_1_SPLITS_BASE + 30:
            // ROOM 302: BEDROOM
            // Move to the living room.
            progress = (
                old.currentWorldId == WORLD_ROOM_302 &&
                old.currentRoomId == ROOM_302__BEDROOM &&
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__LIVING_ROOM);
            break;
        case FOREST_1_SPLITS_BASE + 31:
            // ROOM 302: LIVING ROOM (+KEY)
            // Retrieve the bloody key from the box, and enter the bathroom.
            progress = (
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__BATHROOM);
            break;
        case FOREST_1_SPLITS_BASE + 32:
            // ROOM 302: BATHROOM
            // Enter the hole.
            progress = (current.currentWorldId != WORLD_ROOM_302);
            break;
        case FOREST_1_SPLITS_BASE + 33:
            // WISH HOUSE COURTYARD
            // Enter Wish House using the key.
            progress = (
                old.currentWorldId == WORLD_FOREST &&
                old.currentRoomId == FOREST__WISH_HOUSE_COURTYARD_1 &&
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__WISH_HOUSE_INSIDE);
            break;
        case FOREST_1_SPLITS_BASE + 34:
            // WISH HOUSE INSIDE (HOLY SCRIPTURE, +PLACARD)
            // Read the holy scripture, pick up the plate, and enter the door.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__WISH_HOUSE_ALTAR);
            break;
        case FOREST_1_SPLITS_BASE + 35:
            // END OF WORLD_FOREST WORLD
            // Skip cutscene.
            progress = (current.currentWorldId != WORLD_FOREST);
            break;

        ///////////////////////////////////////////////////////////////////////
        // WATER PRISON WORLD
        ///////////////////////////////////////////////////////////////////////

        case WATER_PRISON_1_SPLITS_BASE + 0:
            // ROOM 302: BEDROOM
            // Move to the living room.
            progress = (
                old.currentWorldId == WORLD_ROOM_302 &&
                old.currentRoomId == ROOM_302__BEDROOM &&
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__LIVING_ROOM);
            break;
        case WATER_PRISON_1_SPLITS_BASE + 1:
            // ROOM 302: LIVING ROOM
            // Enter the bathroom.
            progress = (
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__BATHROOM);
            break;
        case WATER_PRISON_1_SPLITS_BASE + 2:
            // ROOM 302: BATHROOM
            // Enter the hole.
            progress = (current.currentWorldId != WORLD_ROOM_302);
            break;
        case WATER_PRISON_1_SPLITS_BASE + 3:
            // 1F PRISON
            // Leave the hallway.
            progress = (
                old.currentWorldId == WORLD_WATER_PRISON &&
                old.currentRoomId == WATER_PRISON__1F_PRISON_HALLWAY &&
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__SPIRAL_STAIRWAY_ACCESS);
            break;
        case WATER_PRISON_1_SPLITS_BASE + 4:
            // STAIRWAY ACCESS
            // Enter the stairway.
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__SPIRAL_STAIRWAY);
            break;
        case WATER_PRISON_1_SPLITS_BASE + 5:
            // STAIRWAY
            // Go down and enter the waterwheel room.
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__WATERWHEEL_ROOM);
            break;
        case WATER_PRISON_1_SPLITS_BASE + 6:
            // WATERWHEEL ROOM (+KEY)
            // Pick up the key, and go back.
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__SPIRAL_STAIRWAY);
            break;
        case WATER_PRISON_1_SPLITS_BASE + 7:
            // STAIRWAY
            // Go back up, and enter the stairway access room.
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__SPIRAL_STAIRWAY_ACCESS);
            break;
        case WATER_PRISON_1_SPLITS_BASE + 8:
            // STAIRWAY ACCESS
            // Use the key to go outside.
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__OUTSIDE);
            break;
        case WATER_PRISON_1_SPLITS_BASE + 9:
            // PRISON EXTERIOR
            // Go to the rooftop.
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__ROOFTOP);
            break;
        case WATER_PRISON_1_SPLITS_BASE + 10:
            // PRISON ROOFTOP
            // Turn the handle.
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__OUTSIDE);
            break;
        case WATER_PRISON_1_SPLITS_BASE + 11:
            // PRISON EXTERIOR
            // Enter the 3F hallway.
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__3F_PRISON_HALLWAY);
            break;
        case WATER_PRISON_1_SPLITS_BASE + 12:
            // 3F PRISON HALLWAY
            // Enter the cell that is 2 cells up.
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__3F_PRISON_CELL_G);
            break;
        case WATER_PRISON_1_SPLITS_BASE + 13:
            // 3F PRISON CELL
            // Jump down the hole.
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__2F_PRISON_CELL_G);
            break;
        case WATER_PRISON_1_SPLITS_BASE + 14:
            // 2F PRISON CELL
            // Jump down the hole.            
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__1F_PRISON_CELL_G);
            break;
        case WATER_PRISON_1_SPLITS_BASE + 15:
            // 1F PRISON CELL
            // Jump down the hole.            
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__SHOWER_ROOM);
            break;
        case WATER_PRISON_1_SPLITS_BASE + 16:
            // SHOWER ROOM
            // Leave the room.
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__BASEMENT_HALLWAY);
            break;
        case WATER_PRISON_1_SPLITS_BASE + 17:
            // CENTRAL BASEMENT HALLWAY
            // Go up the ladder.
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__1F_OBSERVATION_ROOM);
            break;
        case WATER_PRISON_1_SPLITS_BASE + 18:
            // 1F OBSERVATION ROOM
            // Go up the ladder.            
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__2F_OBSERVATION_ROOM);
            break;
        case WATER_PRISON_1_SPLITS_BASE + 19:
            // 2F OBSERVATION ROOM
            // Go up the ladder.            
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__3F_OBSERVATION_ROOM);
            break;
        case WATER_PRISON_1_SPLITS_BASE + 20:
            // 3F OBSERVATION ROOM (2R)
            // Turn the wheel to the right two times. Go back down.       
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__2F_OBSERVATION_ROOM);
            break;
        case WATER_PRISON_1_SPLITS_BASE + 21:
            // 2F OBSERVATION ROOM
            // Turn the wheel to the right four times. Go back down.
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__1F_OBSERVATION_ROOM);
            break;
        case WATER_PRISON_1_SPLITS_BASE + 22:
            // 1F OBSERVATION ROOM
            // Go back down.
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__BASEMENT_HALLWAY);
            break;
        case WATER_PRISON_1_SPLITS_BASE + 23:
            // BASEMENT HALLWAY
            // Leave the room.
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__SPIRAL_STAIRWAY);
            break;
        case WATER_PRISON_1_SPLITS_BASE + 24:
            // STAIRWAY
            // Move up the stairs.
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__SPIRAL_STAIRWAY_ACCESS);
            break;
        case WATER_PRISON_1_SPLITS_BASE + 25:
            // SPIRAL STAIRWAY ACCESS
            // Go outside.
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__OUTSIDE);
            break;
        case WATER_PRISON_1_SPLITS_BASE + 26:
            // PRISON EXTERIOR
            // Enter the third floor hallway.
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__3F_PRISON_HALLWAY);
            break;
        case WATER_PRISON_1_SPLITS_BASE + 27:
            // 3F PRISON HALLWAY
            // Go into the cell next to the broken water pipe.
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__3F_PRISON_CELL_F);
            break;
        case WATER_PRISON_1_SPLITS_BASE + 28:
            // 3F PRISON CELL
            // Jump down the hole.               
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__2F_PRISON_CELL_H);
            break;
        case WATER_PRISON_1_SPLITS_BASE + 29:
            // 2F PRISON CELL
            // Jump down the hole.               
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__1F_PRISON_CELL_D);
            break;
        case WATER_PRISON_1_SPLITS_BASE + 30:
            // 1F PRISON CELL
            // Jump down the hole.               
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__KITCHEN);
            break;
        case WATER_PRISON_1_SPLITS_BASE + 31:
            // KITCHEN (+PLACARD, 0302)
            // Approach the door, pick up the plate, and enter the code 0302.
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__MURDER_ROOM);
            break;
        case WATER_PRISON_1_SPLITS_BASE + 32:
            // END OF WATER PRISON
            // Skip the cutscene.
            progress = (current.currentWorldId != WORLD_WATER_PRISON);
            break;

        ///////////////////////////////////////////////////////////////////////
        // BUILDING WORLD
        ///////////////////////////////////////////////////////////////////////

        case BUILDING_1_SPLITS_BASE + 0:
            // ROOM 302: BEDROOM
            // Move to the living room.
            progress = (
                old.currentWorldId == WORLD_ROOM_302 &&
                old.currentRoomId == ROOM_302__BEDROOM &&
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__LIVING_ROOM);
            break;
        case BUILDING_1_SPLITS_BASE + 1:
            // ROOM 302: LIVING ROOM
            // Enter the bathroom.
            progress = (
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__BATHROOM);
            break;
        case BUILDING_1_SPLITS_BASE + 2:
            // ROOM 302: BATHROOM
            // Enter the hole.
            progress = (current.currentWorldId != WORLD_ROOM_302);
            break;
        case BUILDING_1_SPLITS_BASE + 3:
            // LONG ALLEYWAY
            // Go down the long alleyway.
            progress = (
                current.currentWorldId == WORLD_BUILDING &&
                current.currentRoomId == BUILDING__HOTEL_ROOF);
            break;
        case BUILDING_1_SPLITS_BASE + 4:
            // HOTEL ROOF
            // Go down, skip the cutscene, and enter the door.
            progress = (
                current.currentWorldId == WORLD_BUILDING &&
                current.currentRoomId == BUILDING__HOUSE);
            break;
        case BUILDING_1_SPLITS_BASE + 5:
            // HOUSE (+SWORD)
            // Approach the ghost, pick up the key and sword, and leave.
            progress = (
                current.currentWorldId == WORLD_BUILDING &&
                current.currentRoomId == BUILDING__STAIRWELL_C);
            break;
        case BUILDING_1_SPLITS_BASE + 6:
            // STAIRWELL A
            // Go down and enter door.
            progress = (
                current.currentWorldId == WORLD_BUILDING &&
                current.currentRoomId == BUILDING__SMALL_HALLWAY);
            break;
        case BUILDING_1_SPLITS_BASE + 7:
            // SMALL HALLWAY
            // Enter the other door.
            progress = (
                current.currentWorldId == WORLD_BUILDING &&
                current.currentRoomId == BUILDING__STORAGE_ROOM);
            break;
        case BUILDING_1_SPLITS_BASE + 8:
            // STORAGE ROOM
            // Enter the other door.
            progress = (
                current.currentWorldId == WORLD_BUILDING &&
                current.currentRoomId == BUILDING__SPORTS_SHOP);
            break;
        case BUILDING_1_SPLITS_BASE + 9:
            // SPORTS STORE
            // Enter the door on the other side of the room.
            progress = (
                current.currentWorldId == WORLD_BUILDING &&
                current.currentRoomId == BUILDING__STAIRWELL_E);
            break;
        case BUILDING_1_SPLITS_BASE + 10:
            // STAIRWELL B
            // Go down the stairs and enter the door.
            progress = (
                current.currentWorldId == WORLD_BUILDING &&
                current.currentRoomId == BUILDING__PET_SHOP);
            break;
        case BUILDING_1_SPLITS_BASE + 11:
            // PET SHOP (+KEY)
            // Pick up the keys, and leave again.
            progress = (
                current.currentWorldId == WORLD_BUILDING &&
                current.currentRoomId == BUILDING__STAIRWELL_E);
            break;
        case BUILDING_1_SPLITS_BASE + 12:
            // STAIRWELL B
            // Go back up the stairs and enter the door.
            progress = (
                current.currentWorldId == WORLD_BUILDING &&
                current.currentRoomId == BUILDING__SPORTS_SHOP);
            break;
        case BUILDING_1_SPLITS_BASE + 13:
            // SPORTS STORE
            // Use the key to go through the third door in the shop.
            progress = (
                current.currentWorldId == WORLD_BUILDING &&
                current.currentRoomId == BUILDING__STAIRWELL_A);
            break;
        case BUILDING_1_SPLITS_BASE + 14:
            // STAIRWELL C
            // Go down and turn around the corner.
            progress = (
                current.currentWorldId == WORLD_BUILDING &&
                current.currentRoomId == BUILDING__ELEVATOR_ACCESS_TOP);
            break;
        case BUILDING_1_SPLITS_BASE + 15:
            // ELEVATOR ACCESS BALCONY
            // Enter the elevator that is furthest away.
            progress = (
                current.currentWorldId == WORLD_BUILDING &&
                current.currentRoomId == BUILDING__INSIDE_ELEVATORS);
            break;
        case BUILDING_1_SPLITS_BASE + 16:
            // INSIDE ELEVATORS
            // Go down the ladder in the back.
            progress = (
                current.currentWorldId == WORLD_BUILDING &&
                current.currentRoomId == BUILDING__SHOWER_ROOM);
            break;
        case BUILDING_1_SPLITS_BASE + 17:
            // SHOWER ROOM
            // Move through the fungus and go up the ladder.
            progress = (
                current.currentWorldId == WORLD_BUILDING &&
                current.currentRoomId == BUILDING__DANGER_ALLEYWAY_1);
            break;
        case BUILDING_1_SPLITS_BASE + 18:
            // DANGEROUS ALLEYWAY A
            // Move through the alleyway.
            progress = (
                current.currentWorldId == WORLD_BUILDING &&
                current.currentRoomId == BUILDING__DANGER_ALLEYWAY_2);
            break;
        case BUILDING_1_SPLITS_BASE + 19:
            // DANGEROUS ALLEYWAY B
            // Move through the alleyway and enter the door.
            progress = (
                current.currentWorldId == WORLD_BUILDING &&
                current.currentRoomId == BUILDING__FAN_ROOM);
            break;
        case BUILDING_1_SPLITS_BASE + 20:
            // FAN ROOM
            // Go down the stairs and through the door.
            progress = (
                current.currentWorldId == WORLD_BUILDING &&
                current.currentRoomId == BUILDING__STAIRWELL_B);
            break;
        case BUILDING_1_SPLITS_BASE + 21:
            // STAIRWELL D
            // Go down the stairs and through the door.
            progress = (
                current.currentWorldId == WORLD_BUILDING &&
                current.currentRoomId == BUILDING__RUSTY_AXE_BAR);
            break;
        case BUILDING_1_SPLITS_BASE + 22:
            // RUSTY AXE BAR (+AXE)
            // Pick up the axe on the table, enter the code 3750, and leave.
            progress = (
                current.currentWorldId == WORLD_BUILDING &&
                current.currentRoomId == BUILDING__STAIRWELL_D_1);
            break;
        case BUILDING_1_SPLITS_BASE + 23:
            // STAIRWELL E (+PLACARD)
            // Go up the stairs, pick up the plate, and go through the door.
            progress = (
                current.currentWorldId == WORLD_BUILDING &&
                current.currentRoomId == BUILDING__ROOM_207);
            break;
        case BUILDING_1_SPLITS_BASE + 24:
            // END OF BUILDING WORLD
            // Skip the cutscene.
            progress = (current.currentWorldId != WORLD_BUILDING);
            break;

        ///////////////////////////////////////////////////////////////////////
        // APARTMENT WORLD
        ///////////////////////////////////////////////////////////////////////

        case APARTMENT_1_SPLITS_BASE + 0:
            // ROOM 302: BEDROOM
            // Move to the living room.
            progress = (
                old.currentWorldId == WORLD_ROOM_302 &&
                old.currentRoomId == ROOM_302__BEDROOM &&
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__LIVING_ROOM);
            break;
        case APARTMENT_1_SPLITS_BASE + 1:
            // ROOM 302: LIVING ROOM
            // Enter the bathroom.
            progress = (
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__BATHROOM);
            break;
        case APARTMENT_1_SPLITS_BASE + 2:
            // ROOM 302: BATHROOM
            // Enter the hole.
            progress = (current.currentWorldId != WORLD_ROOM_302);
            break;
        case APARTMENT_1_SPLITS_BASE + 3:
            // 3F HALLWAY
            // Skip cutscene of waking up in 3F hallway, and enter room 301.
            progress = (
                old.currentWorldId == WORLD_APARTMENT &&
                old.currentRoomId == APARTMENT__3F_HALLWAY &&
                current.currentWorldId == WORLD_APARTMENT &&
                current.currentRoomId == APARTMENT__ROOM_301);
            break;
        case APARTMENT_1_SPLITS_BASE + 4:
            // ROOM 301 (+KEY)
            // Pick up the superintendent's keys, and go back outside.
            progress = (
                current.currentWorldId == WORLD_APARTMENT &&
                current.currentRoomId == APARTMENT__3F_HALLWAY);
            break;
        case APARTMENT_1_SPLITS_BASE + 5:
            // 3F HALLWAY
            // Run to the central staircase.
            progress = (
                current.currentWorldId == WORLD_APARTMENT &&
                current.currentRoomId == APARTMENT__MAIN_HALL);
            break;
        case APARTMENT_1_SPLITS_BASE + 6:
            // MAIN HALL
            // Move to 1F Hallway West
            progress = (
                current.currentWorldId == WORLD_APARTMENT &&
                current.currentRoomId == APARTMENT__1F_HALLWAY_WEST);
            break;
        case APARTMENT_1_SPLITS_BASE + 7:
            // 1F HALLWAY WEST
            // Enter room 105.
            progress = (
                current.currentWorldId == WORLD_APARTMENT &&
                current.currentRoomId == APARTMENT__ROOM_105);
            break;
        case APARTMENT_1_SPLITS_BASE + 8:
            // ROOM 105 (+APT KEYS)
            // Pick up the apartment keys, and leave room.
            progress = (
                current.currentWorldId == WORLD_APARTMENT &&
                current.currentRoomId == APARTMENT__1F_HALLWAY_WEST);
            break;
        case APARTMENT_1_SPLITS_BASE + 9:
            // 1F HALLWAY WEST
            // Run back to the main hall.
            progress = (
                current.currentWorldId == WORLD_APARTMENT &&
                current.currentRoomId == APARTMENT__MAIN_HALL);
            break;
        case APARTMENT_1_SPLITS_BASE + 10:
            // MAIN HALL
            // Move to the hallway on the other side.
            progress = (
                current.currentWorldId == WORLD_APARTMENT &&
                current.currentRoomId == APARTMENT__1F_HALLWAY_EAST);
            break;
        case APARTMENT_1_SPLITS_BASE + 11:
            // 1F HALLWAY EAST
            // Enter room 102.
            progress = (
                current.currentWorldId == WORLD_APARTMENT &&
                current.currentRoomId == APARTMENT__ROOM_102);
            break;
        case APARTMENT_1_SPLITS_BASE + 12:
            // ROOM 102 (+NOTE)
            // Open fridge, pick up red piece of paper, and leave room.
            progress = (
                current.currentWorldId == WORLD_APARTMENT &&
                current.currentRoomId == APARTMENT__1F_HALLWAY_EAST);
            break;
        case APARTMENT_1_SPLITS_BASE + 13:
            // 1F HALLWAY EAST
            // Run back to the main hall.
            progress = (
                current.currentWorldId == WORLD_APARTMENT &&
                current.currentRoomId == APARTMENT__MAIN_HALL);
            break;
        case APARTMENT_1_SPLITS_BASE + 14:
            // MAIN HALL
            // Run back to 3F hallway.
            progress = (
                current.currentWorldId == WORLD_APARTMENT &&
                current.currentRoomId == APARTMENT__3F_HALLWAY);
            break;
        case APARTMENT_1_SPLITS_BASE + 15:
            // 3F HALLWAY (-NOTE)
            // Put the piece of paper under the door of room 302, and enter
            // room 301.
            progress = (
                current.currentWorldId == WORLD_APARTMENT &&
                current.currentRoomId == APARTMENT__ROOM_301);
            break;
        case APARTMENT_1_SPLITS_BASE + 16:
            // ROOM 301
            // Enter hole.
            progress = (current.currentWorldId != WORLD_APARTMENT);
            break;
        case APARTMENT_1_SPLITS_BASE + 17:
            // ROOM 302: BEDROOM
            // Move to living room.
            progress = (
                old.currentWorldId == WORLD_ROOM_302 &&
                old.currentRoomId == ROOM_302__BEDROOM &&
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__LIVING_ROOM);
            break;
        case APARTMENT_1_SPLITS_BASE + 18:
            // ROOM 302: LIVING ROOM (NOTE)
            // Pick up and read red piece of paper from under door, and
            // return to bedroom.
            progress = (
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__BEDROOM);
            break;
        case APARTMENT_1_SPLITS_BASE + 19:
            // ROOM 302: BEDROOM (+KEY)
            // Pick up key next to the bed, and leave room.
            progress = (
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__LIVING_ROOM);
            break;
        case APARTMENT_1_SPLITS_BASE + 20:
            // ROOM 302: LIVING ROOM
            // Move to bathroom.
            progress = (
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__BATHROOM);
            break;
        case APARTMENT_1_SPLITS_BASE + 21:
            // ROOM 302: BATHROOM
            // Enter hole.
            progress = (current.currentWorldId != WORLD_ROOM_302);
            break;
        case APARTMENT_1_SPLITS_BASE + 22:
            // ROOM 301
            // Move to 3F Hallway.
            progress = (
                current.currentWorldId == WORLD_APARTMENT &&
                current.currentRoomId == APARTMENT__3F_HALLWAY);
            break;
        case APARTMENT_1_SPLITS_BASE + 23:
            // 3F HALLWAY
            // Enter room 303.
            progress = (
                current.currentWorldId == WORLD_APARTMENT &&
                current.currentRoomId == APARTMENT__ROOM_303);
            break;
        case APARTMENT_1_SPLITS_BASE + 24:
            // END OF APARTMENT WORLD
            progress = (current.currentWorldId != WORLD_APARTMENT);
            break;

        ///////////////////////////////////////////////////////////////////////
        // HOSPITAL WORLD
        ///////////////////////////////////////////////////////////////////////

        case HOSPITAL_SPLITS_BASE + 0:
            // ROOM 302: BEDROOM
            // Wake up and move to living room.
            progress = (
                old.currentWorldId == WORLD_ROOM_302 &&
                old.currentRoomId == ROOM_302__BEDROOM &&
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__LIVING_ROOM);
            break;
        case HOSPITAL_SPLITS_BASE + 1:
            // ROOM 302: LIVING ROOM (+TALISMAN)
            // Pick up the talisman, and enter the storage room.
            progress = (
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__STORAGE_ROOM);
            break;
        case HOSPITAL_SPLITS_BASE + 2:
            // ROOM 302: STORAGE ROOM (-TALISMAN, -PLACARDS)
            // Use the talisman on the wall, and put the plates in the right
            // slots in the wall. Then enter the new hole.
            progress = (current.currentWorldId != WORLD_ROOM_302);
            break;
        case HOSPITAL_SPLITS_BASE + 3:
            // EMERGENCY ROOM
            // Skip cutscene.
            progress = (
                old.currentWorldId == WORLD_HOSPITAL &&
                old.currentRoomId == HOSPITAL__EMERGENCY_ROOM_A &&
                current.currentWorldId == WORLD_HOSPITAL &&
                current.currentRoomId == HOSPITAL__LOBBY);
            break;
        case HOSPITAL_SPLITS_BASE + 4:
            // 1F LOBBY
            // Move towards stairwell, skip another cutscene, enter stairwell.
            progress = (
                current.currentWorldId == WORLD_HOSPITAL &&
                current.currentRoomId == HOSPITAL__STAIRWELL);
            break;
        case HOSPITAL_SPLITS_BASE + 5:
            // STAIRWELL
            // Go up the stairs and enter RNG hallway.
            progress = (
                current.currentWorldId == WORLD_HOSPITAL &&
                current.currentRoomId == HOSPITAL__RNG_HALLWAY);
            break;
        case HOSPITAL_SPLITS_BASE + 6:
            // 2F HALLWAY (ELEVATOR BUTTON)
            // Push elevator button, and start searching the rooms for Eileen.
            // WARNING: We split upon checking the first RNG room.
            progress = (
                old.currentWorldId == WORLD_HOSPITAL &&
                old.currentRoomId == HOSPITAL__RNG_HALLWAY &&
                current.currentWorldId == WORLD_HOSPITAL &&
                current.currentRoomId != HOSPITAL__RNG_HALLWAY);
            break;
        case HOSPITAL_SPLITS_BASE + 7:
            // FINDING KEY (+KEY)
            // Find key in one of the RNG hallway's rooms.
            // WARNING: WE SPLIT AFTER FINDING KEY TO PREVENT RUNNERS FROM
            // KNOWING THAT THEY FOUND THE KEY WHILE ROOM IS STILL LOADING.
            progress = (
                old.currentWorldId == WORLD_HOSPITAL &&
                old.currentRoomId == HOSPITAL__PR_HOSPITAL_KEY &&
                current.currentWorldId == WORLD_HOSPITAL &&
                current.currentRoomId == HOSPITAL__RNG_HALLWAY);
            break;
        case HOSPITAL_SPLITS_BASE + 8:
            // EILEEN'S ROOM (+EILEEN)
            // Find Eileen in one of the RNG hallway's rooms.
            // WARNING: WE SPLIT AFTER FINDING EILEEN TO PREVENT RUNNERS FROM
            // KNOWING THAT THEY FOUND EILEEN WHILE ROOM IS STILL LOADING.
            progress = (
                old.currentWorldId == WORLD_HOSPITAL &&
                old.currentRoomId == HOSPITAL__PR_EILEENS_ROOM &&
                current.currentWorldId == WORLD_HOSPITAL &&
                current.currentRoomId == HOSPITAL__RNG_HALLWAY);
            break;
        case HOSPITAL_SPLITS_BASE + 9:
            // 2F HALLWAY
            // Run down the hallway with Eileen and enter stairwell.
            progress = (
                current.currentWorldId == WORLD_HOSPITAL &&
                current.currentRoomId == HOSPITAL__STAIRWELL);
            break;
        case HOSPITAL_SPLITS_BASE + 10:
            // STAIRWELL
            // Run down stairs and enter lobby.
            progress = (
                current.currentWorldId == WORLD_HOSPITAL &&
                current.currentRoomId == HOSPITAL__LOBBY);
            break;
        case HOSPITAL_SPLITS_BASE + 11:
            // 1F LOBBY
            // Enter wash room.
            progress = (
                current.currentWorldId == WORLD_HOSPITAL &&
                current.currentRoomId == HOSPITAL__WASH_ROOM);
            break;
        case HOSPITAL_SPLITS_BASE + 12:
            // WASH ROOM
            // Enter hole.
            progress = (current.currentWorldId != WORLD_HOSPITAL);
            break;
        case HOSPITAL_SPLITS_BASE + 13:
            // ROOM 302: BEDROOM
            // Move to the living room.
            progress = (
                old.currentWorldId == WORLD_ROOM_302 &&
                old.currentRoomId == ROOM_302__BEDROOM &&
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__LIVING_ROOM);
            break;
        case HOSPITAL_SPLITS_BASE + 14:
            // ROOM 302: LIVING ROOM (+KEY)
            // Retrieve the key from the letter under the door, and enter the
            // storage room.
            progress = (
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__STORAGE_ROOM);
            break;
        case HOSPITAL_SPLITS_BASE + 15:
            // ROOM 302: STORAGE ROOM
            // Enter the hole.
            progress = (current.currentWorldId != WORLD_ROOM_302);
            break;
        case HOSPITAL_SPLITS_BASE + 16:
            // WASH ROOM
            // Leave room.
            progress = (
                old.currentWorldId == WORLD_HOSPITAL &&
                old.currentRoomId == HOSPITAL__WASH_ROOM &&
                current.currentWorldId == WORLD_HOSPITAL &&
                current.currentRoomId == HOSPITAL__LOBBY);
            break;
        case HOSPITAL_SPLITS_BASE + 17:
            // 1F LOBBY
            // Unlock door behind elevator and enter.
            progress = (
                current.currentWorldId == WORLD_HOSPITAL &&
                current.currentRoomId == HOSPITAL__LONG_STAIRS_DOWN);
            break;
        case HOSPITAL_SPLITS_BASE + 18:
            // LONG DESCENDING STAIRCASE
            // Go down the stairs and go through the door with Eileen.
            progress = (current.currentWorldId != WORLD_HOSPITAL);
            break;

        ///////////////////////////////////////////////////////////////////////
        // RETURN TO SUBWAY WORLD
        ///////////////////////////////////////////////////////////////////////

        case SUBWAY_2_SPLITS_BASE + 0:
            // STAIRS TO SUBWAY WORLD
            // Run down the stairs and enter the door.
            progress = (current.currentWorldId != WORLD_SPIRAL_STAIRCASE);
            break;
        case SUBWAY_2_SPLITS_BASE + 1:
            // GENERATOR ROOM
            // Leave the room.
            progress = (
                old.currentWorldId == WORLD_SUBWAY &&
                old.currentRoomId == SUBWAY__GENERATOR_ROOM &&
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__ENTRANCE_NORTH);
            break;
        case SUBWAY_2_SPLITS_BASE + 2:
            // ENTRANCE
            // Move to the hallway.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__HALLWAY);
            break;
        case SUBWAY_2_SPLITS_BASE + 3:
            // HALLWAY
            // Enter the women's bathroom.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__BATHROOMS);
            break;
        case SUBWAY_2_SPLITS_BASE + 4:
            // WOMEN'S BATHROOM
            // Enter the hole.
            progress = (current.currentWorldId != WORLD_SUBWAY);
            break;
        case SUBWAY_2_SPLITS_BASE + 5:
            // ROOM 302: BEDROOM
            // Move to the living room.
            progress = (
                old.currentWorldId == WORLD_ROOM_302 &&
                old.currentRoomId == ROOM_302__BEDROOM &&
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__LIVING_ROOM);
            break;
        case SUBWAY_2_SPLITS_BASE + 6:
            // ROOM 302: LIVING ROOM (+TOY KEY)
            // Pick up the toy key from the letter, and enter the storage room.
            progress = (
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__STORAGE_ROOM);
            break;
        case SUBWAY_2_SPLITS_BASE + 7:
            // ROOM 302: STORAGE ROOM
            // Enter the hole.
            progress = (current.currentWorldId != WORLD_ROOM_302);
            break;
        case SUBWAY_2_SPLITS_BASE + 8:
            // WOMEN'S BATHROOM
            // Leave the room.
            progress = (
                old.currentWorldId == WORLD_SUBWAY &&
                old.currentRoomId == SUBWAY__BATHROOMS &&
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__HALLWAY);
            break;
        case SUBWAY_2_SPLITS_BASE + 9:
            // HALLWAY
            // Go to the turnstiles.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__TURNSTILES_2);
            break;
        case SUBWAY_2_SPLITS_BASE + 10:
            // TURNSTILES (-EILEEN)
            // Enter turnstiles, but make sure to leave Eileen behind.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__B2_PASSAGE);
            break;
        case SUBWAY_2_SPLITS_BASE + 11:
            // B2 PASSAGE
            // Go down to the platform.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__B3_PLATFORM_WEST_OPEN);
            break;
        case SUBWAY_2_SPLITS_BASE + 12:
            // WORLD_SUBWAY PLATFORM A
            // Enter the southern section of the subway carts.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__TRAIN_CARTS_SOUTH);
            break;
        case SUBWAY_2_SPLITS_BASE + 13:
            // WORLD_SUBWAY CART SOUTH (+TOY COIN)
            // Open the toy box with the toy key, and leave.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__B3_PLATFORM_WEST_OPEN);
            break;
        case SUBWAY_2_SPLITS_BASE + 14:
            // WORLD_SUBWAY PLATFORM A
            // Enter the maintenance room.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__MAINTENANCE_ROOM_WEST);
            break;
        case SUBWAY_2_SPLITS_BASE + 15:
            // MAINTENANCE ROOM B
            // Go down the ladder.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__MAINTENANCE_TUNNEL);
            break;
        case SUBWAY_2_SPLITS_BASE + 16:
            // MANTENANCE TUNNEL
            // Enter the other maintenance room.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__MAINTENANCE_ROOM_EAST);
            break;
        case SUBWAY_2_SPLITS_BASE + 17:
            // MAINTENANCE ROOM A
            // Enter the hole.
            progress = (current.currentWorldId != WORLD_SUBWAY);
            break;
        case SUBWAY_2_SPLITS_BASE + 18:
            // ROOM 302: BEDROOM
            // Move to the living room.
            progress = (
                old.currentWorldId == WORLD_ROOM_302 &&
                old.currentRoomId == ROOM_302__BEDROOM &&
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__LIVING_ROOM);
            break;
        case SUBWAY_2_SPLITS_BASE + 19:
            // ROOM 302: LIVING ROOM
            // Leave all items behind the box, except the gun and the coin.
            // Wash the coin in the sink, and enter the storage room.
            progress = (
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__STORAGE_ROOM);
            break;
        case SUBWAY_2_SPLITS_BASE + 20:
            // ROOM 302: STORAGE ROOM
            // Enter the hole.
            progress = (current.currentWorldId != WORLD_ROOM_302);
            break;
        case SUBWAY_2_SPLITS_BASE + 21:
            // MAINTENANCE ROOM A
            // Go down the ladder.
            progress = (
                old.currentWorldId == WORLD_SUBWAY &&
                old.currentRoomId == SUBWAY__MAINTENANCE_ROOM_EAST &&
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__MAINTENANCE_TUNNEL);
            break;
        case SUBWAY_2_SPLITS_BASE + 22:
            // MAINTENANCE TUNNEL
            // Go down to the subway platform.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__B4_PLATFORM);
            break;
        case SUBWAY_2_SPLITS_BASE + 23:
            // PLATFORM 3
            // Move to the escalators.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__ESCALATORS);
            break;
        case SUBWAY_2_SPLITS_BASE + 24:
            // ESCALATORS
            // Go up the escalators, and kill the second and third wallmen with
            // the gun.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__B2_PASSAGE);
            break;
        case SUBWAY_2_SPLITS_BASE + 25:
            // B2 PASSAGE
            // Go up to the stairs to the ticket office.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__TURNSTILES_2);
            break;
        case SUBWAY_2_SPLITS_BASE + 26:
            // TURNSTILES (+TICKET)
            // Pick up the commuter's ticket, and go through the turnstiles,
            // all the way to the other side of the B2 Passage. Make sure that
            // you don't take Eileen with you.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__B2_PASSAGE);
            break;
        case SUBWAY_2_SPLITS_BASE + 27:
            // B2 PASSAGE
            // Go down to the subway platform.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__B3_PLATFORM_WEST_OPEN);
            break;
        case SUBWAY_2_SPLITS_BASE + 28:
            // PLATFORM A (+KEY)
            // Use the washed coin to get the key from the vending machine.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__B2_PASSAGE);
            break;
        case SUBWAY_2_SPLITS_BASE + 29:
            // PASSAGE
            // Go back up the stairs to the turnstiles.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__TURNSTILES_2);
            break;
        case SUBWAY_2_SPLITS_BASE + 30:
            // TURNSTILES (+EILEEN)
            // Go through the turnstiles on the other side with Eileen, and use
            // the key to go inside the ticket office.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__TICKET_OFFICE_INSIDE);
            break;
        case SUBWAY_2_SPLITS_BASE + 31:
            // INSIDE TICKET OFFICE (+HANDLE)
            // Pick up the train handle, and go back outside.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__TURNSTILES_2);
            break;
        case SUBWAY_2_SPLITS_BASE + 32:
            // TURNSTILES
            // Go down the stairs.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__B2_PASSAGE);
            break;
        case SUBWAY_2_SPLITS_BASE + 33:
            // B2 PASSAGE
            // Move to the escalators.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__ESCALATORS);
            break;
        case SUBWAY_2_SPLITS_BASE + 34:
            // ESCALATORS (USE BULLETS)
            // Use the rest of the bullets left to stun the first wallman and
            // go down with Eileen.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__B4_PLATFORM);
            break;
        case SUBWAY_2_SPLITS_BASE + 35:
            // B4 SUBWAY PLATFORM (MOVE TRAIN)
            // Use the handle to move the train.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__B4_PLATFORM_MOVED_TRAIN);
            break;
        case SUBWAY_2_SPLITS_BASE + 36:
            // B4 SUBWAY PLATFORM (TRAIN MOVED)
            // Leave the train and enter the door.
            progress = (
                current.currentWorldId == WORLD_SUBWAY &&
                current.currentRoomId == SUBWAY__ENCOUNTER_WITH_WALTER);
            break;
        case SUBWAY_2_SPLITS_BASE + 37:
            // ENCOUNTER WITH WALTER
            // Go through the door.
            progress = (current.currentWorldId != WORLD_SUBWAY);
            break;

        ///////////////////////////////////////////////////////////////////////
        // RETURN TO WORLD_FOREST WORLD
        ///////////////////////////////////////////////////////////////////////

        case FOREST_2_SPLITS_BASE + 0:
            // STAIRS TO WORLD_FOREST WORLD
            // Run down the stairs and enter the door.
            progress = (current.currentWorldId != WORLD_SPIRAL_STAIRCASE);
            break;
        case FOREST_2_SPLITS_BASE + 1:
            // GRAVEYARD (+TORCH, LIT)
            // Pick up the torch, and light it up.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__PATH_TO_GRAVEYARD_B);
            break;
        case FOREST_2_SPLITS_BASE + 2:
            // PATH TO GRAVEYARD B (+DOLL PART)
            // Retrieve the doll part from the well, and continue going
            // towards Wish House.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__PATH_TO_GRAVEYARD_A);
            break;
        case FOREST_2_SPLITS_BASE + 3:
            // PATH TO GRAVEYARD A
            // Go to Wish House.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__WISH_HOUSE_COURTYARD_2);
            break;
        case FOREST_2_SPLITS_BASE + 4:
            // WISH HOUSE COURTYARD (-EILEEN)
            // Leave behind Eileen, and enter the south east door.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__PATH_TO_WISH_HOUSE_B);
            break;
        case FOREST_2_SPLITS_BASE + 5:
            // PATH TO WISH HOUSE B
            // Enter the gate on the other side.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__PATH_OF_ETERNAL_MIST);
            break;
        case FOREST_2_SPLITS_BASE + 6:
            // PATH OF ETERNAL MIST
            // Enter the gate on the other side.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__TREE_ROOT);
            break;
        case FOREST_2_SPLITS_BASE + 7:
            // PATH WITH WEIRD TREE (+SILVER BULLET, LOAD)
            // Pick up the silver bullet, load the gun, and go further.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__DEAD_END);
            break;
        case FOREST_2_SPLITS_BASE + 8:
            // DEAD END (+DOLL PART)
            // Light up the torch, pick up the doll part, and go back.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__TREE_ROOT);
            break;
        case FOREST_2_SPLITS_BASE + 9:
            // PATH WITH WEIRD TREE
            // Move back to Wish House.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__PATH_OF_ETERNAL_MIST);
            break;
        case FOREST_2_SPLITS_BASE + 10:
            // PATH OF ETERNAL MIST
            // Move back to Wish House.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__PATH_TO_WISH_HOUSE_B);
            break;
        case FOREST_2_SPLITS_BASE + 11:
            // PATH TO WISH HOUSE B
            // Move back to Wish House.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__WISH_HOUSE_COURTYARD_2);
            break;
        case FOREST_2_SPLITS_BASE + 12:
            // WISH HOUSE COURTYARD
            // Enter the north east gate that leads to the cliffs. Make sure
            // that Eileen doesn't follow you.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__PATH_TO_WISH_HOUSE_A);
            break;
        case FOREST_2_SPLITS_BASE + 13:
            // PATH TO WISH HOUSE A
            // Enter the gate on the other side.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__SPIKE_TRAP);
            break;
        case FOREST_2_SPLITS_BASE + 14:
            // SPIKE TRAP
            // Enter the gate on the other side.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__MOTHER_STONE);
            break;
        case FOREST_2_SPLITS_BASE + 15:
            // MOTHER STONE
            // Enter the gate on the other side.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__CAR);
            break;
        case FOREST_2_SPLITS_BASE + 16:
            // CAR
            // Enter the gate on the other side.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__FACTORY_WEST);
            break;
        case FOREST_2_SPLITS_BASE + 17:
            // FACTORY B
            // Enter the gate on the other side.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__FACTORY_EAST);
            break;
        case FOREST_2_SPLITS_BASE + 18:
            // FACTORY A
            // Enter the gate on the other side.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__PATH_TO_FACTORY);
            break;
        case FOREST_2_SPLITS_BASE + 19:
            // PATH TO FACTORY (LIT)
            // Light up the torch, and go through the gate on the other side.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__CLIFF);
            break;
        case FOREST_2_SPLITS_BASE + 20:
            // CLIFF (+DOLL PART)
            // Retrieve the doll part, and leave again.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__PATH_TO_FACTORY);
            break;
        case FOREST_2_SPLITS_BASE + 21:
            // PATH TO FACTORY
            // Enter the factory.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__FACTORY_EAST);
            break;
        case FOREST_2_SPLITS_BASE + 22:
            // FACTORY A
            // Continue to go back to Wish House.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__FACTORY_WEST);
            break;
        case FOREST_2_SPLITS_BASE + 23:
            // FACTORY B
            // Continue to go back to Wish House.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__CAR);
            break;
        case FOREST_2_SPLITS_BASE + 24:
            // CAR
            // Continue to go back to Wish House.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__MOTHER_STONE);
            break;
        case FOREST_2_SPLITS_BASE + 25:
            // MOTHER STONE (LIT)
            // Light up the torch, and go through the gate on the other side.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__SPIKE_TRAP);
            break;
        case FOREST_2_SPLITS_BASE + 26:
            // SPIKE TRAP (+DOLL PART)
            // Retrieve the doll part from the well, and continue to go forward
            // towards Wish House.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__PATH_TO_WISH_HOUSE_A);
            break;
        case FOREST_2_SPLITS_BASE + 27:
            // PATH TO WISH HOUSE A
            // Enter the door to Wish House's courtyard.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__WISH_HOUSE_COURTYARD_2);
            break;
        case FOREST_2_SPLITS_BASE + 28:
            // WISH HOUSE COURTYARD
            // Enter the door that leads to the coal mines. Make sure that
            // Eileen stays behind.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__PATH_TO_MINES);
            break;
        case FOREST_2_SPLITS_BASE + 29:
            // PATH TO MINES
            // Enter the coal mines.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__MINE);
            break;
        case FOREST_2_SPLITS_BASE + 30:
            // MINES (+PICKAXE)
            // Pick up the pickaxe, and continue further.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__LAKE);
            break;
        case FOREST_2_SPLITS_BASE + 31:
            // TOLUCA LAKE (+MEDALLION, LIT)
            // Approach the medallion, skip the cutscene, pick up the medallion,
            // light up the torch and go back.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__MINE);
            break;
        case FOREST_2_SPLITS_BASE + 32:
            // MINES
            // Keep going back to Wish House.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__PATH_TO_MINES);
            break;
        case FOREST_2_SPLITS_BASE + 33:
            // PATH TO MINES (DOLL PART)
            // Retrieve the doll part from the well, and go back to Wish House.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__WISH_HOUSE_COURTYARD_2);
            break;
        case FOREST_2_SPLITS_BASE + 34:
            // WISH HOUSE COURTYARD (+Eileen, -Doll Parts)
            // Complete the doll puzzle, and go down to the basement.
            progress = (
                current.currentWorldId == WORLD_FOREST &&
                current.currentRoomId == FOREST__WISH_HOUSE_BASEMENT);
            break;
        case FOREST_2_SPLITS_BASE + 35:
            // WISH HOUSE BASEMENT
            // Place the medallion in the socket, and go through the door.
            progress = (current.currentWorldId != WORLD_FOREST);
            break;

        ///////////////////////////////////////////////////////////////////////
        // RETURN TO WATER PRISON WORLD
        ///////////////////////////////////////////////////////////////////////

        case WATER_PRISON_2_SPLITS_BASE + 0:
            // STAIRS TO WATER WORLD
            // Run down the stairs and enter the door.
            progress = (
                old.currentWorldId == WORLD_SPIRAL_STAIRCASE &&
                old.currentRoomId == SPIRAL_STAIRCASE_TO_WATER_PRISON &&
                current.currentWorldId == WORLD_SPIRAL_STAIRCASE &&
                current.currentRoomId == SPIRAL_STAIRCASE_ABOVE_WATER_PRISON);
            break;
        case WATER_PRISON_2_SPLITS_BASE + 1:
            // ROOM ABOVE WATER PRISON WORLD
            // Enter the elevator.
            progress = (current.currentWorldId != WORLD_SPIRAL_STAIRCASE);
            break;
        case WATER_PRISON_2_SPLITS_BASE + 2:
            // INSIDE ROOFTOP WATER TANK
            // Leave the water tank.
            // WARNING: during the cutscene, the room identifier briefly is
            // the rooftop's room identifier, hence we should check that we
            // leave the water tank, going into the rooftop room
            progress = (
                old.currentWorldId == WORLD_WATER_PRISON &&
                old.currentRoomId == WATER_PRISON__INSIDE_WATER_TANK &&
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__ROOFTOP);
            break;
        case WATER_PRISON_2_SPLITS_BASE + 3:
            // ROOFTOP
            // Leave the rooftop.
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__OUTSIDE);
            break;
        case WATER_PRISON_2_SPLITS_BASE + 4:
            // PRISON EXTERIOR
            // Go down and wait for Eileen to catch up. Enter stairway access
            // with Eileen.
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__SPIRAL_STAIRWAY_ACCESS);
            break;
        case WATER_PRISON_2_SPLITS_BASE + 5:
            // STAIRWAY ACCESS (-EILEEN)
            // Go to far corner, bump into Eileen, and go outside on your own.
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__OUTSIDE);
            break;
        case WATER_PRISON_2_SPLITS_BASE + 6:
            // PRISON EXTERIOR
            // Go to 3rd floor.
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__3F_PRISON_HALLWAY);
            break;
        case WATER_PRISON_2_SPLITS_BASE + 7:
            // 3F HALLWAY
            // Enter the cell next to the broken water pipe.
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__3F_PRISON_CELL_F);
            break;
        case WATER_PRISON_2_SPLITS_BASE + 8:
            // 3F PRISON CELL
            // Jump down the hole.
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__2F_PRISON_CELL_H);
            break;
        case WATER_PRISON_2_SPLITS_BASE + 9:
            // 2F PRISON CELL
            // Jump down the hole.
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__1F_PRISON_CELL_D);
            break;
        case WATER_PRISON_2_SPLITS_BASE + 10:
            // 1F PRISON CELL
            // Jump down the hole.
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__KITCHEN);
            break;
        case WATER_PRISON_2_SPLITS_BASE + 11:
            // KITCHEN
            // Enter the murder room.
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__MURDER_ROOM);
            break;
        case WATER_PRISON_2_SPLITS_BASE + 12:
            // MURDER ROOM (+SHIRT)
            // Pick up the shirt, and leave the room.
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__KITCHEN);
            break;
        case WATER_PRISON_2_SPLITS_BASE + 13:
            // KITCHEN
            // Leave the room.
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__DINING_HALL);
            break;
        case WATER_PRISON_2_SPLITS_BASE + 14:
            // DINING_HALL
            // Leave the room.
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__BASEMENT_HALLWAY);
            break;
        case WATER_PRISON_2_SPLITS_BASE + 15:
            // BASEMENT HALLWAY
            // Leave the room.
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__SPIRAL_STAIRWAY);
            break;
        case WATER_PRISON_2_SPLITS_BASE + 16:
            // STAIRWAY
            // Go up the stairs using the ladders.
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__SPIRAL_STAIRWAY_ACCESS);
            break;
        case WATER_PRISON_2_SPLITS_BASE + 17:
            // STAIRWAY ACCESS
            // Enter the hole.
            progress = (current.currentWorldId != WORLD_WATER_PRISON);
            break;
        case WATER_PRISON_2_SPLITS_BASE + 18:
            // ROOM 302: BEDROOM
            // Leave the room.
            progress = (
                old.currentWorldId == WORLD_ROOM_302 &&
                old.currentRoomId == ROOM_302__BEDROOM &&
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__LIVING_ROOM);
            break;
        case WATER_PRISON_2_SPLITS_BASE + 19:
            // ROOM 302: LIVING ROOM
            // Enter the bathroom.
            progress = (
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__BATHROOM);
            break;
        case WATER_PRISON_2_SPLITS_BASE + 20:
            // ROOM 302: BATHROOM (WASH SHIRT)
            // Wash the shirt out, and leave the bathroom.
            progress = (
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__LIVING_ROOM);
            break;
        case WATER_PRISON_2_SPLITS_BASE + 21:
            // ROOM 302: LIVING ROOM
            // Drop everything in the box, and take out the rusty axe, pickaxe,
            // the gun with one silver bullet, 12 bullets, and the sword.
            // Enter the storage room.
            progress = (
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__STORAGE_ROOM);
            break;
        case WATER_PRISON_2_SPLITS_BASE + 22:
            // ROOM 302: STORAGE ROOM
            // Enter the hole.
            progress = (current.currentWorldId != WORLD_ROOM_302);
            break;
        case WATER_PRISON_2_SPLITS_BASE + 23:
            // STAIRCASE ACCESS
            // Enter staircase with Eileen.
            progress = (
                old.currentWorldId == WORLD_WATER_PRISON &&
                old.currentRoomId == WATER_PRISON__SPIRAL_STAIRWAY_ACCESS &&
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__SPIRAL_STAIRWAY);
            break;
        case WATER_PRISON_2_SPLITS_BASE + 24:
            // SPIRAL STAIRCASE
            // Shoot the ghost with the silver bullet, pin him down with sword,
            // pick up the key for the generator room, and go down the stairs.
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__WATERWHEEL_ROOM);
            break;
        case WATER_PRISON_2_SPLITS_BASE + 25:
            // WATERWHEEL ROOM
            // Enter the generator room with Eileen.
            progress = (
                current.currentWorldId == WORLD_WATER_PRISON &&
                current.currentRoomId == WATER_PRISON__GENERATOR_ROOM);
            break;
        case WATER_PRISON_2_SPLITS_BASE + 26:
            // BEYOND WATERWHEEL ROOM
            // Enter the door at the end of the room with Eileen.
            progress = (current.currentWorldId != WORLD_WATER_PRISON);
            break;

        ///////////////////////////////////////////////////////////////////////
        // RETURN TO BUILDING WORLD
        ///////////////////////////////////////////////////////////////////////

        case BUILDING_2_SPLITS_BASE + 0:
            // STAIRS TO BUILDING WORLD
            // Run down the stairs and enter the door.
            progress = (current.currentWorldId != WORLD_SPIRAL_STAIRCASE);
            break;
        case BUILDING_2_SPLITS_BASE + 1:
            // PARKING LOT
            // Run past the ghost, and enter the elevator.
            progress = (
                old.currentWorldId == WORLD_BUILDING &&
                old.currentRoomId == BUILDING__PARKING_LOT &&
                current.currentWorldId == WORLD_BUILDING &&
                current.currentRoomId == BUILDING__INSIDE_ELEVATORS);
            break;
        case BUILDING_2_SPLITS_BASE + 2:
            // INSIDE ELEVATORS (GO DOWN)
            // Go down with the elevator, and exit elevator.
            progress = (
                current.currentWorldId == WORLD_BUILDING &&
                current.currentRoomId == BUILDING__ELEVATOR_ACCESS_BOTTOM);
            break;
        case BUILDING_2_SPLITS_BASE + 3:
            // ELEVATOR ACCESS (+BULLETS, -EILEEN)
            // Pick up bullets, bump into Eileen, enter left elevator alone.
            progress = (
                current.currentWorldId == WORLD_BUILDING &&
                current.currentRoomId == BUILDING__INSIDE_ELEVATORS);
            break;
        case BUILDING_2_SPLITS_BASE + 4:
            // INSIDE ELEVATORS
            // Go down the ladder in the back.
            progress = (
                current.currentWorldId == WORLD_BUILDING &&
                current.currentRoomId == BUILDING__SHOWER_ROOM);
            break;
        case BUILDING_2_SPLITS_BASE + 5:
            // SHOWER ROOM
            // Move through the fungus and go up the stairs.
            progress = (
                current.currentWorldId == WORLD_BUILDING &&
                current.currentRoomId == BUILDING__DANGER_ALLEYWAY_1);
            break;
        case BUILDING_2_SPLITS_BASE + 6:
            // DANGEROUS ALLEYWAY A
            // Run down the alleyway.
            progress = (
                current.currentWorldId == WORLD_BUILDING &&
                current.currentRoomId == BUILDING__DANGER_ALLEYWAY_2);
            break;
        case BUILDING_2_SPLITS_BASE + 7:
            // DANGEROUS ALLEYWAY B (+EILEEN, LOAD GUN)
            // Wait at the door for Eileen to catch up, then enter fan room.
            progress = (
                current.currentWorldId == WORLD_BUILDING &&
                current.currentRoomId == BUILDING__FAN_ROOM);
            break;
        case BUILDING_2_SPLITS_BASE + 8:
            // FAN ROOM
            // Go down the stairs, and enter the door.
            progress = (
                current.currentWorldId == WORLD_BUILDING &&
                current.currentRoomId == BUILDING__STAIRWELL_B);
            break;
        case BUILDING_2_SPLITS_BASE + 9:
            // STAIRCASE
            // Enter the rusty axe bar.
            progress = (
                current.currentWorldId == WORLD_BUILDING &&
                current.currentRoomId == BUILDING__RUSTY_AXE_BAR);
            break;
        case BUILDING_2_SPLITS_BASE + 10:
            // RUSTY AXE BAR
            // Move to the door, and enter the code 4890, and go through.
            progress = (
                current.currentWorldId == WORLD_BUILDING &&
                current.currentRoomId == BUILDING__STAIRWELL_D_2);
            break;
        case BUILDING_2_SPLITS_BASE + 11:
            // STAIRCASE (HEAL)
            // Run down the stairs and enter the door with Eileen. Heal while
            // waiting for Eileen to come down.
            progress = (current.currentWorldId != WORLD_BUILDING);
            break;

        ///////////////////////////////////////////////////////////////////////
        // ONE TRUTH
        ///////////////////////////////////////////////////////////////////////

        case ONE_TRUTH_SPLITS_BASE + 0:
            // ONE TRUTH
            // Defeat The One Truth.
            progress = (
                old.currentWorldId == WORLD_SPIRAL_STAIRCASE &&
                old.currentRoomId == SPIRAL_STAIRCASE_THE_ONE_TRUTH_ROOM &&
                current.currentWorldId == WORLD_SPIRAL_STAIRCASE &&
                current.currentRoomId == SPIRAL_STAIRCASE_TO_ROOM_302);
            break;

        ///////////////////////////////////////////////////////////////////////
        // PAST ROOM 302
        ///////////////////////////////////////////////////////////////////////

        case PAST_ROOM_302_SPLITS_BASE + 0:
            // STAIRS TO PAST ROOM 302
            // Run down the stairs and enter the door.
            progress = (current.currentWorldId != WORLD_SPIRAL_STAIRCASE);
            break;
        case PAST_ROOM_302_SPLITS_BASE + 1:
            // LIVING ROOM
            // Pick up notes on table, and move to bedroom.
            progress = (
                old.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                old.currentRoomId == OUTSIDE_ROOM_302__PAST_LIVING_ROOM &&
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__PAST_BEDROOM);
            break;
        case PAST_ROOM_302_SPLITS_BASE + 2:
            // BEDROOM
            // Pick up all the notes, and leave bedroom.
            progress = (
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__PAST_LIVING_ROOM);
            break;
        case PAST_ROOM_302_SPLITS_BASE + 3:
            // LIVING ROOM (+PICKAXE)
            // Go down to trigger the cutscene, skip cutscene, pick up pickaxe,
            // and enter hole.
            progress = (current.currentWorldId != WORLD_OUTSIDE_ROOM_302);
            break;
        case PAST_ROOM_302_SPLITS_BASE + 4:
            // ROOM 302: BEDROOM
            // Leave room.
            progress = (
                old.currentWorldId == WORLD_ROOM_302 &&
                old.currentRoomId == ROOM_302__BEDROOM &&
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__LIVING_ROOM);
            break;
        case PAST_ROOM_302_SPLITS_BASE + 5:
            // ROOM 302: LIVING ROOM
            // Use pickaxe on wall, and enter hole in the wall.
            progress = (
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__HIDDEN_BACK_ROOM);
            break;
        case PAST_ROOM_302_SPLITS_BASE + 6:
            // ROOM 302: HIDDEN BACK ROOM (+KEY)
            // Pick up the keys of liberation, and leave.
            progress = (
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__LIVING_ROOM);
            break;
        case PAST_ROOM_302_SPLITS_BASE + 7:
            // ROOM 302: LIVING ROOM
            // Run to the door and leave room 302.
            progress = (current.currentWorldId != WORLD_ROOM_302);
            break;

        ///////////////////////////////////////////////////////////////////////
        // OUTSIDE ROOM 302
        ///////////////////////////////////////////////////////////////////////

        case OUTSIDE_ROOM_302_SPLITS_BASE + 0:
            // 3F HALLWAY
            // Enter room 301.
            progress = (
                old.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                old.currentRoomId == OUTSIDE_ROOM_302__3F_HALLWAY &&
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__ROOM_201_301);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 1:
            // ROOM 201/301
            // Go down the stairs, and leave the room.
            progress = (
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__2F_HALLWAY_EAST);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 2:
            // 2F EAST HALLWAY
            // Enter room 202.
            progress = (
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__ROOM_202);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 3:
            // ROOM 202
            // Move to gap in the wall and go through.
            progress = (
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__ROOM_203);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 4:
            // ROOM 203
            // Leave room.
            progress = (
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__2F_HALLWAY_EAST);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 5:
            // 2F HALLWAY EAST
            // Leave the hallway.
            progress = (
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__CENTRAL_STAIRWAY);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 6:
            // MAIN HALL
            // Enter the hallway on the other side.
            progress = (
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__2F_HALLWAY_WEST);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 7:
            // 2F WEST HALLWAY
            // Enter room 206.
            progress = (
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__ROOM_206);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 8:
            // ROOM 206
            // Move to gap in the wall and go through.
            progress = (
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__ROOM_207);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 9:
            // ROOM 207
            // Leave room.
            progress = (
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__2F_HALLWAY_WEST);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 10:
            // 2F WEST HALLWAY
            // Go down the stairs.
            progress = (
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__1F_HALLWAY_WEST);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 11:
            // 1F WEST HALLWAY
            // Leave the hallway.
            progress = (
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__CENTRAL_STAIRWAY);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 12:
            // MAIN HALL
            // Move to the hallway on the other side.
            progress = (
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__1F_HALLWAY_EAST);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 13:
            // 1F EAST HALLWAY
            // Enter room 104.
            progress = (
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__ROOM_104);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 14:
            // ROOM 104
            // Touch body, and leave room.
            progress = (
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__1F_HALLWAY_EAST);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 15:
            // 1F HALLWAY EAST
            // Touch body in corner of hallway, and enter room 103.
            progress = (
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__ROOM_103);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 16:
            // ROOM 103
            // Touch body, and leave room.
            progress = (
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__1F_HALLWAY_EAST);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 17:
            // 1F HALLWAY EAST
            // Enter room 102.
            progress = (
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__ROOM_102);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 18:
            // ROOM 102
            // Touch body and leave room.
            progress = (
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__1F_HALLWAY_EAST);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 19:
            // 1F HALLWAY EAST
            // Touch body at the end of hallway, and enter room 101.
            progress = (
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__ROOM_101);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 20:
            // ROOM 101
            // Touch body, and leave room.
            progress = (
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__1F_HALLWAY_EAST);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 21:
            // 1F HALLWAY EAST
            // Leave hallway.
            progress = (
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__CENTRAL_STAIRWAY);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 22:
            // CENTRAL STAIRCASE
            // Skip cutscene, and enter other hallway.
            progress = (
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__1F_HALLWAY_WEST);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 23:
            // 1F HALLWAY WEST
            // Enter room 105 (superintendent's room).
            progress = (
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__ROOM_105);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 24:
            // ROOM 105
            // Pick up umbilical cord, skip cutscene, and leave room.
            progress = (
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__1F_HALLWAY_WEST);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 25:
            // 1F HALLWAY WEST
            // Skip cutscene, and run up the stairs.
            progress = (
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__2F_HALLWAY_WEST);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 26:
            // 2F HALLWAY WEST
            // Enter room 207.
            progress = (
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__ROOM_207);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 27:
            // ROOM 207
            // Move to gap in the wall and go through.
            progress = (
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__ROOM_206);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 28:
            // ROOM 206
            // Leave room.
            progress = (
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__2F_HALLWAY_WEST);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 29:
            // 2F WEST HALLWAY
            // Leave hallway.
            progress = (
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__CENTRAL_STAIRWAY);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 30:
            // MAIN HALL
            // Enter hallway on the other side.
            progress = (
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__2F_HALLWAY_EAST);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 31:
            // 2F HALLWAY EAST
            // Enter room 203.
            progress = (
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__ROOM_203);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 32:
            // ROOM 203
            // Move to gap in the wall and go through.
            progress = (
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__ROOM_202);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 33:
            // ROOM 202
            // Leave room.
            progress = (
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__2F_HALLWAY_EAST);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 34:
            // 2F EAST HALLWAY
            // Enter room 201.
            progress = (
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__ROOM_201_301);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 35:
            // ROOM 201/301
            // Move up the stairs, and leave room.
            progress = (
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302 &&
                current.currentRoomId == OUTSIDE_ROOM_302__ROOM_201_301);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 36:
            // 3F HALLWAY
            // Enter room 302.
            progress = (
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__LIVING_ROOM);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 37:
            // ROOM 302: LIVING ROOM
            // Move to the room beyond the wall.
            progress = (
                current.currentWorldId == WORLD_ROOM_302 &&
                current.currentRoomId == ROOM_302__HIDDEN_BACK_ROOM);
            break;
        case OUTSIDE_ROOM_302_SPLITS_BASE + 38:
            // ROOM 302: HIDDEN BACK ROOM
            // Touch the black puddle at Walter's feet.
            progress = (current.currentWorldId != WORLD_ROOM_302);
            break;

        ///////////////////////////////////////////////////////////////////////
        // THE END
        ///////////////////////////////////////////////////////////////////////

        case THE_END_SPLITS_BASE + 0:
            // ABOVE RITUAL CHAMBER
            // Jump down the hole.
            progress = (
                old.currentWorldId == WORLD_THE_END &&
                old.currentRoomId == THE_END__ABOVE_RITUAL_ROOM &&
                current.currentWorldId == WORLD_THE_END &&
                current.currentRoomId == THE_END__BOSS_ROOM);
            break;
        case THE_END_SPLITS_BASE + 1:
            // CHAMBER OF THE 21 SACRAMENTS
            // Defeat Walter Sullivan.
            // WARNING: luckily, the room identifier changes after defeating
            // Walter, so we are able to do the final split easily.
            progress = (
                current.currentWorldId == WORLD_THE_END &&
                current.currentRoomId != THE_END__BOSS_ROOM);
            break;
        case THE_END_SPLITS_BASE + 2:
            // FINISHED
            // Enjoy the credits.
            progress = (0 == 1);
            break;

        ///////////////////////////////////////////////////////////////////////
        // THE END
        ///////////////////////////////////////////////////////////////////////

        default:
            print("Missing section: " + vars.currentSegment);
            break;
    }

    if (progress) {
        vars.currentSegment += 1;
    }

    return progress;
}

