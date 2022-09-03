/**
 *      Config object for `FixDoshSpam_Feature`.
 *      Copyright 2021-2022 Anton Tarasenko
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

var public config float doshPerSecondLimitMax;
var public config float doshPerSecondLimitMin;
var public config int   criticalDoshAmount;
var public config float checkInterval;

protected function HashTable ToData()
{
    local HashTable data;
    data = __().collections.EmptyHashTable();
    data.SetFloat(P("doshPerSecondLimitMax"), doshPerSecondLimitMax);
    data.SetFloat(P("doshPerSecondLimitMin"), doshPerSecondLimitMin);
    data.SetInt(P("criticalDoshAmount"), criticalDoshAmount);
    data.SetFloat(P("checkInterval"), checkInterval);
    return data;
}

protected function FromData(HashTable source)
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