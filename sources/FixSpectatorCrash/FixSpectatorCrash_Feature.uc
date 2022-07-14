/**
 *      This feature attempts to prevent server crashes caused by someone
 *  quickly switching between being spectator and an active player.
 *
 *      We do so by disconnecting players who start switching way too fast
 *  (more than twice in a short amount of time) and temporarily faking a large
 *  amount of players on the server, to prevent such spam from affecting the server.
 *      Copyright 2020 Anton Tarasenko
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
class FixSpectatorCrash_Feature extends Feature
    dependson(ConnectionService);

/**
 *      We use broadcast events to track when someone is switching
 *  to active player or spectator and remember such people
 *  for a short time (cooldown), defined by (`spectatorChangeTimeout`).
 *  If one of the player we've remembered tries to switch again,
 *  before the defined cooldown ran out, - we kick him
 *  by destroying his controller.
 *      One possible problem arises from the fact that controllers aren't
 *  immediately destroyed and instead initiate player disconnection, -
 *  exploiter might have enough time to cause a lag or even crash the server.
 *  We address this issue by temporarily blocking anyone from
 *  becoming active player (we do this by setting `numPlayers` variable in
 *  killing floor's game info to a large value).
 *  After all malicious players have successfully disconnected, -
 *  we remove the block.
 */

//      This fix will try to kick any player that switches between active player
//  and cooldown faster than time (in seconds) in this value.
//      NOTE: raising this value past default value of `0.25`
//  won't actually improve crash prevention.
var private config float    spectatorChangeTimeout;

//      [ADVANCED] Don't change this setting unless you know what you're doing.
//      Allows you to turn off server blocking.
//  Players that don't respect timeout will still be kicked.
//      This might be needed if this fix conflicts with another mutator
//  that also changes `numPlayers`.
//  However, it is necessary to block aggressive enough server crash attempts,
//  but can cause compatibility issues with some mutators.
//  It's highly preferred to rewrite such a mutator to be compatible.
//      NOTE: it should be compatible with most faked players-type mutators,
//  since this fix remembers the difference between amount of
//  real players and `numPlayers`.
//  After unblocking, it sets `numPlayers` to
//  the current amount of real players + that difference.
//  So 4 players + 3 (=7 numPlayers) after kicking 1 player becomes
//  3 players + 3 (=6 numPlayers).
var private config bool     allowServerBlock;

//      Stores remaining cooldown value before the next allowed
//  spectator change per player.
struct CooldownRecord
{
    //  Reference to `PlayerController`
    var NativeActorRef  player;
    var float           cooldown;
};

//  Currently active cooldowns
var private array<CooldownRecord> currentCooldowns;

//      Players who were decided to be violators and
//  were marked for disconnecting.
//      We'll be maintaining server block as long as even one
//  of them hasn't yet disconnected.
//      References to `PlayerController`s.
var private array<NativeActorRef> violators;

//  Is server currently blocked?
var private bool    becomingActiveBlocked;
//      This value introduced to accommodate mods such as faked player that can
//  change `numPlayers` to a value that isn't directly tied to the
//  current number of active players.
//      We remember the difference between active players and `numPlayers`
/// variable in game type before server block and add it after block is over.
//  If some mod introduces a more complicated relation between amount of
//  active players and `numPlayers`, then it must take care of
//  compatibility on it's own.
var private int     recordedNumPlayersMod;

//  IDs of localized messages, ripped from sources
var private const int becomeAlivePlayerID;
var private const int becomeSpectatorID;

protected function OnEnabled()
{
    _server.unreal.OnTick(self).connect = Tick;
    _server.unreal.broadcasts.OnHandleLocalized(self).connect = HandleLocalized;
}

protected function OnDisabled()
{
    _server.unreal.OnTick(self).Disconnect();
    _server.unreal.broadcasts.OnHandleLocalized(self).Disconnect();
}

protected function SwapConfig(FeatureConfig config)
{
    local FixSpectatorCrash newConfig;
    newConfig = FixSpectatorCrash(config);
    if (newConfig == none) {
        return;
    }
    spectatorChangeTimeout  = newConfig.spectatorChangeTimeout;
    allowServerBlock        = newConfig.allowServerBlock;
}

private function bool HandleLocalized(
    Actor                           sender,
    BroadcastAPI.LocalizedMessage   message)
{
    local PlayerController senderController;
    if (sender == none)                                         return true;
    if (sender.level == none || sender.level.game == none)      return true;
    if (message.class != sender.level.game.gameMessageClass)    return true;
    if (    message.id != default.becomeAlivePlayerID
        &&  message.id != default.becomeSpectatorID)            return true;

    senderController = GetController(sender);
    NotifyStatusChange(senderController);
    return (!IsViolator(senderController));
}

private final function PlayerController GetController(Actor sender)
{
    local Pawn senderPawn;
    senderPawn = Pawn(sender);
    if (senderPawn != none) {
        return PlayerController(senderPawn.controller);
    }
    return PlayerController(sender);
}

//      If given `PlayerController` is registered in our cooldown records, -
//  returns it's index.
//      If it doesn't exists (or `none` value was passes), - returns `-1`.
private final function int GetCooldownIndex(PlayerController player)
{
    local int i;
    if (player == none) return -1;

    for (i = 0; i < currentCooldowns.length; i += 1)
    {
        if (currentCooldowns[i].player.Get() == player) {
            return i;
        }
    }
    return -1;
}

