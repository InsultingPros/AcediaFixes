/**
 *      This feature addressed two dosh-related issues:
 *      1.  Crashing servers by spamming 'CashPickup' actors with 'TossCash';
 *      2.  Breaking collision detection logic by stacking large amount of
 *      'CashPickup' actors in one place, which allows one to either
 *      reach unintended locations or even instantly kill zeds.
 *
 *      It fixes them by limiting speed, with which dosh can spawn, and
 *  allowing this limit to decrease when there's already too much dosh
 *  present on the map.
 *      Copyright 2019 - 2021 Anton Tarasenko
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
class FixDoshSpam_Feature extends Feature;

/**
 *      First, we limit amount of dosh that can be spawned simultaneously.
 *  The simplest method is to place a cooldown on spawning `CashPickup` actors,
 *  i.e. after spawning one `CashPickup` we'd completely prevent spawning
 *  any other instances of it for a fixed amount of time.
 *  However, that might allow a malicious spammer to block others from
 *  throwing dosh, - all he needs to do is to spam dosh at right time intervals.
 *      We'll resolve this issue by recording how many `CashPickup` actors
 *  each player has spawned as their "contribution" and decay
 *  that value with time, only allowing to spawn new dosh after
 *  contribution decayed to zero. Speed of decay is derived from current dosh
 *  spawning speed limit and decreases with amount of players
 *  with non-zero contributions (since it means that they're throwing dosh).
 *      Second issue is player amassing a large amount of dosh in one point
 *  that leads to skipping collision checks, which then allows players to pass
 *  through level geometry or enter zeds' collisions, instantly killing them.
 *  Since dosh disappears on it's own, the easiest method to prevent that is to
 *  severely limit how much dosh players can throw per second,
 *  so that there's never enough dosh laying around to affect collision logic.
 *  The downside to such severe limitations is that game behaves less
 *  vanilla-like, where you could throw away streams of dosh.
 *  To solve that we'll first use a more generous limit on dosh players can
 *  throw per second, but will track how much dosh is currently present
 *  in a level and linearly decelerate speed, according to that amount.
 */

//      Highest and lowest speed with which players can throw dosh wads.
//  It'll be evenly spread between all players.
//  For example, if speed is set to 6 and only one player will be spamming dosh,
//  - he'll be able to throw 6 wads of dosh per second;
//  but if all 6 players are spamming it, - each will throw only 1 per second.
//      NOTE: these speed values can be exceeded, since a player is guaranteed
//  to be able to throw at least one wad of dosh, if he didn't do so in awhile.
//      NOTE #2: if maximum value is less than minimum one,
//  the lowest (maximum one) will be used.
var private /*config*/ float doshPerSecondLimitMax;
var private /*config*/ float doshPerSecondLimitMin;
//      Amount of dosh pickups on the map at which we must set dosh per second
//  to `doshPerSecondLimitMin`.
//  We use `doshPerSecondLimitMax` when there's no dosh on the map and
//  scale linearly between them as it's amount grows.
var private /*config*/ int criticalDoshAmount;

//      We immediately reduce the rate dosh can be spawned at when players throw
//  new wads of cash. But, for performance reasons, we only periodically turn it
//  back up. This interval determines how often we check for whether it's okay
//  to raise the limit on the spawned dosh.
//      You should not set this value too high, it is recommended not to exceed
//  1 second.
var private /*config*/ float checkInterval;

//      This structure records how much a certain player has
//  contributed to an overall dosh creation.
struct DoshStreamPerPlayer
{
    //  Reference to `PlayerController`
    var NativeActorRef  player;
    //  Amount of dosh we remember this player creating, decays with time.
    var float           contribution;
};
var private array<DoshStreamPerPlayer> currentContributors;

//  Wads of cash that are lying around on the map.
var private array<NativeActorRef> wads;

//  Generates "reset" events when `wads` array is getting cleaned from
//  destroyed/picked up dosh and players' contributions are reduced.
var private Timer checkTimer;

protected function OnEnabled()
{
    local LevelInfo     level;
    local CashPickup    nextCash;
    checkTimer = _server.time.StartRealTimer(checkInterval, true);
    checkTimer.OnElapsed(self).connect = Tick;
    _server.unreal.mutator.OnCheckReplacement(self).connect = CheckReplacement;
    level = _server.unreal.GetLevel();
    //      Find all wads of cash laying around on the map,
    //  so that we could accordingly limit the cash spam.
    foreach level.DynamicActors(class'KFMod.CashPickup', nextCash) {
        wads[wads.length] = _server.unreal.ActorRef(nextCash);
    }
}

protected function OnDisabled()
{
    local int i;
    _.memory.FreeMany(wads);
    for (i = 0; i < currentContributors.length; i += 1) {
        currentContributors[i].player.FreeSelf();
    }
    wads.length                 = 0;
    currentContributors.length  = 0;
    _server.unreal.mutator.OnCheckReplacement(self).Disconnect();
    checkTimer.FreeSelf();
}

