 /**
 *      This feature fixes a vulnerability in a code of `Frag` that can allow
 *  player to throw grenades even when he no longer has any.
 *  There's also no cooldowns on the throw, which can lead to a server crash.
 *      Copyright 2019 Anton Tarasenko
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
class FixInfiniteNades_Feature extends Feature;

/**
 *      It is possible to call `ServerThrow` function from client,
 *  forcing it to get executed on a server. This function consumes the grenade
 *  ammo and spawns a nade, but it doesn't check if player had any grenade ammo
 *  in the first place, allowing you him to throw however many grenades
 *  he wants. Moreover, unlike a regular throwing method, calling this function
 *  allows to spawn many grenades without any delay,
 *  which can lead to a server crash.
 *
 *      This fix tracks every instance of `Frag` weapon that's responsible for
 *  throwing grenades and records how much ammo they have have.
 *  This is necessary, because whatever means we use, when we get a say in
 *  preventing grenade from spawning the ammo was already reduced.
 *  This means that we can't distinguished between a player abusing a bug by
 *  throwing grenade when he doesn't have necessary ammo and player throwing
 *  his last nade, as in both cases current ammo visible to us will be 0.
 *  Then, before every nade throw, it checks if player has enough ammo and
 *  blocks grenade from spawning if he doesn't.
 *      We change a `FireModeClass[0]` from `FragFire` to `FixedFragFire` and
 *  only call `super.DoFireEffect()` if we decide spawning grenade
 *  should be allowed. The side effect is a change in server's `FireModeClass`.
 */

//      Setting this flag to `true` will allow to throw grenades by calling
//  `ServerThrow()` directly, as long as player has necessary ammo.
//  This can allow some players to throw grenades much quicker than intended,
//  so if you wish to prevent it, keep this flag set to `false`.
var private /*config*/ bool ignoreTossFlags;

//  Set to `true` when this fix is getting disabled to avoid replacing the
//  fire class again.
var private bool shuttingDown;

//  Records how much ammo given frag grenade (`Frag`) has.
struct FragAmmoRecord
{
    //  Reference to `Frag`
    var public NativeActorRef   fragReference;
    var public int              amount;
};
var private array<FragAmmoRecord> ammoRecords;

protected function OnEnabled()
{
    local Frag      nextFrag;
    local LevelInfo level;
    level = _server.unreal.GetLevel();
    _server.unreal.OnTick(self).connect = Tick;
    _server.unreal.mutator.OnCheckReplacement(self).connect = CheckReplacement;
    shuttingDown = false;
    //  Find all frags, that spawned when this fix wasn't running.
    foreach level.DynamicActors(class'KFMod.Frag', nextFrag) {
        RegisterFrag(nextFrag);
    }
    RecreateFrags();
}

protected function OnDisabled()
{
    _server.unreal.OnTick(self).Disconnect();
    _server.unreal.mutator.OnCheckReplacement(self).Disconnect();
    shuttingDown = true;
    RecreateFrags();
    ammoRecords.length = 0;
}

protected function SwapConfig(FeatureConfig config)
{
    local FixInfiniteNades newConfig;
    newConfig = FixInfiniteNades(config);
    if (newConfig == none) {
        return;
    }
    ignoreTossFlags = newConfig.ignoreTossFlags;
}

private function bool CheckReplacement(Actor other, out byte isSuperRelevant)
{
    local Frag relevantFrag;
    if (shuttingDown) {
        return true;
    }
    //  Handle detecting new frag (weapons that allows to throw nades)
    relevantFrag = Frag(other);
    if (relevantFrag != none)
    {
        RegisterFrag(relevantFrag);
        relevantFrag.FireModeClass[0] = class'FixedFragFire';
        return true;
    }
    return true;
}

//  Returns index of the connection corresponding to the given controller.
//  Returns `-1` if no connection correspond to the given controller.
//  Returns `-1` if given controller is equal to `none`.
private final function int GetAmmoIndex(Frag fragToCheck)
{
    local int i;
    if (fragToCheck == none) return -1;

    for (i = 0; i < ammoRecords.length; i += 1)
    {
        if (ammoRecords[i].fragReference.Get() == fragToCheck) {
            return i;
        }
    }
    return -1;
}