//  Checks if given `PlayerController` is registered as a violator.
//  `none` value isn't a violator.
public final function bool IsViolator(PlayerController player)
{
    local int i;
    if (player == none) return false;

    for (i = 0; i < violators.length; i += 1)
    {
        if (violators[i].Get() == player) {
            return true;
        }
    }
    return false;
}

//      This function is to notify our fix that some player just changed status
//  of active player / spectator.
//  If passes value isn't `none`, it puts given player on cooldown or kicks him.
public final function NotifyStatusChange(PlayerController player)
{
    local int               index;
    local CooldownRecord    newRecord;
    if (player == none) return;

    index = GetCooldownIndex(player);
    //  Players already on cool down must be kicked and marked as violators
    if (index >= 0)
    {
        player.Destroy();
        violators[violators.length] = currentCooldowns[index].player;
        currentCooldowns.Remove(index, 1);
        if (allowServerBlock) {
            SetBlock(true);
        }
    }
    //      Players that aren't on cooldown are
    //  either violators (do nothing, just wait for their disconnect)
    //  or didn't recently change their status (put them on cooldown).
    else if (!IsViolator(player))
    {
        newRecord.player    = _server.unreal.ActorRef(player);
        newRecord.cooldown  = spectatorChangeTimeout;
        currentCooldowns[currentCooldowns.length] = newRecord;
    }
}

//  Pass `true` to block server, `false` to unblock.
//  Only works if `allowServerBlock` is set to `true`.
private final function SetBlock(bool activateBlock)
{
    local KFGameType kfGameType;
    //  Do we even need to do anything?
    if (!allowServerBlock)                      return;
    if (activateBlock == becomingActiveBlocked) return;

    //  Actually block/unblock
    kfGameType = _server.unreal.GetKFGameType();
    becomingActiveBlocked = activateBlock;
    if (activateBlock)
    {
        recordedNumPlayersMod = GetNumPlayersMod();
        //      This value both can't realistically fall below
        //  `kfGameType.maxPlayer` and won't overflow from random increase
        //  in vanilla code.
        kfGameType.numPlayers = maxInt / 2;
    }
    else
    {
        //      Adding `recordedNumPlayersMod` should prevent
        //  faked players from breaking.
        kfGameType.numPlayers = GetRealPlayers() + recordedNumPlayersMod;
    }
}

//  Performs server blocking if violators have disconnected.
private final function TryUnblocking()
{
    local int i;
    if (!allowServerBlock)      return;
    if (!becomingActiveBlocked) return;

    for (i = 0; i < violators.length; i += 1)
    {
        if (violators[i].Get() != none) {
            return;
        }
    }
    _.memory.FreeMany(violators);
    violators.length = 0;
    SetBlock(false);
}

//      Counts current amount of "real" active players
//  (connected to the server and not spectators).
//      Need `ConnectionService` to be running, otherwise return `-1`.
private final function int GetRealPlayers()
{
    //  Auxiliary variables
    local int               i;
    local int               realPlayersAmount;
    local PlayerController  player;
    //  Information extraction
    local ConnectionService                     service;
    local array<ConnectionService.Connection>   connections;
    service = ConnectionService(class'ConnectionService'.static.GetInstance());
    if (service == none) return -1;

    //  Count non-spectators
    connections = service.GetActiveConnections();
    realPlayersAmount = 0;
    for (i = 0; i < connections.length; i += 1)
    {
        player = connections[i].controllerReference;
        if (player == none)                         continue;
        if (player.playerReplicationInfo == none)   continue;
        if (!player.playerReplicationInfo.bOnlySpectator) {
            realPlayersAmount += 1;
        }
    }
    return realPlayersAmount;
}

//      Calculates difference between current amount of "real" active players
//  and `numPlayers` from `KFGameType`.
//  Most typically this difference will be non-zero when using
//  faked players-type mutators
//  (difference will be equal to the amount of faked players).
private final function int GetNumPlayersMod()
{
    return _server.unreal.GetKFGameType().numPlayers - GetRealPlayers();
}

private final function ReduceCooldowns(float timePassed)
{
    local int i;
    i = 0;
    while (i < currentCooldowns.length)
    {
        currentCooldowns[i].cooldown -= timePassed;
        if (    currentCooldowns[i].player.Get() != none
            &&  currentCooldowns[i].cooldown > 0.0)
        {
            i += 1;
        }
        else
        {
            currentCooldowns[i].player.FreeSelf();
            currentCooldowns.Remove(i, 1);
        }
    }
}

private function Tick(float delta, float tileDilationCoefficient)
{
    local float trueTimePassed;
    trueTimePassed = delta / tileDilationCoefficient;
    TryUnblocking();
    ReduceCooldowns(trueTimePassed);
}

defaultproperties
{
    configClass = class'FixSpectatorCrash'
    //  Configurable variables
    spectatorChangeTimeout  = 0.25
    allowServerBlock        = true
    //  Inner variables
    becomingActiveBlocked   = false
    //  Ripped IDs of localized messages of interest
    becomeAlivePlayerID = 1
    becomeSpectatorID   = 14
}