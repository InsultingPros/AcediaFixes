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
class FixProjectileFFClass_ZEDGunProjectile extends ZEDGunProjectile;

function TakeDamage(
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
    if (canTakeThisDamage && !bDud) {
        Explode(hitLocation, Vect(0, 0, 0));
    }
}

defaultproperties
{
    RemoteRole = ROLE_None
}