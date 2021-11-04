/**
 *      This feature fixes different instances of log spam by the killing floor
 *  with various warnings and errors. Some of them have actual underlying bugs
 *  that need to be fixed, but a lot seem to be just a byproduct of dead and
 *  abandoned features or simple negligence.
 *      Whatever the case, now that TWI will no longer make any new changes to
 *  the game a lot of them do not serve any purpose and simply pollute
 *  log files. We try to get rid of at least some of them.
 *      Since changes we make do not actually have gameplay effect and
 *  are more aimed at convenience of server owners, our philosophy with the
 *  changes will be to avoid solutions that are way too "hacky" and prefer some
 *  message spam getting through to the possibility of some unexpected gameplay
 *  effects as far as vanilla game is concerned.
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
class FixLogSpam_Feature extends Feature;

//      This is responsible for fixing log spam due to picking up dropped
//  weapons without set `inventory` variable.
var private /*config*/ bool fixPickupSpam;
var private HelperPickup    helperPickupSpam;

var private /*config*/ bool fixTraderSpam;
var private HelperTrader    helperTraderSpam;

protected function OnEnabled()
{
    if (fixPickupSpam) {
        helperPickupSpam = HelperPickup(_.memory.Allocate(class'HelperPickup'));
    }
    if (fixTraderSpam) {
        helperTraderSpam = HelperTrader(_.memory.Allocate(class'HelperTrader'));
    }
}

protected function OnDisabled()
{
    _.memory.Free(helperPickupSpam);
    helperPickupSpam = none;
    _.memory.Free(helperTraderSpam);
    helperTraderSpam = none;
}

protected function SwapConfig(FeatureConfig config)
{
    local FixLogSpam newConfig;
    newConfig = FixLogSpam(config);
    if (newConfig == none) {
        return;
    }
    //  Pickup spam
    fixPickupSpam = newConfig.fixPickupSpam;
    if (fixPickupSpam && helperPickupSpam == none) {
        helperPickupSpam = HelperPickup(_.memory.Allocate(class'HelperPickup'));
    }
    if (!fixPickupSpam && helperPickupSpam != none)
    {
        _.memory.Free(helperPickupSpam);
        helperPickupSpam = none;
    }
    //  Trader fixTraderSpam
    fixTraderSpam = newConfig.fixTraderSpam;
    if (fixTraderSpam && helperTraderSpam == none) {
        helperTraderSpam = HelperTrader(_.memory.Allocate(class'HelperPickup'));
    }
    if (!fixTraderSpam && helperTraderSpam != none)
    {
        _.memory.Free(helperTraderSpam);
        helperTraderSpam = none;
    }
}

defaultproperties
{
    configClass = class'FixLogSpam'
    fixPickupSpam = true
    fixTraderSpam = true
}