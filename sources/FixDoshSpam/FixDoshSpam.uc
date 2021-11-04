/**
 *      Config object for `FixDoshSpam_Feature`.
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
class FixDoshSpam extends FeatureConfig
    perobjectconfig
    config(AcediaFixes);

var public /*config*/ float doshPerSecondLimitMax;
var public /*config*/ float doshPerSecondLimitMin;
var public /*config*/ int   criticalDoshAmount;
var public /*config*/ float checkInterval;

protected function AssociativeArray ToData()
{
    local AssociativeArray data;
    data = __().collections.EmptyAssociativeArray();
    data.SetFloat(P("doshPerSecondLimitMax"), doshPerSecondLimitMax, true);
    data.SetFloat(P("doshPerSecondLimitMin"), doshPerSecondLimitMin, true);
    data.SetInt(P("criticalDoshAmount"), criticalDoshAmount, true);
    data.SetFloat(P("checkInterval"), checkInterval, true);
    return data;
}

protected function FromData(AssociativeArray source)
{
    if (source != none)
    {
        doshPerSecondLimitMax = source.GetFloat(P("doshPerSecondLimitMax"), 50);
        doshPerSecondLimitMin = source.GetFloat(P("doshPerSecondLimitMin"), 5);
        criticalDoshAmount = source.GetInt(P("criticalDoshAmount"), 25);
        checkInterval = source.GetFloat(P("checkInterval"), 0.25);
    }
}

protected function DefaultIt()
{
    doshPerSecondLimitMax   = 50;
    doshPerSecondLimitMin   = 5;
    criticalDoshAmount      = 25;
    checkInterval           = 0.25;
}

defaultproperties
{
    configName = "AcediaFixes"
    doshPerSecondLimitMax   = 50
    doshPerSecondLimitMin   = 5
    criticalDoshAmount      = 25
    checkInterval           = 0.25
}