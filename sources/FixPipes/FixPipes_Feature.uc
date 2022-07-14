/**
 *      This feature addresses several bugs related to pipe bombs:
 *      1. Gaining extra explosive damage by shooting pipes with
 *          a high fire rate weapon;
 *      2. Other players exploding one's pipes;
 *      3. Corpses and story NPCs exploding nearby pipes;
 *      4. Pipes being stuck in places where they cannot detect nearby
 *          enemies and, therefore, not exploding.
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
class FixPipes_Feature extends Feature;

/**
 *      There are two main culprits for the issues we are interested in:
 *  `TakeDamage()` and `Timer()` methods. `TakeDamage()` lacks sufficient checks
 *  for instigator allows for ways to damage it, causing explosion. It also
 *  lacks any checks for whether pipe bom already exploded, allowing players to
 *  damage it several time before it's destroyed, causing explosion every time.
 *  `Timer()` method simply contains a porximity check for hostile pawns that
 *  wrongfully detects certain actor (like `KF_StoryNPC` or players' corpses)
 *  and cannot detect zeds around itself if pipe is placed in a way that
 *  prevents it from having a direct line of sight towards zeds.
 *      To fix our issues we have to somehow overload both of these methods,
 *  which is impossible while keeping Acedia server-side. So we will have to
 *  do some hacks.
 *
 *      `TakeDamage()`. To override this method's behavior we will remove actor
 *  collision from pipe bombs, preventing it from being directly damaged, then
 *  add an `ExtendedZCollision` subclass around it to catch `TakeDamage()`
 *  events that would normally target pipe bombs themselves. There we can add
 *  additional checks to help us decide whether pipe bombs should actually
 *  be damaged.
 *
 *      `Timer()`. It would be simple to take control of this method by, say,
 *  spamming `SetTimer(0.0, false)` every tick and then executing our own logic
 *  elsewhere. However we only care about changin `Timer()`'s logic when pipe
 *  bomb attempts to detect cnearby enemies and do not want to manage the rest
 *  of `Timer()`'s logic.
 *      Pipe bombs work like this: after being thrown they fall until they land,
 *  invoking `Landed()` and `HitWall()` calls that start up the timer. Then
 *  timer uses `ArmingCountDown` variable to count down the time for pipe to
 *  "arm", that is, start functioning. It's after that that pipe starts to try
 *  and detect nearby enemies until it decides to start exploding sequence,
 *  instantly exploded with damage or disintegrated by siren's scream.
 *      We want to catch the moment when `ArmingCountDown` reaches zero and
 *  only then disable the timer. Then case we'll only need to reimplement logic
 *  that takes care of enemy detection. We also do not need to constantly
 *  re-reset the timer, since any code that will restart it would mean that
 *  pipe bomb no longer needs to look for enemies.
 *      When we detect enough enemies nearby or a change in pipe bomb's state
 *  due to outside factors (being exploded or disintegrated) we simply need to
 *  start it's the timer (if it was not done for us already).
 */

//      NOTE #1: setting either of `preventMassiveDamage` or
//  `preventSuspiciousDamage` might change how and where pipes might fall on
//  the ground (for example, pipe hats shoul not work anymore). In most cases,
//  however, there should be no difference from vanilla gameplay.
//      Setting this to `true` fixes a mechanic that allows pipes to deal extra
//  damage when detonated with a high fire rate weapons: pipes will now always
//  deal the same amount of damage.
var public /*config*/ bool  preventMassiveDamage;
//      It's possible for teammates to explode one's pipe under certain
//  circumstances. Setting this setting to `true` will prevent that
//  from happening.
var public /*config*/ bool  preventSuspiciousDamage;
//      Setting this to `true` will prevent pipe bombs from being detonated by
//  the nearby corpses on other player.
var public /*config*/ bool  preventCorpseDetonation;
//      Setting this to `true` will prevents pipe bombs from being detonated by
//  nearby KFO NPCs (Ringmaster Lockheart).
var public /*config*/ bool  preventNPCDetonation;
//      Certain spots prevent pipe bombs from having a line of sight to the
//  nearby zeds, preventing them from ever exploding. This issue can be resolves
//  by checking zed's proximity not to the pipe itself, but to a point directly
//  above it (20 units above by default).
//      If you wish to disable this part of the feature - set it to zero or
//  negative value. Otherwise it is suggested to keep it at `20`.
var public /*config*/ float proximityCheckElevation;

