/**
 *      A helper class for `FixProjectileFF` that adds an instigator and
 *  friendly fire checks to `TakeDamage()` method to avoid exploding projectiles
 *  when not expected.
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
class FixProjectileFFClass_SealSquealProjectile extends SealSquealProjectile;

var private SealSquealProjectile projectileFace;

public final function SetFace(SealSquealProjectile newProjectileFace)
{
    projectileFace = newProjectileFace;
}

public function TakeDamage(
    int                 damage,
    Pawn                instigatedBy,
    Vector              hitLocation,
    Vector              momentum,
    class<DamageType>   damageType,
    optional int        hitIndex)
{
    local bool canTakeThisDamage;
    if (class<SirenScreamDamage>(damageType) != none)
    {
        Disintegrate(hitLocation, Vect(0, 0, 1));
        return;
    }
    canTakeThisDamage =
            (instigatedBy == instigator)
        ||  class'FixProjectileFF_Feature'.static.IsFriendlyFireAcceptable();
    //  Unlike M79/M32 - no `!bDud` check, since it's supposed to fall down
    if (canTakeThisDamage)
    {
        Explode(hitLocation, Vect(0, 0, 0));
        if (projectileFace != none) {
            projectileFace.Explode(hitLocation, Vect(0, 0, 0));
        }
    }
}

simulated function Explode(vector hitLocation, vector HitNormal)
{
    super.Explode(hitLocation, hitNormal);
    if (projectileFace != none) {
        projectileFace.Explode(hitLocation, hitNormal);
    }
}

simulated function Disintegrate(vector hitLocation, vector hitNormal)
{
    super.Disintegrate(hitLocation, hitNormal);
    if (projectileFace != none) {
        projectileFace.Disintegrate(hitLocation, hitNormal);
    }
}

simulated function Stick(Actor hitActor, vector hitLocation)
{
    super.Stick(hitActor, hitLocation);
    if (projectileFace != none)
    {
        projectileFace.SetCollision(true, true);
        projectileFace.SetLocation(location);
        projectileFace.SetRotation(rotation);
        projectileFace.Stick(hitActor, hitLocation);
    }
}

event Tick(float delta)
{
    super.Tick(delta);
    if (projectileFace == none) return;
    if (projectileFace.bStuck)  return;

    projectileFace.SetLocation(location);
    projectileFace.SetRotation(rotation);
    projectileFace.velocity = velocity;
}

event OnDestroyed()
{
    if (projectileFace != none) {
        projectileFace.Destroy();
    }
}

defaultproperties
{
    RemoteRole = ROLE_None
}