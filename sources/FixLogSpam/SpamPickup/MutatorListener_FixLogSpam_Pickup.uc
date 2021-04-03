/**
 *      Overloaded mutator events listener to catch and, possibly,
 *  prevent spawning `KFWeaponPickup` for fixing log spam related to them.
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
class MutatorListener_FixLogSpam_Pickup extends MutatorListenerBase
    abstract;

static function bool CheckReplacement(Actor other, out byte isSuperRelevant)
{
    local HelperPickup      helper;
    local KFWeaponPickup    otherPickup;
    otherPickup = KFWeaponPickup(other);
    if (otherPickup == none)    return true;
    helper = class'HelperPickup'.static.GetInstance();
    if (helper == none)         return true;

    helper.HandlePickup(otherPickup);
    return true;
}

defaultproperties
{
    relatedEvents = class'MutatorEvents'
}