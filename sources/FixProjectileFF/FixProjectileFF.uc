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
class FixProjectileFF extends Feature
    config(AcediaFixes);

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
 *      Issue arises from the fact that these two projectiles can desyncronize:
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
 *      2. `bNetTemporary == true`: projectile version on client side is
 *          actually syncronized with the server-side's one. In this case we
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
var private config bool ignoreFriendlyFire;

//  Stores what pairs of projectile classes that describe what (vulnerable)
//  class must be repalced with what (protected class). It also remembers the
//  previous state of `bGameRelevant` for replacable class to restore it in case
//  this feature is disabled.
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
}

//  Returns "fixed" class that no longer explodes from random damage
public final static function class<ROBallisticProjectile> FindFixedClass(
    class<ROBallisticProjectile> projectileClass)
{
    local int                       i;
    local array<ReplacementRule>    rulesCopy;
    if (projectileClass == none) return none;

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
public final static function bool IsFriendlyFireAcceptable()
{
    local TeamGame          gameType;
    local FixProjectileFF   projectileFFFix;
    projectileFFFix = FixProjectileFF(GetInstance());
    if (projectileFFFix == none)            return false;
    if (projectileFFFix.ignoreFriendlyFire) return false;
    if (projectileFFFix.level == none)      return false;
    gameType = TeamGame(projectileFFFix.level.game);
    if (gameType == none)                   return false;

    return gameType.friendlyFireScale > 0;
}

defaultproperties
{
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
    //  Listeners
    requiredListeners(0) = class'MutatorListener_FixProjectileFF'
}