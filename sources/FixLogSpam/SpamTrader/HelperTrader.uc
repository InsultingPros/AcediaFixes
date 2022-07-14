/**
 *      Helper object for `FixLogSpam` fix, responsible for fixing log spam
 *  due to missing `ShopVolume`s missing `WeaponLocker` in the `myTrader`
 *  variable.
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
class HelperTrader extends AcediaObject
    config(AcediaFixes);

/**
 *      `WeaponLocker` seems be an actor that was supposed to play a certain
 *  animation whenever players enter a shop. Each `WeaponLocker` is also
 *  supposed to find the shop (`ShopVolume`) it's linked to during
 *  `PreBeginPlay()` event and record itself inside `ShopVolume`'s `myTrader`
 *  variable. However this sometimes does not happen: either due to locker's
 *  placement or due to map maker forgetting to put one in at all.
 *  Since `ShoVolume`s do not attempt to check whether their `myTrader` has
 *  a valid reference, they generate log spam when it does not.
 *      Note that while `WeaponLocker` was supposed to do some action when
 *  players enter the shop, it does not actually do anything, so we do not need
 *  to care about linking lost lockers to their intended shops, we just need to
 *  link some locker to shops with empty `myTrader` references. Maps with
 *  custom animated (or otherwise somehow active) lockers should be themselves
 *  responsible that their animations are being played correctly.
 *      This fix deals with issue by either:
 *          1. Spawning our own `WeaponLocker` and assigning it to the shops
 *              with empty `myTrader`;
 *          2. Finding any already existing locker on the map and linking that
 *              to the shops with empty `myTrader`.
 *      First way is prefereable, since we prefer not to touch placed
 *  `WeaponLocker`s in case someone decides to use them correctly and makes
 *  a custom class that plays welcome animation in some shop, but forgets about
 *  `WeaponLocker`s for other regular shops.
 */

//      Remember instance of `WeaponLocker` that we spawned, so we can clean
//  it up later.
//      Reference to `WeaponLocker`
var private NativeActorRef          dummyLocker;
//  Remember fixed shops, so we can unfix them later.
//  Reference tp `ShopVolume`.
var private array<NativeActorRef>   fixedShops;

var LoggerAPI.Definition errNoReplacementLocker;

protected function Constructor()
{
    local LevelInfo     level;
    local ShopVolume    nextShop;
    local WeaponLocker  replacementLocker;
    level = _server.unreal.GetLevel();
    //  Get locker
    replacementLocker = SpawnDummyWeaponLocker();
    if (replacementLocker == none) {
        replacementLocker = FindExistingWeaponLocker();
    }
    if (replacementLocker == none)
    {
        _.logger.Auto(errNoReplacementLocker);
        FreeSelf();
        return;
    }
    //  Setup locker
    foreach level.DynamicActors(class'KFMod.ShopVolume', nextShop)
    {
        if (nextShop == none)           continue;
        if (nextShop.myTrader != none)  continue;
        nextShop.myTrader = replacementLocker;
        fixedShops[fixedShops.length] = _server.unreal.ActorRef(nextShop);
    }
}

protected function Finalizer()
{
    local int           i;
    local ShopVolume    nextShop;
    local Actor         lockerInstance;
    //  Free shops
    for (i = 0; i < fixedShops.length; i += 1)
    {
        nextShop = ShopVolume(fixedShops[i].Get());
        fixedShops[i].FreeSelf();
        if (nextShop != none) {
            nextShop.myTrader = none;
        }
    }
    fixedShops.length = 0;
    //  Free locker
    if (dummyLocker != none) {
        lockerInstance = dummyLocker.Get();
        dummyLocker.FreeSelf();
    }
    if (lockerInstance != none) {
        lockerInstance.Destroy();
    }
}

private final function WeaponLocker SpawnDummyWeaponLocker()
{
    local WeaponLocker lockerInstance;
    local bool savedCollideWorld, savedCollideActors;
    if (dummyLocker != none) {
        return WeaponLocker(dummyLocker.Get());
    }
    //  Disable collision so that dummy `WeaponLocker` would both not affect
    //  gameplay and would not fail spawning due to being inside terrain or
    //  another actor.
    savedCollideWorld   = class'WeaponLocker'.default.bCollideWorld;
    savedCollideActors  = class'WeaponLocker'.default.bBlockActors;
    class'WeaponLocker'.default.bCollideWorld   = false;
    class'WeaponLocker'.default.bBlockActors    = false;
    lockerInstance = WeaponLocker(_.memory.Allocate(class'WeaponLocker'));
    class'WeaponLocker'.default.bCollideWorld   = savedCollideWorld;
    class'WeaponLocker'.default.bBlockActors    = savedCollideActors;
    if (lockerInstance != none)
    {
        lockerInstance.bHidden = true;
        lockerInstance.SetDrawType(DT_None);
        lockerInstance.SetCollision(false);
    }
    dummyLocker = _server.unreal.ActorRef(lockerInstance);
    return lockerInstance;
}

private final function WeaponLocker FindExistingWeaponLocker()
{
    local LevelInfo     level;
    local WeaponLocker  nextLocker;
    level = _server.unreal.GetLevel();
    foreach level.DynamicActors(class'KFMod.WeaponLocker', nextLocker)
    {
        if (nextLocker != none) {
            return nextLocker;
        }
    }
    return none;
}

defaultproperties
{
    errNoReplacementLocker = (l=LOG_Error,m="`FixLogSpam` cannot find or spawn `WeaponLocker` actor. Shop log spam will not be disabled.")
}