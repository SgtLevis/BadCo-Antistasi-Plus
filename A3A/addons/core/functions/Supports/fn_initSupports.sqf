

// Used for creating unique support and marker names
A3A_supportCount = 0;
A3A_supportMarkerCount = 0;

// Array of active/recent supports
// used to limit resource spend in an area
// ["_side", "_callpos", "_targpos", "_resources", "_starttime"]
A3A_supportSpends = [];

// Individual strikes generated by supports (and other sources?) on creation
// used to prevent spamming same base type on a point or target
// target is object for TARGET base type, otherwise position
// power is effect radius for AREA, strength for TROOPS
// ["_side", "_basetype", "_target", "_endtime", "_duration", "_power"]
A3A_supportStrikes = [];

// only need this for the support system itself in this version?

// Active multitarget supports
// [_suppname, _side, _supptype, _center, _radius, _target, _minRadius (opt)]
// _target is [unit, position] array, or [] for free
A3A_activeSupports = [];

// Interfaces:
// Avail func: _weight = [_target, _side, _maxSpend?] call _availFunc;
// Create func:  _resCost = [_suppname, _side, _resPool, _maxSpend, _target, _targpos, _reveal, _delay] call _createFunc;


private _initData = [
    // [supptype, basetype, weight, lowair, effradius, strikepower, unfair, reqtype]
    // weight/lowair: Relative weighting for selection. May be adjusted by availability functions.
    // effradius: Strike radius, used for detecting friendly fire
    // strikepower: Approx resource value per strike for multi-target supports
    ["AIRSTRIKE",       "AREA", 0.5, 0.1, 150,   0,  "", "vehiclesPlanesCAS"],           // balanced against carpetBombs (50/50 at tier 10), total will be 0.5
    ["ARTILLERY",       "AREA", 0.5, 0.9, 150,  85,  "", "vehiclesArtillery"],           // balanced against mortars (50/50 at tier 10), total will be 0.5/0.9
    ["MORTAR",          "AREA", 0.5, 0.9, 100,  50,  "", "staticMortars"],
    ["HOWITZER",        "AREA", 0.5, 0.9, 125,  65,  "", "staticHowitzers"],
    ["ASF",           "TARGET", 1.0, 0.4,   0, 100,  "", "vehiclesPlanesAA"],            // balanced against SAMs (if available), 66/33 weighting
    ["CAS",           "TARGET", 1.0, 0.4,   0, 100,  "", "vehiclesPlanesCAS"],
    ["CASDIVE",       "TARGET", 1.0, 0.4,   0, 100,  "", "vehiclesPlanesCAS"],
    ["QRFLAND",       "TROOPS", 1.0, 1.4,   0,   0,  "", ""],
    ["QRFAIR",        "TROOPS", 0.5, 0.1,   0,   0,  "", ""],
    ["QRFVEHAIRDROP", "TROOPS", 0.4, 0.1,   0,   0,  "", "vehiclesPlanesTransport"],
    ["CARPETBOMBS",     "AREA", 0.5, 0.1, 200,   0, "u", ""],                            // balanced against airstrikes
    ["GUNSHIP",         "AREA", 0.2, 0.1,   0,  80, "u", "vehiclesPlanesGunship"],       // uh. Does AREA work for this? Only lasts 5 minutes so maybe...
    ["SAM",           "TARGET", 1.0, 1.0,   0, 100, "u", ""],                            // balanced against ASF
    ["ORBITALSTRIKE",   "AREA", 0.2, 0.0, 300,   0, "f", ""],
    ["UAV",           "TARGET", 1.0, 0.4,   0, 80,  "", "uavsAttack"]                    // seems that it doesn't use it's weapons
];

// Generate support type hashmap for a faction, suppType -> [baseType, weight, effRadius, strikepower]
private _fnc_buildSupportHM = 
{
    params ["_faction"];
    private _lowAir = _faction getOrDefault ["attributeLowAir", false];
    private _suppHM = createHashMap;
    {
        _x params ["_suppType", "_baseType", "_weight", "_lowAirWeight", "_effRadius", "_strikepower", "_flags", "_reqType"];
        if (_faction get _reqType isEqualTo []) then { continue };
        if ("u" in _flags and !allowUnfairSupports) then { continue };
        if ("f" in _flags and !allowFuturisticSupports) then { continue };

        private _weight = [_weight, _lowAirWeight] select _lowAir;
        _suppHM set [_suppType, [_baseType, _weight, _effRadius, _strikepower]];
    } forEach _initData;
    _suppHM;
};

A3A_supportTypesOcc = A3A_faction_occ call _fnc_buildSupportHM;
A3A_supportTypesInv = A3A_faction_inv call _fnc_buildSupportHM;


// Build marker lists for determining importance of target locations

A3A_supportMarkersXYI = [];        // format [x, y, index into markerTypes]
A3A_supportMarkerTypes = [];     // format [markerName, markerType, hasRadio, defenceMul, ...]

#define RADIO_TOWER_BONUS 0.15

// Build arrays of markers that have defence bonuses
{ A3A_supportMarkerTypes pushBack [_x, "Airport", false, 1.0] } forEach airportsX;
{ A3A_supportMarkerTypes pushBack [_x, "Airport", false, 1.0] } forEach airportsX;
{ A3A_supportMarkerTypes pushBack [_x, "MilitaryBase", false, 0.8] } forEach milbases;
{ A3A_supportMarkerTypes pushBack [_x, "MilitaryBase", false, 0.8] } forEach milbases;
{ A3A_supportMarkerTypes pushBack [_x, "Seaport", false, 0.6] } forEach seaports;
{ A3A_supportMarkerTypes pushBack [_x, "Outpost", false, 0.6] } forEach outposts;
{ A3A_supportMarkerTypes pushBack [_x, "Factory", false, 0.5] } forEach factories;
{ A3A_supportMarkerTypes pushBack [_x, "Town", false, 0.3] } forEach citiesX;
{
    _x pushBack (0.5 + random 0.5);         // current random defence multiplier
    private _pos = markerPos (_x#0);
    A3A_supportMarkersXYI pushBack [_pos#0, _pos#1, _forEachIndex];
} forEach A3A_supportMarkerTypes;

// Find nearest marker for each radio tower and mark it in markersDetail
{
    private _closeMrk = A3A_supportMarkersXYI inAreaArray [getPosATL _x, 500, 500];
    if (_closeMrk isEqualTo []) then { continue };
    private _nearest = [_closeMrk, _x] call BIS_fnc_nearestPosition;
    (A3A_supportMarkerTypes select (_nearest#2)) set [2, true];          // mark as having radio tower
} forEach (antennas + antennasDead);        // ugh

{
    // increase defenceMul if it's a radio tower
    if (_x#2) then { _x set [3, (_x#3) + RADIO_TOWER_BONUS] };
} forEach A3A_supportMarkerTypes;
