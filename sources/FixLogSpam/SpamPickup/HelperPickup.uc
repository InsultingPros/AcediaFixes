/**
 *      Helper object for `FixLogSpam` fix, responsible for fixing log spam
 *  due to picking up dropped weapons without set `inventory` variable.
 *      Copyright 2021 Anton Tarasenko
 *------------------------------------------------------------------------------
 * This file is part of Acedia.
 *
 * Acedia is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3 of the License, or
 * (at your option) any later version.
 *
 * Acedia is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Acedia.  If not, see <https://www.gnu.org/licenses/>.
 */
class HelperPickup extends AcediaObject;

/**
 *      `KFWeaponPickup` class is responsible for spamming log with
 *  error messages about missing `inventory` actor: "Accessed None 'Inventory'".
 *  This is caused by `Destroyed()` event that tries to call `KFGameType`'s
 *  `WeaponDestroyed()` on pickup's `inventory.class`, but it fails because
 *  `inventory` is essentially guaranteed to be `none` for pickups dropped
 *  by players. Since no `inventory != none` check is made, this leads to
 *  log message spam.
 *      To fix it we simply disable `Destroyed()` event altogether, since all
 *  it does is:
 *      1. Fails as we have described;
 *      2. In `super(Pickup).Destroyed()` sets `myMarker.markedItem` to `none`,
 *          which does nothig for pickups dropped by players, since they do not
 *          have any `myMarker` in the first place: they are usually defined to
 *          refer to `InventorySpot`s, generated for placed pickups when
 *          navigation paths are built.
 *
 *  The are two issues that need resolving for this solution to work:
 *      1. Distinguish between pickups dropped by the player versus pickups
 *          placed on the map;
 *      2. Even if one disables `Destroyed()` event, it can get re-enabled again
 *          (possibly by a state change).
 *      One way to accomplish the first goal is to check `instigator` during
 *  `CheckReplacement()` event: it should be `none` for map pickups and point
 *  to the player's pawn for dropped pickups. If, for some reason, instigator
 *  would end up being equal to `none` for a dropped pickup, we also record all
 *  the other pickups and give them some time to initialize
 *  (`CheckReplacement()` is called at the moment they are spawned and
 *  before initialization logic is completed) and check their `bDropped` flag,
 *  since it is what decides whether log message about accessing `none`-value
 *  will be output: `if ( bDropped && class<Weapon>(Inventory.Class) != none )`.
 *  Then we also try to fix all the weapons with `bDropped == true`.
 *      To resolve issue with `Destroyed()` event being re-enabled we use
 *  brute force approach of disabling it every tick:
 *      1. Amount of dropped pickups is small enough for it to not cause
 *          performance issues;
 *      2. Checking change in state or trying to determine other causes for
 *          re-enabling the event would likely just lead to more complicated
 *          logic with around the same or even worse performance.
 *  We also enforce additional update when we catch player trying to pickup some
 *  `KFWeaponPickup` with `GameRules`'s `OverridePickupQuery()`, which is
 *  called soon before pickup's destruction. Note that this update cannot
 *  replace update inside the `Tick()`, since pickup can be destroyed without
 *  being picked up, i.e. at the start of each wave.
 *
 *      Described method does not 100% guarantee removal of the related spam
 *  messages, but should make them virtually impossible. At least on
 *  vanilla servers.
 */

//  For easy access in relevant `GameRules` and mutator event listener.
var private HelperPickup    singletonInstance;
//  Already fixed pickups that we periodically "refix".
var private array<NativeActorRef> recordedPickups;
//      Pickups that will get `bDropped` flag checked the next tick to
//  determine if we need to fix them.
var private array<NativeActorRef> pendingPickups;

protected function Constructor()
{
    local LevelInfo         level;
    local KFWeaponPickup    nextPickup;
    if (default.singletonInstance == none) {
        default.singletonInstance = self;
    }
    //  To detect when player tries to pick something up
    //  (and force additional pickup fix update)
    _server.unreal.gameRules.OnOverridePickupQuery(self).connect = PickupQuery;
    //  To detect newly spawned pickups
    _server.unreal.mutator.OnCheckReplacement(self).connect = CheckReplacement;
    //  For updating pickups as soon as possible
    _server.unreal.OnTick(self).connect = Tick;
    //      Find all `KFWeaponPickup`s laying around on the map,
    //  so that we can fix preexisting ones too.
    //      But add them to pending list in a freaky case this `HealperPickup`
    //  was created during one's initialization. This will give it time to
    //  set up variables that distinguish dropped pickup from another
    //  kind of pickup.
    level = _server.unreal.GetLevel();
    foreach level.DynamicActors(class'KFMod.KFWeaponPickup', nextPickup)
    {
        pendingPickups[pendingPickups.length] =
            _server.unreal.ActorRef(nextPickup);
    }
}