//      Since this feature needs to do proximity check instead of pipes, we will
//  need to track all the pipes we will be doing checks for.
//      This struct contains all reference to the pipe itself and everything
//  else we need to track.
struct PipeRecord
{
    //  Pipe that this record tracks.
    //  Reference to `PipeBombProjectile`.
    var NativeActorRef  pipe;
    //  Each pipe has a separate timer for their scheduled proximity checks,
    //  so we need a separate variable to track when that time comes for
    //  each and every pipe 
    var float           timerCountDown;
    //  `true` if we have already intercepted (and replaced with our own)
    //  the proximity check for the pipe in this record
    var bool            proximityCheckIntercepted;
    //      Reference to the `ExtendedZCollision` we created to catch
    //  `TakeDamage()` event.
    //      Reference to `PipesSafetyCollision`.
    var NativeActorRef  safetyCollision;
};
var private array<PipeRecord> pipeRecords;

//  Store the `bAlwaysRelevant` of the `class'PipeBombProjectile'` before this
//  feature activated to restore it in case it gets disabled
//  (we need to change `bAlwaysRelevant` in order to catch events of
//  pipe bombs spawning).
var private bool pipesRelevancyFlag;

var private Timer cleanupTimer;

protected function OnEnabled()
{
    local LevelInfo             level;
    local PipeBombProjectile    nextPipe;
    pipesRelevancyFlag = class'PipeBombProjectile'.default.bAlwaysRelevant;
    class'PipeBombProjectile'.default.bGameRelevant = false;
    _server.unreal.mutator.OnCheckReplacement(self).connect = CheckReplacement;
    //  Set cleanup timer, there is little point to making
    //  clean up interval configurable.
    cleanupTimer = _server.time.StartTimer(5.0, true);
    cleanupTimer.OnElapsed(self).connect = CleanPipeRecords;
    //  Fix pipes that are already lying about on the map
    level = _server.unreal.GetLevel();
    foreach level.DynamicActors(class'KFMod.PipeBombProjectile', nextPipe) {
        RegisterPipe(nextPipe);
    }
}

protected function OnDisabled()
{
    local int i;
    class'PipeBombProjectile'.default.bGameRelevant = pipesRelevancyFlag;
    _server.unreal.mutator.OnCheckReplacement(self).Disconnect();
    cleanupTimer.FreeSelf();
    for (i = 0; i < pipeRecords.length; i += 1) {
        ReleasePipe(pipeRecords[i]);
    }
    pipeRecords.length = 0;
}

protected function SwapConfig(FeatureConfig config)
{
    local int       i;
    local FixPipes  newConfig;
    newConfig = FixPipes(config);
    if (newConfig == none) {
        return;
    }
    preventMassiveDamage    = newConfig.preventMassiveDamage;
    preventSuspiciousDamage = newConfig.preventSuspiciousDamage;
    preventCorpseDetonation = newConfig.preventCorpseDetonation;
    preventNPCDetonation    = newConfig.preventNPCDetonation;
    proximityCheckElevation = newConfig.proximityCheckElevation;
    for (i = 0; i < pipeRecords.length; i += 1)
    {
        ReleasePipe(pipeRecords[i]);
        RegisterPipe(PipeBombProjectile(pipeRecords[i].safetyCollision.Get()));
    }
}

private function bool CheckReplacement(Actor other, out byte isSuperRelevant)
{
    local PipeBombProjectile pipeProjectile;
    pipeProjectile = PipeBombProjectile(other);
    if (pipeProjectile != none) {
        RegisterPipe(PipeBombProjectile(other));
    }
    return true;
}

//  Adds new pipe to our list and does necessary steps to replace logic of
//  `TakeDamage()` and `Timer()` methods.
public final function RegisterPipe(PipeBombProjectile newPipe)
{
    local int           i;
    local PipeRecord    newRecord;
    if (newPipe == none) {
        return;
    }
    //  Check whether we have already added this pipe
    for (i = 0; i < pipeRecords.length; i += 1)
    {
        if (pipeRecords[i].pipe.Get() == newPipe) {
            return;
        }
    }
    newRecord.pipe = _server.unreal.ActorRef(newPipe);
    //  Setup `PipesSafetyCollision` for catching `TakeDamage()` events
    //  (only if we need to according to settings)
    if (NeedSafetyCollision())
    {
        newRecord.safetyCollision = _server.unreal.ActorRef(
            class'PipesSafetyCollision'.static.ProtectPipes(newPipe));
    }
    pipeRecords[pipeRecords.length] = newRecord;
    //  Intercept proximity checks (only if we need to according to settings)
    if (NeedManagedProximityChecks())
    {
        //  We do this after we have added new pipe record to the complete list
        //  so that we can redo the check early for
        //  the previously recorded pipes
        InterceptProximityChecks();
    }
}

