/**
 *      This feature addresses the bug that allows teammates to explode some of
 *  the player's projectiles by damaging them even when friendly fire is
 *  turned off, therefore killing the player (whether by accident or not).
 *
 *      Problem is solved by "disarming" projectiles vulnerable to this
 *  friendly fire and replacing them with our own class of projectile that is
 *  spawned only on a server and does additional safety checks to ensure it will
 *  only explode when it is expected from it.
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
class FixProjectileFF_Feature extends Feature;

/**
 *      All projectiles vulnerable to this bug (we consider only those that can
 *  explode and harm the player) are derived from `ROBallisticProjectile`. When
 *  one of them is spawned we will:
 *      1. Set it's damage parameters to zero, to ensure that it won't damage
 *          anyone or anything if other measures fail;
 *      2. Disable it's collision, preventing it from being accessed via
 *          `VisibleCollidingActors()` method that is usually used to damage
 *          these projectiles.
 *      Then we spawn our own version of the projectile with fixed
 *  `TakeDamage()` that does additional check that either it's projectile's
 *  owner that damages it or friendly fire is enabled.
 *      To do this replacement we will need to catch the moment when vanilla
 *  projectile spawns. Unfortunately, this cannot be done by default, since all
 *  projectiles have `bGameRelevant` flag set to `true`, which prevents
 *  `CheckReplacement()` from being called for them. So, when feature is
 *  enabled, it forces all the projectiles we are interested in to have
 *  `bGameRelevant = false`.
 *
 *      Issue arises from the fact that these two projectiles can desynchronize:
 *  old projectile, that client sees, might not be in the same location as the
 *  new one (especially since we are disabling collisions for the old one), that
 *  deals damage. There are two cases to consider, depending on
 *  the `bNetTemporary` of the old projectile:
 *      1. `bNetTemporary == true`: projectile version on client side is
 *          independent from the server-side's one. In this case there is
 *          nothing we can do. In fact, vanilla game suffers from this very bug
 *          that makes, say, M79 projectile fly past the zed it exploded
 *          (usually after killing it). To deal with this we would need
 *          the ability to affect client's code, which cannot be done in
 *          the server mode.
 *      2. `bNetTemporary == false`: projectile version on client side is
 *          actually synchronized with the server-side's one. In this case we
 *          will simply make new projectile to constantly force the old one to
 *          be in the same place at the same rotation. We will also propagate
 *          various state-changing events such as exploding, disintegrating from
 *          siren's scream or sticking to the wall/zed. That is, we will make
 *          the old projectile (that client can see) "the face" of the new one
 *          (that client cannot see). Only "The Orca Bomb Propeller" and
 *          "SealSqueal Harpoon Bomber" fall into this group.
 */

//  By default (`ignoreFriendlyFire == false`), when friendly fire is enabled
//  (at any level), this fix allows other players to explode one's projectiles.
//  By setting this to `true` you will force this fix to prevent it no matter
//  what, even when server has full friendly fire enabled.
var private /*config*/ bool ignoreFriendlyFire;

//  Stores what pairs of projectile classes that describe what (vulnerable)
//  class must be replaced with what (protected class). It also remembers the
//  previous state of `bGameRelevant` for replaceable class to restore it in
//  case this feature is disabled.
struct ReplacementRule
{
    //  `bGameRelevant` before this feature set it to `false`
    var bool                            relevancyFlag;
    var class<ROBallisticProjectile>    vulnerableClass;
    var class<ROBallisticProjectile>    protectedClass;
};
var private const array<ReplacementRule> rules;

protected function OnEnabled()
{
    local int i;
    for (i = 0; i < rules.length; i += 1)
    {
        if (rules[i].vulnerableClass == none)   continue;
        if (rules[i].protectedClass == none)    continue;
        rules[i].relevancyFlag = rules[i].vulnerableClass.default.bGameRelevant;
        rules[i].vulnerableClass.default.bGameRelevant = false;
    }
    _server.unreal.mutator.OnCheckReplacement(self).connect = CheckReplacement;
}

protected function OnDisabled()
{
    local int i;
    for (i = 0; i < rules.length; i += 1)
    {
        if (rules[i].vulnerableClass == none)   continue;
        if (rules[i].protectedClass == none)    continue;
        rules[i].vulnerableClass.default.bGameRelevant = rules[i].relevancyFlag;
    }
    _server.unreal.mutator.OnCheckReplacement(self).Disconnect();
}

protected function SwapConfig(FeatureConfig config)
{
    local FixProjectileFF newConfig;
    newConfig = FixProjectileFF(config);
    if (newConfig == none) {
        return;
    }
    ignoreFriendlyFire = newConfig.ignoreFriendlyFire;
    default.ignoreFriendlyFire = ignoreFriendlyFire;
}