//  Recreates all the `Frag` actors, to change their fire mode mid-game.
private final function RecreateFrags()
{
    local int                   i;
    local float                 maxAmmo, currentAmmo;
    local Frag                  newFrag, oldFrag;
    local Pawn                  fragOwner;
    local array<FragAmmoRecord> oldRecords;
    oldRecords = ammoRecords;
    for (i = 0; i < oldRecords.length; i += 1)
    {
        //  Check if we even need to recreate that instance of `Frag`
        oldFrag = Frag(oldRecords[i].fragReference.Get());
        oldRecords[i].fragReference.FreeSelf();
        if (oldFrag == none)    continue;
        fragOwner = oldFrag.instigator;
        if (fragOwner == none)  continue;
        //  Recreate
        oldFrag.Destroy();
        fragOwner.CreateInventory("KFMod.Frag");
        newFrag = GetPawnFrag(fragOwner);
        //  Restore ammo amount
        if (newFrag != none)
        {
            newFrag.GetAmmoCount(maxAmmo, currentAmmo);
            newFrag.AddAmmo(oldRecords[i].amount - Int(currentAmmo), 0);
        }
    }
}

// Utility function to help find a `Frag` instance in a given pawn's inventory.
static private final function Frag GetPawnFrag(Pawn pawnWithFrag)
{
    local Frag      foundFrag;
    local Inventory invIter;
    if (pawnWithFrag == none) return none;
    invIter = pawnWithFrag.inventory;
    while (invIter != none)
    {
        foundFrag = Frag(invIter);
        if (foundFrag != none) {
            return foundFrag;
        }
        invIter = invIter.inventory;
    }
    return none;
}

//  Utility function for extracting current ammo amount from a frag class.
private final function int GetFragAmmo(Frag fragReference)
{
    local float maxAmmo;
    local float currentAmmo;
    if (fragReference == none) return 0;

    fragReference.GetAmmoCount(maxAmmo, currentAmmo);
    return Int(currentAmmo);
}

//  Attempts to add new `Frag` instance to our records.
public final function RegisterFrag(Frag newFrag)
{
    local int               index;
    local FragAmmoRecord    newRecord;
    index = GetAmmoIndex(newFrag);
    if (index >= 0) return;

    newRecord.fragReference = _server.unreal.ActorRef(newFrag);
    newRecord.amount = GetFragAmmo(newFrag);
    ammoRecords[ammoRecords.length] = newRecord;
}

//      This function tells our fix that there was a nade throw and we should
//  reduce current `Frag` ammo in our records.
//  Returns `true` if we had ammo for that, and `false` if we didn't.
public final function bool RegisterNadeThrow(Frag relevantFrag)
{
    if (CanThrowGrenade(relevantFrag))
    {
        ReduceGrenades(relevantFrag);
        return true;
    }
    return false;
}

//      Can we throw grenade according to our rules?
//  A throw can be prevented if:
//  - we think that player doesn't have necessary ammo;
//  - Player isn't currently `tossing` a nade,
//  meaning it was a direct call of `ServerThrow`.
private final function bool CanThrowGrenade(Frag fragToCheck)
{
    local int index;
    //  Nothing to check
    if (fragToCheck == none)            return false;
    //  No ammo
    index = GetAmmoIndex(fragToCheck);
    if (index < 0)                      return false;
    if (ammoRecords[index].amount <= 0) return false;
    //  Not tossing
    if (ignoreTossFlags)                                        return true;
    if (!fragToCheck.bTossActive || fragToCheck.bTossSpawned)   return false;
    return true;
}

//  Reduces recorded amount of ammo in our records for the given nade.
private final function ReduceGrenades(Frag relevantFrag)
{
    local int index;
    index = GetAmmoIndex(relevantFrag);
    if (index < 0) return;
    ammoRecords[index].amount -= 1;
}

private function Tick(float delta, float timeDilationCoefficient)
{
    local int   i;
    local Frag  nextFrag;
    //  Update our ammo records with current, correct data.
    while (i < ammoRecords.length)
    {
        nextFrag = Frag(ammoRecords[i].fragReference.Get());
        if (nextFrag != none)
        {
            ammoRecords[i].amount = GetFragAmmo(nextFrag);
            i += 1;
        }
        else
        {
            ammoRecords[i].fragReference.FreeSelf();
            ammoRecords.Remove(i, 1);
        }
    }
}

defaultproperties
{
    configClass = class'FixInfiniteNades'
    ignoreTossFlags = true
}