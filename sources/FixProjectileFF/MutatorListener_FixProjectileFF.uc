/**
 *      Overloaded mutator events listener to replace projectiles vulnerable to
 *  friendly fire.
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
class MutatorListener_FixProjectileFF extends MutatorListenerBase
    abstract;

static function bool CheckReplacement(Actor other, out byte isSuperRelevant)
{
    local ROBallisticProjectile         projectile;
    local class<ROBallisticProjectile>  newClass;
    projectile = ROBallisticProjectile(other);
    if (projectile == none) return true;

    projectile.bGameRelevant = true;
    newClass =
        class'FixProjectileFF'.static.FindFixedClass(projectile.class);
    if (newClass == none || newClass == projectile.class) {
        return true;
    }
    ReplaceProjectileWith(ROBallisticProjectile(other), newClass);
    return true;
}

static function ReplaceProjectileWith(
    ROBallisticProjectile           oldProjectile,
    class<ROBallisticProjectile>    replacementClass)
{
    local Pawn                  instigator;
    local ROBallisticProjectile newProjectile;
    if (oldProjectile == none)      return;
    if (replacementClass == none)   return;
    instigator = oldProjectile.instigator;
    if (instigator == none)         return;
    newProjectile = instigator.Spawn(   replacementClass,,,
                                        oldProjectile.location,
                                        oldProjectile.rotation);
    if (newProjectile == none)      return;

    //      Move projectile damage data to make sure new projectile deals
    //  exactly the same damage as the old one and the old one no longer
    //  deals any.
    //      Technically we only need to zero `oldProjectile` damage values for
    //  most weapons, since they are automatically the same for the
    //  new projectile.
    //      However `KFMod.HuskGun` is an exception that changes these values
    //  depending of the charge, so we need to either consider this as a
    //  special case or just move valkues all the time - which is what we have
    //  chosen to do.
    newProjectile.damage        = oldProjectile.damage;
    oldProjectile.damage        = 0;
    newProjectile.damageRadius  = oldProjectile.damageRadius;
    oldProjectile.damageRadius  = 0;
    MoveImpactDamage(oldProjectile, newProjectile);
    //  New projectile must govern all of the mechanics, so make the old mimick
    //  former's movements as close as possible
    SetupOldProjectileAsFace(oldProjectile, newProjectile);
}

//  Make old projectile behave as close to the new one as possible
static function SetupOldProjectileAsFace(
    ROBallisticProjectile oldProjectile,
    ROBallisticProjectile newProjectile)
{
    local FixProjectileFFClass_SPGrenadeProjectile  newProjectileAsOrca;
    local FixProjectileFFClass_SealSquealProjectile newProjectileAsHarpoon;
    if (oldProjectile == none) return;
    if (newProjectile == none) return;

    //  Removing collisions:
    //      1. Avoids unnecessary bumping into zeds and other `Actor`s;
    //      2. Removes `oldProjectile` from being accessible by
    //          `VisibleCollidingActors()`, therefore avoiding unwanted
    //          `TakeDamage()` calls from friendly fire.
    oldProjectile.SetCollision(false, false);
    //  Prevent `oldProjectile` from dealing explosion damage in case something
    //  still damages it
    oldProjectile.bHurtEntry = true;
    //  We can only make client-side projectile follow server-side one for
    //  two projectile classes
    newProjectileAsOrca =
        FixProjectileFFClass_SPGrenadeProjectile(newProjectile);
    if (newProjectileAsOrca != none)
    {
        newProjectileAsOrca.SetFace(SPGrenadeProjectile(oldProjectile));
        return;
    }
    newProjectileAsHarpoon =
        FixProjectileFFClass_SealSquealProjectile(newProjectile);
    if (newProjectileAsHarpoon != none) {
        newProjectileAsHarpoon.SetFace(SealSquealProjectile(oldProjectile));
    }
}

//  `impactDamage` is sepratly defined in 4 different base classes of interest
//  and moving (or zeroing) it is cumbersome enough to warrant a separate method
static function MoveImpactDamage(
    ROBallisticProjectile oldProjectile,
    ROBallisticProjectile newProjectile)
{
    local LAWProj               oldProjectileAsLaw, newProjectileAsLaw;
    local M79GrenadeProjectile  oldProjectileAsM79, newProjectileAsM79;
    local SPGrenadeProjectile   oldProjectileAsOrca, newProjectileAsOrca;
    local SealSquealProjectile  oldProjectileAsHarpoon, newProjectileAsHarpoon;
    if (oldProjectile == none) return;
    if (newProjectile == none) return;

    //  L.A.W + derivatives:
    //  Zed guns, Flare Revolver, Husk Gun
    oldProjectileAsLaw = LawProj(oldProjectile);
    newProjectileAsLaw = LawProj(newProjectile);
    if (oldProjectileAsLaw != none && newProjectileAsLaw != none)
    {
        newProjectileAsLaw.impactDamage = oldProjectileAsLaw.impactDamage;
        oldProjectileAsLaw.impactDamage = 0;
        return;
    }
    //  M79 Grenade Launcher + derivatives:
    //  M32, M4 203
    oldProjectileAsM79 = M79GrenadeProjectile(oldProjectile);
    newProjectileAsM79 = M79GrenadeProjectile(newProjectile);
    if (oldProjectileAsM79 != none && newProjectileAsM79 != none)
    {
        newProjectileAsM79.impactDamage = oldProjectileAsM79.impactDamage;
        oldProjectileAsM79.impactDamage = 0;
        return;
    }
    //  The Orca Bomb Propeller
    oldProjectileAsOrca = SPGrenadeProjectile(oldProjectile);
    newProjectileAsOrca = SPGrenadeProjectile(newProjectile);
    if (oldProjectileAsOrca != none && newProjectileAsOrca != none)
    {
        newProjectileAsOrca.impactDamage = oldProjectileAsOrca.impactDamage;
        oldProjectileAsOrca.impactDamage = 0;
        return;
    }
    //  SealSqueal Harpoon Bomber
    oldProjectileAsHarpoon = SealSquealProjectile(oldProjectile);
    newProjectileAsHarpoon = SealSquealProjectile(newProjectile);
    if (oldProjectileAsHarpoon != none && newProjectileAsHarpoon != none)
    {
        newProjectileAsHarpoon.impactDamage = oldProjectileAsHarpoon.impactDamage;
        oldProjectileAsHarpoon.impactDamage = 0;
        return;
    }
}

defaultproperties
{
    relatedEvents = class'MutatorEvents'
}