private function bool CheckReplacement(Actor other, out byte isSuperRelevant)
{
    local ROBallisticProjectile         projectile;
    local class<ROBallisticProjectile>  newClass;
    projectile = ROBallisticProjectile(other);
    if (projectile == none) {
        return true;
    }
    projectile.bGameRelevant = true;
    newClass = FindFixedClass(projectile.class);
    if (newClass == none || newClass == projectile.class) {
        return true;
    }
    ReplaceProjectileWith(ROBallisticProjectile(other), newClass);
    return true;
}

private function ReplaceProjectileWith(
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
    //  special case or just move values all the time - which is what we have
    //  chosen to do.
    newProjectile.damage        = oldProjectile.damage;
    oldProjectile.damage        = 0;
    newProjectile.damageRadius  = oldProjectile.damageRadius;
    oldProjectile.damageRadius  = 0;
    MoveImpactDamage(oldProjectile, newProjectile);
    //  New projectile must govern all of the mechanics, so make the old mimic
    //  former's movements as close as possible
    SetupOldProjectileAsFace(oldProjectile, newProjectile);
}

//  Make old projectile behave as close to the new one as possible
private function SetupOldProjectileAsFace(
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
    //  still damages and explodes it
    oldProjectile.bHurtEntry = true;
    //  We can only make client-side projectile follow new server-side one for
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

//  `impactDamage` is separately defined in 4 different base classes of interest
//  and moving (or zeroing) it is cumbersome enough to warrant a separate method
private function MoveImpactDamage(
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
        newProjectileAsHarpoon.impactDamage =
            oldProjectileAsHarpoon.impactDamage;
        oldProjectileAsHarpoon.impactDamage = 0;
        return;
    }
}

//  Returns "fixed" class that no longer explodes from random damage
private final function class<ROBallisticProjectile> FindFixedClass(
    class<ROBallisticProjectile> projectileClass)
{
    local int                       i;
    local array<ReplacementRule>    rulesCopy;
    if (projectileClass == none) {
        return none;
    }
    rulesCopy = default.rules;
    for (i = 0; i < rulesCopy.length; i += 1)
    {
        if (rulesCopy[i].vulnerableClass == projectileClass) {
            return rulesCopy[i].protectedClass;
        }
    }
    return projectileClass;
}

//      Check if, according to this fix, projectiles should explode from
//  friendly fire
//      If `FixProjectileFF` in disabled always returns `false`.
public static final function bool IsFriendlyFireAcceptable()
{
    if (default.ignoreFriendlyFire) {
        return false;
    }
    return __server().unreal.GetKFGameType().friendlyFireScale > 0;
}

defaultproperties
{
    configClass = class'FixProjectileFF'
    ignoreFriendlyFire = false
    rules(0) = (vulnerableClass=class'KFMod.M79GrenadeProjectile',protectedClass=class'FixProjectileFFClass_M79GrenadeProjectile')
    rules(1) = (vulnerableClass=class'KFMod.M32GrenadeProjectile',protectedClass=class'FixProjectileFFClass_M32GrenadeProjectile')
    rules(2) = (vulnerableClass=class'KFMod.LAWProj',protectedClass=class'FixProjectileFFClass_LAWProj')
    rules(3) = (vulnerableClass=class'KFMod.M203GrenadeProjectile',protectedClass=class'FixProjectileFFClass_M203GrenadeProjectile')
    rules(4) = (vulnerableClass=class'KFMod.ZEDGunProjectile',protectedClass=class'FixProjectileFFClass_ZEDGunProjectile')
    rules(5) = (vulnerableClass=class'KFMod.ZEDMKIIPrimaryProjectile',protectedClass=class'FixProjectileFFClass_ZEDMKIIPrimaryProjectile')
    rules(6) = (vulnerableClass=class'KFMod.ZEDMKIISecondaryProjectile',protectedClass=class'FixProjectileFFClass_ZEDMKIISecondaryProjectile')
    rules(7) = (vulnerableClass=class'KFMod.FlareRevolverProjectile',protectedClass=class'FixProjectileFFClass_FlareRevolverProjectile')
    rules(8) = (vulnerableClass=class'KFMod.HuskGunProjectile',protectedClass=class'FixProjectileFFClass_HuskGunProjectile')
    rules(9) = (vulnerableClass=class'KFMod.SPGrenadeProjectile',protectedClass=class'FixProjectileFFClass_SPGrenadeProjectile')
    rules(10) = (vulnerableClass=class'KFMod.SealSquealProjectile',protectedClass=class'FixProjectileFFClass_SealSquealProjectile')
}