protected function SwapConfig(FeatureConfig config)
{
    local FixDoshSpam newConfig;
    newConfig = FixDoshSpam(config);
    if (newConfig == none) {
        return;
    }
    doshPerSecondLimitMax   = newConfig.doshPerSecondLimitMax;
    doshPerSecondLimitMin   = newConfig.doshPerSecondLimitMin;
    criticalDoshAmount      = newConfig.criticalDoshAmount;
    checkInterval           = newConfig.checkInterval;
    if (checkTimer != none) {
        checkTimer.SetInterval(checkInterval);
    }
}

private final function bool CheckReplacement(
    Actor       other,
    out byte    isSuperRelevant)
{
    local PlayerController player;
    if (other == none)                      return true;
    if (other.class != class'CashPickup')   return true;
    //      This means this dosh wasn't spawned in `TossCash()` of `KFPawn`,
    //  so it isn't related to the exploit we're trying to fix.
    if (other.instigator == none)           return true;

    //      We only want to prevent spawning cash if we're already over
    //  the limit and the one trying to throw this cash contributed to it.
    //  We allow other players to throw at least one wad of cash.
    player = PlayerController(other.instigator.controller);
    if (IsDoshStreamOverLimit() && IsContributor(player)) {
        return false;
    }
    //  If we do spawn cash - record this contribution.
    AddContribution(player, CashPickup(other));
    return true;
}

//  Did player with this controller contribute to the latest dosh generation?
public final function bool IsContributor(PlayerController player)
{
    return (GetContributorIndex(player) >= 0);
}

//  Did we already reach allowed limit of dosh per second?
public final function bool IsDoshStreamOverLimit()
{
    local int   i;
    local float overallContribution;
    local float allowedContribution;
    overallContribution = 0.0;
    for (i = 0; i < currentContributors.length; i += 1) {
        overallContribution += currentContributors[i].contribution;
    }
    allowedContribution = checkTimer.GetElapsedTime() * GetCurrentDPSLimit();
    return overallContribution > allowedContribution;
}

//  What is our current dosh per second limit?
private final function float GetCurrentDPSLimit()
{
    local float speedScale;
    if (doshPerSecondLimitMax < doshPerSecondLimitMin) {
        return doshPerSecondLimitMax;
    }
    speedScale = Float(wads.length) / Float(criticalDoshAmount);
    speedScale = FClamp(speedScale, 0.0, 1.0);
    //  At 0.0 scale (no dosh on the map)       - use max speed
    //  At 1.0 scale (critical dosh on the map) - use min speed
    return Lerp(speedScale, doshPerSecondLimitMax, doshPerSecondLimitMin);
}

//  Returns index of the contributor corresponding to the given controller.
//  Returns `-1` if no connection correspond to the given controller.
//  Returns `-1` if given controller is equal to `none`.
private final function int GetContributorIndex(PlayerController player)
{
    local int i;
    if (player == none) return -1;

    for (i = 0; i < currentContributors.length; i += 1)
    {
        if (currentContributors[i].player.Get() == player) {
            return i;
        }
    }
    return -1;
}

//      Adds given cash to given player contribution record and
//  registers that cash in our wads array.
public final function AddContribution(PlayerController player, CashPickup cash)
{
    local int                   playerIndex;
    local DoshStreamPerPlayer   newStreamRecord;
    wads[wads.length] = _server.unreal.ActorRef(cash);
    //  Add contribution to player
    playerIndex = GetContributorIndex(player);
    if (playerIndex >= 0)
    {
        currentContributors[playerIndex].contribution += 1.0;
        return;
    }
    newStreamRecord.player          = _server.unreal.ActorRef(player);
    newStreamRecord.contribution    = 1.0;
    currentContributors[currentContributors.length] = newStreamRecord;
}

private final function ReducePlayerContributions()
{
    local int   i;
    local float streamReduction;
    streamReduction = checkInterval *
        (GetCurrentDPSLimit() / currentContributors.length);
    for (i = 0; i < currentContributors.length; i += 1) {
        currentContributors[i].contribution -= streamReduction;
    }
}

//  Clean out wads that disappeared or were picked up by players.
private final function CleanWadsArray()
{
    local int i;
    i = 0;
    while (i < wads.length)
    {
        if (wads[i].Get() == none)
        {
            wads[i].FreeSelf();
            wads.Remove(i, 1);
        }
        else {
            i += 1;
        }
    }
}

//  Don't track players that no longer contribute to dosh generation.
private final function RemoveNonContributors()
{
    local int                           i;
    local array<DoshStreamPerPlayer>    updContributors;
    for (i = 0; i < currentContributors.length; i += 1)
    {
        //      We want to keep on record even players that quit,
        //  since their contribution still must be accounted for.
        if (currentContributors[i].contribution <= 0.0) {
            currentContributors[i].player.FreeSelf();
        }
        else {
            updContributors[updContributors.length] = currentContributors[i];
        }
    }
    currentContributors = updContributors;
}

private function Tick(Timer source)
{
    CleanWadsArray();
    ReducePlayerContributions();
    RemoveNonContributors();
}

defaultproperties
{
    configClass = class'FixDoshSpam'
    doshPerSecondLimitMax   = 50
    doshPerSecondLimitMin   = 5
    criticalDoshAmount      = 25
    checkInterval           = 0.25
}