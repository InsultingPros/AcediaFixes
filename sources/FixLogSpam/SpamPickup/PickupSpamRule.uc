/**
 *      This rule detects when someone is trying to... pick up a pickup and
 *  forces additional fixing update on all the ones, dropped by players.
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
class PickupSpamRule extends GameRules;

function bool OverridePickupQuery(
    Pawn        toucher,
    Pickup      touchedPickup,
    out byte    allowPickup)
{
    local HelperPickup helper;
    helper = class'HelperPickup'.static.GetInstance();
    if (helper != none) {
        helper.UpdatePickups();
    }
    return super.OverridePickupQuery(toucher, touchedPickup, allowPickup);
}

defaultproperties
{
}