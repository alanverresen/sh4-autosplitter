///////////////////////////////////////////////////////////////////////////////
// sh4.asl
///////////////////////////////////////////////////////////////////////////////

// VERSION 1.1.0

// This script is used by LiveSplit for the game "Silent Hill 4: The Room" to
// automatically split upon leaving each world in an NTSC-U Any% PC speedrun.


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
// PROBLEM: LOADING NEW WORLDS
// ---------------------------
// See room-based auto splitter for more information about this problem.
//
// We can't rely on checking that we go from one room to another when the world
// changes. However, this isn't a real problem, because we typically only deal
// with rooms that are otherwise unreachable, so we can simply check that we
// are unloading a certain room for the first visits to a world.
//
// For the later worlds, we can check that we leave the current world, and
// enter the spiral staircase. The only special case is The One Truth, where
// can apply the same strategy as earlier, and just check that we are leaving
// the room.
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
   vars.walterSplitPostponeFramesCounter = 0;
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
        vars.walterSplitPostponeFramesCounter = 0;
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


    ///////////////////////////////////////////////////////////////////////////
    // SPLIT GOALS
    ///////////////////////////////////////////////////////////////////////////

    bool progress = false;
    switch((int) vars.currentSegment)
    {
        case 0:
            // NIGTHMARE
            // Ends when the cutscene in the room plays, and game loads the
            // bedroom again. Detecting when to split like this fails, if
            // runner goes back to bedroom on their own.
            progress = (
                (
                    old.currentWorldId == WORLD_ROOM_302 &&
                    old.currentRoomId == ROOM_302__LIVING_ROOM
                ) && !(
                    current.currentWorldId == WORLD_ROOM_302 &&
                    current.currentRoomId == ROOM_302__LIVING_ROOM
                ));
            break;
        case 1:
            // ROOM 302
            // Ends when we reach the end of the hole for the first time.
            progress = (
                old.currentWorldId == WORLD_THE_HOLE &&
                current.currentWorldId != WORLD_THE_HOLE);
            break;
        case 2:
            // SUBWAY WORLD
            // Ends when the cutscene in ticket office ends.
            progress = (
                (
                    old.currentWorldId == WORLD_SUBWAY &&
                    old.currentRoomId == SUBWAY__TICKET_OFFICE_INSIDE
                ) && !(
                    current.currentWorldId == WORLD_SUBWAY &&
                    current.currentRoomId == SUBWAY__TICKET_OFFICE_INSIDE
                ));
            break;
        case 3:
            // FOREST WORLD
            // Ends when the cutscene at altar ends.
            progress = (
                (
                    old.currentWorldId == WORLD_FOREST &&
                    old.currentRoomId == FOREST__WISH_HOUSE_ALTAR
                ) && !(
                    current.currentWorldId == WORLD_FOREST &&
                    current.currentRoomId == FOREST__WISH_HOUSE_ALTAR
                ));
            break;
        case 4:
            // WATER PRISON WORLD
            // Ends when the cutscene in murder room ends.
            progress = (
                (
                    old.currentWorldId == WORLD_WATER_PRISON &&
                    old.currentRoomId == WATER_PRISON__MURDER_ROOM
                ) && !(
                    current.currentWorldId == WORLD_WATER_PRISON &&
                    current.currentRoomId == WATER_PRISON__MURDER_ROOM
                ));
            break;
        case 5:
            // BUILDING WORLD
            // Ends when the cutscene in room 207 ends.
            progress = ((
                    old.currentWorldId == WORLD_BUILDING &&
                    old.currentRoomId == BUILDING__ROOM_207
                ) && !(
                    current.currentWorldId == WORLD_BUILDING &&
                    current.currentRoomId == BUILDING__ROOM_207
                ));
            break;
        case 6:
            // APARTMENT WORLD
            // Ends when the cutscene in Eileen's room (303) ends.
            progress = ((
                    old.currentWorldId == WORLD_APARTMENT &&
                    old.currentRoomId == APARTMENT__ROOM_303
                ) && !(
                    current.currentWorldId == WORLD_APARTMENT &&
                    current.currentRoomId == APARTMENT__ROOM_303
                ));
            break;
        case 7:
            // HOSPITAL WORLD
            // Ends when we leave hospital world and enter spiral staircase.
            progress = (
                old.currentWorldId == WORLD_HOSPITAL &&
                current.currentWorldId == WORLD_SPIRAL_STAIRCASE);
            break;
        case 8:
            // RETURN TO SUBWAY WORLD
            // Ends when we leave subway world and enter spiral staircase.
            progress = (
                old.currentWorldId == WORLD_SUBWAY &&
                current.currentWorldId == WORLD_SPIRAL_STAIRCASE);
            break;
        case 9:
            // RETURN TO FOREST WORLD
            // Ends when we leave subway world and enter spiral staircase.
            progress = (
                old.currentWorldId == WORLD_FOREST &&
                current.currentWorldId == WORLD_SPIRAL_STAIRCASE);
            break;
        case 10:
            // RETURN TO WATER PRISON WORLD
            // Ends when we leave water prison world and enter spiral staircase.
            progress = (
                old.currentWorldId == WORLD_WATER_PRISON &&
                current.currentWorldId == WORLD_SPIRAL_STAIRCASE);
            break;
        case 11:
            // RETURN TO BUILDING WORLD
            // Ends when we leave building world and enter One Truth's room,
            // which is programmed to be in the same world as spiral staircase.
            progress = (
                old.currentWorldId == WORLD_BUILDING &&
                current.currentWorldId == WORLD_SPIRAL_STAIRCASE);
            break;
        case 12:
            // BOSS: THE ONE TRUTH
            // Ends when we leave the One Truth's room.
            progress = ((
                    old.currentWorldId == WORLD_SPIRAL_STAIRCASE &&
                    old.currentRoomId == SPIRAL_STAIRCASE_THE_ONE_TRUTH_ROOM
                ) && !(
                    current.currentWorldId == WORLD_SPIRAL_STAIRCASE &&
                    current.currentRoomId == SPIRAL_STAIRCASE_THE_ONE_TRUTH_ROOM
                ));
            break;
        case 13:
            // PAST ROOM 302
            // Ends when we leave room 302 and enter world outside room 302.
            progress = (
                old.currentWorldId == WORLD_ROOM_302 &&
                current.currentWorldId == WORLD_OUTSIDE_ROOM_302);
            break;
        case 14:
            // OUTSIDE ROOM 302
            // Ends when we leave room 302, and enter the 'The End'.
            progress = (
                old.currentWorldId == WORLD_ROOM_302 &&
                current.currentWorldId == WORLD_THE_END);
            break;
        case 15:
            // BOSS: WALTER SULLIVAN
            // WARNING: luckily, the room identifier changes after defeating
            // Walter, so we are able to do the final split easily.            
            progress = (
                old.currentWorldId == WORLD_THE_END &&
                old.currentRoomId == THE_END__BOSS_ROOM &&
                current.currentWorldId == WORLD_THE_END &&
                current.currentRoomId != THE_END__BOSS_ROOM);
            
            // ----------------------------------------------------------------
            // BUG FIX #1
            // ----------------------------------------------------------------
            //
            // [PROBLEM]
            // At the beginning of the last cutscene, the ingame timer resumes
            // and runs for another half second or so. This time needs to be
            // added to the game's timer.
            //
            // [FIX]
            // We overwrite the local progress variable unless we have counted
            // that enough frames have past since the room identifiers have
            // changed to be sure that the timer has completely stopped.
            //
            // ----------------------------------------------------------------

            if (progress) {
                // only executed when the room identifiers just changed
                progress = false;
                vars.walterSplitPostponeFramesCounter = 1;
            }
            else if (vars.walterSplitPostponeFramesCounter < 600) {
                // executed until enough frames have been counted
                progress = false;
                vars.walterSplitPostponeFramesCounter += 1;
            }
            else {
                // executed when enough frames have been counted
                progress = true;
                vars.walterSplitPostponeFramesCounter = 0;
            }

            // ----------------------------------------------------------------
            // END OF BUG FIX #1
            // ----------------------------------------------------------------
            
            break;
        case 16:
            // FINISHED
            // Enjoy the credits.
            progress = (0 == 1);
            break;        
        default:
            print("Missing section: " + vars.currentSegment);
            break;
    }

    if (progress) {
        vars.currentSegment += 1;
    }

    return progress;
}

