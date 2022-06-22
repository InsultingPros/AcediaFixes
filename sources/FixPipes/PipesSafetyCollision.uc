/**
 *      This collision attaches itself to pipes to catch `TakeDamage()` events
 *  in their place and only propagating them after additional checks.
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
class PipesSafetyCollision extends ExtendedZCollision;

//      Static function that raplaces `PipeBombProjectile` damage detectino with
//  safer `PipesSafetyCollision`'s one.
public final static function PipesSafetyCollision ProtectPipes(
    PipeBombProjectile target)
{
    local PipesSafetyCollision newCollision;
    if (target == none) return none;

    newCollision = target.Spawn(class'PipesSafetyCollision', target);
    newCollision.SetCollision(true);
    newCollision.SetCollisionSize(  target.collisionRadius,
                                    target.collisionHeight);
    newCollision.SetLocation(target.location);
    newCollision.SetPhysics(PHYS_None);
    newCollision.SetBase(target);
    newCollision.SetTimer(1.0, true);
    target.SetCollision(false);
    return newCollision;
}

//  Same method for checking suspicious `Pawn`s as in `FixFFHack`.
//  Copy-pasting it once is fine-ish, but if we will need it for another fix -
//  we will have to move it out into a general method, independed from
//  particular fixes.
private function bool IsSuspicious(Pawn instigator)
{
    //  Instigator vanished
    if (instigator == none) {
        return true;
    }
    //  Instigator already became spectator
    if (KFPawn(instigator) != none)
    {
        if (instigator.playerReplicationInfo != none) {
            return instigator.playerReplicationInfo.bOnlySpectator;
        }
        return true; // Replication info is gone => suspicious
    }
    return false;
}

//  Revert changes made by caller `PipesSafetyCollision`, letting corresponding
//  pipes catch damage events on their own again.
public final function TurnOff()
{
    if (owner != none) {
        owner.SetCollision(true);
    }
    SetOwner(none);
    Destroy();
}

//  `TakeDamage()` with added checks
function TakeDamage(
    int                 damage,
    Pawn                instigator,
    Vector              hitlocation,
    Vector              momentum,
    class<DamageType>   damageType,
    optional int        hitIndex)
{
    local FixPipes_Feature      pipesFix;
    local PipeBombProjectile    target;
    target = PipeBombProjectile(owner);
    if (target == none)                                                 return;
    pipesFix = FixPipes_Feature(
        class'FixPipes_Feature'.static.GetEnabledInstance());
    if (pipesFix == none)                                               return;
    if (pipesFix.preventMassiveDamage && target.bTriggered)             return;
    if (pipesFix.preventSuspiciousDamage && IsSuspicious(instigator))   return;

    owner.TakeDamage(   damage, instigator, hitlocation,
                        momentum, damageType, hitIndex);
}

event Timer()
{
    if (owner == none) {
        Destroy();
    }
}

defaultproperties
{
}