//  Rolls back our changes to the pipe in the given `PipeRecord`.
public final function ReleasePipe(PipeRecord pipeRecord)
{
    local PipeBombProjectile    pipe;
    local PipesSafetyCollision  safetyCollision;
    if (pipeRecord.safetyCollision != none)
    {
        safetyCollision =
            PipesSafetyCollision(pipeRecord.safetyCollision.Get());
        pipeRecord.safetyCollision.FreeSelf();
        pipeRecord.safetyCollision = none;
    }
    if (safetyCollision != none) {
        safetyCollision.TurnOff();
    }
    pipe = PipeBombProjectile(pipeRecord.pipe.Get());
    pipeRecord.pipe.FreeSelf();
    pipeRecord.pipe = none;
    if (pipeRecord.proximityCheckIntercepted && pipe != none)
    {
        pipeRecord.proximityCheckIntercepted = false;
        if (IsPipeDoingProximityChecks(pipe)) {
            pipe.SetTimer(pipeRecord.timerCountDown, true);
        }
    }
}

//  Checks whether we actually need to use replace logic of `TakeDamage()`
//  method according to settings.
private final function bool NeedSafetyCollision()
{
    if (preventMassiveDamage)       return true;
    if (preventSuspiciousDamage)    return true;
    return false;
}

//  Checks whether we actually need to use replace logic of `Timer()`
//  method according to settings.
private final function bool NeedManagedProximityChecks()
{
    if (preventCorpseDetonation)        return true;
    if (preventNPCDetonation)           return true;
    if (proximityCheckElevation > 0.0)  return true;
    return false;
}

//  Removes dead records with pipe instances turned into `none`
private final function CleanPipeRecords(Timer source)
{
    local int i;
    while (i < pipeRecords.length)
    {
        if (pipeRecords[i].pipe.Get() == none)
        {
            _.memory.Free(pipeRecords[i].pipe);
            _.memory.Free(pipeRecords[i].safetyCollision);
            pipeRecords.Remove(i, 1);
        }
        else {
            i += 1;
        }
    }
}

//  Tries to replace logic of `SetTimer()` with our own for every pipe we
//  keep track of that:
//      1. Started doing proximity checks;
//      2. Have not yet had it's logic replaced.
private final function InterceptProximityChecks()
{
    local int                   i;
    local PipeBombProjectile    nextPipe;
    for (i = 0; i < pipeRecords.length; i += 1)
    {
        if (pipeRecords[i].proximityCheckIntercepted)   continue;
        nextPipe = PipeBombProjectile(pipeRecords[i].pipe.Get());
        if (nextPipe == none)                           continue;

        if (IsPipeDoingProximityChecks(nextPipe))
        {
            //  Turn off pipe's own timer
            nextPipe.SetTimer(0, false);
            //  We set `1.0` because that is the vanilla value;
            //  Line 123 of "PipeBombProjectile.uc": `SetTimer(1.0,True);`
            pipeRecords[i].timerCountDown = 1.0;
            pipeRecords[i].proximityCheckIntercepted = true;
        }
    }
}

//  Assumes `pipe != none`
private final function bool IsPipeDoingProximityChecks(PipeBombProjectile pipe)
{
    //  These checks need to pass so that `Timer()` call from
    //  "PipeBombProjectile.uc" enters the proximity check code
    //  (starting at line 131)
    if (pipe.bHidden)           return false;
    if (pipe.bTriggered)        return false;
    if (pipe.bEnemyDetected)    return false;
    return (pipe.armingCountDown < 0);
}

//  Checks what pipes have their timers run out and doing proximity checks
//  for them
private final function PerformProximityChecks(float delta)
{
    local int                   i;
    local Vector                checkLocation;
    local PipeBombProjectile    nextPipe;
    for (i = 0; i < pipeRecords.length; i += 1)
    {
        pipeRecords[i].timerCountDown -= delta;
        if (pipeRecords[i].timerCountDown > 0)      continue;
        nextPipe = PipeBombProjectile(pipeRecords[i].pipe.Get());
        if (nextPipe == none)                       continue;
        //  `timerCountDown` does not makes sense for pipes that
        //  are not doing proxiity checks
        if (!IsPipeDoingProximityChecks(nextPipe))  continue;

        checkLocation = nextPipe.location;
        if (proximityCheckElevation > 0) {
            checkLocation.z += proximityCheckElevation;
        }
        //  This method repeats vanilla logic with some additional checks
        //  and sets new timers by itself
        DoPipeProximityCheck(pipeRecords[i], checkLocation);
    }
}