protected function Finalizer()
{
    local int               i;
    local KFWeaponPickup    nextPickup;
    for (i = 0; i < recordedPickups.length; i += 1)
    {
        nextPickup = KFWeaponPickup(recordedPickups[i].Get());
        if (nextPickup != none) {
            recordedPickups[i].Enable('Destroyed');
        }
    }
    _.memory.FreeMany(recordedPickups);
    _.memory.FreeMany(pendingPickups);
    recordedPickups.length = 0;
    pendingPickups.length = 0;
    _server.unreal.gameRules.OnOverridePickupQuery(self).Disconnect();
    _server.unreal.mutator.OnCheckReplacement(self).Disconnect();
    _server.unreal.OnTick(self).Disconnect();
}

function bool PickupQuery(
    Pawn        toucher,
    Pickup      touchedPickup,
    out byte    allowPickup)
{
    UpdatePickups();
    return false;
}

private function bool CheckReplacement(Actor other, out byte isSuperRelevant)
{
    local KFWeaponPickup otherPickup;
    otherPickup = KFWeaponPickup(other);
    if (otherPickup != none) {
        HandlePickup(otherPickup);
    }
    return true;
}

private function Tick(float delta, float timeDilationCoefficient)
{
    CleanRecordedPickups();
    UpdatePickups();
}

public final static function HelperPickup GetInstance()
{
    return default.singletonInstance;
}

//      Checks whether given pickup is recorded in any of our records,
//  including pending pickups.
//      `none` is never recorded.
private final function bool IsPickupRecorded(KFWeaponPickup pickupToCheck)
{
    local int               i;
    local KFWeaponPickup    nextPickup;
    if (pickupToCheck == none) {
        return false;
    }
    for (i = 0; i < recordedPickups.length; i += 1)
    {
        nextPickup = KFWeaponPickup(recordedPickups[i].Get());
        if (nextPickup == pickupToCheck) {
            return true;
        }
    }
    for (i = 0; i < pendingPickups.length; i += 1)
    {
        nextPickup = KFWeaponPickup(pendingPickups[i].Get());
        if (nextPickup == pickupToCheck) {
            return true;
        }
    }
    return false;
}

//  Gets rid of pickups that got destroyed at some point and now are set
//  to `none`.
private final function CleanRecordedPickups()
{
    local int i;
    while (i < recordedPickups.length)
    {
        if (recordedPickups[i].Get() == none)
        {
            recordedPickups[i].FreeSelf();
            recordedPickups.Remove(i, 1);
        }
        else {
            i += 1;
        }
    }
}

//  Makes helper handle given pickup `newPickup` by either fixing it or
//  delaying to check whether it is dropped.
public final function HandlePickup(KFWeaponPickup newPickup)
{
    if (newPickup == none)              return;
    if (IsPickupRecorded(newPickup))    return;

    if (newPickup.instigator != none)
    {
        newPickup.Disable('Destroyed');
        recordedPickups[recordedPickups.length] =
            _server.unreal.ActorRef(newPickup);
    }
    else
    {
        pendingPickups[pendingPickups.length] =
            _server.unreal.ActorRef(newPickup);
    }
}

//  Re-disables `Destroyed()` event for all recorded (confirmed) dropped pickups
//  and processes all pending (for the check if they are dropped) pickups.
private final function UpdatePickups()
{
    local int               i;
    local KFWeaponPickup    nextPickup;
    for (i = 0; i < recordedPickups.length; i += 1)
    {
        nextPickup = KFWeaponPickup(recordedPickups[i].Get());
        if (nextPickup != none) {
            nextPickup.Disable('Destroyed');
        }
    }
    for (i = 0; i < pendingPickups.length; i += 1)
    {
        nextPickup = KFWeaponPickup(pendingPickups[i].Get());
        if (nextPickup == none)     continue;
        if (nextPickup.bDropped)    continue;

        nextPickup.Disable('Destroyed');
        recordedPickups[recordedPickups.length] = pendingPickups[i];
    }
    pendingPickups.length = 0;
}

defaultproperties
{
}