//      Original code is somewhat messy and was reworked in this more manageble
//  form as core logic is simple - for every nearby `Pawn` we increase the
//  percieved level for the pipe and when it reaches certain threshold
//  (`threatThreshhold = 1.0`) pipe explodes.
//      In native logic there are three cases for increasing threat level:
//          1. Zeds increase it by a certain predefined
//              (in `KFMonster` class amount);
//          2. Instigator (and his team, in case friendly fire is enabled and
//              they can be hurt by pipes) raise threat level by a negligible
//              amount (`0.001`) that will not lead to pipes exploding, but
//              will cause them to beep faster, warning about the danger;
//          3. Some wacky code to check whether the `Pawn` is on the same team.
//              In a regualar killing floor game only something that is neither
//              player or zed can fit that. This is what causes corpses and
//              KFO NPCs to explode pipes.
//                  Threat level is not directly set in vanilla code for
//              this case, instead performing two operations
//              `bEnemyDetected=true;` and `SetTimer(0.15,True);`.
//              However, given the code that follows these calls, executing them
//              is equivalent to adding `threatThreshhold` to the current
//              threat level. Which is what we do here instead.
private final function DoPipeProximityCheck(
    out PipeRecord  pipeRecord,
    Vector          checkLocation)
{
    local Pawn                  checkPawn;
    local float                 threatLevel;
    local PipeBombProjectile    pipe;
    pipe = PipeBombProjectile(pipeRecord.pipe.Get());
    if (pipe == none) {
        return;
    }
    pipe.bAlwaysRelevant = false;
    pipe.PlaySound(pipe.beepSound,, 0.5,, 50.0);
    //  Out rewritten logic, which should do exactly the same:
    foreach pipe.VisibleCollidingActors(    class'Pawn', checkPawn,
                                            pipe.detectionRadius, checkLocation)
    {
        threatLevel += GetThreatLevel(pipe, checkPawn);
        //  Explosion! No need to bother with the rest of the `Pawn`s.
        if (threatLevel >= pipe.threatThreshhold) {
            break;
        }
    }
    //  Resume vanilla code from "PipeBombProjectile.uc", lines from 169 to 181:
    if(threatLevel >= pipe.threatThreshhold)
    {
        pipe.bEnemyDetected = true;
        pipe.SetTimer(0.15, true);
    }
    else if(threatLevel > 0) {
        pipeRecord.timerCountDown = 0.5;
    }
    else {
        pipeRecord.timerCountDown = 1.0;
    }
}

//  Threat level calculations are moves to a separate method to make algorithm
//  less cumbersome
private final function float GetThreatLevel(
    PipeBombProjectile  pipe,
    Pawn                checkPawn)
{
    local bool                  onSameTeam;
    local bool                  friendlyFireEnabled;
    local KFGameType            kfGame;
    local PlayerReplicationInfo playerRI;
    local KFMonster             zed;
    if (pipe == none)       return 0.0;
    if (checkPawn == none)  return 0.0;

    playerRI = checkPawn.playerReplicationInfo;
    if (pipe.level != none) {
        kfGame = KFGameType(pipe.level.game);
    }
    if (kfGame != none) {
        friendlyFireEnabled = kfGame.friendlyFireScale > 0;
    }
    //  Warn teammates about pipes
    onSameTeam = playerRI != none && playerRI.team.teamIndex == pipe.placedTeam;
    if (checkPawn == pipe.instigator || (friendlyFireEnabled && onSameTeam)) {
        return 0.001;
    }
    //  Count zed's threat score
    zed = KFMonster(checkPawn);
    if (zed != none) {
        return zed.motionDetectorThreat;
    }
    //  Managed checks
    if (preventCorpseDetonation && checkPawn.health <= 0) {
        return 0.0;
    }
    if (preventNPCDetonation && KF_StoryNPC(CheckPawn) != none) {
        return 0.0;
    }
    //  Something weird demands a special full-alert treatment.
    //  Some checks are removed:
    //      1. Removed `checkPawn.Role == ROLE_Authority` check, since we are
    //          working on server exclusively;
    //      2. Removed `checkPawn != instigator` since, if
    //          `checkPawn == pipe.instigator`, previous `if` block will
    //          prevent us from reaching this point
    if(     playerRI != none && playerRI.team.teamIndex != pipe.placedTeam
        ||  checkPawn.GetTeamNum() != pipe.placedTeam)
    {
        //  Full threat score
        return pipe.threatThreshhold;
    }
    return 0.0;
}

event Tick(float delta)
{
    if (NeedManagedProximityChecks())
    {
        InterceptProximityChecks();
        PerformProximityChecks(delta);
    }
}

defaultproperties
{
    configClass = class'FixPipes'
    preventMassiveDamage    = true
    preventSuspiciousDamage = true
    preventCorpseDetonation = true
    preventNPCDetonation    = true
    proximityCheckElevation = 20.0
}